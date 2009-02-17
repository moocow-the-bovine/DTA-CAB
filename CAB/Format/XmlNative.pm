## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlNative.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: XML (native)

package DTA::CAB::Format::XmlNative;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlCommon);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-native|xml\-dta\-cab|xml)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- input
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output
##     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common: XML element & attribute names
##     documentElt      => $eltName,    ##-- default: 'doc'
##     sentenceElt      => $eltName,    ##-- default: 's'
##     tokenElt         => $eltName,    ##-- default: 'w'
##     tokenTextAttr    => $attr,       ##-- default: 'text'
##     ##
##     ltsElt           => $eltName,    ##-- default: 'lts'
##     ltsAnalysisElt   => $eltName,    ##-- default: 'pho'
##     ltsStringAttr    => $attr,       ##-- default: 's'
##     ltsWeightAttr    => $attr,       ##-- default: 'w'
##     ##
##     morphElt         => $eltName,    ##-- default: 'morph'
##     morphAnalysisElt => $eltName,    ##-- default: 'ma'
##     morphStringAttr  => $attr,       ##-- default: 's'
##     morphWeightAttr  => $attr,       ##-- default: 'w'
##     ##
##     rwElt            => $eltName,    ##-- default: 'rewrite'
##     rwAnalysisElt    => $eltName,    ##-- default: 'rw'
##     rwStringAttr     => $attr,       ##-- default: 's'
##     rwWeightAttr     => $attr,       ##-- default: 'w'
##    }
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- input
			   xprs => XML::LibXML->new,
			   xdoc => undef,

			   ##-- output
			   encoding => 'UTF-8',
			   level => 0,

			   ##-- common: XML names
			   documentElt => 'doc',
			   sentenceElt => 's',
			   tokenElt => 'w',
			   tokenTextAttr => 'text',
			   ##
			   ltsElt           => 'lts',
			   ltsAnalysisElt   => 'pho',
			   ltsStringAttr    => 's',
			   ltsWeightAttr    => 'w',
			   ##
			   morphElt => 'morph',
			   morphAnalysisElt => 'ma',
			   morphStringAttr  => 's',
			   morphWeightAttr  => 'w',
			   ##
			   rwElt => 'rewrite',
			   rwAnalysisElt => 'rw',
			   rwStringAttr => 's',
			   rwWeightAttr => 'w',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Persistence
##  + see Format::XmlCommon
##==============================================================================

##=============================================================================
## Methods: Parsing
##==============================================================================


##--------------------------------------------------------------
## Methods: Parsing: Input selection
##  + see Format::XmlCommon

##--------------------------------------------------------------
## Methods: Parsing: Generic API

## $doc = $fmt->parseDocument()
##  + parses buffered XML::LibXML::Document
sub parseDocument {
  my $fmt = shift;
  if (!defined($fmt->{xdoc})) {
    $fmt->logconfess("parseDocument(): no source document {xdoc} defined!");
    return undef;
  }
  my $root = $fmt->{xdoc}->documentElement;
  my $sents = [];
  my ($s,$tok, $snod,$toknod, $subnod,$subname, $panod,$manod,$rwnod, $rw);
  foreach $snod (@{ $root->findnodes("//body//$fmt->{sentenceElt}") }) {
    push(@$sents, bless({tokens=>($s=[])},'DTA::CAB::Sentence'));
    foreach $toknod (@{ $snod->findnodes(".//$fmt->{tokenElt}") }) {
      push(@$s,$tok=bless({},'DTA::CAB::Token'));
      $tok->{text} = $toknod->getAttribute($fmt->{tokenTextAttr});
      foreach $subnod (grep {UNIVERSAL::isa($_,'XML::LibXML::Element')} $toknod->childNodes) {
	$subname = $subnod->nodeName;
	if ($subname eq 'xlit') {
	  ##-- token: field: 'xlit'
	  $tok->{xlit} = [
			  $subnod->getAttribute('latin1Text'),
			  $subnod->getAttribute('isLatin1'),
			  $subnod->getAttribute('isLatinExt'),
			 ];
	}
	elsif ($subname eq $fmt->{ltsElt}) {
	  ##-- token: field: 'lts'
	  $tok->{lts} = [];
	  foreach $panod (grep {$_->nodeName eq $fmt->{ltsAnalysisElt}} $subnod->childNodes) {
	    push(@{$tok->{lts}}, [$panod->getAttribute($fmt->{ltsStringAttr}), $panod->getAttribute($fmt->{ltsWeightAttr})]);
	  }
	}
	elsif ($subname eq $fmt->{morphElt}) {
	  ##-- token: field: 'morph'
	  $tok->{morph} = [];
	  foreach $manod (grep {$_->nodeName eq $fmt->{morphAnalysisElt}} $subnod->childNodes) {
	    push(@{$tok->{morph}}, [$manod->getAttribute($fmt->{morphStringAttr}), $manod->getAttribute($fmt->{morphWeightAttr})]);
	  }
	}
	elsif ($subname eq 'msafe') {
	  ##-- token: field: 'msafe'
	  $tok->{msafe} = $subnod->getAttribute('safe');
	}
	elsif ($subname eq $fmt->{rwElt}) {
	  ##-- token: field: 'rewrite'
	  $tok->{rw} = [];
	  foreach $rwnod (grep {$_->nodeName eq $fmt->{rwAnalysisElt}} $subnod->childNodes) {
	    push(@{$tok->{rw}}, $rw=[$rwnod->getAttribute($fmt->{rwStringAttr}), $rwnod->getAttribute($fmt->{rwWeightAttr}), []]);
	    foreach $manod (grep {$_->nodeName eq $fmt->{morphAnalysisElt}} $rwnod->childNodes) {
	      push(@{$rw->[2]}, [$manod->getAttribute($fmt->{morphStringAttr}), $manod->getAttribute($fmt->{morphWeightAttr})]);
	    }
	  }
	}
	else {
	  ##-- token: field: ???
	  $fmt->debug("parseDocument(): unknown token child node '$subname' -- skipping");
	  ; ##-- just ignore
	}
      }
    }
  }

  ##-- construct & return document
  return bless({body=>$sents}, 'DTA::CAB::Document');
}


##=============================================================================
## Methods: Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: Local: Nodes

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

  ##-- LTS ('lts')
  my ($ltsnod,$phonod);
  if ($tok->{lts}) {
    $nod->addChild( $ltsnod = XML::LibXML::Element->new($fmt->{ltsElt}) );
    foreach (@{$tok->{lts}}) {
      $ltsnod->addChild( $phonod = XML::LibXML::Element->new($fmt->{ltsAnalysisElt}) );
      $phonod->setAttribute($fmt->{ltsStringAttr},$_->[0]);
      $phonod->setAttribute($fmt->{ltsWeightAttr},$_->[1]);
    }
  }

  ##-- Morphology ('morph')
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

##--------------------------------------------------------------
## Methods: Formatting: Local: Utils

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

##--------------------------------------------------------------
## Methods: Formatting: API

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
