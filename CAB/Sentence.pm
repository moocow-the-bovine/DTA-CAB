## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Sentence.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for sentences passed to/from DTA::CAB::Analyzer

package DTA::CAB::Sentence;
use DTA::CAB::Datum;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Datum);

##==============================================================================
## Constructors etc.
##==============================================================================

## $s = CLASS_OR_OBJ->new(\@tokens,%sentenceAttrs)
##  + object structure: ARRAY
##    [
##     \%sentenceAttrs,          ##-- sentence-global data (may be undef)
##     @tokens,                  ##-- sentence tokens (DTA::CAB::Token objects)
##    ]
sub new {
  return bless([
		{@_[2..$#_]},
		@{$_[1]},
	       ],
	       ref($_[0]) || $_[0]);
}

##==============================================================================
## Methods: ???
##==============================================================================



1; ##-- be happy

__END__
