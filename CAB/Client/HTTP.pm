## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Client::HTTP.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA::CAB generic HTTP server clients

package DTA::CAB::Client::HTTP;
use DTA::CAB::Client::HTTP::XmlRpc;
use DTA::CAB;
use DTA::CAB::Client;
use DTA::CAB::Datum ':all';
use DTA::CAB::Utils ':all';
use LWP::UserAgent;
use URI::Escape qw(uri_escape_utf8);
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
##     serverEncoding => $encoding,   ##-- default: UTF-8
##     timeout => $timeout,           ##-- timeout in seconds, default: 300 (5 minutes)
##     mode => $queryMode,            ##-- query mode; one of 'get', 'post', 'xpost'; default='xpost' (post with get-like parameters)
##     format => $fmtName,            ##-- DTA::CAB::Format name for transfer (default='JSON')
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
			   serverEncoding => 'UTF-8', ##-- default server encoding
			   timeout => 300,
			   testConnect => 1,
			   mode => 'xpost',
			   format => 'JSON',
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
sub analyzers {
  my $cli = shift;
  my $rsp = $cli->uget($cli->{serverURL}.'/list');
  return qw() if (!$rsp || $rsp->is_error);
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

## $response = $cli->uhead($url, $header_name=>$value, ...)
sub uhead {
  return $_[0]->ua->head(@_[1..$#_]);
}

## $response = $cli->uget($url, $header_name=>$value, ...)
sub uget {
  return $_[0]->ua->get(@_[1..$#_]);
}

## $response = $cli->upost( $url, \%form )
## $response = $cli->upost( $url, \@form )
## $response = $cli->upost( $url, \%form, $field_name => $value, ... )
## $response = $cli->upost( $url, $field_name => $value,... Content => \%form )
## $response = $cli->upost( $url, $field_name => $value,... Content => \@form )
## $response = $cli->upost( $url, $field_name => $value,... Content => $content )
sub upost {
  return $_[0]->ua->post(@_[1..$#_]);
}

## $uriStr = $cli->urlEncode(\%form)
## $uriStr = $cli->urlEncode(\@form)
sub urlEncode {
  my ($cli,$form) = @_;
  if (isa($form,'HASH')) {
    return join('&', map { uri_escape_utf8($_)."=".uri_escape_utf8($form->{$_}) } keys(%$form));
  }
  elsif (isa($form,'ARRAY')) {
    my ($i,@params);
    for ($i=1; $i <= $#$form; $i += 2) {
      push(@params, uri_escape_utf8($form->[$i-1]).'='.uri_escape_utf8($form->[$i]));
    }
    return join('&', @params);
  }
  return $form;
}

## $response = $cli->uget_form($url, \%form, $field_name=>$value, ...)
## $response = $cli->uget_form($url, \@form, $field_name=>$value, ...)
sub uget_form {
  my ($cli,$url,$form,@headers) = @_;
  return $cli->uget(($url.'?'.$cli->urlEncode($form)),@headers);
}

## $response = $cli->uxpost($url, \%form, $content, $field_name=>$value, ...)
##  + encodes \%form as url-internal parameters (as for uget_form())
##  + POST data is $content
sub uxpost {
  my ($cli,$url,$form,$data,@headers) = @_;
  return $cli->upost(($url.'?'.$cli->urlEncode($form)), @headers, Content=>$data);
}

##==============================================================================
## Methods: Generic Client API: Queries
##==============================================================================

##-- CONTINUE HERE!

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my ($cli,$aname,$tok,$opts) = @_;


  my $suffix = $opts && $opts->{methodSuffix} ? $opts->{methodSuffix} : ''; ##-- e.g. methodSuffix=>1" for v1.x interface
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeToken${suffix}",
					   $tok,
					   (defined($opts) ? $opts : qw())
					  ));
  return ref($rsp) && !$rsp->is_fault ? toToken($rsp->value) : $rsp;
}

## $sent = $cli->analyzeSentence($analyzer, $sent, \%opts)
sub analyzeSentence {
  my ($cli,$aname,$sent,$opts) = @_;
  my $suffix = $opts && $opts->{methodSuffix} ? $opts->{methodSuffix} : '';  ##-- e.g. methodSuffix=>1" for v1.x interface
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeSentence${suffix}",
					   $sent,
					   (defined($opts) ? $opts : qw())
					  ));
  return ref($rsp) && !$rsp->is_fault ? toSentence($rsp->value) : $rsp;
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my ($cli,$aname,$doc,$opts) = @_;
  my $suffix = $opts && $opts->{methodSuffix} ? $opts->{methodSuffix} : ''; ##-- e.g. methodSuffix=>1" for v1.x interface
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeDocument${suffix}",
					   $doc,
					   (defined($opts) ? $opts : qw())
					  ));
  return ref($rsp) && !$rsp->is_fault ? toDocument($rsp->value) : $rsp;
}

## $data_str = $cli->analyzeData($analyzer, $input_str, \%opts)
sub analyzeData {
  my ($cli,$aname,$data,$opts) = @_;
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeData",
					   RPC::XML::base64->new($data),
					   (defined($opts) ? $opts : qw())
					  ),
			  0 ##-- no deep encode/decode
			 );
  return ref($rsp) && !$rsp->is_fault ? $rsp->value : $rsp;
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
 serverEncoding => $encoding,    ##-- default: UTF-8
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
