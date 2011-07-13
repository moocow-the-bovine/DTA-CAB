## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Fork::Pool.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: generic thread pool for DTA::CAB

package DTA::CAB::Fork::Pool;
use DTA::CAB::Queue::File;
use POSIX qw(:sys_wait_h);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Logger);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fp = CLASS_OR_OBJ->new(%args)
##  + %$fp, %args:
##    {
##     ##-- queue options (for DTA::CAB::Queue::File::Locked)
##     qfile => $filename,   ##-- basename of queue file (will have .dat,.idx suffixes; default="/tmp/fpool.$$")
##     qmode => $mode,       ##-- creation mode (default=0660)
##     qseparator => $str,   ##-- item separator string (default=$/)
##
##     ##-- high-level subprocess pool options
##     njobs  => $n_threads,    ##-- number of subprocesses to fork() off (default=0)
##     init   => \&init,        ##-- called as init($fp) in each subprocess after creation (default: $fp->can('init'))
##     work   => \&work,        ##-- called as work($fp,$item) in a subprocess to process a queue item (default: $fp->can('work'))
##     reap   => \&reap,        ##-- called as reap($fp,$pid,$?) after subprocess exit (default: $fp->can('reap'))
##     free   => \&free,        ##-- called as free($fp) in each subprocess before termination (default: $fp->can('free'))
##
##     logSpawn         => $level,   ##-- log-level for spawning subprocesses [default: 'info']
##     logReap          => $level,   ##-- log-level for messages caught with default catch() [default: 'fatal']
##     propagateErrors  => $bool,    ##-- if true (default), default 'reap' method will exit() the whole process
##     ##
##     ##-- Low-level data
##     pids => \@pids,           ##-- PIDs of spawned subprocesses
##     ppid => $ppid,            ##-- parent pid (default=$$)
##     queue => $queue,          ##-- low-level DTA::CAB::Queue::File::Locked object
##    }
sub new {
  my $that = shift;
  my $fp = bless {
		  qfile  => "/tmp/fpool.$$",
		  qmode  => 0600,
		  qseparator => $/,
		  njobs => 0,
		  init  => $that->can('init'),
		  work  => $that->can('work'),
		  reap  => $that->can('reap'),
		  free  => $that->can('free'),
		  logSpawn => 'info',
		  logReap => 'info',
		  propagateErrors => 1,
		  pids => [],
		  ppid => $$,
		  @_,
		 }, ref($that)||$that;
  my %qargs = map {($_=>$fp->{"q$_"})} qw(file mode separator);
  $fp->{queue} = DTA::CAB::Queue::File::Locked->new(%qargs) if (!$fp->{queue});
  return $fp;
}

##==============================================================================
## Methods: Pool Maintainence

## $fp = $fp->spawn()
##  + ensures that at least $fp->{njobs} PIDs are defined in $fp->{pids}
##  + you must completely populate the queue BEFORE calling this method!
sub spawn {
  my $fp = shift;
  $fp->{pids} = [] if (!$fp->{pids});
  $SIG{CHLD} = $fp->reaper() if (!defined($SIG{CHLD}));
  while (@{$fp->{pids}} < $fp->{njobs}) {
    my $pid = fork();
    if ($pid) {
      ##-- parent
      $fp->vlog($fp->{logSpawn},"spawned subprocess $pid");
      push(@{$fp->{pids}},$pid);
    } else {
      ##-- child
      exit $fp->childMain();
    }
  }
  return $fp;
}

## $fp = $fp->abort()
## $fp = $fp->abort($SIGNAL)
##  + kills subprocesses
sub abort {
  my ($fp,$sig) = @_;
  $sig = 'TERM' if (!defined($sig));
  my ($pid);
  while (defined($pid=shift(@{$fp->{pids}}))) {
    kill($sig,$pid);
  }
  return $fp;
}

## $fp = $fp->reset()
##  + aborts all running subprocesses and empties the queue
sub reset {
  my $fp = shift;
  $fp->abort();
  $fp->{queue}->reset();
  return $fp;
}

## @pids = $fp->pids
##  + list of all child processes
sub pids {
  return @{$_[0]{pids}};
}

## $fp = $fp->waitall()
##  + waits on all child pids
sub waitall {
  my $fp = shift;
  my ($pid);
  while (defined($pid=shift(@{$fp->{pids}}))) {
    waitpid($pid,0);
    $fp->{reap}->($fp,$pid,$?) if ($fp->{reap});
  }
  return $fp;
}

## \&reaper = $fp->reaper()
##  + zombie-harvesting code; installed to local %SIG by default
sub reaper {
  my $fp = shift;
  return sub {
    my ($child);
    while (($child = waitpid(-1,WNOHANG)) > 0) {
      $fp->vlog($fp->{logReap},"reaper got subprocess pid=$child, status=$?");
      $fp->{reap}->($fp,$child,$?) if ($fp->{reap});
      @{$fp->{pids}} = grep {$_ != $child} @{$fp->{pids}};
    }
  };
}

##==============================================================================
## Methods: Queue Maintainence
##  + see DTA::CAB::Queue::File

## undef = $fp->refresh()
##  + refreshes queue; probably needed in subprocesses
sub refresh {
  $_[0]{queue}->refresh;
}

## undef = $fp->enq($item)
##  + enqueue a single item
sub enq {
  $_[0]{queue}->enq(@_[1..$#_]);
}

## undef = $fp->deq()
##  + dequeue a single item
sub deq {
  $_[0]{queue}->deq(@_[1..$#_]);
}

## undef = $fp->peek($count)
##  + preview next $count items without de-queueing
sub peek {
  $_[0]{queue}->peek(@_[1..$#_]);
}

## undef = $fp->unlink()
##  + close and un-link the queue
sub unlink {
  $_[0]{queue}->unlink(@_[1..$#_]);
}

##==============================================================================
## Methods: Queue Processing

## undef = PACKAGE::childMain($fp)
##   + queue worker sub which wraps init() and free() calls
sub childMain {
  my $fp = shift;
  $fp->{init}->($fp) if ($fp->{init});
  $fp->process();
  $fp->{free}->($fp) if ($fp->{free});
  exit 0;
}

## undef = PACKAGE::process($fp)
##   + main queue processing loop (can be called e.g. from main thread)
sub process {
  my $fp = shift;
  my ($item);
  while (defined($item=$fp->refresh->deq)) {
    $fp->{work}->($fp,$item) if ($fp->{work});
  }
}

##==============================================================================
## Methods: Default Callbacks

## undef = init($fp)
##  + default thread initializer (no-op)
sub init { ; }

## undef = work($fp,$item)
##  + default thread queue-processor (no-op)
sub work { ; }

## undef = free($fp)
##  + default thread cleanup function (no-op)
sub free { ; }

## undef = reap($fp,$pid,$?)
##  + called from main thread on subprocess exit
sub reap {
  my ($fp,$pid,$status) = @_;
  $fp->vlog($fp->{logReap},"reaped subprocess $pid with exit status $status");
  if ($fp->{propagateErrors} && $status != 0) {
    $fp->logdie("subprocess $pid exited with abnormal status $status");
  }
}



1; ##-- be happy

__END__
