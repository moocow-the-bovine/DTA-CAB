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
##     timeout => $timeout,           ##-- timeout in seconds, default: 300 (5 minutes)
##     mode => $queryMode,            ##-- query mode: qw(get post xpost xmlrpc); default='xpost' (post with get-like parameters)
##     post => $postmode,             ##-- post mode; one of 'urlencoded' (default), 'multipart'
##     rpcns => $prefix,              ##-- prefix for XML-RPC analyzer names (default='dta.cab.')
##     rpcpath => $path,              ##-- path part of URL for XML-RPC (default='/xmlrpc')
##
##     format   => $formatName,       ##-- default query I/O format (default='json')
##     encoding => $encoding,         ##-- query encoding (default='UTF-8')
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
##     rclient => $xmlrpc_client,       ##-- underlying DTA::CAB::Client::XmlRpc object
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
			   ##
			   format => 'json',
			   encoding => 'UTF-8',
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
  return $cli->rclient->connected if ($cli->{mode} eq 'xmlrpc');
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
  return $cli->rclient->connect if ($cli->{mode} eq 'xmlrpc');
  $cli->ua()
    or $cli->logdie("could not create underlying LWP::UserAgent: $!");
  return $cli->connected();
}

## $bool = $cli->disconnect()
##  + really just deletes the LWP::UserAgent object
sub disconnect {
  my $cli = shift;
  $cli->rclient->disconnect();
  delete @$cli{qw(ua rclient)};
  return 1;
}

