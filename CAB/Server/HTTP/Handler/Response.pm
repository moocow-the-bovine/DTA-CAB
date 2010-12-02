##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::Response.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP handler class: static response
##======================================================================

package DTA::CAB::Server::HTTP::Handler::Response;
use DTA::CAB::Server::HTTP::Handler;
use HTTP::Status;
use Carp;
use strict;

our @ISA = qw(DTA::CAB::Server::HTTP::Handler);

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'DTA::CAB::Server::HTTP::Handler::response' => __PACKAGE__,
						 'response' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## Methods

## $h = $class_or_obj->new(%options)
##  + %options
##     response => $obj,  ##-- HTTP::Response object
sub new {
  my $that = shift;
  return bless { response=>undef, @_ }, ref($that)||$that;
}

## $rsp = $h->run($server, $localPath, $clientConn, $hreq)
sub processClientRequest {
  my ($h,$srv,$path,$csock,$hreq) = @_;
  return $h->cerror($csock, RC_NOT_FOUND) if (!defined($h->{response}));
  return $h->{response};
}


1; ##-- be happy
