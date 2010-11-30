##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::AnalyzerCGI.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP::Handler class: analyzer CGI
##======================================================================

package DTA::CAB::Server::HTTP::Handler::AnalyzerCGI;
use DTA::CAB::Server::HTTP::Handler::CGI;
use HTTP::Status;
use URI::Escape qw(uri_escape uri_escape_utf8);
use Encode qw(encode decode);
use CGI ':standard';
use Carp;
use strict;

our @ISA = qw(DTA::CAB::Server::HTTP::Handler::CGI);

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'AnalyzerCGI' => __PACKAGE__,
						 'analyzerCGI' => __PACKAGE__,
						 'analyzercgi' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## Methods: API

## $handler = $class_or_obj->new(%options)
sub new {
  my $that = shift;
  my $handler =  bless {
			encoding=>'UTF-8', ##-- default CGI parameter encoding
			@_
		       }, ref($that)||$that;
  return $handler;
}

## $bool = $handler->prepare($server)
sub prepare { return 1; }

## $bool = $path->run($server, $localPath, $clientSocket, $httpRequest)
##  + local processing
sub run {
  my ($handler,$srv,$path,$csock,$hreq) = @_;
  my $akey = $path;
  my ($a,$ao);

  ##-- get analyzer
  if (!defined($a=$srv->{as}{$akey})) {
    $srv->clientError($csock, RC_NOT_FOUND, "unknown analyzer '$akey'");
    return 0;
  }
  $ao = $srv->{aos}{$akey} || {};

  ##-- parse query parameters
  my $cgi = $handler->cgiParse($srv,$path,$csock,$hreq)
    or return undef;
  my $vars = $handler->{vars};
  $vars->{q} = decodeString($vars->{q});

  ##-- CONTINUE HERE: how to handle cgi stuff?

  ##-- parse query options
  my $qopts = {
	       %$ao,
	       ($handler->{allowUserOptions} ? %{$handler->{vars} || {}} : qw()),
	      };
}


##--------------------------------------------------------------
## Methods: Local

1; ##-- be happy
