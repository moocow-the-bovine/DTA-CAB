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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-native|xml\-dta\-cab|(?:dta[\-\._]cab[\-\._]xml)|xml)$/);
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
##     ltsLoAttr        => $attr,       ##-- default: 'lo'
##     ltsHiAttr        => $attr,       ##-- default: 'hi'
##     ltsWeightAttr    => $attr,       ##-- default: 'w'
##     ##
##     eqphoElt         => $eltName,    ##-- default: 'eqpho'
##     eqphoSubElt      => $eltName,    ##-- default: 'w'
##     eqphoTextAttr    => $attr,       ##-- default: 'text'
##     ##
##     morphElt         => $eltName,    ##-- default: 'morph'
##     morphAnalysisElt => $eltName,    ##-- default: 'ma'
##     morphLoAttr      => $attr,       ##-- default: 'lo'
##     morphHiAttr      => $attr,       ##-- default: 'hi'
##     morphWeightAttr  => $attr,       ##-- default: 'w'
##     ##
##     rwElt            => $eltName,    ##-- default: 'rewrite'
##     rwAnalysisElt    => $eltName,    ##-- default: 'rw'
##     rwLoAttr         => $attr,       ##-- default: 'lo'
##     rwHiAttr         => $attr,       ##-- default: 'hi'
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
			   ltsLoAttr        => 'lo',
			   ltsHiAttr        => 'hi',
			   ltsWeightAttr    => 'w',
			   ##
			   eqphoElt         => 'eqpho',
			   eqphoSubElt      => 'w',
			   eqphoTextAttr    => 'text',
			   ##
			   morphElt => 'morph',
			   morphAnalysisElt => 'ma',
			   morphLoAttr      => 'lo',
			   morphHiAttr      => 'hi',
			   morphWeightAttr  => 'w',
			   ##
			   rwElt => 'rewrite',
			   rwAnalysisElt => 'rw',
			   rwLoAttr      => 'lo',
			   rwHiAttr      => 'hi',
			   rwWeightAttr  => 'w',

			   ##-- user args
			   @_
			  );
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
  my ($s,$tok, $snod,$toknod, $subnod,$subname, $panod,$manod,$rwnod, $eqanod,$eqatxt, $rw, $fsma);
  foreach $snod (@{ $root->findnodes("//body//$fmt->{sentenceElt}") }) {
    push(@$sents, bless({tokens=>($s=[])},'DTA::CAB::Sentence'));
    foreach $toknod (@{ $snod->findnodes(".//$fmt->{tokenElt}") }) {
      push(@$s,$tok=bless({},'DTA::CAB::Token'));
      $tok->{text} = $toknod->getAttribute($fmt->{tokenTextAttr});
      foreach $subnod (grep {UNIVERSAL::isa($_,'XML::LibXML::Element')} $toknod->childNodes) {
	$subname = $subnod->nodeName;
	if ($subname eq 'xlit') {
	  ##-- token: field: 'xlit'
	  $tok->{xlit} = {
			  latin1Text=>$subnod->getAttribute('latin1Text'),
			  isLatin1=>$subnod->getAttribute('isLatin1'),
			  isLatinExt=>$subnod->getAttribute('isLatinExt'),
			 };
	}
	elsif ($subname eq $fmt->{ltsElt}) {
	  ##-- token: field: 'lts'
	  $tok->{lts} = [];
	  foreach $panod (grep {$_->nodeName eq $fmt->{ltsAnalysisElt}} $subnod->childNodes) {
	    push(@{$tok->{lts}}, $fsma={});
	    @$fsma{qw(lo hi w)} = map {$panod->getAttribute($_)} @$fmt{qw(ltsLoAttr ltsHiAttr ltsWeightAttr)};
	    delete(@$fsma{grep {!defined($fsma->{$_})} keys(%$fsma)});
	  }
	}
	elsif ($subname eq $fmt->{eqphoElt}) {
	  ##-- token: field: 'eqpho'
	  $tok->{eqpho} = [];
	  foreach $eqanod (grep {$_->nodeName eq $fmt->{eqphoSubElt}} $subnod->childNodes) {
	    next if (!defined($eqatxt = $eqanod->getAttribute($fmt->{eqphoTextAttr})));
	    push(@{$tok->{eqpho}}, $eqatxt);
	  }
	}
	elsif ($subname eq $fmt->{morphElt}) {
	  ##-- token: field: 'morph'
	  $tok->{morph} = [];
	  foreach $manod (grep {$_->nodeName eq $fmt->{morphAnalysisElt}} $subnod->childNodes) {
	    push(@{$tok->{lts}}, $fsma={});
	    @$fsma{qw(lo hi w)} = map {$panod->getAttribute($_)} @$fmt{qw(morphLoAttr morphHiAttr morphWeightAttr)};
	    delete(@$fsma{grep {!defined($fsma->{$_})} keys(%$fsma)});
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
	    push(@{$tok->{rw}}, $rw=$fsma={});
	    @$fsma{qw(lo hi w)} = map {$panod->getAttribute($_)} @$fmt{qw(rwLoAttr rwHiAttr rwWeightAttr)};
	    delete(@$fsma{grep {!defined($fsma->{$_})} keys(%$fsma)});
	    ##-- rewrite: sub-analyses
	    foreach ($rwnod->childNodes) {
	      if ($_->nodeName eq $fmt->{ltsAnalysisElt}) {
		##-- rewrite: lts
		push(@{$rw->{lts}}, $fsma={});
		@$fsma{qw(lo hi w)} = map {$:->getAttribute($_)} @$fmt{qw(ltsLoAttr ltsHiAttr ltsWeightAttr)};
		delete(@$fsma{grep {!defined($fsma->{$_})} keys(%$fsma)});
	      }
	      elsif ($_->nodeName eq $fmt->{morphAnalysisElt}) {
		##-- rewrite: morph
		push(@{$rw->{morph}}, $fsma={});
		@$fsma{qw(lo hi w)} = map {$_->getAttribute($_)} @$fmt{qw(morphLoAttr morphHiAttr morphWeightAttr)};
		delete(@$fsma{grep {!defined($fsma->{$_})} keys(%$fsma)});
	      }
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
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Local: Nodes

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
    $xnod->setAttribute('isLatin1',   $tok->{xlit}{isLatin1});
    $xnod->setAttribute('isLatinExt', $tok->{xlit}{isLatinExt});
    $xnod->setAttribute('latin1Text', $tok->{xlit}{latin1Text});
  }

  ##-- LTS ('lts')
  my ($ltsnod,$panod);
  if ($tok->{lts}) {
    $nod->addChild( $ltsnod = XML::LibXML::Element->new($fmt->{ltsElt}) );
    foreach (@{$tok->{lts}}) {
      $ltsnod->addChild( $panod = XML::LibXML::Element->new($fmt->{ltsAnalysisElt}) );
      $panod->setAttribute($fmt->{ltsLoAttr},$_->{lo}) if ($fmt->{ltsLoAttr} && defined($_->{lo}));
      $panod->setAttribute($fmt->{ltsHiAttr},$_->{hi});
      $panod->setAttribute($fmt->{ltsWeightAttr},$_->{w});
    }
  }

  ##-- EqPho ('eqpho')
  my ($eqpnod,$eqpanod);
  if ($tok->{eqpho}) {
    $nod->addChild( $eqpnod = XML::LibXML::Element->new($fmt->{eqphoElt}) );
    foreach (@{$tok->{eqpho}}) {
      $eqpnod->addChild( $eqpanod = XML::LibXML::Element->new($fmt->{eqphoSubElt}) );
      $eqpanod->setAttribute($fmt->{eqphoTextAttr},$_) if ($fmt->{eqphoTextAttr} && defined($_));
    }
  }

  ##-- Morphology ('morph')
  my ($mnod,$manod);
  if ($tok->{morph}) {
    $nod->addChild( $mnod = XML::LibXML::Element->new($fmt->{morphElt}) );
    foreach (@{$tok->{morph}}) {
      $mnod->addChild( $manod = XML::LibXML::Element->new($fmt->{morphAnalysisElt}) );
      $manod->setAttribute($fmt->{morphLoAttr},$_->{lo}) if ($fmt->{morphLoAttr} && defined($_->{lo}));
      $manod->setAttribute($fmt->{morphHiAttr},$_->{hi});
      $manod->setAttribute($fmt->{morphWeightAttr},$_->{w});
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
      $rwanod->setAttribute($fmt->{rwLoAttr},$_->{lo}) if ($fmt->{rwLoAttr} && defined($_->{lo}));
      $rwanod->setAttribute($fmt->{rwHiAttr},$_->{hi});
      $rwanod->setAttribute($fmt->{rwWeightAttr},$_->{w});
      ##-- rewrite: lts
      if ($_->{lts}) {
	foreach (@{$_->{lts}}) {
	  $rwanod->addChild( $panod = XML::LibXML::Element->new($fmt->{ltsAnalysisElt}) );
	  $panod->setAttribute($fmt->{ltsLoAttr},$_->{lo}) if ($fmt->{ltsLoAttr} && defined($_->{lo}));
	  $panod->setAttribute($fmt->{ltsHiAttr},$_->{hi});
	  $panod->setAttribute($fmt->{ltsWeightAttr},$_->{w});
	}
      }
      ##-- rewrite: morph
      if ($_->{morph}) {
	foreach (@{$_->{morph}}) {
	  $rwanod->addChild( $manod = XML::LibXML::Element->new($fmt->{morphAnalysisElt}) );
	  $manod->setAttribute($fmt->{morphLoAttr},$_->{lo}) if ($fmt->{morphLoAttr} && defined($_->{lo}));
	  $manod->setAttribute($fmt->{morphHiAttr},$_->{hi});
	  $manod->setAttribute($fmt->{morphWeightAttr},$_->{w});
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
## Methods: Output: Local: Utils

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
## Methods: Output: API

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

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::XmlNative - Datum parser|formatter: XML (native)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::XmlNative;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::XmlNative->new(%args);
 
 ##========================================================================
 ## Methods: Input
 
 $doc = $fmt->parseDocument();
 
 ##========================================================================
 ## Methods: Output
 
 $xmlnod = $fmt->tokenNode($tok);
 $xmlnod = $fmt->sentenceNode($sent);
 $xmlnod = $fmt->documentNode($doc);
 $bodynode = $fmt->xmlBodyNode();
 $sentnod = $fmt->xmlSentenceNode();
 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putSentence($sent);
 $fmt = $fmt->putDocument($doc);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlNative: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::XmlNative
inherits from
L<DTA::CAB::Format::XmlCommon|DTA::CAB::Format::XmlCommon>.

=item Filenames

DTA::CAB::Format::XmlNative registers the filename regex:

 /\.(?i:xml-native|xml-dta-cab|(?:dta[\-\._]cab[\-\._]xml)|xml)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlNative: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$fmt:

 ##-- input
 xdoc => $xdoc,                   ##-- XML::LibXML::Document
 xprs => $xprs,                   ##-- XML::LibXML parser
 ##
 ##-- output
 encoding => $encoding,           ##-- default: UTF-8; applies to output only!
 level => $level,                 ##-- output formatting level (default=0)
 ##
 ##-- common: XML element & attribute names
 documentElt      => $eltName,    ##-- default: 'doc'
 sentenceElt      => $eltName,    ##-- default: 's'
 tokenElt         => $eltName,    ##-- default: 'w'
 tokenTextAttr    => $attr,       ##-- default: 'text'
 ##
 ltsElt           => $eltName,    ##-- default: 'lts'
 ltsAnalysisElt   => $eltName,    ##-- default: 'pho'
 ltsLoAttr        => $attr,       ##-- default: 'lo'
 ltsHiAttr        => $attr,       ##-- default: 'hi'
 ltsWeightAttr    => $attr,       ##-- default: 'w'
 ##
 eqphoElt         => $eltName,    ##-- default: 'eqpho'
 eqphoSubElt      => $eltName,    ##-- default: 'w'
 eqphoTextAttr    => $attr,       ##-- default: 'text'
 ##
 morphElt         => $eltName,    ##-- default: 'morph'
 morphAnalysisElt => $eltName,    ##-- default: 'ma'
 morphLoAttr      => $attr,       ##-- default: 'lo'
 morphHiAttr      => $attr,       ##-- default: 'hi'
 morphWeightAttr  => $attr,       ##-- default: 'w'
 ##
 rwElt            => $eltName,    ##-- default: 'rewrite'
 rwAnalysisElt    => $eltName,    ##-- default: 'rw'
 rwLoAttr         => $attr,       ##-- default: 'lo'
 rwHiAttr         => $attr,       ##-- default: 'hi'
 rwWeightAttr     => $attr,       ##-- default: 'w'

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlNative: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item parseDocument

 $doc = $fmt->parseDocument();

Parses buffered XML::LibXML::Document in $fmt-E<gt>{xdoc}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlNative: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item tokenNode

 $xmlnod = $fmt->tokenNode($tok);

Returns an XML::LibXML::Node object representing the DTA::CAB::Token $tok.

=item sentenceNode

 $xmlnod = $fmt->sentenceNode($sent);

Returns an XML::LibXML::Node object representing the DTA::CAB::Sentence $sent.

=item documentNode

 $xmlnod = $fmt->documentNode($doc);

Returns an XML::LibXML::Node object representing the DTA::CAB::Document $doc.

=item xmlBodyNode

 $bodynode = $fmt->xmlBodyNode();

Returns an XML::LibXML::Element object representing the
final 'body' element in the output document buffer, creating
one if not yet defined.

=item xmlSentenceNode

 $sentnod = $fmt->xmlSentenceNode();

Returns an XML::LibXML::Element object representing the
final "$fmt-E<gt>{sentenceElt}" (usually 's') element in the output document buffer, creating
one if not yet defined.

=item putToken

 $fmt = $fmt->putToken($tok);

Override: append token $tok to the output buffer.

=item putSentence

 $fmt = $fmt->putSentence($sent);

Override: append sentence $sent to the output buffer.

=item putDocument

 $fmt = $fmt->putDocument($doc);

Override: append document $doc to the output buffer.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## EXAMPLE
##========================================================================
=pod

=head1 EXAMPLE

An example file in the format accepted/generated by this module is:

 <?xml version="1.0" encoding="UTF-8"?>
 <doc>
  <head>
    <HASH ref="DTA::CAB::Document"/>
  </head>
  <body>
    <s>
      <w text="wie">
        <xlit isLatin1="1" isLatinExt="1" latin1Text="wie"/>
        <lts>
          <pho hi="vi" w="0"/>
        </lts>
        <eqpho>
          <w text="Wie"/>
          <w text="wie"/>
        </eqpho>
        <morph>
          <ma hi="wie[_ADV]" w="0"/>
          <ma hi="wie[_KON]" w="0"/>
          <ma hi="wie[_KOKOM]" w="0"/>
          <ma hi="wie[_KOUS]" w="0"/>
        </morph>
        <msafe safe="1"/>
      </w>
      <w text="oede">
        <xlit isLatin1="1" isLatinExt="1" latin1Text="oede"/>
        <lts>
          <pho hi="?2de" w="0"/>
        </lts>
        <eqpho>
          <w text="Oede"/>
          <w text="Öde"/>
          <w text="öde"/>
        </eqpho>
        <morph/>
        <msafe safe="0"/>
        <rewrite>
          <rw hi="öde" w="1">
            <pho hi="?2de" w="0"/>
            <ma hi="öde[_ADJD]" w="0"/>
            <ma hi="öde[_ADJA][pos][sg][nom]*[weak]" w="0"/>
            <ma hi="öde[_ADJA][pos][sg][nom][fem][strong_mixed]" w="0"/>
            <ma hi="öde[_ADJA][pos][sg][acc][fem]*" w="0"/>
            <ma hi="öde[_ADJA][pos][sg][acc][neut][weak]" w="0"/>
            <ma hi="öde[_ADJA][pos][pl][nom_acc]*[strong]" w="0"/>
            <ma hi="öd~en[_VVFIN][first][sg][pres][ind]" w="0"/>
            <ma hi="öd~en[_VVFIN][first][sg][pres][subjI]" w="0"/>
            <ma hi="öd~en[_VVFIN][third][sg][pres][subjI]" w="0"/>
            <ma hi="öd~en[_VVIMP][sg]" w="0"/>
          </rw>
        </rewrite>
      </w>
      <w text="!">
        <xlit isLatin1="1" isLatinExt="1" latin1Text="!"/>
        <lts>
          <pho hi="" w="0"/>
        </lts>
        <morph/>
        <msafe safe="1"/>
      </w>
    </s>
  </body>
 </doc>

=cut


##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
