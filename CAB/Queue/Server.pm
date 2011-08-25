## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Queue::Server.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: UNIX-socket based queue: server

package DTA::CAB::Queue::Server;
use DTA::CAB::Queue::Socket;
use DTA::CAB::Queue::Client;
use DTA::CAB::Utils ':temp', ':files';
use IO::Socket;
use IO::Socket::UNIX;
use Fcntl;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(DTA::CAB::Queue::Socket);

##==============================================================================
## Constructors etc.
##==============================================================================

## $qs = DTA::CAB::Queue::Server->new(%args)
##  + %$qs, %args:
##    (
##     path  => $path,      ##-- path to server socket; default=tmpfsfile('cabqXXXX')
##     perms => $perms,     ##-- creation permissions (default=0600)
##     fh    => $sockfh,    ##-- an IO::Socket::UNIX object for the server socket
##     queue => \@queue,    ##-- actual queue data
##     unlink => $bool,     ##-- unlink on DESTROY()? (default=1)
##     timeout => $secs,    ##-- default timeout for accept() etc; default=undef (no timeout)
##     status => $str,      ##-- queue status (defualt: 'active')
##    )
sub new {
  my ($that,%args) = @_;
  my $qs = $that->SUPER::new(
			     path =>undef,
			     queue=>[],
			     unlink => 1,
			     perms  => 0600,
			     timeout => undef,
			     status => 'active',
			     (ref($that) ? (%$that,unlink=>0) : qw()),
			     fh =>undef,
			     %args,
			    );
  return defined($qs->{fh}) ? $qs : $qs->open();
}

## undef = $qs->DESTROY
##  + destructor calls close()
sub DESTROY {
  $_[0]->unlink() if ($_[0]{unlink});
}

## $qs = $qs->unlink()
##  + unlinks $qs->{path} if possible
##  + implicitly calls close()
sub unlink {
  $_[0]->close();
  CORE::unlink($_[0]{path}) if (-w $_[0]{path});
}

##==============================================================================
## Open/Close

## $bool = $qs->opened()
##  + INHERITED from Queue::Socket

## $qs = $qs->close()
##  + INHERITED from Queue::Socket

## $qs = $qs->open()
## $qs = $qs->open($path)
##  + override unlinks old path if appropriate, sets permissions, etc.
sub open {
  my ($qs,$path) = @_;

  ##-- close and unlink if we can
  $qs->close() if ($qs->opened);
  $qs->unlink() if ($qs->{unlink});

  ##-- get new socket path
  if (!defined($path)) {
    $path = $qs->{path};
    $path = tmpfsfile('cabqXXXX') if (!defined($path));
  }
  $qs->{path} = $path;

  ##-- unlink any stale files of new pathname
  if (-e $path) {
    CORE::unlink($path) or $qs->logconfess("cannot unlink existing file at UNIX socket path '$path': $!");
  }

  ##-- create a new listen socket
  $qs->SUPER::open(Local=>$path,Listen=>1)
    or $qs->logconfess("cannot create UNIX socket '$path': $!");

  ##-- set permissions
  !defined($qs->{perms})
    or chmod($qs->{perms}, $path)
      or $qs->logconfess(sprintf("cannot set perms=%0.4o for UNIX socket '$path': $!", $qs->{perms}, $path));

  ##-- report
  $qs->vlog('trace', sprintf("created UNIX socket '%s' with permissions %0.4o", $path, ((stat($path))[2] & 0777)));

  ##-- return
  return $qs;
}

##==============================================================================
## Socket Communications
## + INHERITED from Queue::Socket

##==============================================================================
## Queue Maintenance
##  + from main thread

## $n_items = $q->size()
sub size {
  return scalar(@{$_[0]{queue}});
}

## $n_items = $q->enq($item)
##  + enqueue an item; returns new number of items in queue
sub enq {
  push(@{$_[0]{queue}},$_[1]);
}

## $item_or_undef = $q->deq()
##  + de-queue a single item; undef at end-of-queue
sub deq {
  shift(@{$_[0]{queue}});
}

## $item = $q->peek()
##  + peek at the top of the queue; undef if queue is empty
sub peek {
  return $_[0]{queue}[0];
}

