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
##     ##---- NEW in Formatter::XmlNative
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
##     ##---- INHERITED from DTA::CAB::Formatter::XmlCommon
##     xdoc => $doc,                   ##-- XML::LibXML::Document (buffered)
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     encoding  => $encoding,         ##-- output encoding
##     level     => $formatLevel,      ##-- format level
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- output buffer
			   #xdoc => undef,

			   ##-- Formatter
			   encoding => 'UTF-8',
			   level => 0,

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
## Methods: Formatting: Local: Nodes
##==============================================================================

## $xmlnod = $fmt->tokenNode($tok)
##  + returns formatted token $tok as an XML node
sub tokenNode {
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

## $xmlnod = $fmt->sentenceNode($sent)
sub sentenceNode {
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
  $snod->addChild($fmt->tokenNode($_)) foreach (@{$sent->{tokens}});
  return $snod;
}

## $xmlnod = $fmt->documentNode($doc)
sub documentNode {
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
  $bodynod->addChild($fmt->sentenceNode($_)) foreach (@{$doc->{body}});

  return $docnod;
}

##==============================================================================
## Methods: Formatting: Local: Utils
##==============================================================================

## $xmldoc = $fmt->xmlDocument()
##  + create or return output buffer $fmt->{xdoc}
##  + inherited from XmlCommon

## $rootnode = $fmt->xmlRootNode($nodname)
##  + returns root node
##  + inherited from XmlCommon

## $bodynode = $fmt->xmlBodyNode()
sub xmlBodyNode {
  my $fmt = shift;
  my $root = $fmt->xmlRootNode($fmt->{documentElt});
  my ($body) = $root->findnodes("./body[last()]");
  return $body if (defined($body));
  return $root->addNewChild(undef,'body');
}

## $sentnod = $fmt->xmlSentenceNode()
sub xmlSentenceNode {
  my $fmt = shift;
  my $body = $fmt->xmlBodyNode();
  my ($snod) = $body->findnodes("./$fmt->{sentenceElt}[last()]");
  return $snod if (defined($snod));
  return $body->addNewChild(undef,$fmt->{sentenceElt});
}

##==============================================================================
## Methods: Formatting: API
##==============================================================================

## $fmt = $fmt->putToken($tok)
sub putToken {
  my ($fmt,$tok) = @_;
  $fmt->sentenceNode->addChild($fmt->tokenNode($tok));
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->bodyNode->addChild($fmt->sentenceNode($sent));
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  my ($fmt,$doc) = @_;
  my $docnod = $fmt->documentNode($doc);
  my $xdoc = $fmt->xmlDocument();
  my ($root);
  if (!defined($root=$xdoc->documentElement)) {
    $xdoc->setDocumentElement($docnod);
  } else {
    $root->addChild($_) foreach ($docnod->childNodes);
  }
  return $fmt;
}

1; ##-- be happy

__END__
