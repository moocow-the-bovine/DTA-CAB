## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::LTS.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: letter-to-sound analysis via Gfsm automata

##==============================================================================
## Package: Analyzer::Morph
##==============================================================================
package DTA::CAB::Analyzer::LTS;
use DTA::CAB::Analyzer::Automaton::Gfsm;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Gfsm);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm, DTA::CAB::Analyzer::Automaton
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- overrides
			      #tolower => 1,

			      ##-- analysis selection
			      #analysisClass => 'DTA::CAB::Analyzer::LTS::Analysis',
			      analyzeDst     => 'lts',
			      wantAnalysisLo => 0,

			      ##-- user args
			      @_
			     );
  return $aut;
}

##==============================================================================
## Analysis Formatting
##==============================================================================


1; ##-- be happy

__END__
