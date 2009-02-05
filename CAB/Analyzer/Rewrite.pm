## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Rewrite.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: rewriteological analysis via Gfsm automata

##==============================================================================
## Package: Analyzer::Rewrite
##==============================================================================
package DTA::CAB::Analyzer::Rewrite;
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
			      #analysisKey   => 'rewrite',
			      #analysisClass => 'DTA::CAB::Analyzer::Rewrite::Analysis',

			      ##-- analysis selection
			      analyzeDst => 'rw',

			      ##-- user args
			      @_
			     );
  return $aut;
}


1; ##-- be happy

__END__