## $q = $q->clear()
##  + clear the queue
sub clear {
  @{$_[0]{queue}} = qw();
  return $_[0];
}

##==============================================================================
## Queue Server Protocol

## $cli_or_undef = $qs->accept()
## $cli_or_undef = $qs->accept($timeout_secs)
##  + accept incoming client connections with optional timeout
##  + if a client connection is available, it will be returned as as DTA::CAB::Queue::ClientConn object
##    (a wrapper subclass for DTA::CAB::Queue::Socket)
##  + otherwise, if no connection is available, undef will be returned
sub accept {
  my $qs = shift;
  if ($qs->canread(@_)) {
    my $fh = $qs->{fh}->accept();
    return DTA::CAB::Queue::ClientConn->new(path=>$qs->{path}, fh=>$fh);
  }
  return undef;
}

## $qs = $qs->process($cli)
## $qs = $qs->process($cli, \&callback)
##  + main server loop
##  + accepts and processes client connections
##  + each client request is a STRING message (command)
##    - request arguments (if required) are sent as separate messages following the command request
##    - server response (if any) depends on command sent
##  + request commands (case-insensitive) handled by the process() method:
##     DEQ          : dequeue the first item in the queue; response: $cli->put($item)
##     DEQ_STR      : dequeue a string reference; response: $cli->put_str(\$item)
##     DEQ_REF      : dequeue a reference; response: $cli->put_ref($item)
##     ENQ $item    : enqueue an item; no response
##     ENQ_STR $str : enqueue a string-reference; no response
##     ENQ_REF $ref : enqueue a reference; no response
##     SIZE         : get current queue size; response=STRING $qs->size()
##     STATUS       : get queue status response: STRING $qs->{status}
##     CLEAR        : clear queue; no response
##     QUIT         : close client connection; no response
##     ...          : other messages are passed to $callback->(\$request,$cli) or produce an error
##  + returns: same as $callback->() if called, otherwise $qs
sub process {
  my ($qs,$cli,$callback) = @_;
  my $creq = $qs->get();
  if (!ref($creq) || ref($creq) ne 'SCALAR') {
    $qs->logconfess("could not parse client request");
  }
  my $cmd = lc($$creq);
  my $qu  = $qs->{queue};
  if ($cmd =~ /^deq(?:_ref|_str)?$/) {
    ##-- DEQ: dequeue an item
    if    (!@{$qs->{queue}})  { $cli->put_eoq(); }
    elsif ($cmd eq 'deq')     { $cli->put( $qu->[0] ); }
    elsif ($cmd eq 'deq_str') { $cli->put_str( ref($qu->[0]) ? $qu->[0] : \$qu->[0] ); }
    elsif ($cmd eq 'deq_ref') { $cli->put_ref( ref($qu->[0]) ? $qu->[0] : \$qu->[0] ); }
    shift(@$qu);
  }
  elsif ($cmd eq 'enq') {
    ##-- ENQ $item: enqueue a raw scalar or frozen reference
    my $buf = undef;
    my $ref = $cli->get(\$buf);
    push(@$qu, ($ref eq \$buf ? $buf : $ref));
  }
  elsif ($cmd eq 'enq_str' || $cmd eq 'enc_ref') {
    ##-- ENQ_STR $string: enqueue a string-reference
    ##-- ENQ_REF $ref   : enqueue a frozen reference
    my $ref = $cli->get();
    push(@$qu, $ref);
  }
  elsif ($cmd eq 'size') {
    my $size = $qs->size;
    $cli->put_str($size);
  }
  elsif ($cmd eq 'status') {
    my $status = $qs->{status};
    $cli->put_str($status);
  }
  elsif ($cmd eq 'clear') {
    @$qu = qw();
  }
  elsif ($cmd eq 'quit') {
    $cli->close();
  }
  elsif (defined($callback)) {
    return $callback->($creq,$cli);
  }
  else {
    $qs->logwarn("unknown command '$cmd' from client ignored");
  }
  return $qs;
}


##==============================================================================
## Client Connections
package DTA::CAB::Queue::ClientConn;
use strict;
our @ISA = qw(DTA::CAB::Queue::Socket);


1;

__END__
