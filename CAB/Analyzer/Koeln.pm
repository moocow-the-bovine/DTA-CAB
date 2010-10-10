## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Koeln.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: phonetic digest analysis using Text::Phonetic::Koeln

package DTA::CAB::Analyzer::Koeln;
use DTA::CAB::Analyzer::TextPhonetic;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::TextPhonetic);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args
##    alg => $alg,            ##-- Text::Phonetic subclass, e.g. 'Soundex','Koeln','Metaphone' (default='Koeln')
##    tpo => $obj,            ##-- underlying Text::Phonetic::Whatever object
##    analyzeGet => $codestr, ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET)
sub new {
  my $that = shift;
  my $tp = $that->SUPER::new(
			     ##-- defaults
			     alg => 'Koeln',

			     ##-- analysis selection
			     label => 'koeln',

			     ##-- user args
			     @_
			    );
  return $tp;
}

1; ##-- be happy

__END__
