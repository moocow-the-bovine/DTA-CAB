## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Client::HTTP.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA::CAB generic HTTP server clients

package DTA::CAB::Client::HTTP;
use DTA::CAB;
use DTA::CAB::Datum ':all';
use DTA::CAB::Utils ':all';
use DTA::CAB::Client;
#use DTA::CAB::Client::XmlRpc;
use LWP::UserAgent;
use HTTP::Status;
use HTTP::Request::Common;
use URI::Escape qw(uri_escape_utf8);
use Encode qw(encode decode encode_utf8 decode_utf8);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Client);

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- server
##     serverURL => $url,             ##-- default: localhost:8000
##     encoding => $enc,              ##-- default character set for client-server I/O (default='UTF-8')
##     timeout => $timeout,           ##-- timeout in seconds, default: 300 (5 minutes)
##     mode => $queryMode,            ##-- query mode: qw(get post xpost xmlrpc); default='xpost' (post with get-like parameters)
##     post => $postmode,             ##-- post mode; one of 'urlencoded' (default), 'multipart'
##     rpcns => $prefix,              ##-- prefix for XML-RPC analyzer names (default='dta.cab.')
##     rpcpath => $path,              ##-- path part of URL for XML-RPC (default='/xmlrpc')
##     format => $fmtName,            ##-- DTA::CAB::Format short name for transfer (default='json')
##
##     ##-- debugging
##     tracefh => $fh,                ##-- dump requests to $fh if defined (default=undef)
##     testConnect => $bool,          ##-- if true connected() will send a test query (default=true)
##
##     ##-- underlying LWP::UserAgent
##     ua => $ua,                     ##-- underlying LWP::UserAgent object
##     uargs => \%args,               ##-- options to LWP::UserAgent->new()
##
##     ##-- optional underlying DTA::CAB::Client::XmlRpc
##     rpcli => $xmlrpc_client,       ##-- underlying DTA::CAB::Client::XmlRpc object
##    }
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- server
			   serverURL  => 'http://localhost:8000',
			   encoding => 'UTF-8',
			   timeout => 300,
			   testConnect => 1,
			   mode => 'xpost',
			   #post => 'multipart',
			   post => 'urlencoded',
			   rpcns => 'dta.cab.',
			   rpcpath => '/xmlrpc',
			   format => 'json',
			   ##
			   ##-- low-level stuff
			   ua => undef,
			   uargs => {},
			   ##
			   ##-- user args
			   @_,
			  );
}

##==============================================================================
## Methods: Generic Client API: Connections
##==============================================================================

## $bool = $cli->connected()
sub connected {
  my $cli = shift;
  return $cli->rpcli->connected if ($cli->{mode} eq 'xmlrpc');
  return 0 if (!$cli->{ua});
  return 1 if (!$cli->{testConnect});

  ##-- send a test query (system.identity())
  my $rsp = $cli->uhead($cli->{serverURL});
  return $rsp && $rsp->is_success ? 1 : 0;
}

## $bool = $cli->connect()
##  + establish connection
##  + really does nothing but create the LWP::UserAgent object
sub connect {
  my $cli = shift;
  return $cli->rpcli->connect if ($cli->{mode} eq 'xmlrpc');
  $cli->ua()
    or $cli->logdie("could not create underlying LWP::UserAgent: $!");
  return $cli->connected();
}

## $bool = $cli->disconnect()
##  + really just deletes the LWP::UserAgent object
sub disconnect {
  my $cli = shift;
  $cli->rpcli->disconnect();
  delete @$cli{qw(ua rpcli)};
  return 1;
}

## @analyzers = $cli->analyzers()
##  + appends '/list' to $cli->{serverURL} and parses returns
##    list of raw text lines returned
##  + die()s on error
sub analyzers {
  my $cli = shift;
  return $cli->rpcli->analyzers() if ($cli->{mode} eq 'xmlrpc');

  my $rsp = $cli->uget($cli->{serverURL}.'/list?format=tt');
  $cli->logdie("analyzers(): GET $cli->{serverURL}/list failed: ", $rsp->status_line)
    if (!$rsp || $rsp->is_error);
  my $content = $rsp->content;
  return grep {defined($_) && $_ ne ''} split(/\r?\n/,$content);
}

##==============================================================================
## Methods: Utils
##==============================================================================

## $agent = $cli->ua()
##  + gets underlying LWP::UserAgent object, caching if required
sub ua {
  return $_[0]{ua} if (defined($_[0]{ua}));
  return $_[0]{ua} = LWP::UserAgent->new(%{$_[0]->{uargs}});
}

