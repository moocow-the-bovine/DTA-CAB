## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Client::HTTP.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA::CAB generic HTTP server clients

package DTA::CAB::Client::HTTP;
#use DTA::CAB::Client::XmlRpc;
use DTA::CAB;
use DTA::CAB::Client;
use DTA::CAB::Datum ':all';
use DTA::CAB::Utils ':all';
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
##     mode => $queryMode,            ##-- query mode; one of 'get', 'post', 'xpost'; default='xpost' (post with get-like parameters)
##     post => $postmode,             ##-- post mode; one of 'urlencoded' (default), 'multipart'
##     format => $fmtName,            ##-- DTA::CAB::Format short name for transfer (default='json')
##
##     ##-- debugging
##     tracefh => $fh,                ##-- dump requests to $fh if defined (default=undef)
##     testConnect => $bool,          ##-- if true connected() will send a test query (default=true)
##
##     ##-- underlying LWP::UserAgent
##     ua => $ua,                     ##-- underlying LWP::UserAgent object
##     uargs => \%args,               ##-- options to LWP::UserAgent->new()
##    }
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- server
			   serverURL      => 'http://localhost:8000',
			   encoding => 'UTF-8',
			   timeout => 300,
			   testConnect => 1,
			   mode => 'xpost',
			   #post => 'multipart',
			   post => 'urlencoded',
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
  $cli->ua()
    or $cli->logdie("could not create underlying LWP::UserAgent: $!");
  return $cli->connected();
}

## $bool = $cli->disconnect()
##  + really just deletes the LWP::UserAgent object
sub disconnect {
  my $cli = shift;
  delete($cli->{ua});
  return 1;
}

## @analyzers = $cli->analyzers()
##  + appends '/list' to $cli->{serverURL} and parses returns
##    list of raw text lines returned
##  + die()s on error
sub analyzers {
  my $cli = shift;
  my $rsp = $cli->uget($cli->{serverURL}.'/list?format=tt');
  $cli->logdie("analyzers(): GET $cli->{serverURL}/list failed: ", $rsp->status_line)
    if (!$rsp || $rsp->is_error);
  my $content = $rsp->content;
  return grep {defined($_) && $_ ne ''} split(/\r?\n/,$content);
}

##==============================================================================
## Methods: Utils
##==============================================================================

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

## $agent = $cli->ua()
##  + gets underlying LWP::UserAgent object, caching if required
sub ua {
  return $_[0]{ua} if (defined($_[0]{ua}));
  return $_[0]{ua} = LWP::UserAgent->new(%{$_[0]->{uargs}});
}

## $response = $cli->request($httpRequest)
##   + gets response for $httpRequest using $cli->ua()
##   + also traces request to $cli->{tracefh} if defined
sub request {
  my ($cli,$hreq) = @_;
  $cli->{tracefh}->print("\n__BEGIN__\n", $hreq->as_string, "__END__\n") if (defined($cli->{tracefh}));
  return $cli->ua->request($hreq);
}

## $request = $cli->request($method)
## $request = $cli->request($method, $uri, $headers)
## $request = $cli->request($method, $uri, $headers, $content)
## $request = $cli->request($method, $uri, $headers, \$content)
##   + returns a new HTTP::Request suitable for passing to LWP::UserAgent::request
##   + also traces to $cli->{tracefh} if defined
sub request_OLD {
  my ($cli,$method,$uri,$header) = @_[0..3];
  $method = 'GET' if (!defined($method));
  $uri    = $cli->{serverURL} if (!defined($uri));
  $header = [] if (!defined($header));
  $header = [ %$header ] if (isa($header,'HASH') && !isa($header,'HTTP::Headers'));
  my $hreq = HTTP::Request->new($method,$uri,$header);
  if (defined($_[4])) {
    if (isa($_[4],'SCALAR')) {
      $hreq->content_ref($_[4]);
    } else {
      $hreq->content($_[4]);
    }
  }
  ##-- trace request
  $cli->{tracefh}->print("\n__BEGIN__\n", $hreq->as_string, "__END__\n") if (defined($cli->{tracefh}));
  return $hreq;
}

