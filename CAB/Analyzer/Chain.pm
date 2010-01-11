## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Chain.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analyzer API: analyzer "chains" / "cascades" / "pipelines" / ...

package DTA::CAB::Analyzer::Chain;
use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Analyzers
##     chain => [ $a1, $a2, ..., $aN ],        ##-- analysis chain (default: empty)
##    )
sub new {
  my $that = shift;
  my $ach = bless({
		   ##-- user args
		   chain => [],
		   @_
		  }, ref($that)||$that);
  $ach->initialize();
  return $ach;
}

## undef = $ach->initialize();
##  + default implementation does nothing
##  + INHERITED from Analyzer

## undef = $ach->dropClosures();
##  + drops '_analyze*' closures
##  + INHERITED from Analyzer

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $ach->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version calls $a->ensureLoaded()
sub ensureLoaded {
  my $ach = shift;
  my $rc  = 1;
  foreach (@{$ach->{chain}}) {
    $rc &&= $_->ensureLoaded();
    last if (!$rc); ##-- short-circuit
  }
  return $rc;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns list of known '_analyze' keys
##  + INHERITED from Analyzer

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
##  + INHERITED from Analyzer

##======================================================================
## Methods: Persistence: Bin

## @keys = $class_or_obj->noSaveBinKeys()
##  + returns list of keys not to be saved for binary mode
##  + default just returns list of known '_analyze' keys
##  + INHERITED from Analyzer

## $loadedObj = $CLASS_OR_OBJ->loadBinRef($ref)
##  + drops closures
##  + INHERITED from Analyzer


##==============================================================================
## Methods: Analysis Closures: Generic
##
## + General schema for thingies of type XXX:
##    $coderef = $ach->getAnalyzeXXXSub();            ##-- generate closure
##    $coderef = $ach->analyzeXXXSub();               ##-- get cached closure or generate
##    $thingy  = $ach->analyzeXXX($thingy,\%options)  ##-- get & apply (cached) closure
## + XXX may be one of: 'Token', 'Sentence', 'Document',...
## + analyze() alone just aliases analyzeToken()
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Generic

## $bool = $ach->canAnalyze()
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
##  + returns true if all analyzers in the chain do as well
sub canAnalyze {
  my $ach = shift;
  foreach (@{$ach->{chain}}) {
    return 0 if (!$_->canAnalyze);
  }
  return 1;
}

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $tok = $ach->analyzeToken($tok,\%analyzeOptions)
##  + destructively alters input token $tok with analysis
##  + really just a convenience wrapper for $ach->analyzeTokenSub()->($in,\%analyzeOptions)
##  + INHERITED from Analyzer

## $coderef = $ach->analyzeTokenSub()
##  + returned sub should be callable as:
##     $tok = $coderef->($tok,\%analyzeOptions)
##  + caches sub in $ach->{_analyzeToken}
##  + implicitly loads analysis data with $ach->ensureLoaded()
##  + otherwise, calls $ach->getAnalyzeTokenSub()
##  + INHERITED from Analyzer

## $coderef = $ach->getAnalyzeTokenSub()
##  + guts for $ach->analyzeTokenSub()
##  + default implementation just chains all inherited analyzeTokenSub()s
sub getAnalyzeTokenSub {
  my $ach = shift;
  my @subs = grep {defined($_)} map {$_->analyzeTokenSub} @{$ach->{chain}};
  my ($a,$tok,$opts);
  return sub {
    ($tok,$opts) = @_;
    $tok = toToken($tok) if (!ref($tok));
    $tok = $_->($tok,$opts) foreach (@subs);
    return $tok;
  };
}

##------------------------------------------------------------------------
## Methods: Analysis: Sentence

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + default implementation just calls analyzeToken() on each token of input sentence
##  + INHERITED from Analyzer

##------------------------------------------------------------------------
## Methods: Analysis: Document

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + default implementation just calls analyzeToken() on each token of input sentence
##  + INHERITED from Analyzer


##------------------------------------------------------------------------
## Methods: Analysis: Raw Data

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + default implementation just calls analyzeToken() on each token of input sentence
##  + INHERITED from Analyzer

##==============================================================================
## Methods: Analysis: v1.x

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $ach->analyzeDocument1($doc,\%opts)
##  + analyze a DTA::CAB::Document $doc
##  + top-level API routine
##  + default implementation just calls:
##      $doc = toDocument($doc);
##      $doc->{types} = $ach->getTypes($doc,\%opts)
##      $ach->ensureLoaded();
##      $ach->analyzeTypes($doc,\%opts)
##      $ach->analyzeTokens($doc,\%opts)
##      $ach->analyzeSentences($doc,\%opts)
##      $ach->analyzeLocal($doc,\%opts)
##      $ach->analyzeClean($doc,\%opts)
##  + INHERITED from Analyzer

## $doc = $ach->analyzeTypes($doc,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + Chain default calls $a->analyzeTypes for each analyzer $a in the chain
sub analyzeTypes {
  my ($ach,$doc,$opts) = @_;
  $_->analyzeTypes($doc,$opts) foreach (@{$ach->{chain}});
  return $doc;
}

## $doc = $ach->analyzeTokens($doc,\%opts)
##  + perform token-wise analysis of all tokens $doc->{body}[$si]{tokens}[$wi]
##  + default implementation just shallow copies tokens in $doc->{types}
##  + INHERITED from Analyzer

## $doc = $ach->analyzeSentences($doc,\%opts)
##  + perform sentence-wise analysis of all sentences $doc->{body}[$si]
##  + Chain default calls $a->analyzeSentences for each analyzer $a in the chain
sub analyzeSentences {
  my ($ach,$doc,$opts) = @_;
  $_->analyzeSentences($doc,$opts) foreach (@{$ach->{chain}});
  return $doc;
}

## $doc = $ach->analyzeLocal($doc,\%opts)
##  + perform local document-level analysis of $doc
##  + Chain default calls $a->analyzeLocal for each analyzer $a in the chain
sub analyzeLocal {
  my ($ach,$doc,$opts) = @_;
  $_->analyzeLocal($doc,$opts) foreach (@{$ach->{chain}});
  return $doc;
}

## $doc = $ach->analyzeClean($doc,\%opts)
##  + cleanup any temporary data associated with $doc
##  + Chain default calls $a->analyzeClean for each analyzer $a in the chain,
##    then superclass Analyzer->analyzeClean
sub analyzeClean {
  my ($ach,$doc,$opts) = @_;
  $_->analyzeClean($doc,$opts) foreach (@{$ach->{chain}});
  return $ach->SUPER::analyzeClean($doc,$opts);
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Wrappers

## $tok = $ach->analyzeToken1($tok_or_string,\%opts)
##  + perform type-, token- and local analyses on $tok_or_string
##  + INHERITED from Analyzer

## $tok = $ach->analyzeSentence1($sent_or_array,\%opts)
##  + perform type- and token-, sentence- and local analyses on $sent_or_array
##  + wrapper for $ach->analyzeDocument1()
##  + INHERITED from Analyzer


##==============================================================================
## Methods: XML-RPC
##  + INHERITED from Analyzer

1; ##-- be happy