## $rpclient = $cli->rpcli()
##  + gets underlying DTA::CAB::Client::XmlRpc object, caching if required
sub rpcli {
  return $_[0]{rpcli} if (defined($_[0]{rpcli}));
  ##
  require DTA::CAB::Client::XmlRpc;
  my $cli = shift;
  my $xuri = URI->new($cli->{serverURL});
  $xuri->path($cli->{rpcpath});
  return $cli->{rpcli} = DTA::CAB::Client::XmlRpc->new(%$cli, serverURL=>$xuri->as_string);
}

## $uriStr = $cli->urlEncode(\%form)
## $uriStr = $cli->urlEncode(\@form)
## $uriStr = $cli->urlEncode( $str)
sub urlEncode {
  my ($cli,$form) = @_;
  my $uri = URI->new;
  if (isa($form,'ARRAY')) {
    $uri->query_form([map {utf8::is_utf8($_) ? Encode::encode_utf8($_) : $_} @$form]);
  }
  elsif (isa($form,'HASH')) {
    $uri->query_form([map {utf8::is_utf8($_) ? Encode::encode_utf8($_) : $_}
		      map {($_=>$form->{$_})}
		      sort keys %$form]);
  }
  else {
    return uri_escape_utf8($form);
  }
  return $uri->query;
}

## $response = $cli->urequest($httpRequest)
##   + gets response for $httpRequest using $cli->ua()
##   + also traces request to $cli->{tracefh} if defined
sub urequest {
  my ($cli,$hreq) = @_;
  $cli->{tracefh}->print("\n__BEGIN__\n", $hreq->as_string, "__END__\n") if (defined($cli->{tracefh}));
  return $cli->ua->request($hreq);
}

