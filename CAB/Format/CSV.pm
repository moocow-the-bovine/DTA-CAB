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

## $fmt = $fmt->parseTextString($string)
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
