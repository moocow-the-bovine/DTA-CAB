## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Queue::JobManager.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: UNIX-socket based queue: job manager for dta-cab-analyze.perl

package DTA::CAB::Queue::JobManager;
use DTA::CAB::Queue::Server;
use DTA::CAB::Format::Builtin;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(DTA::CAB::Queue::Server);

##==============================================================================
## Constructors etc.
##==============================================================================

## $jm = DTA::CAB::Queue::JobManager->new(%args)
##  + %$jm, %args:
##    (
##     ##-- NEW in DTA::CAB::Queue::JobManaeger
##     ntok => $ntok,       ##-- total number of tokens processed by clients
##     nchr => $nchr,       ##-- total number of characters processed by clients
##     blocks => \%blocks,  ##-- ($outfile => $po={cur=>$max_input_byte_written, pending=>\@pending}, ...)
##                          ##   + @pending is a list of pending blocks ($pb={off=>$offset, len=>$length, data=>\$data}, ...)
##     logBlock => $level,  ##-- log-level for block merge operations (default=undef (none))
##     ##
##     ##-- INHERITED from DTA::CAB::Queue::Server
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
			   ##-- statistics
			   ntok => 0,
			   nchr => 0,
			   blocks => {},
			   logBlock => undef,

			   @_,
			  );
}

##==============================================================================
## Local Methods
##  + for use from main thread

##--------------------------------------------------------------
## Local Methods: Statistics

## ($ntok,$nchr) = $jm->totals($ntok,$nchr)
##  + get or add to total number of (tokens,character) processed
sub totals {
  $_[0]{ntok} += $_[1] if (defined($_[1]));
  $_[0]{nchr} += $_[2] if (defined($_[2]));
  return @{$_[0]}{qw(ntok nchr)};
}

##==============================================================================
## Socket: Open/Close

## $bool = $jm->opened()
##  + INHERITED from CAB::Socket::UNIX

## $jm = $jm->close()
##  + INHERITED from CAB::Socket::UNIX

## $jm = $jm->open(%args)
##  + override unlinks old path if appropriate, sets permissions, etc.
##  + INHERITED from CAB::Socket::UNIX

##==============================================================================
## Socket: Protocol
## + INHERITED from CAB::Socket::UNIX

##==============================================================================
## Queue Maintenance
##  + for use from main thread

## $n_items = $q->size()
##  + INHERITED from CAB::Queue::Server

## $n_items = $q->enq($item)
##  + enqueue an item; returns new number of items in queue
##  + INHERITED from CAB::Queue::Server

## $item_or_undef = $q->deq()
##  + de-queue a single item; undef at end-of-queue
##  + INHERITED from CAB::Queue::Server

## $item = $q->peek()
##  + peek at the top of the queue; undef if queue is empty
##  + INHERITED from CAB::Queue::Server

## $q = $q->clear()
##  + clear the queue
##  + INHERITED from CAB::Queue::Server

##==============================================================================
## Server Methods

## $class = $CLASS_OR_OBJECT->clientClass()
##  + default client class, used by newClient()
##  + INHERITED from CAB::Queue::Server

## $cli_or_undef = $jm->accept()
## $cli_or_undef = $jm->accept($timeout_secs)
##  + accept incoming client connections with optional timeout
##  + INHERITED from DTA::CAB::Socket

## $rc = $jm->process($cli)
## $rc = $jm->process($cli, %callbacks)
##  + handle a single client request
##  + INHERITED from CAB::Socket

##--------------------------------------------------------------
## Server Methods: Request Handling
##
##  + request commands handled here:
##     TOTALS "$ntok $nchr" : add to total number of (tokens,characters) processed
##     BLOCK $blk $data     : block output ($blk is a HASH-ref, $data a raw string)
##                            + $blk should have keys: (off=>BYTES, len=>BYTES, outfile=>FILENAME, fmt=>CLASS, ...)
##
##  + request commands (case-insensitive) handled by DTA::CAB::Queue::Server:
##     DEQ          : dequeue the first item in the queue; response: $cli->put($item)
##     DEQ_STR      : dequeue a string reference; response: $cli->put_str(\$item)
##     DEQ_REF      : dequeue a reference; response: $cli->put_ref($item)
##     ENQ $item    : enqueue an item; no response
##     ENQ_STR $str : enqueue a string-reference; no response
##     ENQ_REF $ref : enqueue a reference; no response
##     SIZE         : get current queue size; response=STRING $jm->size()
##     STATUS       : get queue status response: STRING $jm->{status}
##     CLEAR        : clear queue; no response
##     QUIT         : close client connection; no response
##     ...          : other messages are passed to $callback->(\$request,$cli) or produce an error
##  + returns: same as $callback->() if called, otherwise $jm

## $qs = $qs->process_totals($cli,\$cmd)
sub process_totals {
  my ($jm,$cli,$creq) = @_;
  my $buf = $cli->get();
  $jm->totals(split(' ',$$buf,2));
  return $jm;
}

## $jm = $jm->process_block($cli,\$cmd)
sub process_block {
  my ($jm,$cli,$creq) = @_;
  my $blk   = $cli->get();
  my $datar = $cli->get();
  $blk->{data} = $datar;

  ##-- push block to block-tracker's ($bt) pending list
  my ($bt);
  $bt = $jm->{blocks}{$blk->{outfile}} = {cur=>0,pending=>0} if (!defined($bt=$jm->{blocks}{$outfile}));
  push(@{$bt->{pending}}, $blk);

  ##-- greedy append
  if ($blk->{off} == $bt->{cur}) {
    my $fmt = DTA::CAB::Format->newFormat($blk->{fmt} || $DTA::CAB::Format::CLASS_DEFAULT);
    @{$bt->{pending}} = sort {$a->{off}<=>$b->{off}} @{$bt->{pending}};
    while (@{$bt->{pending}} && $bt->{pending}[0]{off}==$bt->{cur}) {
      $blk=shift(@{$po->{pending}});
      $jm->vlog($jm->{logBlock}, "APPEND $blk->{outfile} (off=$blk->{off}, len=$blk->{len})");
      $fmt->blockAppend($blk, $outfile);
      $bt->{cur} += $blk->{len};
    }
  } else {
    $jm->vlog($jm->{logBlock}, "DELAY $blk->{outfile} (off=$blk->{off}, len=$blk->{len})");
  }

  return $jm;
}

1;

__END__
