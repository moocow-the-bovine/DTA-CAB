## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Queue::Client.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: UNIX-socket based queue: server

package DTA::CAB::Queue::Client;
use DTA::CAB::Queue::Socket;
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
##     fh    => $sockfh,    ##-- an IO::Socket::UNIX object for the server socket
##     timeout => $secs,    ##-- default timeout for accept() etc; default=undef (no timeout)
##    )
sub new {
  my ($that,%args) = @_;
  my $qs = $that->SUPER::new(
			     path =>undef,
			     timeout => undef,
			     (ref($that) ? %$that : qw()),
			     fh =>undef,
			     %args,
			    );
  return defined($qs->{fh}) ? $qs : (defined($qs->{path}) ? $qs->open() : $qs);
}

##==============================================================================
## Open/Close

## $bool = $qs->opened()
##  + INHERITED from Queue::Socket

## $qs = $qs->close()
##  + INHERITED from Queue::Socket

## $qs = $qs->open()
## $qs = $qs->open($path)
##  + override sets Peer=>$path
sub open {
  my ($qs,$path) = @_;

  ##-- get new socket path
  $path = $qs->{path} if (!defined($path));
  $qs->{path} = $path;
  $qs->logconfess("cannot open() without a defined path!") if (!defined($path));

  ##-- create a new listen socket
  $qs->SUPER::open(Peer=>$path)
    or $qs->logconfess("cannot open UNIX socket at '$path': $!");

  ##-- report
  $qs->vtrace(sprintf("opened UNIX socket '%s' as client", ($path||'-')));

  ##-- return
  return $qs;
}

## $qs = $qs->connect()
##  + wrapper for ($qs->reopen)
sub connect {
  return $_[0]->reopen();
}

##==============================================================================
## Socket Communications
## + INHERITED from Queue::Socket

##==============================================================================
## Queue Maintenance
##  + TODO

## $n_items = $q->size()

## $n_items = $q->enq($item)
##  + enqueue an item; returns new number of items in queue

## $item_or_undef = $q->deq()
##  + de-queue a single item; undef at end-of-queue

## $item = $q->peek()
##  + peek at the top of the queue; undef if queue is empty

## $q = $q->clear()
##  + clear the queue

##==============================================================================
## Queue Server Protocol
## + TODO

1;

__END__
