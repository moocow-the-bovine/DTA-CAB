## -*- Mode: CPerl -*-
## File: DTA::CAB::Chain::Tweet.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: robust analysis: tweet-munging chain

package DTA::CAB::Chain::Tweet;
use DTA::CAB::Datum ':all';
use DTA::CAB::Chain::Multi;
use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::CAB::Chain::Multi);

##-- HACK: just inherit from DTA::CAB::Chain::DTA for now

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
			   #mlatin=> DTA::CAB::Analyzer::Morph::Latin->new(),
			   #msafe => DTA::CAB::Analyzer::MorphSafe->new(),
			   rw    => DTA::CAB::Analyzer::Rewrite->new(),
			   #rwsub => DTA::CAB::Analyzer::RewriteSub->new(),
			   ##
			   eqpho => DTA::CAB::Analyzer::EqPho->new(),       ##-- default (FST)
			   #eqrw  => DTA::CAB::Analyzer::EqRW->new(),        ##-- default (FST)
			   ##
			   ##
			   dmoot => DTA::CAB::Analyzer::Moot::DynLex->new(), ##-- moot n-gram disambiguator
			   #moot => DTA::CAB::Analyzer::Moot->new(),          ##-- moot tagger

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
  my @akeys = grep {UNIVERSAL::isa($ach->{$_},'DTA::CAB::Analyzer')} keys(%$ach);
  my $chains = $ach->{chains} =
    {
     (map {("sub.$_"=>[$ach->{$_}])} @akeys), ##-- sub.xlit, sub.lts, ...
     ##
     'default.xlit'  =>[@$ach{qw(xlit)}],
     'default.lts'   =>[@$ach{qw(xlit lts)}],
     'default.morph' =>[@$ach{qw(xlit morph)}],
     'default.rw'    =>[@$ach{qw(xlit rw)}],
     'default.base'     =>[@$ach{qw(xlit lts morph)}],
     'default.type'     =>[@$ach{qw(xlit lts morph rw)}],
     ##
     'noexpand'  =>[@$ach{qw(xlit lts morph rw)}],
     'expand'    =>[@$ach{qw(xlit lts morph rw eqpho)}],
     'default'   =>[@$ach{qw(xlit lts morph rw eqpho dmoot)}],
     'all'       =>[@$ach{qw(xlit lts morph rw eqpho dmoot)}],
    };

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

##==============================================================================
## Analysis: Utilities
##==============================================================================

BEGIN { *_parseAnalysis = \&DTA::CAB::Analyzer::Moot::parseAnalysis; }

## @analyses = CLASS::dmootTagsGet($tok)
##  + for 'dmoot' analyzer (DTA::CAB::Analyzer::Moot::DynLex) 'analyzeTagsGet' pseudo-accessor
##  + utility for disambiguation using @$tok{qw(text xlit eqpho rw)} fields by default
##  + returns only $tok->{xlit} field if "$tok->{toktyp}" is true
sub dmootTagsGet {
  return
    ($_[0]{xlit} ? (_parseAnalysis($_[0]{xlit}{latin1Text},src=>'xlit')) : _parseAnalysis($_[0]{text},src=>'text'))
      if ($_[0]{toktyp});
  return
    (($_[0]{xlit}  ? (_parseAnalysis($_[0]{xlit}{latin1Text},src=>'xlit')) : _parseAnalysis($_[0]{text},src=>'text')),
     ($_[0]{eqpho} ? (map {_parseAnalysis($_,src=>'eqpho')} @{$_[0]{eqpho}}) : qw()),
     ($_[0]{rw}    ? (map {_parseAnalysis($_,src=>'rw')} @{$_[0]{rw}}) : qw()),
    );
}


1; ##-- be happy
