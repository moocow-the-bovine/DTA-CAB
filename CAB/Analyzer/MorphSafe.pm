## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MorphSafe.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: safety checker for analyses output by DTA::CAB::Analyzer::Morph (TAGH)

package DTA::CAB::Analyzer::MorphSafe;

use DTA::CAB::Analyzer;

use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, new:
##    ##-- analysis selection
##    analysisSrcKey => $key,    ##-- input token key   (default: 'morph')
##    analysisPrefix => $prefix, ##-- output key prefix (default: 'morph')
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   analysisSrcKey => 'morph',
			   analysisPrefix => 'morph',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $aut->ensureLoaded()
##  + ensures analysis data is loaded
sub ensureLoaded { return 1; }

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Token


## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##     $tok = $coderef->($tok,\%opts)
##  + tests safety of morphological analyses in $tok->{morph}
##  + sets $tok->{ "$anl->{analysisPrefix}.safe" } = $bool
sub getAnalyzeTokenSub {
  my $ms = shift;

  my $srcKey = $ms->{analysisSrcKey};
  my $prefix = $ms->{analysisPrefix};
  my ($tok,$analyses,$safe);
  return sub {
    $tok = shift;
    $analyses = $tok->{$srcKey};
    $safe = 1 if ($tok->{text} =~ /^[[:digit:][:punct:]]*$/); ##-- punctuation, digits are always "safe"
    $safe ||=
      (
       $analyses                 ##-- defined & true
       && @$analyses > 0         ##-- non-empty
       && (
	   grep {                ##-- at least one non-"unsafe" analysis:
	     $_->[0] !~ m(
               (?:               ##-- unsafe: regexes
                   \[_FM\]       ##-- unsafe: tag: FM: foreign material
                 | \[_XY\]       ##-- unsafe: tag: XY: non-word (abbreviations, etc)
                 | \[_ITJ\]      ##-- unsafe: tag: ITJ: interjection
                 | \[_NE\]       ##-- unsafe: tag: NE: proper name

                 ##-- unsafe: verb roots
                 | \b te    (?:\/V|\~)
                 | \b gel   (?:\/V|\~)
                 | \b öl    (?:\/V|\~)

                 ##-- unsafe: noun roots
                 | \b Bus   (?:\/N|\[_NN\])
                 | \b Ei    (?:\/N|\[_NN\])
                 | \b Eis   (?:\/N|\[_NN\])
                 | \b Gel   (?:\/N|\[_NN\])
                 | \b Gen   (?:\/N|\[_NN\])
                 | \b Öl    (?:\/N|\[_NN\])
                 | \b Reh   (?:\/N|\[_NN\])
                 | \b Tee   (?:\/N|\[_NN\])
                 | \b Teig  (?:\/N|\[_NN\])
               )
             )x
	   } @$analyses
	  )
      );

    ##-- output
    $tok->{"${prefix}.safe"} = $safe ? 1 : 0;
  };
}

##==============================================================================
## Methods: Output Formatting: OBSOLETE
##==============================================================================


1; ##-- be happy

__END__
