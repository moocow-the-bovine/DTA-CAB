## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::XmlNative.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: XML (near perl-code)

package DTA::CAB::Formatter::XmlNative;
use DTA::CAB::Formatter;
use DTA::CAB::Formatter::XmlPerl;
use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Formatter::XmlPerl);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- NEW
##     ##-- XML element names
##     documentElt      => $eltName,    ##-- default: 'doc'
##     sentenceElt      => $eltName,    ##-- default: 's'
##     tokenElt         => $eltName,    ##-- default: 'w'
##     tokenTextATtr    => $attr,       ##-- default: 'text'
##     morphElt         => $eltName,    ##-- default: 'morph'
##     morphAnalysisElt => $eltName,    ##-- default: 'ma'
##     morphStringAttr  => $attr,       ##-- default: 's'
##     morphWeightAttr  => $attr,       ##-- default: 'w'
##     rwElt            => $eltName,    ##-- default: 'rewrite'
##     rwAnalysisElt    => $eltName,    ##-- default: 'rw'
##     rwStringAttr     => $attr,       ##-- default: 's'
##     rwWeightAttr     => $attr,       ##-- default: 'w'
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     ##-- output file (optional)
##     #outfh => $output_filehandle,  ##-- for default toFile() method
##     #outfile => $filename,         ##-- for determining whether $output_filehandle is local
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- XML element names
			   documentElt => 'doc',
			   sentenceElt => 's',
			   tokenElt => 'w',
			   tokenTextAttr => 'text',
			   morphElt => 'morph',
			   morphAnalysisElt => 'ma',
			   morphStringAttr  => 's',
			   morphWeightAttr  => 'w',
			   rwElt => 'rewrite',
			   rwAnalysisElt => 'rw',
			   rwStringAttr => 's',
			   rwWeightAttr => 'w',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

## $xmlnod = $fmt->formatToken($tok)
##  + returns formatted token $tok as an XML node
sub formatToken {
  my ($fmt,$tok) = @_;

  ##-- node, text
  my $nod = XML::LibXML::Element->new($fmt->{tokenElt});
  $nod->setAttribute($fmt->{tokenTextAttr},$tok->{text});

  ##-- Transliterator ('xlit')
  if (defined($tok->{"xlit.latin1Text"})) {
    $nod->setAttribute('isLatin1',   $tok->{'xlit.isLatin1'});
    $nod->setAttribute('isLatinExt', $tok->{'xlit.isLatinExt'});
    $nod->setAttribute('latin1Text', $tok->{'xlit.latin1Text'});
  }

  ##-- Morphology automaton ('morph')
  my ($mnod,$manod);
  if ($tok->{morph}) {
    $nod->addChild( $mnod = XML::LibXML::Element->new($fmt->{morphElt}) );
    foreach (@{$tok->{morph}}) {
      $mnod->addChild( $manod = XML::LibXML::Element->new($fmt->{morphAnalysisElt}) );
      $manod->setAttribute($fmt->{morphStringAttr},$_->[0]);
      $manod->setAttribute($fmt->{morphWeightAttr},$_->[1]);
    }
  }

  ##-- MorphSafe ('morph.safe')
  $nod->setAttribute('morph.safe', ($tok->{"morph.safe"} ? 1 : 0)) if (exists($tok->{"morph.safe"}));

  ##-- Rewrite
  my ($rwnod,$rwanod);
  if ($tok->{rw}) {
    $nod->addChild( $rwnod = XML::LibXML::Element->new($fmt->{rwElt}) );
    foreach (@{$tok->{rw}}) {
      $rwnod->addChild( $rwanod = XML::LibXML::Element->new($fmt->{rwAnalysisElt}) );
      $rwanod->setAttribute($fmt->{rwStringAttr},$_->[0]);
      $rwanod->setAttribute($fmt->{rwWeightAttr},$_->[1]);
      ##-- Rewrite: morph
      if ($_->[2]) {
	foreach (@{$_->[2]}) {
	  $rwanod->addChild( $manod = XML::LibXML::Element->new($fmt->{morphAnalysisElt}) );
	  $manod->setAttribute($fmt->{morphStringAttr},$_->[0]);
	  $manod->setAttribute($fmt->{morphWeightAttr},$_->[1]);
	}
      }
    }
  }

  ##-- done
  return $nod;
}

## $xmlnod = $fmt->formatSentence($sent)
sub formatSentence {
  my ($fmt,$sent) = @_;
  my $snod = XML::LibXML::Element->new($fmt->{sentenceElt});
  $snod->addChild($fmt->defaultXmlNode($sent->[0])); ##-- header
  $snod->addChild($fmt->formatToken($_)) foreach (@$sent[1..$#$sent]);
  return $snod;
}

## $xmlnod = $fmt->formatDocument($doc)
sub formatDocument {
  my ($fmt,$doc) = @_;
  my $dnod = XML::LibXML::Element->new($fmt->{documentElt});
  $dnod->addChild($fmt->defaultXmlNode($doc->[0])); ##-- header
  $dnod->addChild($fmt->formatSentence($_)) foreach (@$doc[1..$#$doc]);
  return $dnod;
}



1; ##-- be happy

__END__
