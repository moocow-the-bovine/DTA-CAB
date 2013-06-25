## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TCF.pm
## Author: Bryan Jurish <jurish@bbaw.de>
## Description: Datum parser|formatter: XML: CLARIN-D TCF (selected features only)
##  + uses DTA::CAB::Format::XmlTokWrap for output

package DTA::CAB::Format::TCF;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Datum ':all';
#use DTA::CAB::Utils ':temp';
use XML::LibXML;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlCommon);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:(?:tcf[\.\-_]?xml)|(?:tcf))$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_)
      foreach (qw(tcf-xml tcfxml tcf));
}

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- new in TCF
##     tcfbufr => \$buf,                       ##-- raw TCF buffer, for spliceback mode
##     tcflog  => $level,		       ##-- debugging log-level (default: 'off')
##     spliceback => $bool,                    ##-- (output) if true (default), splice data back into 'tcfbufr' if available; otherwise create new TCF doc
##     tcflayers => $tcf_layer_names,          ##-- layer names to include, space-separated list; default='tokens sentences postags lemmas orthography'
##     tcftagset => $tagset,                   ##-- tagset name for POStags element (default='stts')
##
##     ##-- input: inherited from XmlCommon
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output: inherited from XmlCommon
##     level => $level,                        ##-- output formatting level (default=0)
##     output => [$how,$arg]                   ##-- either ['fh',$fh], ['file',$filename], or ['str',\$buf]
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- local
			      #tcfbufr => undef,
			      tcflog   => 'off', ##-- debugging log-level
			      tcflayers => 'tokens sentences orthography postags lemmas',
			      tcftagset => 'stts',
			      spliceback => 1,

			      ##-- overrides (XmlTokWrap, XmlNative, XmlCommon)
			      ignoreKeys => {
					     tcfbufr=>undef,
					     tcfdoc=>undef,
					    },

			      ##-- user args
			      @_
			     );

  return $fmt;
}

##=============================================================================
## Methods: Generic

##=============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Generic API

## $fmt = $fmt->close()
##  + close current input source, if any
##  + INHERITED from XmlCommon (calls flush())

## $fmt = $fmt->from(String|File|Fh)
##  + INHERITED from XmlCommon : populates $fmt->{xdoc}

