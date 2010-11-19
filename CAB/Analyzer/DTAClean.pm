## -*- Mode: CPerl -*-
## File: DTA::CAB::Analyzer::DTAClean.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Chain::DTA cleanup (prune sensitive and redundant data from document)

package DTA::CAB::Analyzer::DTAClean;
use DTA::CAB::Analyzer;
use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- security
			   label => 'clean',
			   forceClean => 1,  ##-- always run analyzeClean() regardless of options; also checked in analyzeClean() itself

			   ##-- user args
			   @_,
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

##==============================================================================
## Methods: Persistence
##==============================================================================

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Utils

## $bool = $anl->doAnalyze(\%opts, $name)
##  + alias for $anl->can("analyze${name}") && (!exists($opts{"doAnalyze${name}"}) || $opts{"doAnalyze${name}"})
##  + override checks $anl->{forceClean} flag
sub doAnalyze {
  my ($anl,$opts,$name) = @_;
  return 1 if ($anl->{forceClean} && $name eq 'Clean'); ##-- always clean if requested
  return $anl->SUPER::doAnalyze($opts,$name);
}


##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $ach->analyzeDocument($doc,\%opts)
##  + analyze a DTA::CAB::Document $doc
##  + top-level API routine
##  + INHERITED from DTA::CAB::Analyzer

## $doc = $ach->analyzeTypes($doc,$types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + Chain default calls $a->analyzeTypes for each analyzer $a in the chain
##  + INHERITED from DTA::CAB::Chain

## $doc = $ach->analyzeTokens($doc,\%opts)
##  + perform token-wise analysis of all tokens $doc->{body}[$si]{tokens}[$wi]
##  + default implementation just shallow copies tokens in $doc->{types}
##  + INHERITED from DTA::CAB::Analyzer

## $doc = $ach->analyzeSentences($doc,\%opts)
##  + perform sentence-wise analysis of all sentences $doc->{body}[$si]
##  + Chain default calls $a->analyzeSentences for each analyzer $a in the chain
##  + INHERITED from DTA::CAB::Chain

## $doc = $ach->analyzeLocal($doc,\%opts)
##  + perform local document-level analysis of $doc
##  + Chain default calls $a->analyzeLocal for each analyzer $a in the chain
##  + INHERITED from DTA::CAB::Chain

## $doc = $ach->analyzeClean($doc,\%opts)
##  + cleanup any temporary data associated with $doc
##  + Chain default calls $a->analyzeClean for each analyzer $a in the chain,
##    then superclass Analyzer->analyzeClean
sub analyzeClean {
  my ($ach,$doc,$opts) = @_;

  ##-- prune output
  my %keep_keys = map {($_=>undef)} qw(text xlit mlatin eqpho eqrw eqlemma moot);
  foreach (map {@{$_->{tokens}}} @{$doc->{body}}) {
    ##-- delete all unsafe keys
    delete @$_{grep {!exists($keep_keys{$_})} keys %$_};
    delete $_->{moot}{analyses} if ($_->{moot});
  }

  return $doc;
}


1; ##-- be happy
