##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::XmlRpc.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP::Handler class: XML-RPC
##======================================================================

package DTA::CAB::Server::HTTP::Handler::XmlRpc;
use DTA::CAB::Server::HTTP::Handler;
use DTA::CAB::Server::XmlRpc;
use HTTP::Status;
use Encode qw(encode decode);
use CGI;
use Carp;
use strict;

our @ISA = qw(DTA::CAB::Server::HTTP::Handler);

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'DTA::CAB::Server::Server::HTTP::Handler::XmlRpc' => __PACKAGE__,
						 'XmlRpc' => __PACKAGE__,
						 'xmlrpc' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## Methods

## $h = $class_or_obj->new(%options)
## + %options:
##     cxsrv    => $cxsrv,            ##-- underlying DTA::CAB::Server::XmlRpc object
##
## + runtime %$h data:
sub new {
  my $that = shift;
  my $h =  bless {
		  cxsrv => undef,
		  @_
		 }, ref($that)||$that;
  return $h;
}

## $bool = $h->prepare($server)
sub prepare {
  my ($h,$srv,$path) = @_;

  ##-- get underlying DTA::CAB::Server::XmlRpc object
  my ($cxsrv);
  if (!defined($cxsrv=$srv->{cxsrv})) {
    $cxsrv = $srv->{cxsrv} = DTA::CAB::Server::XmlRpc->new(%$srv)
      or $h->logdie("prepare(): could not create DTA::CAB::Server::XmlRpc object: $!");
  }
  $h->{cxsrv} = $cxsrv;

  ##-- prepare underlying server
  return $cxsrv->prepareLocal() if (!defined($cxsrv->{xsrv}));

  return 1;
}

## $rsp = $path->run($server, $localPath, $clientConn, $httpRequest)
##  + perform local processing
##  + should return a HTTP::Response object to pass to the client
##  + if the call die()s or returns undef, an error response will be
##    sent to the client instead if it the connection is still open
##  + this method may return the data to the client itself; if so,
##    it should close the client connection ($csock->shutdown(2); $csock->close())
##    and return undef to prevent bogus error messages.
sub run {
  my ($h, $srv, $path, $csock, $hreq) = @_;
  my $xmlsrv = $h->{cxsrv}{xsrv}; ##-- underlying RPC::XML::Server object

  if ($hreq->method eq 'HEAD') {
    # The HEAD method will be answered with our return headers,
    # both as a means of self-identification and a verification
    # of live-status. All the headers were pre-set in the cached
    # HTTP::Response object. Also, we don't count this for stats.
    return $xmlsrv->response;
  }
  elsif ($hreq->method eq 'POST') {
    # Extract & serve XML-RPC request
    my ($xmlreq);
    $xmlreq = $xmlsrv->parser->parse($hreq->content);
    return $h->cerror($csock, RC_INTERNAL_SERVER_ERROR, "Error parsing XML-RPC request")
      if (!defined($xmlreq));

    # Dispatch will always return a RPC::XML::response.
    # RT29351: If there was an error from RPC::XML::Parser (such as
    # a message that didn't conform to spec), then return it directly
    # as a fault, don't have dispatch() try and handle it.
    my ($xmlrsp);
    if (ref($xmlreq)) {
      local $xmlsrv->{peeraddr} = $csock->peeraddr;
      local $xmlsrv->{peerport} = $csock->peerport;
      local $xmlsrv->{peerhost} = $csock->peerhost;
      $xmlrsp = $xmlsrv->dispatch($xmlreq);
    } else {
      $xmlrsp = RPC::XML::fault->new(RC_INTERNAL_SERVER_ERROR, $xmlreq);
      $xmlrsp = RPC::XML::response->new($xmlrsp);
      return $h->cerror($csock, RC_INTERNAL_SERVER_ERROR, $xmlrsp->as_string)
    }

    # Clone the pre-fab response and set headers
    my $resp    = $xmlsrv->response->clone;
    my $content = $xmlrsp->as_string;
    $resp->content($content);
    $resp->content_length(bytes::length($content));
    $csock->send_response($resp);
    $csock->shutdown(2);
    $csock->close();
  }
  else {
    return $h->cerror($csock, RC_FORBIDDEN)
  }

  return undef;
}

## undef = $h->finish($server, $clientConn)
##  + clean up handler state after run()
##  + default implementation does nothing
sub finish {
  return;
}


1; ##-- be happy
