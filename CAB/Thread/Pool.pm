## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Thread::Pool.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: generic thread pool for DTA::CAB

package DTA::CAB::Thread::Pool;
use threads;
use Thread::Queue;
use DTA::CAB::Logger;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Logger);

##==============================================================================
## Constructors etc.
##==============================================================================

## $tp = CLASS_OR_OBJ->new(%args)
##  + %$tp, %args:
##    {
##     ##-- High-level options
##     njobs  => $n_threads,    ##-- number of worker threads to allocate (default=0)
##     init   => \&init,        ##-- called as init($tp) in each worker thread on creation (default: $tp->can('init'))
##     work   => \&work,        ##-- called as work($tp,@$args) in a worker thread to process a queue item (default: $tp->can('work'))
##     catch  => \&catch,       ##-- called as catch($tp,$@) on sub-thread die() (default: $tp->can('catch'))
##     free   => \&free,        ##-- called as free($tp) in each worker thread before destruction (default: $tp->can('free'))
##
##     catchLogLevel     => $level,   ##-- log-level for messages caught with default catch() [default: 'fatal']
##     catchKillsProcess => $bool,    ##-- if true (default), default 'catch' method will exit() the whole process
##     catchKillsThread  => $bool,    ##-- if true (default), default 'catch' method will exit() the current thread
##     ##
##     ##-- Low-level data
##     queue   => $queue,       ##-- underlying Thread::Queue object
##     threads => \@threads,    ##-- worker threads
##    }
sub new {
  my $that = shift;
  my $tp = bless {
		  njobs => 0,
		  init  => $that->can('init'),
		  work  => $that->can('work'),
		  catch => $that->can('catch'),
		  free  => $that->can('free'),
		  catchLogLevel => 'fatal',
		  catchKillsProcess => 1,
		  catchKillsThread  => 1,
		  queue => undef,
		  threads => [],
		  @_,
		 }, ref($that)||$that;

  ##-- initialize
  $tp->populate();

  return $tp;
}

##==============================================================================
## Methods: Thread Maintainence

## $tp = $tp->populate()
##  + ensures that at least $tp->{njobs} worker threads are defined in $tp->{threads}
sub populate {
  my $tp = shift;
  $tp->{queue} = Thread::Queue->new() if (!$tp->{queue});
  while (@{$tp->{threads}} < $tp->{njobs}) {
    push(@{$tp->{threads}}, threads->create($tp->can('threadMain'), $tp));
  }
  return $tp;
}

## $tp = $tp->abort()
## $tp = $tp->abort($SIGNAL)
##  + kills child threads
sub abort {
  my ($tp,$sig) = @_;
  $sig = 'TERM' if (!defined($sig));
  my ($t);
  while (defined($t=shift(@{$tp->{threads}}))) {
    $t->kill($sig);
    $t->join() if ($t->is_joinable);
  }
  return $tp;
}

## $tp = $tp->reset()
##  + aborts all running threads, empties the queue, and re-populates
sub reset {
  my $tp = shift;
  $tp->abort();
  $tp->{queue}->dequeue($tp->{queue}->pending);
  $tp->populate();
  return $tp;
}

## @threads = $tp->list
##  + list of all sub-threads
sub list {
  return @{$_[0]{threads}};
}

## @threads = $tp->detached()
##  + list of all detached sub-threads
sub detached {
  return grep {$_->is_detached} @{$_[0]{threads}};
}

## @threads = $tp->undetached()
##  + list of all non-detached sub-threads
sub undetached {
  return grep {!$_->is_detached} @{$_[0]{threads}};
}

## @threads = $tp->running()
##  + list of all running sub-threads
sub running {
  return grep {$_->is_running} @{$_[0]{threads}};
}

## @threads = $tp->joinable()
##  + list of all joinable (done running, not detached and not yet joined) sub-threads
sub joinable {
  return grep {$_->is_joinable} @{$_[0]{threads}};
}

## $tp = $tp->join()
##  + join()s on all undetached sub-threads and removes them from $tp->{threads}
sub join {
  my $tp = shift;
  my @detached = $tp->detached;
  $_->join() foreach ($tp->undetached);
  @{$tp->{threads}} = @detached;
  return $tp;
}

## $tp = $tp->detach()
##  + detach()es any as-et undetached sub-threads
##  + prohibits subsequent join(), abort() from joining any threads
sub detach {
  my $tp = shift;
  $_->detach() foreach ($tp->undetached);
  return $tp;
}

##==============================================================================
## Methods: Queue Maintainence

## $tp = $tp->enqueue(\@args, ...)
##  + enqueues a new set of arguments to be processed by $tp->{work}->($tp,@args)
##  + you MUST enqueue() undef (or call $tp->finish()) after enqueuing all 
sub enqueue {
  $_[0]{queue}->enqueue(@_[1..$#_]);
  return $_[0];
}

## $args_or_undef = $tp->dequeue()
## $args_or_undef = $tp->dequeue($n_items)
##  + dequeue item(s) from the queue (blocks)
sub dequeue {
  return $_[0]{queue}->dequeue(@_[1..$#_]);
}

## $n = $tp->pending()
##  + returns number of pending items in the queue
sub pending {
  return $_[0]{queue}->pending();
}

## $tp = $tp->finish()
##  + appends EOQ marker (undef) to the queue and calls $tp->join()
sub finish {
  my $tp = shift;
  $tp->{queue}->enqueue(undef);
  $tp->join();
}


##==============================================================================
## Methods: Queue Processing

## undef = PACKAGE::threadMain($tp)
##   + queue worker sub which wraps init() and free() calls
sub threadMain {
  my $tp = shift;
  $tp->{init}->($tp) if ($tp->{init});
  do {
    eval { $tp->process(); };
    if ($@) {
      if ($tp->{catch}) {
	$tp->{catch}->($tp,$@);
      } else {
	last;
      }
    }
  } while ($@);
  $tp->{free}->($tp) if ($tp->{free});
}

## undef = PACKAGE::process($tp)
##   + main queue processing loop (can be called e.g. from main thread)
sub process {
  my $tp = shift;
  my ($args);
  while (defined($args=$tp->{queue}->dequeue)) {
    $tp->{work}->($tp,@$args) if ($tp->{work});
  }
  $tp->{queue}->enqueue(undef); ##-- re-enqueue end-of-queue marker to catch other threads
}

##==============================================================================
## Methods: Default Callbacks

## undef = init($tp)
##  + default thread initializer (no-op)
sub init { ; }

## undef = work($tp)
##  + default thread queue-processor (no-op)
sub work { ; }

## undef = catch($tp)
##  + die() catcher
sub catch {
  my ($tp,$msg) = @_;
  $tp->vlog($tp->{catchLogLevel},$msg);
  if ($tp->{catchKillsThread} || $tp->{catchKillsProcess}) {
    $tp->{free}->($tp) if ($tp->{free});           ##-- run free callback function before exiting
    exit(1) if ($tp->{catchKillsProcess});         ##-- ... exit() the whole process
    threads->exit(1) if (threads->can('exit'));    ##-- ... kill the current thread (if we can)
    exit(1);                                       ##-- ... and otherwise the whole process
  }
}

## undef = free($tp)
##  + default thread cleanup function (no-op)
sub free { ; }



1; ##-- be happy

__END__
