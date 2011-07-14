## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::JSON::XS.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: JSON code via JSON::XS

package DTA::CAB::Format::JSON::XS;
use DTA::CAB::Format;
#use DTA::CAB::Format::JSON;
use DTA::CAB::Datum ':all';
use JSON::XS;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::JSON);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'json-xs', filenameRegex=>qr/\.(?i:json[\.\-\_]xs|json[\.\-\_]xs)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: hash
##    (
##     ##---- Input
##     doc => $doc,                    ##-- buffered input document
##
##     ##---- new
##     jxs => $json_xs_object,         ##-- json codec object
##
##     ##---- INHERITED from DTA::CAB::Format
##     #encoding  => $encoding,         ##-- n/a: always UTF-8 octets
##     level     => $formatLevel,      ##-- 0:raw, 1:pretty, ... (default=0)
##     outbuf    => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- I/O common
		   encoding => undef,

		   ##-- Input
		   #doc => undef,

		   ##-- guts
		   jxs => JSON::XS->new->utf8(0)->relaxed(1)->canonical(0)->allow_blessed(1)->convert_blessed(1),

		   ##-- Output
		   level  => 0,
		   outbuf => '',

		   ##-- user args
		   @_
		  }, ref($that)||$that);

  if ($fmt->{level} && $fmt->{level} >= 1) {
    $fmt->{jxs}->pretty;
  }

  return $fmt;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
sub noSaveKeys {
  return qw(doc outbuf);
}

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
sub close {
  delete($_[0]{doc});
  return $_[0];
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($filename_or_handle)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
##  + inherited method calls parseYamlString($string)

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseJsonString($str)
sub parseJsonString {
  my $fmt = shift;
  my ($doc);
  #$doc = $fmt->{jxs}->decode($_[0])
  $doc = $fmt->{jxs}->decode(utf8::is_utf8($_[0]) ? $_[0] :Encode::decode_utf8($_[0]))
    or $fmt->warn("parseJsonString(): JSON::XS::decode() failed: $!");
  $fmt->{doc} = $fmt->{raw} ? $doc : $fmt->forceDocument($doc);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##  + inherited returns buffered $fmt->{doc}

##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
##  + inherited method just deletes $fmt->{outbuf}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + inherited from JSON.pm

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putToken($tok)
##  + runs without errors, but will return non-wf object
sub putToken {
  $_[0]{outbuf} .= $_[0]{jxs}->encode($_[1]);
  return $_[0];
}

## $fmt = $fmt->putSentence($sent)
##  + runs without errors, but will return non-wf object
sub putSentence {
  $_[0]{outbuf} .= $_[0]{jxs}->encode($_[1]);
  return $_[0];
}

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  $_[0]{outbuf} .= $_[0]{jxs}->encode($_[1]);
  return $_[0];
}

## $fmt = $fmt->putData($data)
sub putData {
  $_[0]{outbuf} .= $_[0]{jxs}->encode($_[1]);
  return $_[0];
}



1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::JSON::XS - Datum parser|formatter: JSON code via JSON::XS

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::JSON::XS;
 
 $fmt = DTA::CAB::Format::JSON::XS->new(%args);
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $fmt = $fmt->parseJSONString($str);
 $doc = $fmt->parseDocument();
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->flush();
 $str = $fmt->toString();
 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putSentence($sent);
 $fmt = $fmt->putDocument($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::JSON::XS is a L<DTA::CAB::Format|DTA::CAB::Format> datum parser/formatter
which reads & writes data as JSON::XS code using the JSON::XS module.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON::XS: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::JSON::XS
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

=item Filenames

DTA::CAB::Format::JSON::XS registers the filename regex:

 /\.(?i:yaml|yml)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON::XS: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$fmt:

 ##---- Input
 doc    => $doc,                 ##-- buffered input document
 ##
 ##---- Output
 dumper => $dumper,              ##-- underlying Data::Dumper object
 ##
 ##---- INHERITED from DTA::CAB::Format
 #encoding => $encoding,         ##-- n/a
 level     => $formatLevel,      ##-- sets Data::Dumper->Indent() option
 outbuf    => $stringBuffer,     ##-- buffered output

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON::XS: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Override returns list of keys not to be saved.
This implementation returns C<qw(doc outbuf)>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON::XS: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close currently selected input source.

=item fromString

 $fmt = $fmt->fromString($string)

Override: select input from the string $string.

=item parseJSONString

 $fmt = $fmt->parseJSONString($str);

Evaluates $str as perl code, which is expected to
return a L<DTA::CAB::Document|DTA::CAB::Document>
object (or something which can be massaged into one),
and sets $fmt-E<gt>{doc} to this new document object.

=item parseDocument

 $doc = $fmt->parseDocument();

Returns the current contents of $fmt-E<gt>{doc},
e.g. the most recently parsed document.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON::XS: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item flush

 $fmt = $fmt->flush();

Override: flush accumulated output.

=item toString

 $str = $fmt->toString();
 $str = $fmt->toString($formatLevel)

Override: flush buffered output document to byte-string.
This implementation just returns $fmt-E<gt>{outbuf},
which should already be a UTF-8 byte-string, and has no need of encoding.

=item putToken

 $fmt = $fmt->putToken($tok);

Override: writes a token to the output buffer (non-destructive on $tok).

=item putSentence

 $fmt = $fmt->putSentence($sent);

Override: write a sentence to the outupt buffer (non-destructive on $sent).

=item putDocument

 $fmt = $fmt->putDocument($doc);

Override: write a document to the outupt buffer (non-destructive on $doc).

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Example
##======================================================================
=pod

=head1 EXAMPLE

See L<DTA::CAB::Format::JSON/EXAMPLE>.

=cut

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

