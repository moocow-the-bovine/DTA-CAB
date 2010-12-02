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

## $h = $class_or_obj->new(%options)
## + %options:
##     encoding => $defaultEncoding,  ##-- default encoding (UTF-8)
##     allowGet => $bool,             ##-- allow GET requests? (default=1)
##     allowPost => $bool,            ##-- allow POST requests? (default=1)
##
## + runtime %$h data:
##     cgi => $cgiobj,                ##-- CGI object (after cgiParse())
##     vars => \%vars,                ##-- CGI variables (after cgiParse())
##     cgisrc => $cgisrc,             ##-- CGI source (after cgiParse())
sub new {
  my $that = shift;
  my $h =  bless {
			encoding=>'UTF-8', ##-- default CGI parameter encoding
			allowGet=>1,
			allowPost=>1,
			@_
		       }, ref($that)||$that;
  return $h;
}

## $bool = $h->prepare($server)
sub prepare { return 1; }

## \%vars = $h->decodeVars(\%vars,%opts)
##  + decodes cgi-style variables using $h->decodeString($str,%opts)
##  + %opts:
##     vars    => \@vars,      ##-- list of vars to decode (default=keys(%vars))
##     someKey => $someVal,    ##-- passed to $h->decodeString()
sub decodeVars {
  my ($h,$vars,%opts) = @_;
  return undef if (!defined($vars));
  my $keys = $opts{vars} || [keys %$vars];
  my ($vref);
  foreach (grep {exists $vars->{$_}} @$keys) {
    $vref = \$vars->{$_};
    if (ref($$vref)) {
      $_ = $h->decodeString($_,%opts) foreach (@{$$vref});
    } else {
      $$vref = $h->decodeString($$vref,%opts);
    }
  }
  return $vars;
}

## $str = $h->decodeString($string,%opts)
##  + decodes string as $h->{encoding}, optionally handling HTML-style escapes
##  + %opts:
##     allowHtmlEscapes => $bool,    ##-- whether to handle HTML escapes (default=false)
##     encoding         => $enc,     ##-- source encoding (default=$h->{encoding}; see also $h->requestEncoding())
sub decodeString {
  my ($h,$str,%opts) = @_;
  return $str if (!defined($str));
  $str = decode(($opts{encoding}||$h->{encoding}), $str) if (!utf8::is_utf8($str) && ($opts{encoding}||$h->{encoding}));
  if ($opts{allowHtmlEscapes}) {
    $str =~ s/\&\#(\d+)\;/pack('U',$1)/eg;
    $str =~ s/\&\#x([[:xdigit:]]+)\;/pack('U',hex($1))/eg;
  }
  return $str;
}

## \%vars = $h->trimVars(\%vars,%opts)
##  + trims leading and trailing whitespace from selected values in \%vars
##  + %opts:
##     vars    => \@vars,      ##-- list of vars to trim (default=keys(%vars))
sub trimVars {
  my ($h,$vars,%opts) = @_;
  return undef if (!defined($vars));
  my $keys = $opts{vars} || [keys %$vars];
  my ($vref);
  foreach (grep {exists $vars->{$_}} @$keys) {
    $vref = \$vars->{$_};
    if (ref($$vref)) {
      foreach (@{$$vref}) {
	$_ =~ s/^\s+//;
	$_ =~ s/\s+$//;
      }
    } else {
      $$vref =~ s/^\s+//;
      $$vref =~ s/\s+$//;
    }
  }
  return $vars;
}

## \%vars = $h->pushVars(\%vars,\%push)
##  + CGI-like variable push; destructively pushes \%push onto \%vars
sub pushVars {
  my ($h,$vars,$push) = @_;
  foreach (grep {defined($push->{$_})} keys %$push) {
    if (!exists($vars->{$_})) {
      $vars->{$_} = $push->{$_};
    } else {
      $vars->{$_} = [ $vars->{$_} ] if (!ref($vars->{$_}));
      push(@{$vars->{$_}}, ref($push->{$_}) ? @{$push->{$_}} : $push->{$_});
    }
  }
  return $vars;
}

## \%params = $h->uriParams($hreq,%opts)
##  + gets GET-style parameters from $hreq->uri
##  + %opts:
##      #(none)
sub uriParams {
  my ($h,$hreq) = @_;
  if ($hreq->uri =~ m/\=(.*)$/) {
    return scalar(CGI->new($1)->Vars);
  }
  return {};
}

