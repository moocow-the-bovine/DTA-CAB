## -*- Mode: CPerl -*-
## File: DTA::CAB::Chain::DTA.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: robust analysis: default chain

package DTA::CAB::Chain::DTA;
use DTA::CAB::Datum ':all';
use DTA::CAB::Chain;
use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::CAB::Chain);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- analyzers
			   xlit  => DTA::CAB::Analyzer::Unicruft->new(),
			   lts   => DTA::CAB::Analyzer::LTS->new(),
			   ##
			   morph => DTA::CAB::Analyzer::Morph->new(),
			   mlatin=> DTA::CAB::Analyzer::Morph::Latin->new(),
			   msafe => DTA::CAB::Analyzer::MorphSafe->new(),
			   rw    => DTA::CAB::Analyzer::Rewrite->new(),
			   rwsub => DTA::CAB::Analyzer::RewriteSub->new(),
			   ##
			   eqpho => DTA::CAB::Analyzer::EqPho->new(),       ##-- default (FST)
			   eqrw  => DTA::CAB::Analyzer::EqRW->new(),        ##-- default (FST)
			   ##
			   ##
			   dmoot => DTA::CAB::Analyzer::Moot::DynLex->new(), ##-- moot n-gram disambiguator
			   moot => DTA::CAB::Analyzer::Moot->new(),          ##-- moot tagger

			   ##-- user args
			   @_,

			   ##-- overrides
			   chains => undef, ##-- see setupChains() method
			   chain => undef, ##-- see setupChains() method
			  );
}

##==============================================================================
## Methods: Chain selection
##==============================================================================

## $ach = $ach->setupChains()
##  + setup default named sub-chains in $ach->{chains}
sub setupChains {
  my $ach = shift;
  $ach->{rwsub}{chain} = [@$ach{qw(lts morph)}];
  my @akeys = grep {UNIVERSAL::isa($ach->{$_},'DTA::CAB::Analyzer')} keys(%$ach);
  my $chains = $ach->{chains} =
    {
     (map {("sub.$_"=>[$ach->{$_}])} @akeys), ##-- sub.xlit, sub.lts, ...
     ##
     'sub.expand'    =>[@$ach{qw(eqpho eqrw)}],
     'sub.sent'      =>[@$ach{qw(dmoot moot)}],
     ##
     'default.xlit'  =>[@$ach{qw(xlit)}],
     'default.lts'   =>[@$ach{qw(xlit lts)}],
     'default.morph' =>[@$ach{qw(xlit morph)}],
     'default.rw'    =>[@$ach{qw(xlit rw)}],
     'default.rw.safe'  =>[@$ach{qw(xlit morph msafe rw)}], #mlatin
     'default.base'  =>[@$ach{qw(xlit lts morph mlatin msafe)}],
     'default.type'  =>[@$ach{qw(xlit lts morph mlatin msafe rw rwsub)}],
     'default.expand' =>[@$ach{qw(xlit lts morph mlatin msafe rw eqpho eqrw)}],
     ##
     'all'            =>[@$ach{qw(xlit lts morph mlatin msafe rw eqpho eqrw dmoot moot)}],
     'default'        =>[@$ach{qw(xlit lts morph mlatin msafe rw            dmoot moot)}],
    };
  #$chains->{'default'} = [map {@{$chains->{$_}}} qw(default.type sub.sent)];

  ##-- sanitize chains
  foreach (values %{$ach->{chains}}) {
    @$_ = grep {ref($_)} @$_;
  }

  ##-- set default chain
  $ach->{chain} = $ach->{chains}{default};

  ##-- force default labels
  $ach->{$_}{label} = $_ foreach (grep {UNIVERSAL::isa($ach->{$_},'DTA::CAB::Analyzer')} keys(%$ach));
  return $ach;
}

## \@analyzers = $ach->chain()
## \@analyzers = $ach->chain(\%opts)
##  + get selected analyzer chain
##  + OVERRIDE calls setupChains() if $ach->{chain} is empty
##  + OVERRIDE checks for $opts{chain} and returns $ach->{chains}{ $opts{chain} } if available
sub chain {
  $_[0]->ensureChain;
  return $_[0]{chains}{$_[1]{chain}} if ($_[1] && $_[1]{chain} && $_[0]{chains}{$_[1]{chain}});
  return $_[0]{chain};
}

## $ach = $ach->ensureChain()
##  + checks for $ach->{chain}, calls $ach->setupChains() if needed
sub ensureChain {
  $_[0]->setupChains if (!$_[0]{chain} || !@{$_[0]{chain}});
  return $_[0];
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $ach->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + override calls ensureChain() before inherited method
sub ensureLoaded {
  my $ach = shift;
  $ach->ensureChain;
  my $rc = 1;

 LOAD_CHAIN:
  foreach (values %{$ach->{chains}}) {
    foreach (grep {$_} @$_) {
      $rc &&= $_->ensureLoaded();
      last LOAD_CHAIN if (!$rc);
    }

    ##-- sanitize sub-chain
    @$_ = grep {$_ && $_->canAnalyze} @$_;
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
##  + override appends {chain},{chains}
sub noSaveKeys {
  my $ach = shift;
  return ($ach::SUPER->noSaveKeys, qw(chain chains));
}

## $saveRef = $obj->savePerlRef()
##  + return reference to be saved (top-level objects only)
##  + inherited from DTA::CAB::Persistent
#sub savePerlRef {
#  my $ach = shift;
#  return {
#	  map { ($_=>(UNIVERSAL::can($ach->{$_},'savePerlRef') ? $ach->{$_}->savePerlRef : $ach->{$_})) } keys(%$ach)
#	 };
#}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
##  + inherited from DTA::CAB::Persistent

##==============================================================================
## Methods: Analysis
##==============================================================================

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
##  + INHERITED from DTA::CAB::Chain

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
