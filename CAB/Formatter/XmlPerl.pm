## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::XmlPerl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: XML (near perl-code)

package DTA::CAB::Formatter::XmlPerl;
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

			   ##-- defaults
			   encoding => 'UTF-8',
			   level    => 0,
			   #xdoc    => undef,

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: Local: Nodes
##==============================================================================

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

##==============================================================================
## Methods: Formatting: API
##==============================================================================

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