## \%params = $h->contentParams($hreq,%opts)
##  + gets POST-style content parameters from $hreq
##  + if content-type is neither 'application/x-www-form-urlencoded' nor 'multipart/form-data',
##    but content is present, returns $hreq
##  + %opts:
##      defaultName => $name,       ##-- default parameter name (default='POSTDATA')
##      defaultCharset => $charset, ##-- default charset
sub contentParams {
  my ($h,$hreq,%opts) = @_;
  $opts{defaultName} = 'POSTDATA' if (!defined($opts{defaultName}));
  $opts{defaultCharset} = $h->{encoding} if (!defined($opts{defaultCharset}));
  if ($hreq->content_type eq 'application/x-www-form-urlencoded') {
    ##-- x-www-form-urlencoded: parse with CGI module
    return scalar(CGI->new($hreq->content)->Vars);
  }
  elsif ($hreq->content_type eq 'multipart/form-data') {
    ##-- multipart/form-data: parse by hand
    my $vars = {};
    my ($part,$name);
    foreach $part ($hreq->parts) {
      my $dis = $part->header('Content-Disposition');
      if ($dis =~ /^form-data\b/) {
	##-- multipart/form-data: part: form-data
	if ($dis =~ /\bname=[\"\']?([\w\-\.\,\+]*)[\'\"]?/) {
	  ##-- multipart/form-data: part: form-data; name="PARAMNAME"
	  $h->pushVars($vars, { $1 => $part->decoded_content(default_charset=>$opts{defaultCharset}) });
	} else {
	  ##-- multipart/form-data: part: form-data
	  $h->pushVars($vars, { $opts{defaultName}=>$part->decoded_content(default_charset=>$opts{defaultCharset}) });
	}
      }
      else {
	##-- multipart/form-data: part: anything other than 'form-data'
	$h->pushVars($vars, { $opts{defaultName}=>$part->decoded_content(default_charset=>$opts{defaultCharset}) });
      }
    }
    return $vars;
  }
  elsif ($hreq->content_length > 0) {
    ##-- unknown content: use default data key
    return { $opts{defaultName} => $hreq->decoded_content(default_charset=>$opts{defaultCharset}) };
  }
  return {}; ##-- no parameters at all
}

## \%params = $h->params($hreq,%opts)
## + wrapper for $h->pushVars($h->uriParams(),$h->contentParams())
## + %opts are passed to uriParams, contentParams
sub params {
  my ($h,$hreq,%opts) = @_;
  my $vars = $h->uriParams($hreq,%opts);
  $h->pushVars($vars, $h->contentParams($hreq,%opts));
  return $vars;
}


## \%vars = $h->cgiParams($srv,$clientConn,$httpRequest, %opts)
##  + parses cgi parameters from client request
##  + only handles GET or POST requests
##  + wrapper for $h->uriParams(), $h->contentParams()
##  + %opts are passed to uriParams, contentParams
sub cgiParams {
  my ($h,$csock,$hreq,%opts) = @_;

  if ($hreq->method eq 'GET') {
    ##-- HTTP request: GET
    return $h->cerror($csock, RC_METHOD_NOT_ALLOWED, "CGI::cgiParams(): GET method not allowed") if (!$h->{allowGet});
    return $h->uriParams($hreq,%opts);
  }
  elsif ($hreq->method eq 'POST') {
    ##-- HTTP request: POST
    return $h->cerror($csock, RC_METHOD_NOT_ALLOWED, "CGI::cgiParams(): POST method not allowed") if (!$h->{allowPost});
    return $h->params($hreq,%opts);
  }
  else {
    ##-- HTTP request: unknown
    return $h->cerror($csock, RC_METHOD_NOT_ALLOWED, ("CGI::cgiParams(): method not allowed: ".$hreq->method));
  }

  return {};
}

## $enc = $h->requestEncoding($httpRequest)
##  + attempts to guess request encoding from (in order of descending priority):
##    - CGI param 'encoding', from $h->{vars}{encoding}
##    - HTTP header Content-Type charset variable
##    - HTTP header Content-Encoding
##    - $h->{encoding}
sub requestEncoding {
  my ($h,$hreq) = @_;
  return $h->{vars}{encoding} if ($h->{vars} && $h->{vars}{encoding});
  my $ctype = $hreq->content_type;
  return $1 if (defined($ctype) && $ctype =~ /\bcharset=([\w\-]+)/);
  return $hreq->content_encoding if (defined($hreq->content_encoding));
  return $h->{encoding};
}


## undef = $h->finish($server, $clientSocket)
##  + clean up handler state after run()
##  + override deletes @$h{qw(cgi vars cgisrc)}
sub finish {
  my $h = shift;
  delete(@$h{qw(cgi vars cgisrc)});
  return;
}


1; ##-- be happy
