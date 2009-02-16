## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Perl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: perl code via Data::Dumper, eval()

package DTA::CAB::Format::Perl;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use Data::Dumper;
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

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
##     dumper => $dumper,              ##-- underlying Data::Dumper object
##
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

		   ##-- Input
		   #doc => undef,

		   ##-- Output
		   dumper => Data::Dumper->new([])->Purity(1)->Terse(0),
		   level  => 0,
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
##  + default just returns empty list
sub noSaveKeys {
  return qw(doc outbuf);
}

##==============================================================================
## Methods: Parsing
##==============================================================================

##--------------------------------------------------------------
## Methods: Parsing: Input selection

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
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parsePerlString($_[0]);
}

##--------------------------------------------------------------
## Methods: Parsing: Local

## $fmt = $fmt->parsePerlString($str)
sub parsePerlString {
  my $fmt = shift;
  my ($doc);
  $doc = eval "no strict; $fmt->{src}";
  $fmt->warn("parsePerlString(): error in eval: $@") if ($@);
  $doc = DTA::CAB::Utils::deep_utf8_upgrade($doc);
  $fmt->{doc} = $fmt->forceDocument($doc);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Parsing: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument { return $_[0]{doc}; }


##==============================================================================
## Methods: Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  delete($_[0]{outbuf});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
sub toString { return $_[0]{outbuf}; }

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)

##--------------------------------------------------------------
## Methods: Formatting: Generic API

## $fmt = $fmt->putToken($tok)
sub putToken {
  $_[0]{outbuf} .= $_[0]{dumper}->Reset->Indent($_[0]{level})->Names(['token'])->Values([$_[1]])->Dump;
  return $_[0];
}

## $fmt = $fmt->putSentence($sent)
sub putSentence {
  $_[0]{outbuf} .= $_[0]{dumper}->Reset->Indent($_[0]{level})->Names(['sentence'])->Values([$_[1]])->Dump;
  return $_[0];
}

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  $_[0]{outbuf} .= $_[0]{dumper}->Reset->Indent($_[0]{level})->Names(['document'])->Values([$_[1]])->Dump;
  return $_[0];
}


1; ##-- be happy

__END__
