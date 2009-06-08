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
##     multidocElt      => $eltName,    ##-- default: 'corpus'
##     sentenceElt      => $eltName,    ##-- default: 's'
##     tokenElt         => $eltName,    ##-- default: 'w'
##     tokenTextAttr    => $attr,       ##-- default: 't'
##     ##
##     xlitElt          => $eltName,    ##-- default: 'xlit'
##     xlitTextAttr     => $attr,       ##-- default: 't'
##     xlitIsLatin1Attr => $attr,       ##-- default: 'isLatin1'
##     xlitIsLatinExtAttr=>$attr,       ##-- default: 'isLatinExt'
##     ##
##     ltsElt           => $eltName,    ##-- default: 'lts'
##     ltsAnalysisElt   => $eltName,    ##-- default: 'a'
##     ltsLoAttr        => $attr,       ##-- default: 'lo'
##     ltsHiAttr        => $attr,       ##-- default: 'hi'
##     ltsWeightAttr    => $attr,       ##-- default: 'w'
##     ##
##     eqphoElt         => $eltName,    ##-- default: 'eqpho'
##     eqphoAnalysisElt => $eltName,    ##-- default: 'a'
##     eqphoTextAttr    => $attr,       ##-- default: 't'
##     ##
##     morphElt         => $eltName,    ##-- default: 'morph'
##     morphAnalysisElt => $eltName,    ##-- default: 'a'
##     morphLoAttr      => $attr,       ##-- default: 'lo'
##     morphHiAttr      => $attr,       ##-- default: 'hi'
##     morphWeightAttr  => $attr,       ##-- default: 'w'
##     ##
##     msafeElt         => $eltName,    ##-- default: 'msafe'
##     msafeAttr        => $attrName,   ##-- defualt: 'safe'
##     ##
##     rwElt            => $eltName,    ##-- default: 'rewrite'
##     rwAnalysisElt    => $eltName,    ##-- default: 'a'
##     rwLoAttr         => $attr,       ##-- default: 'lo'
##     rwHiAttr         => $attr,       ##-- default: 'hi'
##     rwWeightAttr     => $attr,       ##-- default: 'w'
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			   ##-- input
			      xprs => undef,
			      xdoc => undef,

			      ##-- output
			      encoding => 'UTF-8',
			      level => 0,

			      ##-- common: XML names
			      documentElt => 'doc',
			      multidocElt => 'corpus',
			      sentenceElt => 's',
			      tokenElt      => 'w',
			      tokenTextAttr => 't', #'text',
			      tokenLocAttr  => 'b', #'loc',
			      ##
			      xlitElt          => 'xlit',
			      xlitTextAttr     => 't', #'latin1Text',
			      xlitIsLatin1Attr => 'isLatin1',
			      xlitIsLatinExtAttr=> 'isLatinExt',
			      ##
			      ltsElt           => 'lts',
			      ltsAnalysisElt   => 'a', #'pho',
			      ltsLoAttr        => 'lo',
			      ltsHiAttr        => 'hi',
			      ltsWeightAttr    => 'w',
			      ##
			      eqphoElt         => 'eqpho',
			      eqphoAnalysisElt => 'a', #'w',
			      eqphoTextAttr    => 't', #'text',
			      ##
			      morphElt => 'morph',
			      morphAnalysisElt => 'a', #'ma',
			      morphLoAttr      => 'lo',
			      morphHiAttr      => 'hi',
			      morphWeightAttr  => 'w',
			      ##
			      msafeElt         => 'msafe',
			      msafeAttr        => 'safe',
			      ##
			      rwElt => 'rewrite',
			      rwAnalysisElt => 'a', #'rw',
			      rwLoAttr      => 'lo',
			      rwHiAttr      => 'hi',
			      rwWeightAttr  => 'w',

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
##  + extra %$doc keys parsed:
##    _xmldoc => $doc,              ##-- source XML::LibXML::Document
##    _xmlnod => $node,             ##-- source XML::LibXML::Element
##  + extra %$sentence keys parsed:
##    _xmlnod  => $node,            ##-- source XML::LibXML::Element
##  + extra %$token keys parsed:
##    _xmlnod => $node,             ##-- source XML::LibXML::Element
sub parseDocument {
  my $fmt = shift;
  if (!defined($fmt->{xdoc})) {
    $fmt->logconfess("parseDocument(): no source document {xdoc} defined!");
    return undef;
  }
  my $root = $fmt->{xdoc}->documentElement;
  my $sents = [];
  my $doc   = bless({body=>$sents, _xmldoc=>$fmt->{xdoc}, _xmlnod=>$root, },'DTA::CAB::Document');

  ##-- common variables
  my ($snod,$s,$stoks, $wnod,$tok, $anod,$a, $rwnod,$rw);

  ##-- loop: sentences
  foreach $snod (@{ $root->findnodes(".//$fmt->{sentenceElt}") }) {
    push(@$sents, $s=bless({tokens=>($stoks=[]), _xmlnod=>$snod},'DTA::CAB::Sentence'));

    ##-- loop: sentence/tokens
    foreach $wnod (@{ $snod->findnodes("./$fmt->{tokenElt}") }) {
      push(@$stoks, $tok=bless({ _xmlnod=>$wnod },'DTA::CAB::Token'));

      ##-- token: text
      $tok->{text} = $wnod->getAttribute($fmt->{tokenTextAttr});

      ##-- token: location
      @{$tok->{loc}}{qw(off len)} = split(/\s+/, $wnod->getAttribute($fmt->{tokenLocAttr}))
	if (defined($fmt->{tokenLocAttr}) && $wnod->hasAttribute($fmt->{tokenLocAttr}));

      ##-- token: xlit
      foreach $anod (@{ $wnod->findnodes("./$fmt->{xlitElt}\[last()]") }) {
	$tok->{xlit} = {};
	$tok->{xlit}{latin1Text} = $anod->getAttribute($fmt->{xlitTextAttr}) if ($fmt->{xlitTextAttr});
	$tok->{xlit}{isLatin1}   = $anod->getAttribute($fmt->{xlitIsLatin1Attr}) if ($fmt->{xlitIsLatin1Attr});
	$tok->{xlit}{isLatinExt} = $anod->getAttribute($fmt->{xlitIsLatinExtAttr}) if ($fmt->{xlitIsLatinExtAttr});
      }

      ##-- token: lts
      foreach $anod (@{ $wnod->findnodes("./$fmt->{ltsElt}/$fmt->{ltsAnalysisElt}") }) {
	#$tok->{lts} = [] if (!$tok->{lts});
	push(@{$tok->{lts}}, $a={});
	@$a{qw(lo hi w)} = map {$anod->getAttribute($_)} @$fmt{qw(ltsLoAttr ltsHiAttr ltsWeightAttr)};
	delete(@$a{grep {!defined($a->{$_})} keys(%$a)});
      }

      ##-- token: morph
      foreach $anod (@{ $wnod->findnodes("./$fmt->{morphElt}/$fmt->{morphAnalysisElt}") }) {
	#$tok->{morph} = [] if (!$tok->{morph});
	push(@{$tok->{morph}}, $a={});
	@$a{qw(lo hi w)} = map {$anod->getAttribute($_)} @$fmt{qw(morphLoAttr morphHiAttr morphWeightAttr)};
	delete(@$a{grep {!defined($a->{$_})} keys(%$a)});
      }

      ##-- token: eqpho
      foreach $anod (@{ $wnod->findnodes("./$fmt->{eqphoElt}/$fmt->{eqphoAnalysisElt}") }) {
	#$tok->{eqpho} = [] if (!$tok->{eqpho});
	push(@{$tok->{eqpho}}, $anod->getAttribute($fmt->{eqphoTextAttr}));
      }

      ##-- token: msafe
      foreach $anod (@{ $wnod->findnodes("./$fmt->{msafeElt}\[last()]") }) {
	$tok->{msafe} = $anod->getAttribute('safe') ? 1 : 0;
      }

      ##-- token: rewrite
      foreach $rwnod (@{ $wnod->findnodes("./$fmt->{rwElt}/$fmt->{rwAnalysisElt}") }) {
	#$tok->{rw} = [] if (!$tok->{rw});
	push(@{$tok->{rw}}, $rw={});
	@$rw{qw(lo hi w)} = map {$rwnod->getAttribute($_)} @$fmt{qw(rwLoAttr rwHiAttr rwWeightAttr)};
	delete(@$rw{grep {!defined($rw->{$_})} keys(%$rw)});

	##-- token: rewrite: lts
	foreach $anod (@{ $rwnod->findnodes("./$fmt->{ltsElt}/$fmt->{ltsAnalysisElt}") }) {
	  #$rw->{lts} = [] if (!$rw->{lts});
	  push(@{$rw->{lts}}, $a={});
	  @$a{qw(lo hi w)} = map {$anod->getAttribute($_)} @$fmt{qw(ltsLoAttr ltsHiAttr ltsWeightAttr)};
	  delete(@$a{grep {!defined($a->{$_})} keys(%$a)});
	}

        ##-- token: rewrite: morph
	foreach $anod (@{ $rwnod->findnodes("./$fmt->{morphElt}/$fmt->{morphAnalysisElt}") }) {
	  #$rw->{morph} = [] if (!$rw->{morph});
	  push(@{$rw->{morph}}, $a={});
	  @$a{qw(lo hi w)} = map {$anod->getAttribute($_)} @$fmt{qw(morphLoAttr morphHiAttr morphWeightAttr)};
	  delete(@$a{grep {!defined($a->{$_})} keys(%$a)});
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
##  + if $tok has a key '_xmlnod', that node is modified in-place!
sub tokenNode {
  my ($fmt,$tok) = @_;
  $tok = toToken($tok);

  ##-- token: node, text
  my $nod = $tok->{_xmlnod} || XML::LibXML::Element->new($fmt->{tokenElt});
  $nod->setAttribute($fmt->{tokenTextAttr},$tok->{text});

  ##-- common variables
  my ($anod, $aa,$aanod, $rwnod,$rwanod,$rwa);

  ##-- token: loc
  if (defined($tok->{loc}) && $fmt->{tokenLocAttr}) {
    $nod->setAttribute($fmt->{tokenLocAttr}, "$tok->{loc}{off} $tok->{loc}{len}");
  }

  ##-- token: xlit
  if (defined($tok->{xlit}) && $fmt->{xlitElt}) {
    $nod->removeChild($_) foreach (@{$nod->findnodes("./$fmt->{xlitElt}")});
    $anod = $nod->addNewChild(undef, $fmt->{xlitElt});
    $anod->setAttribute($fmt->{xlitTextAttr}, $tok->{xlit}{latin1Text}) if ($fmt->{xlitTextAttr});
    $anod->setAttribute($fmt->{xlitIsLatin1Attr}, $tok->{xlit}{isLatin1}) if ($fmt->{xlitIsLatin1Attr});
    $anod->setAttribute($fmt->{xlitIsLatinExtAttr}, $tok->{xlit}{isLatinExt}) if ($fmt->{xlitIsLatinExtAttr});
  }

  ##-- token: lts
  if ($tok->{lts} && $fmt->{ltsElt}) {
    $nod->removeChild($_) foreach (@{$nod->findnodes("./$fmt->{ltsElt}")});
    $anod = $nod->addNewChild(undef, $fmt->{ltsElt});
    foreach $aa (@{$tok->{lts}}) {
      $aanod = $anod->addNewChild(undef, $fmt->{ltsAnalysisElt});
      $aanod->setAttribute($fmt->{ltsLoAttr},$aa->{lo})    if ($fmt->{ltsLoAttr} && defined($aa->{lo}));
      $aanod->setAttribute($fmt->{ltsHiAttr},$aa->{hi})    if ($fmt->{ltsHiAttr} && defined($aa->{hi}));
      $aanod->setAttribute($fmt->{ltsWeightAttr},$aa->{w}) if ($fmt->{ltsWeightAttr} && defined($aa->{w}));
    }
  }

  ##-- token: eqpho
  if ($tok->{eqpho} && $fmt->{eqphoElt}) {
    $nod->removeChild($_) foreach (@{$nod->findnodes("./$fmt->{eqphoElt}")});
    $anod = $nod->addNewChild(undef, $fmt->{eqphoElt});
    foreach $aa (@{$tok->{eqpho}}) {
      $aanod = $anod->addNewChild(undef, $fmt->{eqphoAnalysisElt});
      $aanod->setAttribute($fmt->{eqphoTextAttr},$aa) if ($fmt->{eqphoTextAttr} && defined($aa));
    }
  }

  ##-- token: morph
  if ($tok->{morph} && $fmt->{morphElt}) {
    $nod->removeChild($_) foreach (@{$nod->findnodes("./$fmt->{morphElt}")});
    $anod = $nod->addNewChild(undef, $fmt->{morphElt});
    foreach $aa (@{$tok->{morph}}) {
      $aanod = $anod->addNewChild(undef, $fmt->{morphAnalysisElt});
      $aanod->setAttribute($fmt->{morphLoAttr},$aa->{lo})    if ($fmt->{morphLoAttr} && defined($aa->{lo}));
      $aanod->setAttribute($fmt->{morphHiAttr},$aa->{hi})    if ($fmt->{morphHiAttr} && defined($aa->{hi}));
      $aanod->setAttribute($fmt->{morphWeightAttr},$aa->{w}) if ($fmt->{morphWeightAttr} && defined($aa->{w}));
    }
  }

  ##-- token: msafe
  if (exists($tok->{msafe}) && $fmt->{msafeElt}) {
    $nod->removeChild($_) foreach (@{$nod->findnodes("./$fmt->{msafeElt}")});
    $anod = $nod->addNewChild(undef,$fmt->{msafeElt});
    $anod->setAttribute($fmt->{msafeAttr}, $tok->{msafe} ? 1 : 0);
  }

  ##-- token: rewrites
  if ($tok->{rw} && $fmt->{rwElt}) {
    $nod->removeChild($_) foreach (@{$nod->findnodes("./$fmt->{rwElt}")});
    $rwnod = $nod->addNewChild(undef,$fmt->{rwElt});
    foreach $rwa (@{$tok->{rw}}) {
      $rwanod = $rwnod->addNewChild(undef,$fmt->{rwAnalysisElt});
      $rwanod->setAttribute($fmt->{rwLoAttr},$rwa->{lo})    if ($fmt->{rwLoAttr} && defined($rwa->{lo}));
      $rwanod->setAttribute($fmt->{rwHiAttr},$rwa->{hi})    if ($fmt->{rwHiAttr} && defined($rwa->{hi}));
      $rwanod->setAttribute($fmt->{rwWeightAttr},$rwa->{w}) if ($fmt->{rwWeightAttr} && defined($rwa->{w}));

      ##-- token: rewrite: lts
      if ($rwa->{lts} && $fmt->{ltsElt}) {
	$anod = $rwanod->addNewChild(undef, $fmt->{ltsElt});
	foreach $aa (@{$rwa->{lts}}) {
	  $aanod = $anod->addNewChild(undef, $fmt->{ltsAnalysisElt});
	  $aanod->setAttribute($fmt->{ltsLoAttr},$aa->{lo})    if ($fmt->{ltsLoAttr} && defined($aa->{lo}));
	  $aanod->setAttribute($fmt->{ltsHiAttr},$aa->{hi})    if ($fmt->{ltsHiAttr} && defined($aa->{hi}));
	  $aanod->setAttribute($fmt->{ltsWeightAttr},$aa->{w}) if ($fmt->{ltsWeightAttr} && defined($aa->{w}));
	}
      }

      ##-- token: rewrite: morph
      if ($rwa->{morph} && $fmt->{morphElt}) {
	$anod = $rwanod->addNewChild(undef, $fmt->{morphElt});
	foreach $aa (@{$rwa->{morph}}) {
	  $aanod = $anod->addNewChild(undef, $fmt->{morphAnalysisElt});
	  $aanod->setAttribute($fmt->{morphLoAttr},$aa->{lo})    if ($fmt->{morphLoAttr} && defined($aa->{lo}));
	  $aanod->setAttribute($fmt->{morphHiAttr},$aa->{hi})    if ($fmt->{morphHiAttr} && defined($aa->{hi}));
	  $aanod->setAttribute($fmt->{morphWeightAttr},$aa->{w}) if ($fmt->{morphWeightAttr} && defined($aa->{w}));
	}
      }
    }
  }

  ##-- done
  return $nod;
}

## $xmlnod = $fmt->sentenceNode($sent)
##  + uses $sent->{_xmlnod} if present
sub sentenceNode {
  my ($fmt,$sent) = @_;
  $sent = toSentence($sent);

  my $snod   = $sent->{_xmlnod} || XML::LibXML::Element->new($fmt->{sentenceElt});
  my $sowner = $snod->getOwner;
  foreach (@{$sent->{tokens}}) {
    if ($_->{_xmlnod} && $_->{_xmlnod}->getOwner->isSameNode($sowner)) {
      ##-- in-place
      $fmt->tokenNode($_);
    } else {
      ##-- copy or generate
      $snod->addChild($fmt->tokenNode($_));
    }
  }

  return $snod;
}

## $xmlnod = $fmt->documentNode($doc)
##  + uses $doc->{_xmlnod} if present
sub documentNode {
  my ($fmt,$doc) = @_;
  $doc = toDocument($doc);

  my $docnod   = $doc->{_xmlnod} || XML::LibXML::Element->new($fmt->{documentElt});
  my $docowner = $docnod->getOwner;
  foreach (@{$doc->{body}}) {
    if ($_->{_xmlnod} && $_->{_xmlnod}->getOwner->isSameNode($docowner)) {
      ##-- in-place
      $fmt->sentenceNode($_);
    } else {
      ##-- copy or generate
      $docnod->addChild($fmt->sentenceNode($_));
    }
  }

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
  return $fmt->xmlRootNode($fmt->{documentElt});
}

## $sentnod = $fmt->xmlSentenceNode()
sub xmlSentenceNode {
  my $fmt = shift;
  my $body = $fmt->xmlBodyNode();
  my ($snod) = $body->findnodes(".//$fmt->{sentenceElt}\[last()]");
  return $snod if (defined($snod));
  return $body->addNewChild(undef,$fmt->{sentenceElt});
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
  my $docnod = $fmt->documentNode($doc); ##-- respects in-place processing
  my ($xdoc,$root);
  if (!defined($xdoc=$fmt->{xdoc}) || !defined($root=$fmt->{xdoc}->documentElement)) {
    if (defined($doc->{_xmldoc})) {
      ##-- in-place on document
      $xdoc = $fmt->{xdoc} = $doc->{_xmldoc};
    } else {
      ##-- in-place on doc node
      $xdoc = $fmt->{xdoc} = $fmt->xmlDocument() if (!$fmt->{xdoc});
      $xdoc->setDocumentElement($docnod);
    }
  } else {
    ##-- append-mode for real or converted input
    if ($root->nodeName ne $fmt->{multidocElt}) {
      my $oldroot = $root;
      $root = $xdoc->createElement($fmt->{multidocElt});
      $root->addChild($oldroot);
      $xdoc->setDocumentElement($root);
    }
    $root->appendChild($docnod); ##-- use appendChild() since we might need to import/copy
  }

  return $fmt;
}

##========================================================================
## package DTA::CAB::Format::Xml : alias for 'XmlNative'
package DTA::CAB::Format::Xml;
use strict;
use base qw(DTA::CAB::Format::XmlNative);


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
 $sentnod = $fmt->xmlSentenceNode();
 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putSentence($sent);
 $fmt = $fmt->putDocument($doc);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

"Native" XML datum parser|formatter class.
Should be compatible with C<.t.xml> files
as created by L<dta-tokwrap.perl(1)|dta-tokwrap.perl>.

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
 multidocElt      => $eltName,    ##-- default: 'corpus'
 sentenceElt      => $eltName,    ##-- default: 's'
 tokenElt         => $eltName,    ##-- default: 'w'
 tokenTextAttr    => $attr,       ##-- default: 't'
 ##
 xlitElt          => $eltName,    ##-- default: 'xlit'
 xlitTextAttr     => $attr,       ##-- default: 't'
 xlitIsLatin1Attr => $attr,       ##-- default: 'isLatin1'
 xlitIsLatinExtAttr=>$attr,       ##-- default: 'isLatinExt'
 ##
 ltsElt           => $eltName,    ##-- default: 'lts'
 ltsAnalysisElt   => $eltName,    ##-- default: 'a'
 ltsLoAttr        => $attr,       ##-- default: 'lo'
 ltsHiAttr        => $attr,       ##-- default: 'hi'
 ltsWeightAttr    => $attr,       ##-- default: 'w'
 ##
 eqphoElt         => $eltName,    ##-- default: 'eqpho'
 eqphoAnalysisElt => $eltName,    ##-- default: 'a'
 eqphoTextAttr    => $attr,       ##-- default: 't'
 ##
 morphElt         => $eltName,    ##-- default: 'morph'
 morphAnalysisElt => $eltName,    ##-- default: 'a'
 morphLoAttr      => $attr,       ##-- default: 'lo'
 morphHiAttr      => $attr,       ##-- default: 'hi'
 morphWeightAttr  => $attr,       ##-- default: 'w'
 ##
 msafeElt         => $eltName,    ##-- default: 'msafe'
 msafeAttr        => $attrName,   ##-- defualt: 'safe'
 ##
 rwElt            => $eltName,    ##-- default: 'rewrite'
 rwAnalysisElt    => $eltName,    ##-- default: 'a'
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

Extra %$doc keys parsed:

 _xmldoc => $doc,              ##-- source XML::LibXML::Document
 _xmlnod => $node,             ##-- source XML::LibXML::Element

Extra %$sentence keys parsed:

 _xmlnod  => $node,            ##-- source XML::LibXML::Element

Extra %$token keys parsed:

 _xmlnod => $node,             ##-- source XML::LibXML::Element

These keys are handy for in-place processing of XML::LibXML::Document objects.
See the L<tokenNode()|/tokenNode>, L<sentenceNode()|/sentenceNode>, and L<documentNode|/documentNode()>
methods for more details.

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
If $tok has a key C<_xmlnod>, it is expected to contain an XML::LibXML::Element
object, which is modified in-place and returned by this method.
This is handy for passing through structure other than that explicitly handled by the DTA::CAB utilities.

=item sentenceNode

 $xmlnod = $fmt->sentenceNode($sent);

Returns an XML::LibXML::Node object representing the DTA::CAB::Sentence $sent.
If $sent has a key C<_xmlnod>, it is expected to contain an XML::LibXML::Element
object, which is modified in-place and returned by this method.

=item documentNode

 $xmlnod = $fmt->documentNode($doc);

Returns an XML::LibXML::Node object representing the DTA::CAB::Document $doc.
If $doc has a key C<_xmlnod>, it is expected to contain an XML::LibXML::Element
object, which B<may be> modified in-place and returned by this method.  Sometimes
$doc-E<gt>{_xmlnod} will be copied even if it is present, e.g.
if you're concatenating multiple source documents into a single output document,
mixing output APIs, or doing something else creative.

=item xmlBodyNode

 $bodynode = $fmt->xmlBodyNode();

Currently just an alias for
L<$fmt-E<gt>xmlRootNode($fmt-E<gt>{documentElt}))|DTA::CAB::Format::XmlCommon/xmlRootNode>.

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
  <s>
    <w t="wie">
      <xlit t="wie" isLatin1="1" isLatinExt="1"/>
      <lts>
        <a hi="vi" w="0"/>
      </lts>
      <eqpho>
        <a t="Wie"/>
        <a t="wie"/>
      </eqpho>
      <morph>
        <a hi="wie[_ADV]" w="0"/>
        <a hi="wie[_KON]" w="0"/>
        <a hi="wie[_KOKOM]" w="0"/>
        <a hi="wie[_KOUS]" w="0"/>
      </morph>
      <msafe safe="1"/>
    </w>
    <w t="oede">
      <xlit t="oede" isLatin1="1" isLatinExt="1"/>
      <lts>
        <a hi="?2de" w="0"/>
      </lts>
      <eqpho>
        <a t="Oede"/>
        <a t="Öde"/>
        <a t="öde"/>
      </eqpho>
      <msafe safe="0"/>
      <rewrite>
        <a hi="öde" w="1">
          <lts>
            <a hi="?2de" w="0"/>
          </lts>
          <morph>
            <a hi="öde[_ADJD]" w="0"/>
            <a hi="öde[_ADJA][pos][sg][nom]*[weak]" w="0"/>
            <a hi="öde[_ADJA][pos][sg][nom][fem][strong_mixed]" w="0"/>
            <a hi="öde[_ADJA][pos][sg][acc][fem]*" w="0"/>
            <a hi="öde[_ADJA][pos][sg][acc][neut][weak]" w="0"/>
            <a hi="öde[_ADJA][pos][pl][nom_acc]*[strong]" w="0"/>
            <a hi="öd~en[_VVFIN][first][sg][pres][ind]" w="0"/>
            <a hi="öd~en[_VVFIN][first][sg][pres][subjI]" w="0"/>
            <a hi="öd~en[_VVFIN][third][sg][pres][subjI]" w="0"/>
            <a hi="öd~en[_VVIMP][sg]" w="0"/>
          </morph>
        </a>
      </rewrite>
    </w>
    <w t="!">
      <xlit t="!" isLatin1="1" isLatinExt="1"/>
      <lts>
        <a hi="" w="0"/>
      </lts>
      <msafe safe="1"/>
    </w>
  </s>
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
