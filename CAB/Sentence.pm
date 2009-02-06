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



## $s = CLASS_OR_OBJ->new(\@tokens,%args)
##  + object structure: HASH
##    {
##     tokens => \@tokens,   ##-- DTA::CAB::Token objects
##    }
sub new {
  return bless({
		tokens => ($#_>=1 ? $_[1] : []),
		@_[2..$#_],
	       }, ref($_[0])||$_[0]);
}

##  + object structure: ARRAY
##    [ @tokens ]                ##-- sentence tokens (DTA::CAB::Token objects)
##                               ##   + may contain "dummy" tokens w/o 'text' attribute
sub new_v1 {
  return bless((@_==2 && ref($_[1]) eq 'ARRAY'
		? $_[1]
		: [ @_[1..$#_] ]),
	       ref($_[0]) || $_[0]);
}

##  + object structure: ARRAY
##    [ \%attrs, @tokens ]                ##-- sentence tokens (DTA::CAB::Token objects)
##                                        ##   + may contain "dummy" tokens w/o 'text' attribute
sub new_v0 {
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
