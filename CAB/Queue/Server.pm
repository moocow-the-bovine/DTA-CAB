## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Queue::Server.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: UNIX-socket based queue: server

package DTA::CAB::Queue::Server;
use DTA::CAB::Socket ':flags';
use DTA::CAB::Socket::UNIX;
use DTA::CAB::Queue::Client;
use DTA::CAB::Utils ':temp', ':files';
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(DTA::CAB::Socket::UNIX);

##==============================================================================
## Constructors etc.
##==============================================================================

## $qs = DTA::CAB::Queue::Server->new(%args)
##  + %$qs, %args:
##    (
##     ##-- NEW in DTA::CAB::Queue::Socket
##     queue => \@queue,    ##-- actual queue data
##     status => $str,      ##-- queue status (defualt: 'active')
##     ##
##     ##-- INHERITED from DTA::CAB::Socket::UNIX
##     local  => $path,     ##-- path to local UNIX socket (for server; set to empty string to use a tempfile)
##     #peer   => $path,     ##-- path to peer socket (for client)
##     listen => $n,        ##-- queue size for listen (default=SOMAXCONN)
##     unlink => $bool,     ##-- if true, server socket will be unlink()ed on DESTROY() (default=true)
##     perms  => $perms,    ##-- file create permissions for server socket (default=0600)
##     ##
##     ##-- INHERITED from DTA::CAB::Socket
##     fh    => $sockfh,    ##-- an IO::Socket::UNIX object for the socket
##     timeout => $secs,    ##-- default timeout for select() (default=undef: none)
##     logTrace => $level,  ##-- log level for full trace (default=undef (none))
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   local => '', ##-- use temp socket if unspecified
			   queue=>[],
			   status => 'active',
			   @_,
			  );
}

##==============================================================================
## Open/Close

## $bool = $qs->opened()
##  + INHERITED from CAB::Socket::UNIX

## $qs = $qs->close()
##  + INHERITED from CAB::Socket::UNIX

## $qs = $qs->open(%args)
##  + override unlinks old path if appropriate, sets permissions, etc.
##  + INHERITED from CAB::Socket::UNIX

##==============================================================================
## Socket Communications
## + INHERITED from CAB::Socket::UNIX

##==============================================================================
## Queue Maintenance
##  + for use from main thread

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
## Server Methods

## $class = $CLASS_OR_OBJECT->clientClass()
##  + default client class, used by newClient()
sub clientClass {
  return 'DTA::CAB::Queue::ClientConn';
}

## $cli_or_undef = $qs->accept()
## $cli_or_undef = $qs->accept($timeout_secs)
##  + accept incoming client connections with optional timeout
##  + INHERITED from DTA::CAB::Socket

## $rc = $qs->process($cli)
## $rc = $qs->process($cli, \&callback)
##  + handle a single client request
##  + each client request is a STRING message (command)
##    - request arguments (if required) are sent as separate messages following the command request
##    - server response (if any) depends on command sent
##  + this method parses client request command $cmd and dispatches to
##    - the method $qs->can("process_".lc($cmd))->($qs,$cli,\$cmd), if available
##    - the method $qs->can("process_DEFAULT")->($qs,$cli,\$cmd)
##  + returns whatever the handler subroutine does
##  + INHERITED from CAB::Socket

##--------------------------------------------------------------
## Server Methods: Request Handling
##
##  + request commands (case-insensitive) handled here:
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


## $qs = $qs->process_deq($cli,\$cmd)
## $qs = $qs->process_deq_str($cli,\$cmd)
## $qs = $qs->process_deq_ref($cli,\$cmd)
##  + implements "$item = DEQ", "\$str = DEQ_STR", "$ref = DEQ_REF"
BEGIN {
  *process_deq_str = *process_deq_ref = \&process_deq;
}
sub process_deq {
  my ($qs,$cli,$creq) = @_;
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
  return $qs;
}

## $qs = $qs->process_enq($cli,\$cmd)
##  + implements "ENQ $item"
sub process_enq {
  my ($qs,$cli,$creq) = @_;
  my $buf = undef;
  my $ref = $cli->get(\$buf);
  push(@{$qs->{queue}}, ($ref eq \$buf ? $buf : $ref));
  return $qs;
}

## $qs = $qs->process_enq_str($cli,\$cmd)
## $qs = $qs->process_enq_ref($cli,\$cmd)
##  + implements "ENQ_STR \$str", "ENQ_REF $ref"
BEGIN {
  *process_enq_str = *process_enq_ref;
}
sub process_enq_ref {
  my ($qs,$cli,$creq) = @_;
  my $ref = $cli->get();
  push(@{$qs->{queue}}, $ref);
  return $qs;
}

## $qs = $qs->process_size($cli,$creq)
##  + implements "$size = SIZE"
sub process_size {
  #my ($qs,$cli,$creq) = @_;
  #my $size = $_[0]->size;
  $_[1]->put_str($_[0]->size);
  return $_[0];
}

## $qs = $qs->process_status($cli,$creq)
##  + implements "$status = STATUS"
sub process_status {
  #my ($qs,$cli,$creq) = @_;
  $_[1]->put_str($_[0]{status});
  return $_[0];
}

## $qs = $qs->process_clear($cli,$creq)
##  + implements "CLEAR"
sub process_clear {
  @{$_[0]{queue}} = qw();
  return $_[0];
}

## $qs = $qs->process_quit($cli,$creq)
sub process_quit {
  $_[1]->close();
  return $_[0];
}

##==============================================================================
## Client Connections
package DTA::CAB::Queue::ClientConn;
use strict;
our @ISA = qw(DTA::CAB::Socket::UNIX);


1;

__END__
