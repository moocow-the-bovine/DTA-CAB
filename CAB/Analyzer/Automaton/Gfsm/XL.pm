## -*- Mode: CPerl -*-
## File: DTA::CAB::Analyzer::Automaton::Gfsm::XL.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Gfsm::XL::Cascade -based transductions

package DTA::CAB::Analyzer::Automaton::Gfsm::XL;
use DTA::CAB::Analyzer::Automaton;
use Gfsm;
use Gfsm::XL;
use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Automaton);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton
##  + new data / changes
##    (
##     ##-- Analysis objects
##     fst  => $cl,       ##-- a Gfsm::XL::Cascade::Lookup object (default=new)
##
##     ##-- Lookup options (new)
##     max_paths  => $max_paths,  ##-- sets $cl->max_paths()
##     max_weight => $max_weight, ##-- sets $cl->max_weight()
##     max_ops    => $max_ops,    ##-- sets $cl->max_ops()
##    )
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- analysis objects
			      fst=>undef, #Gfsm::XL::Cascade::Lookup->new(undef),

			      ##-- lookup options
			      max_weight => 3e38,
			      max_paths  => 1,
			      max_ops    => -1,

			      ##-- user args
			      @_
			     );
  $aut->setLookupOptions($aut);
  return $aut;
}


## $aut = $aut->clear()
sub clear {
  my $aut = shift;

  $aut->{fst}->_cascade_set(undef);

  ##-- inherited
  $aut->SUPER::clear();
}

## $aut = $aut->resetProfilingData()
## - inherited

##--------------------------------------------------------------
## Methods: Lookup Options

## $aut = $aut->setLookupOptions(\%opts)
## + \%opts keys:
##   max_weight => $w,
##   max_paths  => $n_paths,
##   max_ops    => $n_ops,
sub setLookupOptions {
  my ($aut,$opts) = @_;
  my $cl   = $aut->{fst};
  return if (!defined($cl));
  $cl->max_weight($opts->{max_weight}) if (defined($opts->{max_weight}));
  $cl->max_paths ($opts->{max_paths})  if (defined($opts->{max_paths}));
  $cl->max_ops   ($opts->{max_ops})    if (defined($opts->{max_ops}));
  return $aut;
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $class = $aut->fstClass()
##  + default FST class for loadFst() method
sub fstClass { return 'Gfsm::XL::Cascade'; }

## $class = $aut->labClass()
##  + default labels class for loadLabels() method
sub labClass { return 'Gfsm::Alphabet'; }

## $bool = $aut->fstOk()
##  + should return false iff fst is undefined or "empty"
sub fstOk { return defined($_[0]{fst}) && defined($_[0]{fst}->cascade) && $_[0]{fst}->cascade->depth>0; }

## $bool = $aut->labOk()
##  + should return false iff label-set is undefined or "empty"
#(inherited)

## $bool = $aut->dictOk()
##  + should return false iff dict is undefined or "empty"
##(inherited)


##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $aut = $aut->load(fst=>$fstFile, lab=>$labFile, dict=>$dictFile)
## + inherited

##--------------------------------------------------------------
## Methods: I/O: Input: Dictionary

## $aut = $aut->loadDict($dictfile)
## + inherited


##--------------------------------------------------------------
## Methods: I/O: Input: Transducer

## $aut = $aut->loadCascade($cscfile)
## $aut = $aut->loadFst    ($cscfile)
*loadFst = \&loadCascade;
sub loadCascade {
  my ($aut,$cscfile) = @_;
  my $csc = Gfsm::XL::Cascade->new();
  if (!$csc->load($cscfile)) {
    confess(ref($aut)."::loadCascade(): load failed for '$cscfile': $!");
    return undef;
  }
  $aut->{fst} = Gfsm::XL::Cascade::Lookup->new($csc);
  $aut->setLookupOptions($aut);
  $aut->{result} = Gfsm::Automaton->new($csc->semiring_type);  ##-- reset result automaton
  delete($aut->{_analyze});
  return $aut;
}

##--------------------------------------------------------------
## Methods: I/O: Input: Labels

## $aut = $aut->loadLabels($labfile)
## + inherited

## $aut = $aut->parseLabels()
## + inherited

##==============================================================================
## Methods: Analysis
##==============================================================================

## $key = $anl->analysisKey()
##   + get token output key for analysis sub
##   + default is $anl->{analysisKey} or 'gfsmxl'
sub analysisKey {
  return $_[0]{analysisKey} if (defined($_[0]{analysisKey}));
  return $_[0]{analysisKey} = 'gfsmxl';
}

## $token = $anl->analyze($token_or_text,\%analyzeOptions)
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->analyzeSub()
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->getAnalyzeSub()
##  + inherited from DTA::CAB::Analyzer::Automaton


1; ##-- be happy
