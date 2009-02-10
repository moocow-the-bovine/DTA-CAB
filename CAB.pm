## -*- Mode: CPerl -*-
## File: DTA::CAB.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: robust morphological analysis: top-level

package DTA::CAB;

use DTA::CAB::Logger;
use DTA::CAB::Persistent;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Automaton;
use DTA::CAB::Analyzer::Automaton::Gfsm;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
use DTA::CAB::Analyzer::Transliterator;
use DTA::CAB::Analyzer::Morph;
use DTA::CAB::Analyzer::MorphSafe;
use DTA::CAB::Analyzer::Rewrite;

use DTA::CAB::Datum ':all';
use DTA::CAB::Token;
use DTA::CAB::Sentence;
use DTA::CAB::Document;

use DTA::CAB::Formatter;
use DTA::CAB::Formatter::Freeze;
use DTA::CAB::Formatter::Text;
use DTA::CAB::Formatter::TT;
use DTA::CAB::Formatter::Perl;
use DTA::CAB::Formatter::XmlCommon;
use DTA::CAB::Formatter::XmlNative;
use DTA::CAB::Formatter::XmlPerl;
use DTA::CAB::Formatter::XmlRpc;

use DTA::CAB::Parser;
use DTA::CAB::Parser::Freeze;
use DTA::CAB::Parser::Perl;
use DTA::CAB::Parser::Text;
use DTA::CAB::Parser::TT;
use DTA::CAB::Parser::XmlCommon;
use DTA::CAB::Parser::XmlNative;
use DTA::CAB::Parser::XmlPerl;
use DTA::CAB::Parser::XmlRpc;

use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================

our $VERSION = 0.01;
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
			   xlit  => DTA::CAB::Analyzer::Transliterator->new(),
			   morph => DTA::CAB::Analyzer::Morph->new(),
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
  $rc &&= $cab->{morph}->ensureLoaded() if ($cab->{morph});
  $rc &&= $cab->{msafe}->ensureLoaded() if ($cab->{msafe});
  $rc &&= $cab->{rw}->ensureLoaded()    if ($cab->{rw});
  $cab->{rw}{subanalysisFormatter} = $cab->{morph} if ($cab->{rw} && $cab->{morph});
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
##     do_xlit  => $bool,    ##-- enable/disable transliterator (default: enabled)
##     do_morph => $bool,    ##-- enable/disable morphological analysis (default: enabled)
##     do_msafe => $bool,    ##-- enable/disable morphSafe analysis (default: enabled)
##     do_rw    => $bool,    ##-- enable/disable rewrite analysis (default: enabled; depending on morph, msafe)
##     do_morph_rw => $bool, ##-- enable/disable morph/rewrite analysis (default: enabled)
##     ...
sub getAnalyzeTokenSub {
  my $cab = shift;
  my ($xlit,$morph,$msafe,$rw) = @$cab{qw(xlit morph msafe rw)};
  my $a_xlit  = $xlit->getAnalyzeTokenSub()  if ($xlit);
  my $a_morph = $morph->getAnalyzeTokenSub() if ($morph);
  my $a_msafe = $msafe->getAnalyzeTokenSub() if ($msafe);
  my $a_rw    = $rw->getAnalyzeTokenSub()    if ($rw);
  my ($tok, $w,$opts,$l);
  return sub {
    ($tok,$opts) = @_;
    $tok = DTA::CAB::Token::toToken($tok) if (!ref($tok));

    ##-- analyze: transliterator
    if ($a_xlit && (!defined($opts->{do_xlit}) || $opts->{do_xlit})) {
      $a_xlit->($tok,$opts);
      $l = $tok->{$xlit->{analysisKey}}[0];
    } else {
      $l = $tok->{text};
    }
    $opts->{src} = $l;

    ##-- analyze: morph
    if ($a_morph && (!defined($opts->{do_morph}) || $opts->{do_morph})) {
      $a_morph->($tok, $opts);
    }

    ##-- analyze: morph: safe?
    if ($a_msafe && (!defined($opts->{do_msafe}) || $opts->{do_msafe})) {
      $a_msafe->($tok,$opts);
    }

    ##-- analyze: rewrite (if morphological analysis is "unsafe")
    if ($a_rw && !$tok->{msafe} && (!defined($opts->{do_rw}) || $opts->{do_rw})) {
      $a_rw->($tok, $opts);
      if ($a_morph && (!defined($opts->{do_morph_rw}) || $opts->{do_morph_rw})) {
	##-- analyze: rewrite: sub-morphology
	foreach (@{ $tok->{rw} }) {
	  $opts->{src} = $_->[0];
	  $opts->{dst} = \$_->[2];
	  $a_morph->($tok, $opts);
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

DTA::CAB - "Cascaded Analysis Broker" for robust morphological analysis

=head1 SYNOPSIS

 ##-------------------------------------------------------------
 ## Requirements
 use DTA::CAB;

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

The DTA::CAB package provides an object-oriented compiler/interpreter for
error-tolerant heuristic morphological analysis of tokenized text.

=cut

##==============================================================================
## Methods
##==============================================================================
=pod

=head1 METHODS

Not yet written.

=cut


##==============================================================================
## Footer
##==============================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2008 by Bryan Jurish

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
