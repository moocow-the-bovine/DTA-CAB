## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlRpc.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: XML-RPC using RPC::XML

package DTA::CAB::Format::XmlRpc;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Datum ':all';
use RPC::XML;
use RPC::XML::Parser;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlCommon);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-rpc|rpc[\-\.]xml)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- input
##     rxprs  => $rpc_parser,      ##-- RPC::XML::Parser object
##     rxdata => $rpc_data,        ##-- structured data as decoded by RPC::XML::Parser
##
##     ##-- output
##     docbuf => $doc,             ##-- DTA::CAB::Document output buffer
##     xprs   => $xml_parser,      ##-- XML::LibXML parser object
##     level  => $formatLevel,     ##-- format level
##     encoding => $encoding,      ##-- output encoding
##
##     ##-- common
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   rxprs => RPC::XML::Parser->new(),
		   #rxdata => undef,

		   ##-- output
		   docbuf   => DTA::CAB::Document->new(),
		   encoding => 'UTF-8',
		   level    => 0,
		   #xprs => XML::LibXML->new, (inherited from XmlCommon)
		   #xdoc => undef, (inherited from XmlCommon)

		   ##-- common
		   #(none)

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $fmt;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns empty list
sub noSaveKeys {
  return qw(rxprs rxdata docbuf xprs);
}


##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
##  + close current input source, if any
sub close {
  delete($_[0]{rxdata});
  return $_[0];
}

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->close;
  $fmt->{rxdata} = $fmt->{rxprs}->parse($_[0]);
  return $fmt->checkData();
}

