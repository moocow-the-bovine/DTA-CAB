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

## $doc = CLASS_OR_OBJ->new(\@sentences,%args)
##  + object structure: HASH
##    {
##     body => \@sentences,  ##-- DTA::CAB::Sentence objects
##    }
sub new {
  return bless({
		body => ($#_>=1 ? $_[1] : []),
		@_[2..$#_],
	       }, ref($_[0])||$_[0]);
}

##==============================================================================
## Methods: ???
##==============================================================================

1; ##-- be happy

__END__