## $doc = $fmt->parseDocument()
##  + parse buffered XML::LibXML::Document from $fmt->{xdoc}
sub parseDocument {
  my $fmt = shift;
  $fmt->vlog($fmt->{tcflog}, "parseDocument()");

  ##-- parse: basic
  my $doc   = DTA::CAB::Document->new();
  my $xdoc  = $fmt->{xdoc};
  my $xroot = $xdoc->documentElement;
  $doc->{tcfdoc} = $xdoc if ($fmt->{spliceback});

  ##-- parse: metadata
  if (defined(my $xmeta = $xroot->findnodes('*[local-name()="MetaData"]')->[0])) {
    my $tmp = $xmeta->findnodes('*[local-name()="source"][1]')->[0];
    $doc->{source} = $tmp->textContent if (defined($tmp));
  }

  ##-- parse: corpus
  my $xcorpus = $xroot->findnodes('*[local-name()="TextCorpus"]')->[0]
    or $fmt->logconfess("parseDocument(): no TextCorpus node found in XML document");

  ##-- parse: tokens
  my (@w,%id2w,$w);
  my $xtokens = $xcorpus->findnodes('*[local-name()="tokens"]')->[0]
    or $fmt->logconfess("parseDocument(): no TextCorpus/tokens node found in XML document");
  foreach (@{$xtokens->findnodes('*[local-name()="token"]')}) {
    push(@w, $w={text=>$_->textContent});
    if (!defined($w->{id}=$_->getAttribute('ID'))) {
      $w->{id} = sprintf("w%x", $#w);
      $_->setAttribute('ID'=>$w->{id});
    }
    $id2w{$w->{id}} = $w;
  }

  ##-- parse: sentences
  my ($s);
  if (defined(my $xsents = $xcorpus->findnodes('*[local-name()="sentences"]')->[0])) {
    my $body = $doc->{body};
    foreach (@{$xsents->findnodes('*[local-name()="sentence"]')}) {
      push(@$body, $s={});
      $s->{id}     = $_->getAttribute('ID') if ($_->hasAttribute('ID'));
      $s->{tokens} = [ @id2w{split(' ',$_->getAttribute('tokenIDs'))} ];
    }
  } else {
    $doc->{body} = \@w; ##-- single-sentence
  }

  ##-- parse: POStags -> moot/tag
  my ($id);
  if (defined(my $xpostags = $xcorpus->findnodes('*[local-name()="POStags"]')->[0])) {
    foreach (@{$xpostags->findnodes('*[local-name()="tag"]')}) {
      $id = $_->getAttribute('tokenIDs');
      $id2w{$id}{moot}{tag} = $_->textContent;
    }
  }

  ##-- parse: lemmas -> moot/lemma
  if (defined(my $xlemmas = $xcorpus->findnodes('*[local-name()="lemmas"]')->[0])) {
    foreach (@{$xlemmas->findnodes('*[local-name()="lemma"]')}) {
      $id = $_->getAttribute('tokenIDs');
      $id2w{$id}{moot}{lemma} = $_->textContent;
    }
  }

  ##-- parse: orthography -> moot/word
  if (defined(my $xorths = $xcorpus->findnodes('*[local-name()="orthography"]')->[0])) {
    foreach (@{$xorths->findnodes('*[local-name()="correction"][@operation="replace"]')}) {
      $id = $_->getAttribute('tokenIDs');
      $id2w{$id}{moot}{word} = $_->textContent;
    }
  }

  $fmt->vlog($fmt->{tcflog}, "parseDocument(): returning");
  return $doc;
}

##=============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME & HTTP stuff

## $short = $fmt->shortName()
##  + returns "official" short name for this format
##  + default just returns package suffix
sub shortName {
  return 'tcf';
}

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format (default='.cab')
sub defaultExtension { return '.tcf.xml'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush any buffered output to selected output source
sub flush {
  my $fmt = shift;
  $fmt->vlog($fmt->{tcflog}, "flush()") if (Log::Log4perl->initialized);
  $fmt->SUPER::flush(@_) || return undef;
  delete @$fmt{qw(tcfbufr tcfdoc outbufr)};
  return $fmt;
}

## $fmt = $fmt->to(String|File|Fh)
##  + INHERITED from XmlCommon : sets up $fmt->{output}=($outputHow,$outputArg)

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putDocument($doc)
##  + override respects local 'spliceback' and 'tcflayers' flags
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->vlog($fmt->{tcflog}, "putDocument()");

  ##-- common vars
  my $spliceback = $fmt->{spliceback};
  my $layers = $fmt->{tcflayers} // '';

  ##-- spliceback?
  my ($xdoc);
  if ($spliceback) {
    $xdoc = $doc->{tcfdoc} // $fmt->{tcfdoc};
    if (!$xdoc) {
      my $bufr = $doc->{tcfbufr} // $fmt->{tcfbufr};
      if (!$bufr || !$$bufr) {
	$fmt->logwarn("spliceback mode requested but no 'tcfdoc' or 'tcfbufr' document property - creating new document!");
	$spliceback = 0;
      }
    }
  }
  $xdoc //= XML::LibXML::Document->new("1.0","UTF-8");
  $fmt->{xdoc} = $xdoc;

  ##-- document structure: root
  my ($xroot);
  if (!defined($xroot = $xdoc->documentElement)) {
    $xdoc->setDocumentElement( $xroot = $xdoc->createElement('D-Spin') );
    $xroot->setNamespace('http://www.dspin.de/data');
    $xroot->setAttribute('version'=>'0.4');
  }

  ##-- document structure: metadata
  my ($xmeta);
  if (!defined($xmeta = $xroot->findnodes('*[local-name()="MetaData"]')->[0])) {
    $xmeta = $xroot->addNewChild(undef,'MetaData');
    $xmeta->setNamespace('http://www.dspin.de/data/metadata');
    $xmeta->appendTextChild('source', $doc->{source}) if (defined($doc->{source}));
  }

  ##-- document structure: corpus
  my ($xcorpus);
  if (!defined($xcorpus = $xroot->findnodes('*[local-name()="TextCorpus"]')->[0])) {
    $xcorpus = $xroot->addNewChild(undef,'TextCorpus');
    $xcorpus->setNamespace('http://www.dspin.de/data/textcorpus');
    $xcorpus->setAttribute('lang'=>'de');
  }

  ##-- document structure: corpus structure
  my ($tokens,$sents,$lemmas,$postags,$orths);
  if ($layers =~ /\btokens\b/ && !defined($xcorpus->findnodes('*[local-name()="tokens"]')->[0])) {
    $tokens = $xcorpus->addNewChild(undef,'tokens');
  }
  if ($layers =~ /\bsentences\b/ && !defined($xcorpus->findnodes('*[local-name()="sentences"]')->[0])) {
    $sents = $xcorpus->addNewChild(undef,'sentences');
  }
  if ($layers =~ /\blemmas\b/ && !defined($xcorpus->findnodes('*[local-name()="lemmas"]')->[0])) {
    $lemmas = $xcorpus->addNewChild(undef,'lemmas');
    #$lemmas->setAttribute('type'=>'CAB');
  }
  if ($layers =~ /\bpostags\b/ && !defined($xcorpus->findnodes('*[local-name()="POStags"]')->[0])) {
    $postags = $xcorpus->addNewChild(undef,'POStags');
    $postags->setAttribute('tagset'=>$fmt->{tcftagset}) if ($fmt->{tcftagset});
    #$postags->setAttribute('type'=>'CAB');
  }
  if ($layers =~ /\borthography\b/ && !defined($xcorpus->findnodes('*[local-name()="orthography"]')->[0])) {
    $orths = $xcorpus->addNewChild(undef,'orthography');
    #$orths->setAttribute('type'=>'CAB');
  }

  ##-- ensure ids
  my $wi = 0;
  my ($s,$w,$wid,@wids,$snod,$wnod);
  my ($pos,$lemma,$orth);
  foreach $s (@{$doc->{body}}) {
    @wids = qw();
    foreach $w (@{$s->{tokens}}) {
      $wid = $w->{id} // sprintf("w%x",$wi);
      push(@wids,$wid);
      ++$wi;

      ##-- generate token node: <token ID="t_0">Karin</token>
      if ($tokens) {
	$wnod = $tokens->addNewChild(undef,'token');
	$wnod->setAttribute(ID=>$wid);
	$wnod->appendText($w->{text});
      }

      ##-- generate token data: tag, lemma, orthography
      if ($w->{moot}) {
	$pos   = $w->{moot}{tag};
	$lemma = $w->{moot}{lemma};
	$orth  = $w->{moot}{word};
      }
      elsif ($w->{dmoot}) {
	$orth = $w->{dmoot}{tag};
      }
      $orth  //= $w->{exlex} // ($w->{xlit} && $w->{xlit}{isLatinExt} ? $w->{xlit}{latin1Text} : undef);

      if ($postags && defined($pos)) {
	##-- POStags: <tag ID="pt_0" tokenIDs="t_0">NE</tag>
	  $wnod = $postags->addNewChild(undef,'tag');
	  $wnod->setAttribute(tokenIDs=>$wid);
	  $wnod->appendText($pos);
	}
      if ($lemmas && defined($lemma)) {
	##-- lemmas: <lemma ID="le_0" tokenIDs="t_0">Karin</lemma>
	$wnod = $lemmas->addNewChild(undef,'lemma');
	$wnod->setAttribute(tokenIDs=>$wid);
	$wnod->appendText($lemma);
      }
      if ($orths && defined($orth) && $orth ne $w->{text}) {
	##-- orthography: <correction operation="replace" tokenIDs="t_0">Karina</correction>
	$wnod = $orths->addNewChild(undef,'correction');
	$wnod->setAttribute(tokenIDs=>$wid);
	$wnod->setAttribute(operation=>'replace'); ##-- "norm" would be better, but isn't allowed
	$wnod->appendText($orth);
      }
    }

    if ($sents) {
      ##-- generate sentence node: <sentence ID="s_0" tokenIDs="t_0 t_1 t_2 t_3 t_4 t_5"></sentence>
      $snod = $sents->addNewChild(undef,'sentence');
      $snod->setAttribute(ID=>$s->{id}) if (defined($s->{id}));
      $snod->setAttribute(tokenIDs=>join(' ',@wids));
    }
  }

  $fmt->vlog($fmt->{tcflog}, "putDocument(): returning");
  return $fmt;
}





1; ##-- be happy

__END__
