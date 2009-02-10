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
##     ##---- INHERITED from DTA::CAB::Formatter
##     ##-- output file (optional)
##     #outfh => $output_filehandle,  ##-- for default toFile() method
##     #outfile => $filename,         ##-- for determining whether $output_filehandle is local
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- encoding
			   encoding => 'UTF-8',

			   ##-- Dumper
			   dumper => Data::Dumper->new([])->Purity(1)->Terse(0)->Indent(1),

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: verbosity

## $fmt = $fmt->verbose($level)
##   + 0 <= $level <= 3 : set verbosity level (Data::Dumper 'Indent' property)
sub verbose {
  $_[0]{dumper}->Indent($_[1]);
  return $_[0];
}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================


## $out = $fmt->formatToken($tok)
sub formatToken {
  return $_[0]{dumper}->Reset->Names(['token'])->Values([$_[1]])->Dump;
}

## $out = $fmt->formatSentence($sent)
sub formatSentence {
  return $_[0]{dumper}->Reset->Names(['sentence'])->Values([$_[1]])->Dump;
}

## $out = $fmt->formatDocument($doc)
sub formatDocument {
  return $_[0]{dumper}->Reset->Names(['document'])->Values([$_[1]])->Dump;
}


1; ##-- be happy

__END__
