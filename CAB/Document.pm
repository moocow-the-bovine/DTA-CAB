## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for whole documents passed to/from DTA::CAB::Analyzer

package DTA::CAB::Document;
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

## $doc = CLASS_OR_OBJ->new(\@sentences,%documentAttrs)
##  + object structure: HASH
##    [
##     \%documentAttrs,          ##-- document-global attributes (may be undef)
##     @sentences,               ##-- document sentences (DTA::CAB::Sentence objects)
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
