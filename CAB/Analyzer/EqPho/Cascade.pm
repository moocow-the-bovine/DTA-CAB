## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::EqPho::Cascade.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: phonetic equivalence via Gfsm::XL cascade

##==============================================================================
## Package: Analyzer::EqPho::Cascade
##==============================================================================
package DTA::CAB::Analyzer::EqPho::Cascade;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Gfsm::XL);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm::XL
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- defaults
			      #analysisClass => 'DTA::CAB::Analyzer::Rewrite::Analysis',

			      ##-- analysis selection
			      analyzeDst => 'eqpho',
			      wantAnalysisLo => 0,
			      tolower => 1,

			      ##-- analysis parameters
			      max_weight => 1e38,
			      max_paths  => 32,
			      max_ops    => -1,

			      ##-- user args
			      @_
			     );
  return $aut;
}


1; ##-- be happy

__END__