## $response = $cli->uhead($url, Header=>Value, ...)
sub uhead {
  return $_[0]->urequest(HEAD @_[1..$#_]);
}

## $response = $cli->uget($url, $headers)
sub uget {
  #return $_[0]->ua->get(@_[1..$#_]);
  return $_[0]->urequest(GET @_[1..$#_]);
}

## $response = $cli->upost( $url )
## $response = $cli->upost( $url,  $content, Header => Value,... )
## $response = $cli->upost( $url, \$content, Header => Value,... )
## $response = $cli->upost( $url, \%form,    Header => Value,... )
##  + specify 'Content-Type'=>'form-data' to get "multipart/form-data" forms
sub upost {
  #return $_[0]->ua->post(@_[1..$#_]);
  my ($hreq);
  if (isa($_[2],'HASH')) {
    ##-- form
    $hreq = POST @_[1..$#_];
  }
  elsif (isa($_[2],'SCALAR')) {
    ##-- content reference
    $hreq = POST $_[1], @_[3..$#_];
    $hreq->content_ref($_[2]);
  }
  else {
    ##-- content string
    $hreq = POST $_[1], @_[3..$#_], Content=>$_[2];
  }
  return $_[0]->urequest($hreq);
}

## $response = $cli->uget_form($url, \%form)
## $response = $cli->uget_form($url, \@form, @headers)
sub uget_form {
  my ($cli,$url,$form,@headers) = @_;
  return $cli->uget(($url.'?'.$cli->urlEncode($form)),@headers);
}

## $response = $cli->uxpost($url, \%form,  $content, @headers)
## $response = $cli->uxpost($url, \%form, \$content, @headers);
##  + encodes \%form as url-internal parameters (as for uget_form())
##  + POST data is $content
sub uxpost {
  #my ($cli,$url,$form,$data,@headers) = @_;
  return $_[0]->upost(($_[1].'?'.$_[0]->urlEncode($_[2])), @_[3..$#_]);
}

##==============================================================================
## Methods: Generic Client API: Queries
##==============================================================================

## $fmt = $cli->getFormat(\%opts)
sub getFormat {
  my ($cli,$opts) = @_;
  my $fmtClass = $opts->{format} || $cli->{format} || $DTA::CAB::Format::CLASS_DEFAULT;
  return DTA::CAB::Format->newFormat($fmtClass,
				     encoding=>($opts->{encoding} || $cli->{encoding}),
				    );
}

## $response = $cli->analyzeDataRef($analyzer, \$data_str, \%opts)
##  + client-side %opts
##     contentType => $mimeType,      ##-- Content-Type to apply for mode='xpost'
##     encoding    => $charset,       ##-- character set for mode='xpost'; also used by server
##  + server-side %opts:
##     ##-- query data, in order of preference
##     data => $docData,              ##-- document data (for analyzeDocument())
##     q    => $rawQuery,             ##-- raw untokenized query string (for analyzeDocument())
##     ##
##     ##-- misc
##     a => $analyer,                 ##-- analyzer key in %{$srv->{as}}
##     format => $format,             ##-- I/O format
##     encoding => $enc,              ##-- I/O encoding (default=$cli->{encoding})
##     pretty => $level,              ##-- pretty-printing level
##     raw => $bool,                  ##-- if true, data will be returned as text/plain (default=$h->{returnRaw})
sub analyzeDataRef {
  my ($cli,$aname,$dataref,$opts) = @_;
  return $cli->rpcli->analyzeData($cli->{rpcns}.$aname,$$dataref,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my %form = (format=>$cli->{format},
	      encoding=>$cli->{encoding},
	      %$opts,
	      a=>$aname,
	     );
  my $ctype = $opts->{contentType};
  $ctype = 'application/octet-stream' if (!$ctype);
  delete(@form{qw(q data contentType)});
  my ($rsp);
  if ($cli->{mode} eq 'get') {
    $form{'q'} = $$dataref;
    return $cli->uget_form($cli->{serverURL}, \%form);
  }
  elsif ($cli->{mode} eq 'post') {
    $form{'data'} = $$dataref;
    return $cli->upost($cli->{serverURL}, \%form,
		       ($cli->{post} && $cli->{post} eq 'multipart' ? ('Content-Type'=>'form-data') : qw()),
		      );
  }
  elsif ($cli->{mode} eq 'xpost') {
    $ctype .= "; charset=\"$form{encoding}\"" if ($ctype !~ /octet-stream/ && $ctype !~ /\bcharset=/);
    return $cli->uxpost($cli->{serverURL}, \%form, $$dataref, 'Content-Type'=>$ctype);
  }

  ##-- should never happen
  return HTTP::Response->new(RC_NOT_IMPLEMENTED, "not implemented: unknown client mode '$cli->{mode}'");
}

## $data_str = $cli->analyzeData($analyzer, \$data_str, \%opts)
##  + wrapper for analyzeDataRef()
##  + die()s on error
##  + you should pass $opts->{'Content-Type'} as some sensible value
sub analyzeData {
  my ($cli,$aname,$data,$opts) = @_;
  return $cli->rpcli->analyzeData($cli->{rpcns}.$aname,$data,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $rsp = $cli->analyzeDataRef($aname,\$data,$opts);
  $cli->logdie("server returned error: " . $rsp->status_line) if ($rsp->is_error);
  return $rsp->content;
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my ($cli,$aname,$doc,$opts) = @_;
  return $cli->rpcli->analyzeDocument($cli->{rpcns}.$aname,$doc,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $fmt = $cli->getFormat($opts);
  $fmt->putDocument($doc)
    or $cli->logdie("analyzeDocument(): could not format document with class ".ref($fmt).": $!");
  my $str = $fmt->toString;
  $fmt->flush;
  my $rsp = $cli->analyzeDataRef($aname,\$str,{%$opts, format=>$fmt->shortName, contentType=>$fmt->mimeType, encoding=>$fmt->{encoding}});
  $cli->logdie("server returned error: " . $rsp->status_line) if ($rsp->is_error);
  return $fmt->parseString($rsp->content);
}

## $sent = $cli->analyzeSentence($analyzer, $sent, \%opts)
sub analyzeSentence {
  my ($cli,$aname,$sent,$opts) = @_;
  return $cli->rpcli->analyzeSentence($cli->{rpcns}.$aname,$sent,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $doc = toDocument [toSentence $sent];
  $doc = $cli->analyzeDocument($aname,$doc,$opts)
    or $cli->logdie("analyzeSentence(): could not analyze temporary document: $!");
  return $doc->{body}[0];
}

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my ($cli,$aname,$tok,$opts) = @_;
  return $cli->rpcli->analyzeToken($cli->{rpcns}.$aname,$tok,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $doc = toDocument [toSentence [toToken $tok]];
  $doc = $cli->analyzeDocument($aname,$doc,$opts)
    or $cli->logdie("analyzeToken(): could not analyze temporary document: $!");
  return $doc->{body}[0]{tokens}[0];
}


1; ##-- be happy

__END__

