## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlPerl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: XML (perl-near)

package DTA::CAB::Format::XmlPerl;
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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-perl|perl[\-\.]xml)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##-- input
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output
##     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- input
			   #xdoc => undef,
			   #xprs => XML::LibXML->new,

			   ##-- output
			   encoding => 'UTF-8',
			   level    => 0,

			   ##-- common

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns empty list
sub noSaveKeys {
  return qw(xdoc xprs);
}


##=============================================================================
## Methods: Parsing
##==============================================================================

##--------------------------------------------------------------
## Methods: Parsing: Input selection


##--------------------------------------------------------------
## Methods: Parsing: Local

## $obj = $fmt->parseNode($nod)
sub parseNode {
  my ($fmt,$nod) = @_;
  my $nodname = $nod->nodeName;
  my ($val,$ref);
  if ($nodname eq 'VALUE') {
    ##-- non-reference: <VALUE>$val</VALUE> or <VALUE undef="1"/>
    $val = $nod->getAttribute('undef') ? undef : $nod->textContent;
  }
  elsif ($nodname eq 'HASH') {
    ##-- HASH ref: <HASH ref="$ref"> ... <ENTRY key="$eltKey">defaultXmlNode($eltVal)</ENTRY> ... </HASH>
    $ref = $nod->getAttribute('ref');
    $val = {};
    $val = bless($val,$ref) if ($ref && $ref ne 'HASH');
    foreach (grep {$_->nodeName eq 'ENTRY'} $nod->childNodes) {
      $val->{ $_->getAttribute('key') } = $fmt->parseNode(grep {ref($_) eq 'XML::LibXML::Element'} $_->childNodes);
    }
  }
  elsif ($nodname eq 'ARRAY') {
    ##-- ARRAY ref: <ARRAY ref="$ref"> ... xmlNode($eltVal) ... </ARRAY>
    $ref = $nod->getAttribute('ref');
    $val = [];
    $val = bless($val,$ref) if ($ref && $ref ne 'ARRAY');
    foreach (grep {ref($_) eq 'XML::LibXML::Element'} $nod->childNodes) {
      push(@$val, $fmt->parseNode($_));
    }
  }
  elsif ($nodname eq 'SCALAR') {
    ##-- SCALAR ref: <SCALAR ref="$ref"> xmlNode($$val) </SCALAR>
    my $val0 = $fmt->parseNode( grep {ref($_) eq 'XML::LibXML::Element'} $_->childNodes );
    $ref = $nod->getAttribute('ref');
    $val = \$val0;
    $val = bless($val,$ref) if ($ref && $ref ne 'SCALAR');
  }
  else {
    ##-- unknown : skip
  }
  return $val;
}

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
  my $parsed = $fmt->parseNode($fmt->{xdoc}->documentElement);

  ##-- force document
  return $fmt->forceDocument($parsed);
}


##=============================================================================
## Methods: Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: Local: Nodes

## $xmlnod = $fmt->tokenNode($tok)
##  + returns formatted token $tok as an XML node
sub tokenNode { return $_[0]->defaultXmlNode($_[1]); }

## $xmlnod = $fmt->sentenceNode($sent)
sub sentenceNode { return $_[0]->defaultXmlNode($_[1]); }

## $xmlnod = $fmt->documentNode($doc)
sub documentNode { return $_[0]->defaultXmlNode($_[1]); }


## $body_array_node = $fmt->xmlBodyNode()
##  + gets or creates buffered body array node
sub xmlBodyNode {
  my $fmt = shift;
  my $root = $fmt->xmlRootNode($fmt->{documentElt});
  my ($body) = $root->findnodes('./ENTRY[@key="body"][last()]');
  if (!defined($body)) {
    $body = $root->addNewChild(undef,"ENTRY");
    $body->setAttribute('key','body');
  }
  my ($ary) = $body->findnodes("./ARRAY[last()]");
  return $ary if (defined($ary));
  return $body->addNewChild(undef,"ARRAY");
}

## $sentence_array_node = $fmt->xmlSentenceNode()
##  + gets or creates buffered sentence array node
sub xmlSentenceNode {
  my $fmt = shift;
  my $body = $fmt->xmlBodyNode();
  my ($snod) = $body->findnodes('./*[@ref="DTA::CAB::Sentence"][last()]');
  if (!defined($snod)) {
    $snod = $body->addNewChild(undef,"HASH");
    $snod->setAttribute("ref","DTA::CAB::Sentence");
  }
  my ($toks) = $snod->findnodes('./ENTRY[@key="tokens"][last()]');
  if (!defined($toks)) {
    $toks = $body->addNewChild("ENTRY");
    $toks->setAttribute("key","tokens");
  }
  my ($ary) = $toks->findnodes("./ARRAY[last()]");
  if (!defined($ary)) {
    $ary = $toks->addNewChild(undef,'ARRAY');
  }
  return $ary;
}

##--------------------------------------------------------------
## Methods: Formatting: API

## $fmt = $fmt->putToken($tok)
sub putToken {
  my ($fmt,$tok) = @_;
  $fmt->sentenceNode->addChild( $fmt->tokenNode($tok) );
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->bodyNode->addChild( $fmt->sentenceNode($sent) );
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
    my $body = $fmt->xmlBodyNode();
    $body->addChild($_) foreach ($docnod->findnodes('./ENTRY[@key="body"]/ARRAY/*'));
  }
  return $fmt;
}


1; ##-- be happy

__END__
