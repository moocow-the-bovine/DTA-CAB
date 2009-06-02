## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlTW.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: XML (dta-tokwrap .t.xml)

package DTA::CAB::Format::XmlTW;
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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/(?i:\.t\.xml)$/);
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
##     ##-- analysis stuff
##     analysisElt => $elt,                    ##-- default: 'a'
##     analysisSrcAttr => $attr,               ##-- default: 'src'
##     analysisSrcDefault => $val,             ##-- default: 'tok' (tokenizer)
##    }
##  + parses doc, token, sentence keys 'xmlattrs' => \%hash
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- input
			   xprs => XML::LibXML->new,
			   xdoc => undef,

			   ##-- output
			   encoding => 'UTF-8',
			   level => 0,

			   ##-- analysis parsing
			   analysisElt => 'a',
			   analysisSrcAttr => 'src',
			   analysisSrcDefault => 'tok',

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
##  + extra %$doc keys parsed:
##    xmlattrs=>\%xml_attributes,
##  + extra %$sentence keys parsed:
##    xmlattrs=>\%xml_attributes,
##  + extra %$token keys parsed:
##    xmlattrs=>\%xml_attributes,
##    xmldtrs=>\@unparsedTokenChildElementStrings
sub parseDocument {
  my $fmt = shift;
  if (!defined($fmt->{xdoc})) {
    $fmt->logconfess("parseDocument(): no source document {xdoc} defined!");
    return undef;
  }
  my $root = $fmt->{xdoc}->documentElement;
  my $sents = [];
  my $doc   = bless({body=>$sents},'DTA::CAB::Document');

  ##-- parse document root xmlattrs
  $doc->{xmlattrs}{$_->nodeName} = $_->nodeValue foreach ($root->attributes);

  ##-- find & parse sentences
  my ($snod,$s,$stoks, $wnod,$tok, $anod,$asrc,$astr, $aanod,$aasrc,$aastr,$aa, $aaa);
  foreach $snod (@{ $root->findnodes("./s") }) {
    push(@$sents, $s=bless({tokens=>($stoks=[])},'DTA::CAB::Sentence'));

    ##-- parse sentence xmlattrs
    $s->{xmlattrs}{$_->nodeName} = $_->nodeValue foreach ($snod->attributes);

    ##-- find & parse sentence tokens
    foreach $wnod (@{ $snod->findnodes("./w") }) {
      push(@$stoks, $tok=bless({},'DTA::CAB::Token'));

      ##-- parse token xmlattrs
      $tok->{xmlattrs}{$_->nodeName} = $_->nodeValue foreach ($wnod->attributes);

      ##-- local xmlattrs
      $tok->{text} = $tok->{xmlattrs}{'t'}; ##-- PARAM
      delete($tok->{xmlattrs}{'t'});
      delete($tok->{xmlattrs}) if (!%{$tok->{xmlattrs}});

      ##-- find & parse token analyses
      foreach $anod (@{ $wnod->findnodes("./$fmt->{analysisElt}") }) {

	##-- get analysis src
	$asrc = $anod->getAttribute($fmt->{analysisSrcAttr});
	$asrc = $fmt->{analysisSrcDefault} if (!defined($asrc));

	##-- parse analysis
	if ($asrc eq 'xlit') {
	  ##-- token: field: 'xlit'
	  $tok->{xlit} = {
			  #latin1Text=>$anod->textContent,
			  latin1Text=>$anod->getAttribute('latin1Text'),
			  isLatin1  =>$anod->getAttribute('isLatin1'),
			  isLatinExt=>$anod->getAttribute('isLatinExt'),
			 };
	}
	elsif ($asrc eq 'lts') { #-- PARAM
	  ##-- token: field: 'lts'
	  $tok->{lts} = [] if (!$tok->{lts});
	  push(@{$tok->{lts}},
	       $aa={lo=>$anod->getAttribute('lo'), hi=>$anod->getAttribute('hi'), w=>$anod->getAttribute('w')});
	  delete(@$aa{grep {!defined($aa->{$_})} keys(%$aa)});
	}
	elsif ($asrc eq 'eqpho') { #-- PARAM
	  ##-- token: field: 'eqpho'
	  $tok->{eqpho} = [] if (!$tok->{eqpho});
	  push(@{$tok->{eqpho}}, $anod->getAttribute('t')); ##-- PARAM
	}
	elsif ($asrc eq 'morph') { ##-- PARAM
	  ##-- token: field: 'morph'
	  $tok->{morph} = [] if (!$tok->{morph});
	  push(@{$tok->{morph}},
	       $aa={lo=>$anod->getAttribute('lo'), hi=>$anod->getAttribute('hi'), w=>$anod->getAttribute('w')}); ##-- PARAM
	  delete(@$aa{grep {!defined($aa->{$_})} keys(%$aa)});
	}
	elsif ($asrc eq 'msafe') { ##-- PARAM
	  ##-- token: field: 'msafe'
	  $tok->{msafe} = $anod->getAttribute('safe');
	}
	elsif ($asrc eq 'rw') { ##-- PARAM
	  ##-- token: field: 'rewrite'
	  $tok->{rw} = [] if (!$tok->{rw});
	  push(@{$tok->{rw}},
	       $aa={lo=>$anod->getAttribute('lo'), hi=>$anod->getAttribute('hi'), w=>$anod->getAttribute('w')}); ##-- PARAM
	  delete(@$aa{grep {!defined($aa->{$_})} keys(%$aa)});

	  ##-- rewrite: sub-analyses
	  foreach $aanod (@{ $anod->findnodes("./$fmt->{analysisElt}") }) { ##-- PARAM
	    ##-- rewrite: get analysis src
	    $aasrc = $aanod->getAttribute($fmt->{analysisSrcAttr});
	    $aasrc = $fmt->{analysisSrcDefault} if (!defined($aasrc));

	    if ($aasrc eq 'lts') { ##-- PARAM
	      ##-- token: rewrite: field: 'lts'
	      $aa->{lts} = [] if (!$aa->{lts});
	      push(@{$aa->{lts}},
		   $aaa={lo=>$aanod->getAttribute('lo'), hi=>$aanod->getAttribute('hi'), w=>$aanod->getAttribute('w')});
	      delete(@$aaa{grep {!defined($aaa->{$_})} keys(%$aaa)});
	    }
	    elsif ($aasrc eq 'morph') { ##-- PARAM
	      ##-- token: rewrite: field: 'morph'
	      $aa->{morph} = [] if (!$aa->{morph});
	      push(@{$aa->{morph}},
		   $aaa={lo=>$aanod->getAttribute('lo'), hi=>$aanod->getAttribute('hi'), w=>$aanod->getAttribute('w')});
	      delete(@$aaa{grep {!defined($aaa->{$_})} keys(%$aaa)});
	    }
	  }
	}
	else {
	  ##-- token: field: unparsed
	  $tok->{xmldtrs} = [] if (!$tok->{xmldtrs});
	  push(@{$tok->{xmldtrs}}, $anod->toString(0));
	}
      }
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

  ##-- node, text
  my $nod = XML::LibXML::Element->new('w'); ##-- PARAM
  $nod->setAttribute('t',$tok->{text});     ##-- PARAM

  ##-- inherited attributes
  if ($tok->{xmlattrs}) {
    $nod->setAttribute($_, $tok->{xmlattrs}{$_}) foreach (keys(%{$tok->{xmlattrs}}));
  }

  ##-- unparsed analyses
  if ($tok->{xmldtrs}) {
    $nod->appendWellBalancedChunk($_) foreach (@{$tok->{xmldtrs}});
  }

  ##-- common variables
  my ($anod, $rw,$rwanod);

  ##-- Transliterator ('xlit')
  if (defined($tok->{xlit})) {
    $anod = $nod->addNewChild(undef, 'a');
    $anod->setAttribute('src', 'xlit'); ##-- PARAM
    $anod->setAttribute('latin1Text', $tok->{xlit}{latin1Text}); ##-- PARAM
    $anod->setAttribute('isLatin1',   $tok->{xlit}{isLatin1});   ##-- PARAM
    $anod->setAttribute('isLatinExt', $tok->{xlit}{isLatinExt}); ##-- PARAM
  }

  ##-- LTS ('lts')
  if ($tok->{lts}) { ##-- PARAM
    foreach (@{$tok->{lts}}) {
      $anod = $nod->addNewChild(undef, 'a');
      $anod->setAttribute('src','lts'); ##-- PARAM
      $anod->setAttribute('lo',$_->{lo}) if (defined($_->{lo})); ##-- PARAM
      $anod->setAttribute('hi',$_->{hi}); ##-- PARAM
      $anod->setAttribute('w', $_->{w});  ##-- PARAM
    }
  }

  ##-- EqPho ('eqpho')
  if ($tok->{eqpho}) {
    foreach (@{$tok->{eqpho}}) {
      $anod = $nod->addNewChild(undef, 'a');
      $anod->setAttribute('src','eqpho'); ##-- PARAM
      $anod->setAttribute('t',$_) if (defined($_)); ##-- PARAM
    }
  }

  ##-- Morphology ('morph')
  if ($tok->{morph}) {
    foreach (@{$tok->{morph}}) {
      $anod = $nod->addNewChild(undef, 'a');
      $anod->setAttribute('src','morph'); ##-- PARAM
      $anod->setAttribute('lo',$_->{lo}) if (defined($_->{lo})); ##-- PARAM
      $anod->setAttribute('hi',$_->{hi}); ##-- PARAM
      $anod->setAttribute('w',$_->{w}); ##-- PARAM
    }
  }

  ##-- MorphSafe ('msafe')
  if (exists($tok->{msafe})) {
    $anod = $nod->addNewChild(undef,'a');
    $anod->setAttribute('src', 'msafe'); ##-- PARAM
    $anod->setAttribute('safe', $tok->{msafe} ? 1 : 0); ##-- PARAM
  }

  ##-- Rewrite ('rw')
  if ($tok->{rw}) {
    foreach $rw (@{$tok->{rw}}) {
      $rwanod = $nod->addNewChild(undef, 'a');
      $rwanod->setAttribute('src','rw'); ##-- PARAM
      $rwanod->setAttribute('lo',$rw->{lo}) if (defined($rw->{lo})); ##-- PARAM
      $rwanod->setAttribute('hi',$rw->{hi}); ##-- PARAM
      $rwanod->setAttribute('w',$rw->{w}); ##-- PARAM

      ##-- rewrite: lts
      if ($rw->{lts}) {
	foreach (@{$rw->{lts}}) {
	  $anod = $rwanod->addNewChild(undef, 'a');
	  $anod->setAttribute('src','lts'); ##-- PARAM
	  $anod->setAttribute('lo',$_->{lo}) if (defined($_->{lo})); ##-- PARAM
	  $anod->setAttribute('hi',$_->{hi}); ##-- PARAM
	  $anod->setAttribute('w', $_->{w});  ##-- PARAM
	}
      }

      ##-- rewrite: morph
      if ($rw->{morph}) {
	foreach (@{$rw->{morph}}) {
	  $anod = $rwanod->addNewChild(undef, 'a');
	  $anod->setAttribute('src','morph'); ##-- PARAM
	  $anod->setAttribute('lo',$_->{lo}) if (defined($_->{lo})); ##-- PARAM
	  $anod->setAttribute('hi',$_->{hi}); ##-- PARAM
	  $anod->setAttribute('w',$_->{w}); ##-- PARAM
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
  my $snod = XML::LibXML::Element->new('s'); ##-- PARAM

  ##-- inherited attributes
  if ($sent->{xmlattrs}) {
    $snod->setAttribute($_, $sent->{xmlattrs}{$_}) foreach (keys(%{$sent->{xmlattrs}}));
  }

  ##-- format sentence 'tokens'
  $snod->addChild($fmt->tokenNode($_)) foreach (@{$sent->{tokens}});
  return $snod;
}

## $xmlnod = $fmt->documentNode($doc)
sub documentNode {
  my ($fmt,$doc) = @_;
  $doc = toDocument($doc);
  my $docnod = XML::LibXML::Element->new('sentences'); ##-- PARAM

  ##-- inherited attributes
  if ($doc->{xmlattrs}) {
    $docnod->setAttribute($_, $doc->{xmlattrs}{$_}) foreach (keys(%{$doc->{xmlattrs}}));
  }

  ##-- format sentences
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
sub xmlBodyNode {
  my $fmt = shift;
  return $fmt->xmlRootNode('sentences'); ##-- PARAM
}

## $sentnod = $fmt->xmlSentenceNode()
sub xmlSentenceNode {
  my $fmt = shift;
  my $body = $fmt->xmlBodyNode();
  my ($snod) = $body->findnodes("./s[last()]"); ##-- PARAM
  return $snod if (defined($snod));
  return $body->addNewChild(undef,'s'); ##-- PARAM
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

DTA::CAB::Format::XmlTW - Datum parser|formatter: XML (native)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::XmlTW;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::XmlTW->new(%args);
 
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
## DESCRIPTION: DTA::CAB::Format::XmlTW: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::XmlTW
inherits from
L<DTA::CAB::Format::XmlCommon|DTA::CAB::Format::XmlCommon>.

=item Filenames

DTA::CAB::Format::XmlTW registers the filename regex:

 /\.(?i:xml-native|xml-dta-cab|(?:dta[\-\._]cab[\-\._]xml)|xml)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlTW: Constructors etc.
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

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlTW: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item parseDocument

 $doc = $fmt->parseDocument();

Parses buffered XML::LibXML::Document in $fmt-E<gt>{xdoc}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlTW: Methods: Output
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

(TODO)


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
