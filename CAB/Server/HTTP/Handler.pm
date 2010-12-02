##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description:
##  + abstract handler API class for DTA::CAB::Server::HTTP
##======================================================================

package DTA::CAB::Server::HTTP::Handler;
use HTTP::Status;
use DTA::CAB::Logger;
use UNIVERSAL qw(isa);
use strict;

our @ISA = qw(DTA::CAB::Logger);

##======================================================================
## API
##======================================================================

## $h = $class_or_obj->new(%options)
sub new {
  my $that = shift;
  return bless { @_ }, ref($that)||$that;
}

## $bool = $h->prepare($server,$path)
sub prepare { return 1; }

## $rsp = $path->run($server, $localPath, $clientConn, $httpRequest)
##  + perform local processing
##  + should return a HTTP::Response object to pass to the client
##  + if the call die()s or returns undef, an error response will be
##    sent to the client instead if it the connection is still open
sub run {
  my ($h,$srv,$path,$csock,$hreq) = @_;
  $h->logdie("run() method not implemented");
}

## undef = $h->finish($server, $clientConn)
##  + clean up handler state after run()
##  + default implementation does nothing
sub finish {
  return;
}

##======================================================================
## Generic Utilities

## $rsp = $h->headResponse()
## $rsp = $h->headResponse(\@headers)
## #$rsp = $h->headResponse(\%headers)
## $rsp = $h->headResponse($httpHeaders)
## + rudimentary handling for HEAD requests
sub headResponse {
  my ($h,$hdr) = @_;
  return $h->response(RC_OK,undef,$hdr);
}

## $rsp = $CLASS_OR_OBJECT->response($code=RC_OK, $msg=status_message($code), $hdr, $content)
##  + $hdr may be a HTTP::Headers object, an array or hash-ref
##  + wrapper for HTTP::Response->new()
sub response {
  my $h = shift;
  my $code = shift;
  $code = RC_OK if (!defined($code));
  ##
  my $msg  = @_ ? shift : undef;
  $msg  = status_message($code) if (!defined($msg));
  ##
  my $hdr  = @_ ? shift : undef;
  $hdr  = [] if (!$hdr);
  ##
  return HTTP::Response->new($code,$msg,$hdr) if (!@_);
  return HTTP::Response->new($code,$msg,$hdr,@_);
}

## undef = $h->cerror($csock, $status=RC_INTERNAL_SERVER_ERROR, @msg)
##  + sends an error response and sends it to the client socket
##  + also logs the error at level ($c->{logError}||'warn') and shuts down the socket
sub cerror {
  my ($h,$c,$status,@msg) = @_;
  if (defined($c) && $c->opened) {
    $status   = RC_INTERNAL_SERVER_ERROR if (!defined($status));
    my $chost = $c->peerhost();
    my $msg   = @msg ? join('',@msg) : status_message($status);
    $h->vlog(($h->{logError}||'error'), "client=$chost: $msg");
    {
      my $_warn=$^W;
      $^W=0;
      $c->send_error($status, $msg);
      $^W=$_warn;
    }
    $c->shutdown(2);
    $c->close();
  }
  return undef;
}


##======================================================================
## Handler class aliases (for derived classes)
##======================================================================

## %ALIAS = ($aliasName => $className, ...)
our (%ALIAS);

## undef = DTA::CAB::Server::HTTP::Handler->registerAlias($aliasName=>$fqClassName, ...)
sub registerAlias {
  shift; ##-- ignore class argument
  my (%alias) = @_;
  @ALIAS{keys(%alias)} = values(%alias);
}

## $className_or_undef = DTA::CAB::Server::HTTP::Handler->fqClass($alias_or_class_suffix)
sub fqClass {
  my $alias = $_[1]; ##-- ignore class argument

  ##-- Case 0: $alias wasn't defined in the first place: use empty string
  $alias = '' if (!defined($alias));

  ##-- Case 1: $alias is already fully qualified
  return $alias if (isa($alias,'DTA::CAB::Server::HTTP::Handler'));

  ##-- Case 2: $alias is a registered alias: recurse
  return $_[0]->fqClass($ALIAS{$alias}) if (defined($ALIAS{$alias}) && $ALIAS{$alias} ne $alias);

  ##-- Case 2: $alias is a valid "DTA::CAB::Server::HTTP::Handler::" suffix
  return "DTA::CAB::Server::HTTP::Handler::${alias}" if (isa("DTA::CAB::Server::HTTP::Handler::${alias}", 'DTA::CAB::Server::HTTP::Handler'));

  ##-- default: return undef
  return undef;
}

##======================================================================
## Local package aliases
##======================================================================
BEGIN {
  __PACKAGE__->registerAlias(
			     'DTA::CAB::Server::HTTP::Handler::base' => __PACKAGE__,
			     'base' => __PACKAGE__,
			    );
}

1; ##-- be happy
