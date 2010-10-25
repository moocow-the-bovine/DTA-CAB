## -*- Mode: CPerl -*-
## File: DTA::CAB::Chain::DTA.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: robust analysis: default chain

package DTA::CAB::Chain::DTA;
use DTA::CAB::Datum ':all';
use DTA::CAB::Chain::Multi;

##-- sub-analyzers
use DTA::CAB::Analyzer::EqPhoX;
use DTA::CAB::Analyzer::RewriteSub;
use DTA::CAB::Analyzer::DmootSub;

use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::CAB::Chain::Multi);

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
			   eqphox => DTA::CAB::Analyzer::EqPhoX->new(),     ##-- default (cascade)
			   eqpho => DTA::CAB::Analyzer::EqPho->new(),       ##-- default (FST)
			   eqrw  => DTA::CAB::Analyzer::EqRW->new(),        ##-- default (FST)
			   ##
			   ##
			   dmoot => DTA::CAB::Analyzer::Moot::DynLex->new(), ##-- moot n-gram disambiguator
			   dmootsub => DTA::CAB::Analyzer::DmootSub->new(),  ##-- moot n-gram disambiguator: sub-morph
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
##  + override
sub setupChains {
  my $ach = shift;
  $ach->{rwsub}{chain} = [@$ach{qw(lts morph)}];
  $ach->{dmootsub}{chain} = [@$ach{qw(morph)}];
  my @akeys = grep {UNIVERSAL::isa($ach->{$_},'DTA::CAB::Analyzer')} keys(%$ach);
  my $chains = $ach->{chains} =
    {
     (map {("sub.$_"=>[$ach->{$_}])} @akeys), ##-- sub.xlit, sub.lts, ...
     ##
     'sub.expand'    =>[@$ach{qw(eqpho eqrw)}],
     'sub.sent'      =>[@$ach{qw(dmoot dmootsub moot)}],
     ##
     'default.xlit'  =>[@$ach{qw(xlit)}],
     'default.lts'   =>[@$ach{qw(xlit lts)}],
     'default.eqphox'=>[@$ach{qw(xlit lts eqphox)}],
     'default.morph' =>[@$ach{qw(xlit morph)}],
     'default.msafe' =>[@$ach{qw(xlit morph msafe)}],
     'default.rw'    =>[@$ach{qw(xlit rw)}],
     'default.rw.safe'  =>[@$ach{qw(xlit morph msafe rw)}], #mlatin
     'default.dmoot'    =>[@$ach{qw(xlit lts eqphox morph msafe rw dmoot)}],
     'default.moot'     =>[@$ach{qw(xlit lts eqphox morph msafe rw dmoot dmootsub moot)}],
     'default.base'     =>[@$ach{qw(xlit lts morph mlatin msafe)}],
     'default.type'     =>[@$ach{qw(xlit lts morph mlatin msafe rw rwsub)}],
     ##
     'noexpand'  =>[@$ach{qw(xlit lts morph mlatin msafe rw rwsub)}],
     'expand'    =>[@$ach{qw(xlit lts morph mlatin msafe rw eqpho eqrw)}],
     'default'   =>[@$ach{qw(xlit lts morph mlatin msafe rw rwsub eqphox dmoot dmootsub moot)}],
     'all'       =>[@$ach{qw(xlit lts morph mlatin msafe rw rwsub eqphox eqpho eqrw dmoot moot)}],
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
##  + inherited from DTA::CAB::Chain::Multi
##    - calls setupChains() if $ach->{chain} is empty
##    - checks for $opts{chain} and returns $ach->{chains}{ $opts{chain} } if available

## $ach = $ach->ensureChain()
##  + checks for $ach->{chain}, calls $ach->setupChains() if needed
##  + inherited from DTA::CAB::Chain::Multi

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $ach->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + inherited DTA::CAB::Chain::Multi override calls ensureChain() before inherited method
sub ensureLoaded {
  my $ach = shift;
  $ach->SUPER::ensureLoaded(@_) || return 0;

  ##-- hack: copy chain members AFTER loading for sub-analyzers, setting 'enabled' if appropriate
  my ($subkey);
  foreach $subkey (qw(rwsub dmootsub)) {
    if (ref($ach->{$subkey})) {
      foreach (grep {!$_->{"_${subkey}"}} @{$ach->{$subkey}{chain}}) {
	$_ = bless( {%$_}, ref($_) );
	$_->{label}   = $subkey.'_'.$_->{label};
	$_->{enabled} = $ach->{$subkey}{enabled};
	$_->{"_$subkey"}  = 1;
      }
    }
  }

  return 1;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just greps for CODE-refs
##  + inherited from DTA::CAB::Chain::Multi: override appends {chain},{chains}

## $saveRef = $obj->savePerlRef()
##  + return reference to be saved (top-level objects only)
##  + inherited from DTA::CAB::Persistent

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
##  + INHERITED from DTA::CAB::Chain::Multi

1; ##-- be happy
