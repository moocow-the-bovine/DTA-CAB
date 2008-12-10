## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Automaton::Gfsm.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analysis automaton API: Gfsm automata

package DTA::CAB::Automaton::Gfsm;
use DTA::CAB::Automaton;
use Gfsm;
use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Automaton);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Automaton
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- analysis objects
			      fst=>Gfsm::Automaton->new,
			      lab=>Gfsm::Alphabet->new,
			      result=>Gfsm::Automaton->new,

			      ##-- user args
			      @_
			     );
  return $aut;
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $class = $aut->fstClass()
##  + default FST class for loadFst() method
sub fstClass { return 'Gfsm::Automaton'; }

## $class = $aut->labClass()
##  + default labels class for loadLabels() method
sub labClass { return 'Gfsm::Alphabet'; }

## $bool = $aut->fstOk()
##  + should return false iff fst is undefined or "empty"
sub fstOk { return defined($_[0]{fst}) && $_[0]{fst}->n_states>0; }

## $bool = $aut->labOk()
##  + should return false iff label-set is undefined or "empty"
sub labOk { return defined($_[0]{lab}) && $_[0]{lab}->size>0; }

## $bool = $aut->dictOk()
##  + should return false iff dict is undefined or "empty"
##(inherited)

##==============================================================================
## Methods: I/O
##==============================================================================

##==============================================================================
## Methods: Analysis
##==============================================================================

## $coderef = $aut->analysis_sub()
##  + returned sub is callable as:
##     $coderef->($native_perl_encoded_string,\%analyzeOptions)
##  + caches sub in $aut->{_analyze}
##  + implicitly loads automaton and labels
##(inherited)



1; ##-- be happy

__END__
