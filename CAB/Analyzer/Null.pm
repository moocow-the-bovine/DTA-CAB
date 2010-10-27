## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Null.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: null analyzer (dummy)

package DTA::CAB::Analyzer::Null;
use DTA::CAB::Analyzer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args
##    alg => $alg,            ##-- Text::Phonetic subclass, e.g. 'Soundex','Koeln','Metaphone' (default='Koeln')
##    tpo => $obj,            ##-- underlying Text::Phonetic::Whatever object
##    analyzeGet => $codestr, ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET)
sub new {
  my $that = shift;
  my $a = $that->SUPER::new(
			    ##-- analysis selection
			    label => 'null',
			    ##-- user args
			    @_
			   );
  return $a;
}


1; ##-- be happy

__END__
