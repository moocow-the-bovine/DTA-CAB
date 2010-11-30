##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::CGI.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP::Handler class: CGI
##======================================================================

package DTA::CAB::Server::HTTP::Handler::CGI;
use DTA::CAB::Server::HTTP::Handler;
use HTTP::Status;
use URI::Escape qw(uri_escape uri_escape_utf8);
use Encode qw(encode decode);
use CGI;
use Carp;
use strict;

our @ISA = qw(DTA::CAB::Server::HTTP::Handler);

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'DTA::CAB::Server::Server::HTTP::Handler::CGI' => __PACKAGE__,
						 'cgi' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## Methods

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

## $str = $handler->decodeString($string)
##  + decodes string as $handler->{encoding}, also handles HTML-style escapes
sub decodeString {
  my ($handler,$str) = @_;
  return $str if (!defined($str));
  $str = decode($handler->{encoding}, $str);
  $str =~ s/\&\#(\d+)\;/pack('U',$1)/eg;
  $str =~ s/\&\#x([[:xdigit:]]+)\;/pack('U',hex($1))/eg;
  return $str;
}

## $cgi_obj = $handler->cgiParse($srv,$localPath,$clientSocket,$httpRequest)
##  + parses cgi parameters from client request
##  + sets following $handler fields:
##     cgi    => $cgi_obj,
##     vars   => \%cgi_vars,
##     cgisrc => $cgi_src_str,
##  + returns undef on error
sub cgiParse {
  my ($handler,$srv,$localPath,$csock,$hreq) = @_;

  my ($cgisrc);
  if ($hreq->method eq 'GET') {
    ##-- HTTP request: GET
    if ($hreq->uri =~ m/\?(.*)$/) {
      $cgisrc = $1;
    } else {
      #$srv->clientError($csock, RC_NOT_FOUND, ("(CGI) Server::HTTP::Handler ".$hreq->uri." not found."));
      #$srv->clientError($csock, RC_INTERNAL_SERVER_ERROR, ("(CGI) Server::HTTP::Handler ".$hreq->uri.": no parameters specified!"));
      #return undef;
      $cgisrc = '';
    }
  }
  elsif ($hreq->method eq 'POST') {
    ##-- HTTP request: POST
    $cgisrc = $hreq->content;
  }
  else {
    ##-- HTTP request: unknown
    $srv->clientError($csock, RC_METHOD_NOT_ALLOWED, ("(CGI) method not allowed: ".$hreq->method));
    return undef;
  }

  ##-- parse CGI parameters
  my $cgi = $handler->{cgi} = CGI->new($cgisrc || '');
  $handler->{vars}   = $cgi->Vars();
  $handler->{cgisrc} = $cgisrc;

  return $cgi;
}


1; ##-- be happy
