## -*- Mode: CPerl -*-
## File: DTA::CAB.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: robust morphological analysis: top-level

package DTA::CAB;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Automaton;
use DTA::CAB::Analyzer::Automaton::Gfsm;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
use DTA::CAB::Analyzer::Morph;
use DTA::CAB::Analyzer::Rewrite;
use DTA::CAB::Analyzer::Transliterator;

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
			   rw    => DTA::CAB::Analyzer::Rewrite->new(),

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
  $rc &&= $cab->{rw}->ensureLoaded()    if ($cab->{rw});
  return $rc;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

## $token = $anl->analyze($token_or_text,\%analyzeOptions)
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->analyzeSub()
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->getAnalyzeSub()
##  + guts for $anl->analyzeSub()
sub getAnalyzeSub {
  my $cab = shift;
  my ($xlit,$morph,$rw) = @$cab{qw(xlit morph rw)};
  my $a_xlit  = $xlit->getAnalyzeSub()  if ($xlit);
  my $a_morph = $morph->getAnalyzeSub() if ($morph);
  my $a_rw    = $rw->getAnalyzeSub()    if ($rw);
  my ($tok,$opts, $xtok);
  return sub {
    ($tok,$opts) = @_;
    $tok = $xtok = DTA::CAB::Token->toToken($tok);

    if ($a_xlit) {
      ##-- analyze: transliterate
      $a_xlit->($tok,$opts);
      $xtok = $tok->{xlit};
    }

    if ($a_morph) {
      ##-- analyze: morph
      $a_morph->($xtok,$opts) if ($a_morph);
	if (!@{$xtok->{morph}}) {
	  ##-- analyzer: rewrite (if morphological analysis is "unsafe")
	  if ($a_rw) {
	    $a_rw->($xtok);
	    foreach (@{$xtok->{rw}}) {
	      push(@$_, $a_morph->($_->[0])->{morph});
	    }
	  }
	}
    } elsif ($a_rw) {
      ##-- no morph analysis: just rewrite
      $a_rw->($xtok);
    }

    return $tok;
  };
}



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
