## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::Perl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: perl code

package DTA::CAB::Formatter::Perl;
use DTA::CAB::Formatter;
use Data::Dumper;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Formatter);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- NEW
##     dumper => $data_dumper,         ##-- underlying Data::Dumper object
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     #encoding => $encoding,         ##-- n/a
##     level     => $formatLevel,      ##-- sets Data::Dumper->Indent() option
##     outbuf    => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- Dumper
			   dumper => Data::Dumper->new([])->Purity(1)->Terse(0),
			   level  => 0,
			   outbuf => '',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: output selection
##==============================================================================

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


##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================


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
