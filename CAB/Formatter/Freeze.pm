## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::Freeze.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: Storable::freeze

package DTA::CAB::Formatter::Freeze;
use DTA::CAB::Formatter;
use Storable;
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
			   ##-- user args
			   @_
			  );
}


##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

## $out = $fmt->formatToken($tok)
sub formatToken {
  return Storable::nfreeze($_[1]);
}

## $out = $fmt->formatSentence($sent)
sub formatSentence {
  return Storable::nfreeze($_[1]);
}

## $out = $fmt->formatDocument($doc)
sub formatDocument {
  return Storable::nfreeze($_[1]);
}


1; ##-- be happy

__END__
