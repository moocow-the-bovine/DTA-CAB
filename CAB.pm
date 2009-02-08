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
use DTA::CAB::Formatter::Text;
use DTA::CAB::Formatter::Perl;
use DTA::CAB::Formatter::XmlNative;
use DTA::CAB::Formatter::XmlPerl;
use DTA::CAB::Formatter::XmlRpc;

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
    if ($a_xlit) {
      $a_xlit->($tok,$opts);
      $l = $tok->{"xlit.latin1Text"};
    } else {
      $l = $tok->{text};
    }

    ##-- analyze: morph
    if ($a_morph) {
      $a_morph->($tok, { ($opts ? %$opts : qw()), src=>$l });
    }

    ##-- analyze: morph: safe?
    if ($a_msafe) {
      $a_msafe->($tok,$opts);
    }

    ##-- analyze: rewrite (if morphological analysis is "unsafe")
    if ($a_rw && !$tok->{"morph.safe"}) {
      $a_rw->($tok, { ($opts ? %$opts : qw()), src=>$l });
      if ($a_morph) {
	##-- analyze: rewrite: sub-morphology
	foreach (@{ $tok->{rw} }) {
	  $a_morph->($tok, { ($opts ? %$opts : qw()), src=>$_->[0], dst=>\$_->[2] });
	}
      }
    }

    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: Perl

## $str = $anl->analysisPerl($out,\%opts)
##  + inherited from DTA::CAB::Analyzer

##--------------------------------------------------------------
## Methods: Formatting: Text

## $str = $anl->analysisText($out,\%opts)
##  + text string for output $out with options \%opts
sub analysisText {
  my ($cab,$tok) = @_;
  return join("\t",
	      $tok->{text},
	      '/xlit:',  ($cab->{xlit}  && $tok->{xlit}  ? ($cab->{xlit}->analysisText($tok->{xlit}))   : qw()),
	      '/morph:', ($cab->{morph} && $tok->{morph} ? ($cab->{morph}->analysisText($tok->{morph})) : qw()),
	      '/msafe:', ($cab->{msafe} && $tok->{msafe} ? ($cab->{msafe}->analysisText($tok->{msafe})) : qw()),
	      '/rw:',    ($cab->{rw}    && $tok->{rw}    ? ($cab->{morph}->analysisText($tok->{rw}))    : qw()),
	     );
}

##--------------------------------------------------------------
## Methods: Formatting: Verbose Text

## @lines = $anl->analysisVerbose($out,\%opts)
##  + verbose text line(s) for output $out with options \%opts
##  + default version just calls analysisText()
sub analysisVerbose {
  my ($cab,$tok) = @_;
  return
    ($tok->{text},
     ($cab->{xlit}  && $tok->{xlit}  ? (" +(xlit)", map { "\t$_" } $cab->{xlit}->analysisVerbose($tok->{xlit}))   : qw()),
     ($cab->{morph} && $tok->{morph} ? (" +(morph)", map { "\t$_" } $cab->{morph}->analysisVerbose($tok->{morph})) : qw()),
     ($cab->{msafe} && 1             ? (" +(msafe)", map { "\t$_" } $cab->{msafe}->analysisVerbose($tok->{msafe})) : qw()),
     ($cab->{rw}    && $tok->{rw}    ? (" +(rewrite)", map { "\t$_" } $cab->{rw}->analysisVerbose($tok->{rw})) : qw()),
    );
}


##--------------------------------------------------------------
## Methods: Formatting: XML

## $nod = $anl->analysisXmlNode($out,\%opts)
##  + XML node for output $out with options \%opts
##  + returns new XML element:
##    <$anl->{xmlTokenElt} text="$text">
##      <xlit> ... </xlit>
##      <morph safe="$msafe"> ... </morph>
##      <rewrite> ... </rewrite>
##    </$anl->{xmlTokenElt}>
sub analysisXmlNode {
  my ($cab,$tok) = @_;
  my $nod = XML::LibXML::Element->new($cab->{xmlTokenElt} || DTA::CAB::Utils::xml_safe_string(ref($cab)));
  my ($kid);
  $nod->setAttribute('text', $tok->{text});
  $nod->addChild($cab->{xlit}->analysisXmlNode($tok->{xlit}))   if ($cab->{xlit} && $tok->{xlit});
  $nod->addChild($kid=$cab->{morph}->analysisXmlNode($tok->{morph})) if ($cab->{morph} && $tok->{morph});
  $kid->setAttribute("safe", $tok->{msafe} ? 1 : 0);
  $nod->addChild($cab->{rw}->analysisXmlNode($tok->{rw}))       if ($cab->{rw} && $tok->{rw});
  return $nod;
}

## $nod = $anl->defaultXmlNode($val)
##  + default XML node generator
##  + inherited from DTA::CAB::Analyzer


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