## $fmt = $fmt->fromFile($filename_or_handle)
sub fromFile { return $_[0]->DTA::CAB::Format::fromFile(@_[1..$#_]); }

## $fmt = $fmt->fromFh($handle)
sub fromFh {
  my ($fmt,$fh) = @_;
  $fmt->close;
  $fmt->{rxdata} = $fmt->{rxprs}->parse($fh);
  return $fmt->checkData();
}

## $fmt_or_undef = $fmt->checkData()
##  + check for valid parse
sub checkData {
  my $fmt = shift;
  if (!defined($fmt->{rxdata})) {
    $fmt->logwarn("checkData(): no parse data {rxdata} defined");
    return undef;
  }
  elsif (!ref($fmt->{rxdata})) {
    $fmt->logwarn("checkData(): parse error: $fmt->{rxdata}");
    return undef;
  }
  elsif ($fmt->{rxdata}->is_fault) {
    $fmt->logwarn("checkData(): fault: (".$fmt->{rxdata}->code.") ".$fmt->{rxdata}->string);
    return undef;
  }
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument();
## + Override: parse document from currently selected input source.
sub parseDocument {
  my $fmt = shift;
  if (!defined($fmt->{rxdata})) {
    $fmt->logconfess("parseDocument(): no source data {rxdata} defined!");
    return undef;
  }
  my $doc = $fmt->forceDocument($fmt->{rxdata}->value);

  ##-- force doc refs, deep
  if (UNIVERSAL::isa($doc,'DTA::CAB::Document')) {
    @{$doc->{body}} = map { toSentence($_) } @{$doc->{body}};
    foreach (@{$doc->{body}}) {
      @{$_->{tokens}} = map { toToken($_) } @{$_->{tokens}};
    }
  }

  return $doc;
}

##==============================================================================
## Methods: Output
##==============================================================================


##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  $_[0]{docbuf} = DTA::CAB::Document->new();
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output in $fmt->{docbuf} to byte-string
sub toString {
  my ($fmt,$level) = @_;
  my $rpcobj = RPC::XML::smart_encode( $fmt->{docbuf} );
  $level     = $fmt->{level} if (!defined($level));
  return (defined($level) && $level>0
	  ? $fmt->rpcXmlDocument($rpcobj)->toString($level)
	  : encode($fmt->{encoding}, $rpcobj->as_string));
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
sub toFh {
  my ($fmt,$fh,$level) = @_;
  my $rpcobj = RPC::XML::smart_encode( $fmt->{docbuf} );
  $level     = $fmt->{level} if (!defined($level));
  $fmt->rpcXmlDocument($rpcobj)->toFH($fh,$level);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Output: Local

## $parser = $fmt->xmlParser()
sub xmlParser {
  return $_[0]{xprs} if ($_[0]{xprs});
  return $_[0]{xprs} = XML::LibXML->new();
}

## $xmldoc = $fmt->rpcXmlDocument($rpcobj_or_string)
sub rpcXmlDocument {
  return $_[0]->xmlParser->parse_string( ref($_[1]) ? $_[1]->as_string : $_[1] );
}

##--------------------------------------------------------------
## Methods: Output: Recommended API

## $fmt = $fmt->putToken($tok)
sub putToken { $_[0]->putTokenRaw(Storable::dclone($_[1])); }
sub putTokenRaw {
  my ($fmt,$tok) = @_;
  my $buf = $fmt->{docbuf};
  if (@{$buf->{body}}) {
    push(@{$buf->{body}[$#{$buf->{body}}]}, $tok);
  } else {
    push(@{$buf->{body}}, toSentence([$tok]));
  }
}

## $fmt = $fmt->putSentence($sent)
sub putSentence { $_[0]->putSentenceRaw(Storable::dclone($_[1])); }
sub putSentenceRaw {
  my ($fmt,$sent) = @_;
  push(@{$fmt->{docbuf}{body}}, $sent);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Output: Required API

## $fmt = $fmt->putDocument($doc)
sub putDocument { $_[0]->putDocumentRaw(Storable::dclone($_[1])); }
sub putDocumentRaw {
  my ($fmt,$doc) = @_;
  my $buf = $fmt->{docbuf};
  if (scalar(keys(%$buf))==1 && !@{$buf->{body}}) {
    ##-- steal $doc
    $fmt->{docbuf} = $doc;
  } else {
    ##-- append $doc->{body} onto $buf->{body}
    push(@{$buf->{body}}, @{$doc->{body}});
    foreach (grep {$_ ne 'body'} keys(%$doc)) {
      $buf->{$_} = $doc->{$_}; ##-- clobber existing keys
    }
  }
  return $fmt;
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::XmlRpc - Datum parser: XML-RPC using RPC::XML

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::XmlRpc;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::XmlRpc->new(%args);
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $fmt = $fmt->fromString($string);
 $fmt = $fmt->fromFile($filename_or_handle);
 $fmt = $fmt->fromFh($handle);
 $fmt_or_undef = $fmt->checkData();
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->flush();
 $str = $fmt->toString();
 $parser = $fmt->xmlParser();
 $xmldoc = $fmt->rpcXmlDocument($rpcobj_or_string);
 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putSentence($sent);
 $fmt = $fmt->putDocument($doc);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlRpc: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::XmlRpc
inherits from
L<DTA::CAB::Format::XmlCommon>.

=item Filenames

DTA::CAB::Format::XmlRpc registers the filename regex:

 /\.(?i:xml-rpc|rpc[\-\.]xml)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlRpc: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$fmt:

 ##-- input
 rxprs  => $rpc_parser,      ##-- RPC::XML::Parser object
 rxdata => $rpc_data,        ##-- structured data as decoded by RPC::XML::Parser
 ##
 ##-- output
 docbuf => $doc,             ##-- DTA::CAB::Document output buffer
 xprs   => $xml_parser,      ##-- XML::LibXML parser object
 level  => $formatLevel,     ##-- format level
 encoding => $encoding,      ##-- output encoding
 ##
 ##-- common
 #(nothing here)

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlRpc: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Override: returns list of keys not to be saved
Here, returns C<qw(rxprs rxdata docbuf xprs)>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlRpc: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close current input source, if any.

=item fromString

 $fmt = $fmt->fromString($string);

Override: select input from string $string.

=item fromFile

 $fmt = $fmt->fromFile($filename_or_handle);

Override: select input from named file or handle.
Calls L<DTA::CAB::Format::fromFile()|DTA::CAB::Format/item_fromFile>.

=item fromFh

 $fmt = $fmt->fromFh($handle);

Override: select input from filehandle.

=item checkData

 $fmt_or_undef = $fmt->checkData();

Checks input buffer for valid parse.
Called by C<fromWhatever()> methods.

=item parseDocument

 $doc = $fmt->parseDocument();

Override: parse document from currently selected input source.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlRpc: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item flush

 $fmt = $fmt->flush();

Override: flush accumulated output.

=item toString

 $str = $fmt->toString();
 $str = $fmt->toString($formatLevel);

Override: flush buffered output in $fmt-E<gt>{docbuf} to byte-string.
Calls RPC::XML::smart_encode(), L<$fmt-E<gt>rpcXmlDocument()|/rpcXmlDocument>.

=item toFh

 $fmt_or_undef = $fmt->toFh($fh,$formatLevel);

Override: flush buffered output to filehandle $fh.

=item xmlParser

 $parser = $fmt->xmlParser();

Returns an XML::LibXML object for RPC-XML.

=item rpcXmlDocument

 $xmldoc = $fmt->rpcXmlDocument($rpcobj_or_string);

Returns an XML::LibXML::Document representing its argument $rpcobj_or_string,
which may be either a RPC::XML object or an XML source string.

=item putToken

=item putTokenRaw

 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putTokenRaw($tok);

Non-destructive / destructrive token output.

=item putSentence

=item putSentenceRaw

 $fmt = $fmt->putSentence($sent);
 $fmt = $fmt->putSentenceRaw($sent);

Non-destructive / destructive sentence output.

=item putDocument

=item putDocumentRaw

 $fmt = $fmt->putDocument($doc);
 $fmt = $fmt->putDocumentRaw($doc);

Non-destructive / destructive document output.

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


=cut
