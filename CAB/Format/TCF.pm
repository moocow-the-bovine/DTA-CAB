## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TCF.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: Datum parser|formatter: XML: CLARIN-D TCF (selected features only)
##  + uses DTA::CAB::Format::XmlTokWrap for output

package DTA::CAB::Format::TCF;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Format::Raw; ##-- for tcf text tokenization
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

  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_, opts=>{tcflayers=>'text'})
      foreach (qw(tcf-text tcf+text));
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_, opts=>{tcflayers=>'text tokens sentences'})
      foreach (qw(tcf-tok tcf+tok));
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_, opts=>{tcflayers=>'tokens sentences orthography'})
      foreach (qw(tcf-orth tcf+orth tcf-web)); ##-- for weblicht
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_, opts=>{tcflayers=>'tokens sentences orthography postags lemmas'})
      foreach (qw(tcf tcf-xml tcfxml full-tcf xtcf));

  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_, opts=>{tcflayers=>'tei text'})
      foreach (qw(tcf-tei-text tcf-tei+text tcf+tei+text));
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_, opts=>{tcflayers=>'tei text tokens sentences'})
      foreach (qw(tcf-tei-tok tcf-tei+tok tcf+tei+tok));
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
##     textbufr => \$text,                     ##-- raw text buffer, for spliceback mode
##     tcflog  => $level,		       ##-- debugging log-level (default: 'off')
##     spliceback => $bool,                    ##-- (output) if true (default), splice data back into 'tcfbufr' if available; otherwise create new TCF doc
##     tcflayers => $tcf_layer_names,          ##-- layer names to include, space-separated list; known='tei text tokens sentences postags lemmas orthography'
##     tcftagset => $tagset,                   ##-- tagset name for POStags element (default='stts')
##     logsplice => $level,		       ##-- log level for spliceback messages (default:'none')
##     trimtext => $bool,                      ##-- if true (default), waste tokenizer hints will be trimmed from 'text' layer
##
##     ##-- input: inherited from XmlCommon
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output: inherited from XmlCommon
##     level => $level,                        ##-- output formatting level (OVERRIDE: default=1)
##     output => [$how,$arg]                   ##-- either ['fh',$fh], ['file',$filename], or ['str',\$buf]
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- local
			      #tcfbufr => undef,
			      tcflog   => 'off', ##-- debugging log-level
			      #tcflayers => 'tei text tokens sentences orthography postags lemmas',
			      tcflayers => 'tokens sentences orthography',
			      tcftagset => 'stts',
			      spliceback => 1,
			      logsplice => 'none',
			      trimtext => 1,

			      ##-- overrides (XmlTokWrap, XmlNative, XmlCommon)
			      ignoreKeys => {
					     tcfbufr=>undef,
					     textbufr=>undef,
					     tcfdoc=>undef,
					    },
			      xprsopts => {keep_blanks=>0},
			      level => 1,

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
  if (defined(my $xmeta = [$xroot->getChildrenByLocalName("MetaData")]->[0])) {
    my ($xsrc) = $xmeta->getChildrenByLocalName('source');
    $doc->{source} = $xsrc->textContent if (defined($xsrc));
  }

  ##-- parse: corpus
  my $xcorpus = [$xroot->getChildrenByLocalName('TextCorpus')]->[0]
    or $fmt->logconfess("parseDocument(): no TextCorpus node found in XML document");

  ##-- parse: text (textbufr)
  ## + annoying hack: we grep for elements here b/c libxml getChildrenByLocalName('text') also returns text-nodes!
  my ($xtext) = grep {UNIVERSAL::isa($_,'XML::LibXML::Element')} $xcorpus->getChildrenByLocalName('text');
  if ($xtext) {
    my $textbuf = $xtext->textContent;
    $doc->{textbufr} = \$textbuf;
  }

  ##-- check for pre-tokenized input
  if (defined(my $xtokens = [$xcorpus->getChildrenByLocalName('tokens')]->[0])) {
    ##------------ pre-tokenized input
    ##-- parse: tokens
    my (@w,%id2w,$w);
    foreach ($xtokens->getChildrenByLocalName('token')) {
      push(@w, $w={text=>$_->textContent});
      if (!defined($w->{id}=$_->getAttribute('ID'))) {
	$w->{id} = sprintf("w%x", $#w);
	$_->setAttribute('ID'=>$w->{id});
      }
      $id2w{$w->{id}} = $w;
    }

    ##-- parse: sentences
    my ($s);
    if (defined(my $xsents = [$xcorpus->getChildrenByLocalName('sentences')]->[0])) {
      my $body = $doc->{body};
      foreach ($xtokens->getChildrenByLocalName('sentence')) {
	push(@$body, $s={});
	$s->{id}     = $_->getAttribute('ID') if ($_->hasAttribute('ID'));
	$s->{tokens} = [ @id2w{split(' ',$_->getAttribute('tokenIDs'))} ];
      }
    } else {
      $doc->{body} = \@w; ##-- single-sentence
    }

    ##-- parse: POStags -> moot/tag
    my ($id);
    if (defined(my $xpostags = [$xcorpus->getChildrenByLocalName('POStags')]->[0])) {
      foreach ($xpostags->getChildrenByLocalName('tag')) {
	$id = $_->getAttribute('tokenIDs');
	$id2w{$id}{moot}{tag} = $_->textContent;
      }
    }

    ##-- parse: lemmas -> moot/lemma
    if (defined(my $xlemmas = [$xcorpus->getChildrenByLocalName('lemmas')]->[0])) {
      foreach ($xlemmas->getChildrenByLocalName('lemma')) {
	$id = $_->getAttribute('tokenIDs');
	$id2w{$id}{moot}{lemma} = $_->textContent;
      }
    }

    ##-- parse: orthography -> moot/word
    if (defined(my $xorths = [$xcorpus->getChildrenByLocalName('orthography')]->[0])) {
      foreach (grep {($_->getAttribute('operation')//'') eq 'replace'} $xorths->getChildrenByLocalName('correction')) {
	$id = $_->getAttribute('tokenIDs');
	$id2w{$id}{moot}{word} = $_->textContent;
      }
    }
  }
  elsif ($doc->{textbufr}) {
    ##------------ un-tokenized input
    my $rawfmt = DTA::CAB::Format::Raw->new();
    my $rawdoc = DTA::CAB::Format::Raw->new->parseString( ${$doc->{textbufr}} );
    $doc->{body} = $rawdoc->{body};
  }
  else {
    ##------------ no source
    $fmt->logconfess("parseDocument(): no TextCorpus/text or TextCorpus/tokens node found in XML document");
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

## $type = $fmt->mimeType()
##  + override returns text/xml
sub mimeType { return 'text/tcf+xml'; }

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
	$fmt->vlog($fmt->{logsplice}, "spliceback mode requested but no 'tcfdoc' or 'tcfbufr' document property - creating new document!");
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
  my ($xmeta) = $xroot->getChildrenByLocalName('MetaData');
  if (!defined($xmeta)) {
    $xmeta = $xroot->addNewChild(undef,'MetaData');
    $xmeta->setNamespace('http://www.dspin.de/data/metadata');
    $xmeta->appendTextChild('source', $doc->{source}) if (defined($doc->{source}));
  }

  ##-- document structure: corpus
  my ($xcorpus) = $xroot->getChildrenByLocalName('TextCorpus');
  if (!defined($xcorpus)) {
    $xcorpus = $xroot->addNewChild(undef,'TextCorpus');
    $xcorpus->setNamespace('http://www.dspin.de/data/textcorpus');
    $xcorpus->setAttribute('lang'=>'de');
  }

  ##-- document structure: TextCorpus/tei
  if ($layers =~ /\btei\b/ && defined($doc->{teibufr})) {
    my ($xtei) = $xcorpus->getChildrenByLocalName("tei");
    if (!defined($xtei)) {
      $xtei = $xcorpus->addNewChild(undef,'tei');
      #$teinod->setAttribute('type'=>'text/tei+xml');
      $xtei->appendText(${$doc->{teibufr}});
    }
  }

  ##-- document structure: TextCorpus/text
  if ($layers =~ /\btext\b/) {
    ##-- annoying hack: we grep for elements here b/c libxml getChildrenByLocalName('text') also returns text-nodes!
    my ($xtext) = grep {UNIVERSAL::isa($_,'XML::LibXML::Element')} $xcorpus->getChildrenByLocalName('text');
    if (!defined($xtext)) {
      $xtext = $xcorpus->addNewChild(undef,'text');
      if (defined($doc->{textbufr})) {
	##-- use doc-buffered text content
	my $txt = ${$doc->{textbufr}};
	$txt =~ s/\s*\$WB\$\s*/ /sg;
	$txt =~ s/\s*\$SB\$\s*/\n\n/sg;
	$txt =~ s/%%[^%]*%%//sg;
	$xtext->appendText($txt);
      }
      else {
	##-- generate dummy text content
	$xtext->appendText(join(' ', map {$_->{text}} @{$_->{tokens}})."\n") foreach (@{$doc->{body}});
      }
    }
  }

  ##-- document structure: corpus structure
  my ($tokens,$sents,$lemmas,$postags,$orths);
  if ($layers =~ /\btokens\b/ && !$xcorpus->getChildrenByLocalName('tokens')) {
    $tokens = $xcorpus->addNewChild(undef,'tokens');
  }
  if ($layers =~ /\bsentences\b/ && !$xcorpus->getChildrenByLocalName('sentences')) {
    $sents = $xcorpus->addNewChild(undef,'sentences');
  }
  if ($layers =~ /\blemmas\b/ && !$xcorpus->getChildrenByLocalName('lemmas')) {
    $lemmas = $xcorpus->addNewChild(undef,'lemmas');
    #$lemmas->setAttribute('type'=>'CAB');
  }
  if ($layers =~ /\bpostags\b/ && !$xcorpus->getChildrenByLocalName('POStags')) {
    $postags = $xcorpus->addNewChild(undef,'POStags');
    $postags->setAttribute('tagset'=>$fmt->{tcftagset}) if ($fmt->{tcftagset});
    #$postags->setAttribute('type'=>'CAB');
  }
  if ($layers =~ /\borthography\b/ && !$xcorpus->getChildrenByLocalName('orthography')) {
    $orths = $xcorpus->addNewChild(undef,'orthography');
    #$orths->setAttribute('type'=>'CAB');
  }

  ##-- ensure ids
  my $wi = 0;
  my $si = 0;
  my ($s,$w,$wid,@wids,$snod,$wnod);
  my ($pos,$lemma,$orth);
  foreach $s (@{$doc->{body}}) {
    @wids = qw();
    foreach $w (@{$s->{tokens}}) {
      $wid = $w->{id} // sprintf("w%x",$wi);
      push(@wids,$wid);
      ++$wi;
      ++$si;

      ##-- generate token node: <token ID="t_0">Karin</token>
      if ($tokens) {
	$wnod = $tokens->addNewChild(undef,'token');
	$wnod->setAttribute(ID=>$wid);
	$wnod->appendText($w->{text});
      }

      ##-- generate token data: tag, lemma, orthography
      $pos = $lemma = $orth = undef;
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
      $snod->setAttribute(ID=>(defined($s->{id}) ? $s->{id}) : sprintf("s%s",$si)));
      $snod->setAttribute(tokenIDs=>join(' ',@wids));
    }
  }

  $fmt->vlog($fmt->{tcflog}, "putDocument(): returning");
  return $fmt;
}

1; ##-- be happy

__END__
