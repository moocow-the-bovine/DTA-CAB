## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Null.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: null formatter

package DTA::CAB::Format::Null;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  #DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:prl|pl|perl|dump)$/);
  ;
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- INHERITED from DTA::CAB::Format
##     #encoding => $encoding,         ##-- n/a
##     level     => $formatLevel,      ##-- sets Data::Dumper->Indent() option
##     outbuf    => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- I/O common
		   encoding => undef,
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


##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
sub close {
  return $_[0];
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($filename_or_handle)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parsePerlString($str)
sub parsePerlString {
  return $_[0];
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument { return DTA::CAB::Document->new; }


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
sub toString { return ''; }

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putToken($tok)
sub putToken { return $_[0]; }

## $fmt = $fmt->putSentence($sent)
sub putSentence { return $_[0]; }

## $fmt = $fmt->putDocument($doc)
sub putDocument { return $_[0]; }


1; ##-- be happy

__END__
