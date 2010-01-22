## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Chain.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analyzer API: analyzer "chains" / "cascades" / "pipelines" / ...

package DTA::CAB::Chain;
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
##     chain => [ $a1, $a2, ..., $aN ],        ##-- default analysis chain; see also chain() method (default: empty)
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
##  + INHERITED from DTA::CAB::Analyzer

## undef = $ach->dropClosures();
##  + drops '_analyze*' closures
##  + INHERITED from DTA::CAB::Analyzer

##==============================================================================
## Methods: Chain selection
##==============================================================================

## \@analyzers = $ach->chain()
## \@analyzers = $ach->chain(\%opts)
##  + get selected analyzer chain
##  + default method just returns $anl->{chain}
sub chain {
  return $_[0]{chain};
}

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $ach->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version calls $a->ensureLoaded() for each $a in $ach->{chain}
sub ensureLoaded {
  my $ach = shift;
  my $rc  = 1;
  @{$ach->{chain}} = grep {$_} @{$ach->{chain}}; ##-- hack: chuck undef chain-links here
  foreach (@{$ach->chain}) {
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
##  + default just greps for CODE-refs
##  + INHERITED from DTA::CAB::Analyzer

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
##  + INHERITED from DTA::CAB::Analyzer

##======================================================================
## Methods: Persistence: Bin

## @keys = $class_or_obj->noSaveBinKeys()
##  + returns list of keys not to be saved for binary mode
##  + default just returns list of known '_analyze' keys
##  + INHERITED from DTA::CAB::Analyzer

## $loadedObj = $CLASS_OR_OBJ->loadBinRef($ref)
##  + drops closures
##  + INHERITED from DTA::CAB::Analyzer

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Generic

## $bool = $ach->canAnalyze()
## $bool = $ach->canAnalyze(\%opts)
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
##  + returns true if all analyzers in the chain do to
sub canAnalyze {
  my $ach = shift;
  foreach (@{$ach->chain(@_)}) {
    if (!$_ || !$_->canAnalyze) {
      #$ach->logwarn("canAnalyze() returning 0 for sub-analyzer \"$_\"");
      return 0;
    }
  }
  return 1;
}

##==============================================================================
## Methods: Analysis: v1.x

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $ach->analyzeDocument($doc,\%opts)
##  + analyze a DTA::CAB::Document $doc
##  + top-level API routine
##  + INHERITED from DTA::CAB::Analyzer

## $doc = $ach->analyzeTypes($doc,$types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + Chain default calls $a->analyzeTypes for each analyzer $a in the chain
sub analyzeTypes {
  my ($ach,$doc,$types,$opts) = @_;
  foreach (@{$ach->chain($opts)}) {
    $_->analyzeTypes($doc,$types,$opts);
  }
  return $doc;
}

## $doc = $ach->analyzeTokens($doc,\%opts)
##  + perform token-wise analysis of all tokens $doc->{body}[$si]{tokens}[$wi]
##  + default implementation just shallow copies tokens in $doc->{types}
##  + INHERITED from DTA::CAB::Analyzer

## $doc = $ach->analyzeSentences($doc,\%opts)
##  + perform sentence-wise analysis of all sentences $doc->{body}[$si]
##  + Chain default calls $a->analyzeSentences for each analyzer $a in the chain
sub analyzeSentences {
  my ($ach,$doc,$opts) = @_;
  foreach (@{$ach->chain($opts)}) {
    $_->analyzeSentences($doc,$opts);
  }
  return $doc;
}

## $doc = $ach->analyzeLocal($doc,\%opts)
##  + perform local document-level analysis of $doc
##  + Chain default calls $a->analyzeLocal for each analyzer $a in the chain
sub analyzeLocal {
  my ($ach,$doc,$opts) = @_;
  foreach (@{$ach->chain($opts)}) {
    $_->analyzeLocal($doc,$opts);
  }
  return $doc;
}

## $doc = $ach->analyzeClean($doc,\%opts)
##  + cleanup any temporary data associated with $doc
##  + Chain default calls $a->analyzeClean for each analyzer $a in the chain,
##    then superclass Analyzer->analyzeClean
sub analyzeClean {
  my ($ach,$doc,$opts) = @_;
  foreach (@{$ach->chain($opts)}) {
    $_->analyzeClean($doc,$opts);
  }
  return $ach->SUPER::analyzeClean($doc,$opts);
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Wrappers

## $tok = $ach->analyzeToken($tok_or_string,\%opts)
##  + perform type- and token-analyses on $tok_or_string
##  + wrapper for $ach->analyzeDocument()
##  + INHERITED from DTA::CAB::Analyzer

## $tok = $ach->analyzeSentence($sent_or_array,\%opts)
##  + perform type-, token-, and sentence-analyses on $sent_or_array
##  + wrapper for $ach->analyzeDocument()
##  + INHERITED from DTA::CAB::Analyzer

## $rpc_xml_base64 = $anl->analyzeData($data_str,\%opts)
##  + analyze a raw (formatted) data string $data_str with internal parsing & formatting
##  + wrapper for $anl->analyzeDocument()
##  + INHERITED from DTA::CAB::Analyzer

##==============================================================================
## Methods: XML-RPC
##  + INHERITED from DTA::CAB::Analyzer

1; ##-- be happy

