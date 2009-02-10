## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::XmlNative.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: XML (near perl-code)

package DTA::CAB::Formatter::XmlNative;
use DTA::CAB::Formatter;
use DTA::CAB::Formatter::XmlCommon;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Formatter::XmlCommon);

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
			   ##-- encoding
			   encoding => 'UTF-8',

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
  $tok = toToken($tok);

  ##-- node, text
  my $nod = XML::LibXML::Element->new($fmt->{tokenElt});
  $nod->setAttribute($fmt->{tokenTextAttr},$tok->{text});

  ##-- Transliterator ('xlit')
  if (defined($tok->{xlit})) {
    my $xnod = $nod->addNewChild(undef, 'xlit');
    $xnod->setAttribute('isLatin1',   $tok->{xlit}[1]);
    $xnod->setAttribute('isLatinExt', $tok->{xlit}[2]);
    $xnod->setAttribute('latin1Text', $tok->{xlit}[0]);
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

  ##-- MorphSafe ('msafe')
  if (exists($tok->{msafe})) {
    $mnod = $nod->addNewChild(undef,'msafe');
    $mnod->setAttribute('safe', $tok->{msafe} ? 1 : 0);
  }

  ##-- Rewrite ('rw')
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
  $sent = toSentence($sent);
  my $snod = XML::LibXML::Element->new($fmt->{sentenceElt});
#
#  ##-- format non-tokens (?)
#  if (keys(%$sent) > 1 || !exists($sent->{tokens})) {
#    my $toks = $sent->{tokens};
#    delete($sent->{tokens});
#    $snod->addChild($fmt->defaultXmlNode($sent));
#    $sent->{tokens} = $toks;
#  }
#
  ##-- format sentence 'tokens'
  $snod->addChild($fmt->formatToken($_)) foreach (@{$sent->{tokens}});
  return $snod;
}

## $xmlnod = $fmt->formatDocument($doc)
sub formatDocument {
  my ($fmt,$doc) = @_;
  $doc = toDocument($doc);
  my $docnod = XML::LibXML::Element->new($fmt->{documentElt});

  ##-- format non-body (?)
  my $headnod = $docnod->addNewChild(undef, 'head');
  my $docbody = $doc->{body}; ##-- save
  delete($doc->{body});
  $headnod->addChild($fmt->defaultXmlNode($doc));
  $doc->{body} = $docbody;    ##-- restore

  ##-- format doc 'body'
  my $bodynod = $docnod->addNewChild(undef, 'body');
  $bodynod->addChild($fmt->formatSentence($_)) foreach (@{$doc->{body}});

  return $docnod;
}



1; ##-- be happy

__END__
