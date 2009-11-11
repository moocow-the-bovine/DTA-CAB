## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlVz.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: XML (Vz)

package DTA::CAB::Format::XmlVz;
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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-vz|(?:vz[\-\._]xml))$/);
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
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- input
			      xprs => undef,
			      xdoc => undef,

			      ##-- output
			      encoding => 'UTF-8',
			      level => 1,

			      ##-- user args
			      @_
			     );

  if (!$fmt->{xprs}) {
    $fmt->{xprs} = XML::LibXML->new;
    $fmt->{xprs}->keep_blanks(0);
  }
  return $fmt;
}

##==============================================================================
## Methods: Persistence
##  + see Format::XmlCommon
##==============================================================================

##=============================================================================
## Methods: Input
##==============================================================================


##--------------------------------------------------------------
## Methods: Input: Input selection
##  + see Format::XmlCommon

##--------------------------------------------------------------
## Methods: Input: Generic API

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
  my $doc   = bless({body=>$sents},'DTA::CAB::Document');

  ##-- common variables
  my ($snod,$s,$stoks, $wnod,$w);

  ##-- doc attributes: xmlbase
  $doc->{$_->name} = $_->value foreach ($root->attributes);

  ##-- loop: sentences
  foreach $snod (@{ $root->findnodes(".//s") }) {
    push(@$sents, $s=bless({tokens=>($stoks=[])},'DTA::CAB::Sentence'));
    $s->{$_->name} = $_->value foreach ($snod->attributes);

    ##-- loop: sentence/tokens
    foreach $wnod (@{ $snod->findnodes("./w") }) {
      push(@$stoks, $w=bless({},'DTA::CAB::Token'));
      $w->{$_->name} = $_->value foreach ($wnod->attributes);
      $w->{text} = $w->{plain} if (!defined($w->{text})); ##-- hack
    }
  }

  ##-- return document
  return $doc;
}


##=============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Local: Nodes

## $xmlnod = $fmt->tokenNode($tok)
##  + returns formatted token $tok as an XML node
sub tokenNode {
  my ($fmt,$tok) = @_;
  $tok = toToken($tok);
  my $wnod = XML::LibXML::Element->new('w');
  $wnod->setAttribute($_,$tok->{$_}) foreach (grep {defined($tok->{$_}) && !ref($tok->{$_})} sort(keys(%$tok)));
  return $wnod;
}

## $xmlnod = $fmt->sentenceNode($sent)
sub sentenceNode {
  my ($fmt,$sent) = @_;
  $sent = toSentence($sent);
  my $snod  = XML::LibXML::Element->new('s');
  $snod->setAttribute($_,$sent->{$_}) foreach (grep {defined($sent->{$_}) && !ref($sent->{$_})} sort(keys(%$sent)));
  $snod->addChild($fmt->tokenNode($_)) foreach (@{$sent->{tokens}});
  return $snod;
}

## $xmlnod = $fmt->documentNode($doc)
sub documentNode {
  my ($fmt,$doc) = @_;
  $doc = toDocument($doc);
  my $docnod = XML::LibXML::Element->new('doc');
  $docnod->setAttribute($_,$doc->{$_}) foreach (grep {defined($doc->{$_}) && !ref($doc->{$_})} sort(keys(%$doc)));
  $docnod->addChild($fmt->sentenceNode($_)) foreach (@{$doc->{body}});
  return $docnod;
}

##--------------------------------------------------------------
## Methods: Output: Local: Utils

## $xmldoc = $fmt->xmlDocument()
##  + create or return output buffer $fmt->{xdoc}
##  + inherited from XmlCommon

## $rootnode = $fmt->xmlRootNode($nodname)
##  + returns root node
##  + inherited from XmlCommon

## $bodynode = $fmt->xmlBodyNode()
##  + really just a wrapper for $fmt->xmlRootNode($fmt->{documentElement})
sub xmlBodyNode {
  my $fmt = shift;
  return $fmt->xmlRootNode('doc');
}

## $sentnod = $fmt->xmlSentenceNode()
sub xmlSentenceNode {
  my $fmt = shift;
  my $body = $fmt->xmlBodyNode();
  my ($snod) = $body->findnodes(".//s\[last()]");
  return $snod if (defined($snod));
  return $body->addNewChild(undef,'s');
}


##--------------------------------------------------------------
## Methods: Output: API

## $fmt = $fmt->putToken($tok)
sub putToken {
  my ($fmt,$tok) = @_;
  $fmt->xmlSentenceNode->addChild($fmt->tokenNode($tok));
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->xmlBodyNode->addChild($fmt->sentenceNode($sent));
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  my ($fmt,$doc) = @_;
  my $docnod = $fmt->documentNode($doc);
  my ($xdoc,$root);
  if (!defined($xdoc=$fmt->{xdoc}) || !defined($root=$fmt->{xdoc}->documentElement)) {
    $xdoc = $fmt->{xdoc} = $fmt->xmlDocument() if (!$fmt->{xdoc});
    $xdoc->setDocumentElement($docnod);
  } else {
    ##-- append-mode for real or converted input
    $root->appendChild($docnod);
  }

  return $fmt;
}

##========================================================================
## package DTA::CAB::Format::VzXml : alias for 'XmlVz'
package DTA::CAB::Format::VzXml;
use strict;
use base qw(DTA::CAB::Format::XmlVz);


1; ##-- be happy

__END__
