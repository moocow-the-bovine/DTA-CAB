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

## $handler = $class_or_obj->new(%options)
##  + %options
##     response => $obj,  ##-- HTTP::Response object
sub new {
  my $that = shift;
  return bless { response=>undef, @_ }, ref($that)||$that;
}

## $bool = $handler->run($server, $localPath, $clientSocket)
sub processClientRequest {
  my ($handler,$srv,$path,$csock) = @_;
  if (!defined($handler->{response})) {
    $srv->clientError($csock,RC_NOT_FOUND);
    return 1;
  }
  $csock->send_response($handler->{response});
  return 1;
}


1; ##-- be happy
