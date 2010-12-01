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
## + %options:
##     encoding => $defaultEncoding,  ##-- default encoding (UTF-8)
##     allowGet => $bool,             ##-- allow GET requests? (default=1)
##     allowPost => $bool,            ##-- allow POST requests? (default=1)
##
## + runtime %$handler data:
##     cgi => $cgiobj,                ##-- CGI object (after cgiParse())
##     vars => \%vars,                ##-- CGI variables (after cgiParse())
##     cgisrc => $cgisrc,             ##-- CGI source (after cgiParse())
sub new {
  my $that = shift;
  my $handler =  bless {
			encoding=>'UTF-8', ##-- default CGI parameter encoding
			allowGet=>1,
			allowPost=>1,
			@_
		       }, ref($that)||$that;
  return $handler;
}

## $bool = $handler->prepare($server)
sub prepare { return 1; }

## \%vars = $handler->decodeVars(\%vars,%opts)
##  + decodes cgi-style variables using $handler->decodeString($str,%opts)
##  + %opts:
##     vars    => \@vars,      ##-- list of vars to decode (default=keys(%vars))
##     someKey => $someVal,    ##-- passed to $handler->decodeString()
sub decodeVars {
  my ($handler,$vars,%opts) = @_;
  return undef if (!defined($vars));
  my $keys = $opts{vars} || [keys %$vars];
  my ($vref);
  foreach (grep {exists $vars->{$_}} @$keys) {
    $vref = \$vars->{$_};
    if (ref($$vref)) {
      $_ = $handler->decodeString($_,%opts) foreach (@{$$vref});
    } else {
      $$vref = $handler->decodeString($$vref,%opts);
    }
  }
  return $vars;
}

## $str = $handler->decodeString($string,%opts)
##  + decodes string as $handler->{encoding}, optionally handling HTML-style escapes
##  + %opts:
##     allowHtmlEscapes => $bool,    ##-- whether to handle HTML escapes (default=false)
##     encoding         => $enc,     ##-- source encoding (default=$handler->{encoding})
sub decodeString {
  my ($handler,$str,%opts) = @_;
  return $str if (!defined($str));
  $str = decode(($opts{encoding}||$handler->{encoding}), $str) if (!utf8::is_utf8($str) && ($opts{encoding}||$handler->{encoding}));
  if ($opts{allowHtmlEscapes}) {
    $str =~ s/\&\#(\d+)\;/pack('U',$1)/eg;
    $str =~ s/\&\#x([[:xdigit:]]+)\;/pack('U',hex($1))/eg;
  }
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
    return $srv->clientError($csock, RC_METHOD_NOT_ALLOWED, "(CGI) GET method not allowed") if (!$handler->{allowGet});
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
    return $srv->clientError($csock, RC_METHOD_NOT_ALLOWED, "(CGI) POST method not allowed") if (!$handler->{allowPost});
    $cgisrc = $hreq->content;
  }
  else {
    ##-- HTTP request: unknown
    return $srv->clientError($csock, RC_METHOD_NOT_ALLOWED, ("(CGI) method not allowed: ".$hreq->method));
  }

  ##-- parse CGI parameters
  my $cgi = $handler->{cgi} = CGI->new($cgisrc || '');
  $handler->{vars}   = $cgi->Vars();
  $handler->{cgisrc} = $cgisrc;

  return $cgi;
}


1; ##-- be happy
