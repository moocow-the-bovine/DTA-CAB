## -*- Mode: CPerl -*-
## File: DTA::CAB.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: robust morphological analysis: top-level

package DTA::CAB;

use DTA::CAB::Logger;
use DTA::CAB::Persistent;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Automaton;
use DTA::CAB::Analyzer::Automaton::Gfsm;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
#use DTA::CAB::Analyzer::Transliterator;
use DTA::CAB::Analyzer::Unicruft;
use DTA::CAB::Analyzer::LTS;
use DTA::CAB::Analyzer::EqClass;
use DTA::CAB::Analyzer::EqPho;
use DTA::CAB::Analyzer::Morph;
use DTA::CAB::Analyzer::Morph::Latin;
use DTA::CAB::Analyzer::MorphSafe;
use DTA::CAB::Analyzer::Rewrite;

use DTA::CAB::Datum ':all';
use DTA::CAB::Token;
use DTA::CAB::Sentence;
use DTA::CAB::Document;

use DTA::CAB::Format;
use DTA::CAB::Format::Builtin;

use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================

# v0.08: added EqPho (using Gfsm::XL cascade: loads quicker, runtime slower, ...)
our $VERSION = 0.08;

our @ISA = qw(DTA::CAB::Analyzer);

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
			   eqpho => DTA::CAB::Analyzer::EqClass->new(),
			   #eqpho => DTA::CAB::Analyzer::EqPho->new(),
			   morph => DTA::CAB::Analyzer::Morph->new(),
			   mlatin=> DTA::CAB::Analyzer::Morph::Latin->new(),
			   msafe => DTA::CAB::Analyzer::MorphSafe->new(),
			   rw    => DTA::CAB::Analyzer::Rewrite->new(),

			   ##-- formatting: XML
			   #xmlTokenElt => 'token', ##-- token element

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $cab->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version always returns true
sub ensureLoaded {
  my $cab = shift;
  my $rc  = 1;
  $rc &&= $cab->{xlit}->ensureLoaded()  if ($cab->{xlit});
  $rc &&= $cab->{lts}->ensureLoaded()   if ($cab->{lts});
  $rc &&= $cab->{eqpho}->ensureLoaded() if ($cab->{eqpho});
  $rc &&= $cab->{morph}->ensureLoaded() if ($cab->{morph});
  $rc &&= $cab->{mlatin}->ensureLoaded() if ($cab->{mlatin});
  $rc &&= $cab->{msafe}->ensureLoaded() if ($cab->{msafe});
  $rc &&= $cab->{rw}->ensureLoaded()    if ($cab->{rw});
  #$cab->{rw}{subanalysisFormatter} = $cab->{morph} if ($cab->{rw} && $cab->{morph}); ##-- OBSOLETE!
  return $rc;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## $saveRef = $obj->savePerlRef()
##  + return reference to be saved (top-level objects only)
##  + default implementation just returns $obj
sub savePerlRef {
  my $cab = shift;
  return {
	  map { ($_=>(UNIVERSAL::can($cab->{$_},'savePerlRef') ? $cab->{$_}->savePerlRef : $cab->{$_})) } keys(%$cab)
	 };
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
##  + inherited from DTA::CAB::Persistent


##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##     $tok = $coderef->($tok,\%opts)
##  + performs all known & selected analyses on $tok
##  + known \%opts:
##     do_xlit  => $bool,    ##-- enable/disable unicruft transliterator (default: enabled)
##     do_morph => $bool,    ##-- enable/disable morphological analysis (default: enabled)
##     do_mlatin=> $bool,    ##-- enable/disable latin-language analysis (default: enabled)
##     do_lts   => $bool,    ##-- enable/disable LTS analysis (default: enabled)
##     do_eqpho => $bool,    ##-- enable/disable phonetic-equivalence-class analysis (default: enabled)
##     do_msafe => $bool,    ##-- enable/disable morphSafe analysis (default: enabled)
##     do_rw    => $bool,    ##-- enable/disable rewrite analysis (default: enabled; depending on morph, msafe)
##     do_rw_morph => $bool, ##-- enable/disable morph/rewrite analysis (default: enabled)
##     do_rw_lts   => $bool, ##-- enable/disable lts/rewrite analysis (default: enabled)
##     ...
sub getAnalyzeTokenSub {
  my $cab = shift;
  my ($xlit,$lts,$eqpho,$morph,$mlatin,$msafe,$rw) = @$cab{qw(xlit lts eqpho morph mlatin msafe rw)};
  my $a_xlit   = $xlit->getAnalyzeTokenSub()   if ($xlit);
  my $a_lts    = $lts->getAnalyzeTokenSub()    if ($lts);
  my $a_eqpho  = $eqpho->getAnalyzeTokenSub()  if ($eqpho);
  my $a_morph  = $morph->getAnalyzeTokenSub()  if ($morph);
  my $a_mlatin = $mlatin->getAnalyzeTokenSub() if ($mlatin);
  my $a_msafe  = $msafe->getAnalyzeTokenSub()  if ($msafe);
  my $a_rw     = $rw->getAnalyzeTokenSub()     if ($rw);
  my ($tok, $w,$opts,$l);
  return sub {
    ($tok,$opts) = @_;
    $tok = DTA::CAB::Token::toToken($tok) if (!ref($tok));

    ##-- analyze: transliterator
    if ($a_xlit && (!defined($opts->{do_xlit}) || $opts->{do_xlit})) {
      $a_xlit->($tok,$opts);
      $l = $tok->{$xlit->{analysisKey}}{latin1Text};
    } else {
      $l = $tok->{text};
    }
    $opts->{src} = $l;

    ##-- analyze: lts
    if ($a_lts && (!defined($opts->{do_lts}) || $opts->{do_lts})) {
      $a_lts->($tok, $opts);
    }

    ##-- analyze: eqpho
    if ($a_eqpho && (!defined($opts->{do_eqpho}) || $opts->{do_eqpho})) {
      $a_eqpho->($tok, $opts);
    }

    ##-- analyze: morph
    if ($a_morph && (!defined($opts->{do_morph}) || $opts->{do_morph})) {
      $a_morph->($tok, $opts);
    }

    ##-- analyze: mlatin
    if ($a_mlatin && (!defined($opts->{do_mlatin}) || $opts->{do_mlatin})) {
      $a_mlatin->($tok, $opts);
    }

    ##-- analyze: morph: safe?
    if ($a_msafe && (!defined($opts->{do_msafe}) || $opts->{do_msafe})) {
      $a_msafe->($tok,$opts);
    }

    ##-- analyze: rewrite (if morphological analysis is "unsafe")
    if ($a_rw && !$tok->{msafe} && (!defined($opts->{do_rw}) || $opts->{do_rw})) {
      $a_rw->($tok, $opts);
      ##
      ##-- analyze: rewrite: sub-morphology
      if ($tok->{rw} && $a_morph && (!defined($opts->{do_rw_morph}) || $opts->{do_rw_morph})) {
	foreach (@{ $tok->{rw} }) {
	  $opts->{src} = $_->{hi};
	  $opts->{src} =~ s/\\(.)/$1/g;
	  $opts->{dst} = \$_->{morph};
	  $a_morph->($tok, $opts);
	}
      }
      ##
      ##-- analyze: rewrite: sub-LTS
      if ($tok->{rw} && $a_lts && (!defined($opts->{do_rw_lts}) || $opts->{do_rw_lts})) {
	foreach (@{ $tok->{rw} }) {
	  $opts->{src} = $_->{hi};
	  $opts->{src} =~ s/\\(.)/$1/g;
	  $opts->{dst} = \$_->{lts};
	  $a_lts->($tok, $opts);
	}
      }
    }
    delete(@$opts{qw(src dst)}); ##-- hack
    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting: OBSOLETE
##==============================================================================

__END__

##==============================================================================
## PODS
##==============================================================================
=pod

=head1 NAME

DTA::CAB - "Cascaded Analysis Broker" for robust morphological analysis, etc.

=head1 SYNOPSIS

 use DTA::CAB;
 
 $cab = CLASS_OR_OBJ->new(%args);
 
 ##-- DTA::CAB::Analyzer API
 $tok = $cab->analyzeToken($tok,\%analyzeOptions)
 $sent = $cab->analyzeSentence($sent,\%analyzeOptions)
 $doc = $anl->analyzeDocument($sent,\%analyzeOptions)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

The DTA::CAB package provides an object-oriented compiler/interpreter for
error-tolerant heuristic morphological analysis of tokenized text.

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Constants
=pod

=head2 Constants

=over 4

=item Variable: $VERSION

Module version.

=item Variable: @ISA

DTA::CAB inherits from L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>,
and supports the L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> analysis API.

=back

=cut


##==============================================================================
## Methods
##==============================================================================
=pod

=head1 METHODS

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $cab = CLASS_OR_OBJ->new(%args);

%args, %$cab:

 ##-- analyzers
 xlit  => $xlit,  ##-- DTA::CAB::Analyzer::Unicruft object
 lts   => $lts,   ##-- DTA::CAB::Analyzer::LTS object
 eqpho => $eqpho, ##-- DTA::CAB::Analyzer::EqClass object
 morph => $morph, ##-- DTA::CAB::Analyzer::Morph object
 latin => $latin, ##-- DTA::CAB::Analyzer::Latin object
 msafe => $msafe, ##-- DTA::CAB::Analyzer::MorphSafe object
 rw    => $rw,    ##-- DTA::CAB::Analyzer::Rewrite object

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $cab->ensureLoaded();

Ensures analysis data is loaded from default files.
Calls ensureLoaded() for all defined sub-analyzers.

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Methods: Persistence: Perl
=pod

=head2 Methods: Persistence: Perl

=over 4

=item savePerlRef

 $saveRef = $cab->savePerlRef();

Return reference to be saved (top-level objects only).
Recurses 1 level on $cab values to construct $saveRef.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item getAnalyzeTokenSub

 $coderef = $anl->getAnalyzeTokenSub();

Implements L<DTA::CAB::Analyzer::getAnalyzeTokenSub()|DTA::CAB::Analyzer/item_getAnalyzeTokenSub>.
Returned sub is callable as:

 $tok = $coderef->($tok,\%opts)

Performs all defined & selected analyses on $tok.
Known \%opts:

 do_xlit  => $bool,    ##-- enable/disable unicruft transliterator (default: enabled)
 do_morph => $bool,    ##-- enable/disable morphological analysis (default: enabled)
 do_latin => $bool,    ##-- enable/disable latin-language recognition (default: enabled)
 do_lts   => $bool,    ##-- enable/disable LTS analysis (default: enabled)
 do_eqpho => $bool,    ##-- enable/disable phonetic-equivalence-class analysis (default: enabled)
 do_msafe => $bool,    ##-- enable/disable morphSafe analysis (default: enabled)
 do_rw    => $bool,    ##-- enable/disable rewrite analysis (default: enabled; depending on morph, msafe)
 do_rw_morph => $bool, ##-- enable/disable morph/rewrite analysis (default: enabled)
 do_rw_lts   => $bool, ##-- enable/disable lts/rewrite analysis (default: enabled)
 ...                   ##-- ... and maybe more

=back

=cut


##==============================================================================
## Footer
##==============================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2009 by Bryan Jurish

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