## @analyzers = $cli->analyzers()
##  + appends '/list' to $cli->{serverURL} and parses returns
##    list of raw text lines returned
##  + die()s on error
sub analyzers {
  my $cli = shift;
  return $cli->rclient->analyzers() if ($cli->{mode} eq 'xmlrpc');

  my $rsp = $cli->uget($cli->{serverURL}.'/list?f=tt');
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

## $rclientent = $cli->rclient()
##  + gets underlying DTA::CAB::Client::XmlRpc object, caching if required
sub rclient {
  return $_[0]{rclient} if (defined($_[0]{rclient}));
  ##
  require DTA::CAB::Client::XmlRpc;
  my $cli = shift;
  my $xuri = URI->new($cli->{serverURL});
  $xuri->path($cli->{rpcpath});
  return $cli->{rclient} = DTA::CAB::Client::XmlRpc->new(%$cli, serverURL=>$xuri->as_string);
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
##  + returns a new DTA::CAB::Format object appropriate for
##    parsing/formatting a $cli query with \%opts
sub getFormat {
  my ($cli,$opts) = @_;
  my $fc  = $opts->{format} || $opts->{fmt} || $cli->{format} || $DTA::CAB::Format::CLASS_DEFAULT;
  my $enc = $opts->{encoding} || $opts->{enc} || $cli->{encoding};
  return DTA::CAB::Format->newFormat($fc, encoding=>$enc);
}

## $response = $cli->analyzeDataRef($analyzer, \$data_str, \%opts)
##  + client-side %opts
##     contentType => $mimeType,      ##-- Content-Type to apply for mode='xpost'
##     encoding    => $charset,       ##-- character set for mode='xpost'; also used by server
##     qraw        => $bool,          ##-- if true, query is a raw untokenized string (default=false)
##  + server-side %opts: see DTA::CAB::Server::HTTP::Handler::Query
sub analyzeDataRef {
  my ($cli,$aname,$dataref,$opts) = @_;
  return $cli->rclient->analyzeData($cli->{rpcns}.$aname,$$dataref,$opts) if ($cli->{mode} eq 'xmlrpc');

  ##-- build form
  my %form = (
	      fmt=>$cli->{format},
	      enc=>$cli->{encoding},
	      %$opts,
	      a=>$aname,
	     );

  ##-- sanity checks (long parameter names clobber short names)
  $form{enc} = $form{encoding} if ($form{encoding});
  $form{fmt} = $form{format} if ($form{format});
  delete(@form{qw(format encoding qraw)});
  delete(@form{grep {!defined($form{$_})} keys %form});

  ##-- content-type hacks
  my $ctype = $opts->{contentType};
  $ctype = 'application/octet-stream' if (!$ctype);
  delete(@form{qw(q qd contentType)});

  ##-- compatibility check / raw vs. formatted
  my $qname = $opts->{qraw} ? 'q' : 'qd';
  my $qmode = $cli->{mode};
  if ($qname eq 'q' && $cli->{mode} eq 'xpost') {
    $cli->logcarp("analyzeDataRef(): 'xpost' method not supported for raw queries; using 'post' instead");
    $qmode = 'post';
  }

  ##-- get response
  my ($rsp);
  if ($qmode eq 'get') {
    $form{$qname} = $$dataref;
    return $cli->uget_form($cli->{serverURL}, \%form);
  }
  elsif ($qmode eq 'post') {
    $form{$qname} = $$dataref;
    return $cli->upost($cli->{serverURL}, \%form,
		       ($cli->{post} && $cli->{post} eq 'multipart' ? ('Content-Type'=>'form-data') : qw()),
		      );
  }
  elsif ($qmode eq 'xpost') {
    $ctype .= "; charset=\"$form{enc}\"" if ($ctype !~ /octet-stream/ && $ctype !~ /\bcharset=/);
    return $cli->uxpost($cli->{serverURL}, \%form, $$dataref, 'Content-Type'=>$ctype);
  }

  ##-- should never happen
  return HTTP::Response->new(RC_NOT_IMPLEMENTED, "not implemented: unknown client mode '$qmode'");
}

## $data_str = $cli->analyzeData($analyzer, \$data_str, \%opts)
##  + wrapper for analyzeDataRef()
##  + die()s on error
##  + you should pass $opts->{'Content-Type'} as some sensible value
sub analyzeData {
  my ($cli,$aname,$data,$opts) = @_;
  return $cli->rclient->analyzeData($cli->{rpcns}.$aname,$data,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $rsp = $cli->analyzeDataRef($aname,\$data,$opts);
  $cli->logdie("server returned error: " . $rsp->status_line) if ($rsp->is_error);
  return $rsp->content;
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my ($cli,$aname,$doc,$opts) = @_;
  return $cli->rclient->analyzeDocument($cli->{rpcns}.$aname,$doc,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $fmt = $cli->getFormat($opts);
  $fmt->putDocument($doc)
    or $cli->logdie("analyzeDocument(): could not format document with class ".ref($fmt).": $!");
  my $str = $fmt->toString;
  $fmt->flush;
  ##
  my $rsp = $cli->analyzeDataRef($aname,\$str,{%$opts,
					       fmt => $fmt->shortName,
					       enc => $fmt->{encoding},
					       contentType=>$fmt->mimeType,
					      });
  $cli->logdie("server returned error: " . $rsp->status_line) if ($rsp->is_error);
  return $fmt->parseString($rsp->content);
}

## $sent = $cli->analyzeSentence($analyzer, $sent, \%opts)
sub analyzeSentence {
  my ($cli,$aname,$sent,$opts) = @_;
  return $cli->rclient->analyzeSentence($cli->{rpcns}.$aname,$sent,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $doc = toDocument [toSentence $sent];
  $doc = $cli->analyzeDocument($aname,$doc,$opts)
    or $cli->logdie("analyzeSentence(): could not analyze temporary document: $!");
  return $doc->{body}[0];
}

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my ($cli,$aname,$tok,$opts) = @_;
  return $cli->rclient->analyzeToken($cli->{rpcns}.$aname,$tok,$opts) if ($cli->{mode} eq 'xmlrpc');
  ##
  my $doc = toDocument [toSentence [toToken $tok]];
  $doc = $cli->analyzeDocument($aname,$doc,$opts)
    or $cli->logdie("analyzeToken(): could not analyze temporary document: $!");
  return $doc->{body}[0]{tokens}[0];
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Client::HTTP - generic HTTP server client for DTA::CAB

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Client::HTTP;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 
 ##========================================================================
 ## Methods: Generic Client API: Connections
 
 $bool = $cli->connected();
 $bool = $cli->connect();
 $bool = $cli->disconnect();
 @analyzers = $cli->analyzers();
 
 ##========================================================================
 ## Methods: Generic Client API: Queries
 
 $data_str = $cli->analyzeData($analyzer, \$data_str, \%opts);
 $doc = $cli->analyzeDocument($analyzer, $doc, \%opts);
 $sent = $cli->analyzeSentence($analyzer, $sent, \%opts);
 $tok = $cli->analyzeToken($analyzer, $tok, \%opts);
 
 $fmt = $cli->getFormat(\%opts);
 $response = $cli->analyzeDataRef($analyzer, \$data_str, \%opts);
 
 ##========================================================================
 ## Methods: Low-Level Utilities
 
 $agent    = $cli->ua();
 $rclient  = $cli->rclient();
 $uriStr   = $cli->urlEncode(\%form);
 $response = $cli->urequest($httpRequest);
 $response = $cli->uhead($url, Header=>Value, ...);
 $response = $cli->uget($url, $headers);
 $response = $cli->upost( $url );
 $response = $cli->uget_form($url, \%form);
 $response = $cli->uxpost($url, \%form,  $content, @headers);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::HTTP: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Client::HTTP inherits from
L<DTA::CAB::Client|DTA::CAB::Client>, and
optionally uses
L<DTA::CAB::Client::XmlRpc|DTA::CAB::Client::XmlRpc>
for communication with an XML-RPC server.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::HTTP: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $cli = CLASS_OR_OBJ->new(%args);

%args, %$cli:

    (
     ##-- server
     serverURL => $url,             ##-- default: localhost:8000
     encoding => $enc,              ##-- default character set for client-server I/O (default='UTF-8')
     timeout => $timeout,           ##-- timeout in seconds, default: 300 (5 minutes)
     mode => $queryMode,            ##-- query mode: qw(get post xpost xmlrpc); default='xpost' (post with get-like parameters)
     post => $postmode,             ##-- post mode; one of 'urlencoded' (default), 'multipart'
     rpcns => $prefix,              ##-- prefix for XML-RPC analyzer names (default='dta.cab.')
     rpcpath => $path,              ##-- path part of URL for XML-RPC (default='/xmlrpc')
     format => $fmtName,            ##-- DTA::CAB::Format short name for transfer (default='json')
     ##
     ##-- debugging
     tracefh => $fh,                ##-- dump requests to $fh if defined (default=undef)
     testConnect => $bool,          ##-- if true connected() will send a test query (default=true)
     ##
     ##-- underlying LWP::UserAgent
     ua => $ua,                     ##-- underlying LWP::UserAgent object
     uargs => \%args,               ##-- options to LWP::UserAgent->new()
     ##
     ##-- optional underlying DTA::CAB::Client::XmlRpc
     rclient => $xmlrpc_client,     ##-- underlying DTA::CAB::Client::XmlRpc object
    )

If $cli-E<gt>{mode} is "xmlrpc", all methods calls will be dispatched to the
underlying L<DTA::CAB::Client::XmlRpc|DTA::CAB::Client::XmlRpc> object
$cli-E<gt>{rclient}.  See L<DTA::CAB::Client::XmlRpc|DTA::CAB::Client::XmlRpc> for details.
The rest of this manual page documents object behavior in "raw HTTP mode",
in which $cli-E<gt>{mode} is one of:

=over 4

=item get

Queries are sent to the server using HTTP GET requests.
Best if you are sending many short queries.

=item post

Queries are sent to the server using HTTP POST requests.
Form data is encoded according to $cli-E<gt>{post}.

=item xpost

Queries are sent to the server using HTTP POST requests,
in which query options are passed directly in the request
URL (as for GET requests), and the data to be analyzed
is formatted and passed as the literal request content.
This is the default query mode.

=back

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::HTTP: Methods: Generic Client API: Connections
=pod

=head2 Methods: Generic Client API: Connections

=over 4

=item connected

 $bool = $cli->connected();

Returns true if a test query (HEAD) returns a successful response.

=item connect

 $bool = $cli->connect();

Establish connection to server.  Generates the underlying connection object
($cli-E<gt>{ua} or $cli-E<gt>{rclient}).
Really does nothing but create the LWP::UserAgent object in raw HTTP mode.

=item disconnect

 $bool = $cli->disconnect();

Deletes underlying LWP::UserAgent object.


=item analyzers

 @analyzers = $cli->analyzers();

Appends '/list' to $cli-E<gt>{serverURL} and parses
list of raw text lines returned;
die()s on error

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::HTTP: Methods: Generic Client API: Queries
=pod

=head2 Methods: Generic Client API: Queries

=over 4

=item getFormat

 $fmt = $cli->getFormat(\%opts);

Returns a new DTA::CAB::Format object appropriate for a $cli query with %opts.

=item analyzeDataRef

 $response = $cli->analyzeDataRef($analyzer, \$data_str, \%opts);

Low-level wrapper for the various query methods.
$analyzer is the name of an analyzer known to the server,
\$data_str is a reference to a formatted buffer holding the data to be analyzed,
and \%opts represent the query options (see below).
Returns a HTTP::Response object representing the server response.

=over 4

=item Client-Side Options

 contentType => $mimeType,      ##-- Content-Type header to apply for mode='xpost'
 encoding    => $charset,       ##-- Character set for mode='xpost'; also used by server

=item Server-Side Options

 ##-- query data, in order of preference
 data => $docData,              ##-- document data; set from $data_ref (post, xpost)
 q    => $rawQuery,             ##-- query string; set from $data_ref (get)
 ##
 ##-- misc
 a => $analyzer,                ##-- analyzer name; set from $analyzer
 format => $format,             ##-- I/O format
 encoding => $enc,              ##-- I/O encoding (default=$cli->{encoding})
 pretty => $level,              ##-- pretty-printing level
 raw => $bool,                  ##-- if true, data will be returned as text/plain (default=$h->{returnRaw})

See L<DTA::CAB::Server::HTTP::Handler::Query|DTA::CAB::Server::HTTP::Handler::Query>
for a full list of parameters supported by raw HTTP servers.

=back

=item analyzeData

 $data_str = $cli->analyzeData($analyzer, \$data_str, \%opts);

Wrapper for analyzeDataRef();
die()s on error.

You should pass $opts-E<gt>{'Content-Type'} as some sensible value
for the query data.  If you don't, the Content-Type header will be
'application/octet-stream'.

=item analyzeDocument

 $doc = $cli->analyzeDocument($analyzer, $doc, \%opts);

Implements L<DTA::CAB::Client::analyzeDocument|DTA::CAB::Client/analyzeDocument>.

=item analyzeSentence

 $sent = $cli->analyzeSentence($analyzer, $sent, \%opts);

Implements L<DTA::CAB::Client::analyzeSentence|DTA::CAB::Client/analyzeSentence>.

=item analyzeToken

 $tok = $cli->analyzeToken($analyzer, $tok, \%opts);

Implements L<DTA::CAB::Client::analyzeToken|DTA::CAB::Client/analyzeToken>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::HTTP: Methods: Utils
=pod

=head2 Methods: Low-Level Utilities

=over 4

=item ua

 $agent = $cli->ua();

Gets underlying LWP::UserAgent object, caching if required.

=item rclient

 $rclientent = $cli->rclient();

For xmlrpc mode, gets underlying DTA::CAB::Client::XmlRpc object, caching if required.

=item urlEncode

 $uriStr = $cli->urlEncode(\%form);
 $uriStr = $cli->urlEncode(\@form);
 $uriStr = $cli->urlEncode( $str);

Encodes query form parameters or a raw string for inclusing in a URL.

=item urequest

 $response = $cli->urequest($httpRequest);

Gets response for $httpRequest (a HTTP::Request object) using $cli-E<gt>ua-E<gt>request().
Also traces request to $cli-E<gt>{tracefh} if defined.

=item uhead

 $response = $cli->uhead($url, Header=>Value, ...);

HEAD request.

=item uget

 $response = $cli->uget($url, $headers);

GET request.

=item upost

 $response = $cli->upost( $url );
 $response = $cli->upost( $url,  $content, Header =E<gt> Value,... )
 $response = $cli->upost( $url, \$content, Header =E<gt> Value,... )
 $response = $cli->upost( $url, \%form,    Header =E<gt> Value,... )

POST request.
Specify 'Content-Type'=E<gt>'form-data' to get "multipart/form-data" forms.

=item uget_form

 $response = $cli->uget_form($url, \%form);
 $response = $cli->uget_form($url, \@form, @headers);

GET request for form data.

=item uxpost

 $response = $cli->uxpost($url, \%form,  $content, @headers);
 $response = $cli->uxpost($url, \%form, \$content, @headers);

POST request which encodes \%form in the URL (as for GET) and sends $content
as the request content.

=back

=cut


##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<dta-cab-http-server.perl(1)|dta-cab-http-server.perl>,
L<dta-cab-http-client.perl(1)|dta-cab-http-client.perl>,
L<dta-cab-xmlrpc-server.perl(1)|dta-cab-xmlrpc-server.perl>,
L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl>,
L<DTA::CAB::Client(3pm)|DTA::CAB::Client>,
L<DTA::CAB::Server::HTTP(3pm)|DTA::CAB::Server::HTTP>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...

=cut