## $response = $cli->uhead($url, Header=>Value, ...)
sub uhead {
  return $_[0]->request(HEAD @_[1..$#_]);
}

## $response = $cli->uget($url, $headers)
sub uget {
  #return $_[0]->ua->get(@_[1..$#_]);
  return $_[0]->request(GET @_[1..$#_]);
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
  return $_[0]->request($hreq);
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
  my $rsp = $cli->analyzeDataRef($aname,\$data,$opts);
  $cli->logdie("server returned error: " . $rsp->status_line) if ($rsp->is_error);
  return $rsp->content;
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my ($cli,$aname,$doc,$opts) = @_;
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
  my $doc = toDocument [toSentence $sent];
  $doc = $cli->analyzeDocument($aname,$doc,$opts)
    or $cli->logdie("analyzeSentence(): could not analyze temporary document: $!");
  return $doc->{body}[0];
}

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my ($cli,$aname,$tok,$opts) = @_;
  my $doc = toDocument [toSentence [toToken $tok]];
  $doc = $cli->analyzeDocument($aname,$doc,$opts)
    or $cli->logdie("analyzeToken(): could not analyze temporary document: $!");
  return $doc->{body}[0]{tokens}[0];
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Client::XmlRpc - DTA::CAB XML-RPC server clients

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Client::XmlRpc;
 
 ##========================================================================
 ## Constructors etc.
 
 $cli = DTA::CAB::Client::XmlRpc->new(%args);
 
 ##========================================================================
 ## Methods: Generic Client API: Connections
 
 $bool = $cli->connected();
 $bool = $cli->connect();
 $bool = $cli->disconnect();
 @analyzers = $cli->analyzers();
 
 ##========================================================================
 ## Methods: Utils
 
 $rsp_or_error = $cli->request($req);
 
 ##========================================================================
 ## Methods: Generic Client API: Queries
 
 $req  = $cli->newRequest($methodName, @args);
 $tok  = $cli->analyzeToken($analyzer, $tok, \%opts);
 $sent = $cli->analyzeSentence($analyzer, $sent, \%opts);
 $doc  = $cli->analyzeDocument($analyzer, $doc, \%opts);


=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::XmlRpc: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Client::XmlRpc
inherits from
L<DTA::CAB::Client|DTA::CAB::Client>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::XmlRpc: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $cli = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$cli:

 ##-- server selection
 serverURL      => $url,         ##-- default: localhost:8000
 encoding       => $encoding,    ##-- default: UTF-8
 timeout        => $timeout,     ##-- timeout in seconds, default: 300 (5 minutes)
 ##
 ##-- underlying RPC::XML client
 xcli           => $xcli,        ##-- RPC::XML::Client object

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::XmlRpc: Methods: Generic Client API: Connections
=pod

=head2 Methods: Generic Client API: Connections

=over 4

=item connected

 $bool = $cli->connected();

Override: returns true iff $cli is connected to a server.

=item connect

 $bool = $cli->connect();

Override: establish connection to the selected server.

=item disconnect

 $bool = $cli->disconnect();

Override: close current server connection, if any.

=item analyzers

 @analyzers = $cli->analyzers();

Override: get list of known analyzers from the server.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::XmlRpc: Methods: Utils
=pod

=head2 Methods: Utils

=over 4

=item request

 $rsp_or_error = $cli->request($req);
 $rsp_or_error = $cli->request($req, $doDeepEncoding=1)

Send an XML-RPC request $req, log if error occurs.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client::XmlRpc: Methods: Generic Client API: Queries
=pod

=head2 Methods: Generic Client API: Queries

=over 4

=item newRequest

 $req = $cli->newRequest($methodName, @args);

Returns new RPC::XML::request for $methodName(@args).
Encodes all atomic data types as strings

=item analyzeToken

 $tok = $cli->analyzeToken($analyzer, $tok, \%opts);

Override: server-side token analysis.

=item analyzeSentence

 $sent = $cli->analyzeSentence($analyzer, $sent, \%opts);

Override: server-side sentence analysis.

=item analyzeDocument

 $doc = $cli->analyzeDocument($analyzer, $doc, \%opts);

Override: server-side document analysis.

=item analyzeData

 $data_str = $cli->analyzeData($analyzer, $input_str, \%opts)

Override: server-side raw-data analysis.

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

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
