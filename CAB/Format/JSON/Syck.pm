## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::JSON::Syck.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: YML code via JSON::Syck

package DTA::CAB::Format::JSON::Syck;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use JSON::Syck qw();
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::JSON);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:json\.syck|jsn\.syck)$/);
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
##     ##---- INHERITED from DTA::CAB::Format
##     #encoding => $encoding,         ##-- n/a: always UTF-8 octets
##     level     => $formatLevel,      ##-- 0:raw, 1:types, ... (default=0); has no effect here
##     outbuf    => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- I/O common
		   encoding => undef,

		   ##-- Input
		   #doc => undef,

		   ##-- Output
		   level  => 1,
		   outbuf => '',

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
  $JSON::Syck::ImplicitTyping  = 0;  # if true, e.g. Load('Yes') becomes 1 and Load('No') becomes ''.
  $JSON::Syck::ImplicitUnicode = 1;  # automagically set utf8 flag for valid utf8 sequences
  $JSON::Syck::LoadCode        = 0;  # don't automatically eval embedded perl code
  $doc = JSON::Syck::Load($_[0])
    or $fmt->logwarn("ParseJsonString(): JSON::Syck::Load() failed: $!");
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
#sub toString {
#  $_[0]->formatLevel($_[1]) if (defined($_[1]));
#  return $_[0]{outbuf};
#}


## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putToken($tok)
##  + runs, but doesn't produce well-formed output
sub putToken {
  $JSON::Syck::ImplicitTyping  = 0;  # if true, e.g. Load('Yes') becomes 1 and Load('No') becomes ''.
  $JSON::Syck::ImplicitUnicode = 0;  # automagically set utf8 flag for valid utf8 sequences, also on output strings
  $JSON::Syck::DumpCode        = 1;  # automagically deparse embedded perl code
  $_[0]{outbuf} .= JSON::Syck::Dump($_[1]);
  return $_[0];
}

## $fmt = $fmt->putSentence($sent)
##  + runs, but doesn't produce well-formed output
sub putSentence {
  $JSON::Syck::ImplicitTyping  = 0;  # if true, e.g. Load('Yes') becomes 1 and Load('No') becomes ''.
  $JSON::Syck::ImplicitUnicode = 0;  # automagically set utf8 flag for valid utf8 sequences, also on output strings
  $JSON::Syck::DumpCode        = 1;  # automagically deparse embedded perl code
  $_[0]{outbuf} .= JSON::Syck::Dump($_[1]);
  return $_[0];
}

## $fmt = $fmt->putDocument($doc)
##  + runs, but doesn't produce well-formed output
sub putDocument {
  $JSON::Syck::ImplicitTyping  = 0;  # if true, e.g. Load('Yes') becomes 1 and Load('No') becomes ''.
  $JSON::Syck::ImplicitUnicode = 0;  # automagically set utf8 flag for valid utf8 sequences, also on output strings
  $JSON::Syck::DumpCode        = 1;  # automagically deparse embedded perl code
  $_[0]{outbuf} .= JSON::Syck::Dump($_[1]);
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

DTA::CAB::Format::JSON::Syck - Datum parser|formatter: JSON code via JSON::Syck

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::JSON::Syck;
 
 $fmt = DTA::CAB::Format::JSON::Syck->new(%args);
 
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

DTA::CAB::Format::JSON::Syck is a L<DTA::CAB::Format|DTA::CAB::Format> datum parser/formatter
which reads & writes data as JSON::Syck code using the JSON::Syck module.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON::Syck: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::JSON::Syck
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

=item Filenames

DTA::CAB::Format::JSON::Syck registers the filename regex:

 /\.(?i:yaml|yml)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON::Syck: Constructors etc.
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
## DESCRIPTION: DTA::CAB::Format::JSON::Syck: Methods: Persistence
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
## DESCRIPTION: DTA::CAB::Format::JSON::Syck: Methods: Input
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
## DESCRIPTION: DTA::CAB::Format::JSON::Syck: Methods: Output
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

