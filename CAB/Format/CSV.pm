## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::CSV.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser: concise minimal-output human-readable text

package DTA::CAB::Format::CSV;
use DTA::CAB::Format;
use DTA::CAB::Format::TT;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::TT);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:csv|cab\-csv)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- Input
##     doc => $doc,                    ##-- buffered input document
##
##     ##---- Output
##     #level    => $formatLevel,      ##-- output formatting level: n/a
##     outbuf    => $stringBuffer,     ##-- buffered output
##
##     ##---- Common
##     encoding  => $encoding,         ##-- default: 'UTF-8'
##    )
## + inherited from DTA::CAB::Format::TT

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved: qw(doc outbuf)
##  + inherited from DTA::CAB::Format::TT

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
##  + inherited from DTA::CAB::Format::TT

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($fh)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
##  + wrapper for: $fmt->close->parseTTString($_[0])
##  + inherited from DTA::CAB::Format::TT
##  + name is aliased here to parseTextString() !

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseCsvString($string)
BEGIN { *parseTTString = \&parseCsvString; }
sub parseCsvString {
  my ($fmt,$src) = @_;
  $src =~ s|^([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$|$1\t[moot/word] $2\t[moot/tag] $3\t[moot/lemma] $4|mg;
  return DTA::CAB::Format::TT::parseTTString($fmt,$src);
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##  + just returns $fmt->{doc}
##  + inherited from DTA::CAB::Format::TT


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.csv'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
##  + inherited from DTA::CAB::Format::TT

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
##  + inherited TT default just encodes string in $fmt->{outbuf}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putToken($tok)
##  + appends $tok to output buffer
## $fmt = $fmt->putToken($tok)
sub putToken {
  my ($fmt,$tok) = @_;
  $fmt->{outbuf} .= join("\t",
			 $tok->{text},
			 ($tok->{moot} ? (@{$tok->{moot}}{qw(word tag lemma)}) : ('','','')),
			)."\n";
}

## $fmt = $fmt->putSentence($sent)
##  + concatenates formatted tokens, adding sentence-id comment if available
##  + inherited from DTA::CAB::Format::TT

## $out = $fmt->formatDocument($doc)
##  + concatenates formatted sentences, adding document 'xmlbase' comment if available
##  + inherited from DTA::CAB::Format::TT

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::CSV - Datum I/O: concise minimal-output human-readable text

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::CSV;
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->parseCsvString($string);
 
 ##========================================================================
 ## Methods: Output
 
 $type = $fmt->mimeType();
 $ext = $fmt->defaultExtension();
 $fmt = $fmt->putToken($tok);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::CSV
is a L<DTA::CAB::Format|DTA::CAB::Format> subclass
for representing the minimal "interesting" results of a
L<DTA::CAB::Chain::DTA|DTA::CAB::Chain::DTA> canonicalization
in a (more or less) human- and machine-friendly TAB-separated format.
As for L<DTA::CAB::Format::TT|DTA::CAB::Format::TT> (from which this class inherits),
each token is represented by a single line and sentence boundaries
are represented by blank lines.  Token lines have the format:

 OLD_TEXT   NEW_TEXT    POS_TAG    LEMMA

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::CSV: Methods: Input: Local
=pod

=head2 Methods: Input: Local

=over 4

=item parseCsvString

 $fmt = $fmt->parseCsvString($string);

Hack which converts a CSV string to a TT string and passes it to
L<DTA::CAB::Format::TT::parseTTString|DTA::CAB::Format::TT/parseTTString>().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::CSV: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item mimeType

 $type = $fmt->mimeType();

Default returns text/plain.

=item defaultExtension

 $ext = $fmt->defaultExtension();

Deturns default filename extension for this format.
Override returns '.csv'.

=item putToken

 $fmt = $fmt->putToken($tok);

Appends $tok to output buffer.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod



=cut

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<DTA::CAB::Format::TT(3pm)|DTA::CAB::Format::TT>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
