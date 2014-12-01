## -*- Mode: CPerl; coding: utf-8 -*-
##
## File: DTA::CAB::Format::TEIws.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: Datum parser|formatter: XML: TEI: with //w and //s elements, as output by DTA::TokWrap
##  + uses DTA::CAB::Format::XmlTokWrap for output

package DTA::CAB::Format::TEIws;
use DTA::CAB::Format::TEI;
use DTA::CAB::Datum ':all';
use DTA::CAB::Utils ':temp', ':libxml';
use DTA::TokWrap;
use DTA::TokWrap::Utils qw();
use File::Path;
use XML::LibXML;
use IO::File;
use Carp;
use utf8;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlTokWrap);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:(?:spliced|tei[\.\-\+]?ws?|wst?)[\.\-]xml)$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_)
      foreach (qw(tei-ws tei+ws tei+w tei-w teiw wst-xml wstxml teiws-xml));
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
##     ##-- new in Format::TEIws
##     spliceback => $bool,                    ##-- (output) if true (default), return .cws.cab.xml ; otherwise just .cab.t.xml [requires doc 'teibufr' attribute]
##     teibufr => \$buf,                       ##-- tei+ws buffer, for spliceback mode
##     teidoc => $doc,			       ##-- tei+ws XML::LibXML::Document
##     spliceopts => \%opts,		       ##-- options for DTA::ToKWrap::Processor::idsplice::new()
##
##     ##-- input: inherited from Format::XmlNative
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document (tokwrap syntax)
##     xprs => $xprs,                          ##-- XML::LibXML parser
##     parseXmlData => $bool,		       ##-- if true, _xmldata key will be parsed (default OVERRIDE=false)
##
##     ##-- output: inherited from Format::XmlTokWrap
##     arrayEltKeys => \%akey2ekey,            ##-- maps array keys to element keys for output
##     arrayImplicitKeys => \%akey2undef,      ##-- pseudo-hash of array keys NOT mapped to explicit elements
##     key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
##     xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
##     ##
##     ##-- output: inherited from Format::XmlNative
##     #encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common: safety
##     safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- defaults
			      spliceback => 1,
			      spliceopts => {soIgnoreAttrs=>[qw(xb c teitext teixp)]},

			      ##-- user args
			      @_
			     );

  #$fmt->{ignoreKeys}{'c'} = undef;
  $fmt->{parseXmlData} = 0 if (!exists($fmt->{parseXmlData})); ##-- ignore XML content

  if (0) {
    ##-- DEBUG: also consider setting $DTA::CAB::Logger::defaultLogOpts{twLevel}='TRACE', e.g. with '-lo twLevel=TRACE' on the command-line
    $fmt->{twopts}{$_} = 'DEBUG' foreach (qw(spliceInfo));
    $DTA::TokWrap::Utils::TRACE_RUNCMD = 'debug';
  }

  return $fmt;
}

##=============================================================================
## Methods: Generic

##=============================================================================
## Methods: Input

##--------------------------------------------------------------
## Methods: Input: Generic API

## $fmt = $fmt->close()
##  + close current input source, if any
sub close {
  my $fmt = shift;
  delete $fmt->{teidoc};
  return $fmt->SUPER::close(@_);
}

## $fmt = $fmt->fromString(\$string)
##  + select input from string $string
sub fromString {
  my $fmt = shift;
  my $str = ref($_[0]) ? $_[0] : \$_[0];
  $fmt->close();

  ##-- prepare & save tei buffer
  utf8::encode($$str) if (utf8::is_utf8($$str));
  $$str =~ s|(<[^>]*)\sxmlns=|$1 XMLNS=|g;  ##-- encode default namespaces so that XML::LibXML::Node::nodePath() works
  $fmt->{teibufr} = $str if ($fmt->{spliceback});

  ##-- load source xml to $fmt->{teidoc}
  $fmt->{teidoc} = $fmt->xmlparser()->parse_string($$str)
    or $fmt->logconfess("XML::LibXML::parse_string() failed: $!");

  return $fmt;
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + calls $fmt->fromFh()
sub fromFile {
  return $_[0]->DTA::CAB::Format::fromFile(@_[1..$#_]);
}

## $fmt = $fmt->fromFh($handle)
##  + just calls $fmt->fromString()
sub fromFh {
  return $_[0]->DTA::CAB::Format::fromFh_str(@_[1..$#_]);
}

## $doc = $fmt->parseDocument()
##  + parses buffered XML::LibXML::Document
##  + override inserts $doc->{teibufr} attribute for spliceback mode
sub parseDocument {
  my $fmt = shift;
  if (!defined($fmt->{teidoc})) {
    $fmt->logconfess("parseDocument(): no source document {teidoc} defined!");
    return undef;
  }
  my $teidoc = $fmt->{teidoc} or return undef;
  my $teiroot = $teidoc->documentElement or die("parseDocument(): no root element!");

  ##-- setup xpath context
  my $xc = libxml_xpcontext($teiroot);

  ##-- parse nodes
  my (@sids);
  my (%id2s,%id2w); ##-- %id2s->{$sid} = \%s ; %id2w->{$wid} = $w
  my (%id2prev,%id2next);
  my ($snod,$wnod,$sid,$wid,$s,$w, $si,$wi);
  foreach $snod (@{$xc->findnodes('//*[local-name()="s"]',$teiroot)}) {
    $sid = $snod->getAttribute('id') || $snod->getAttribute('xml:id') || ("teiws_s_".++$si);
    $s   = $id2s{$sid} = {(map {($_->name=>$_->value)} $snod->attributes), id=>$sid, teixp=>$snod->nodePath, wids=>[]};
    $id2prev{$sid} = $snod->getAttribute('prev') if ($snod->hasAttribute('prev'));
    $id2next{$sid} = $snod->getAttribute('next') if ($snod->hasAttribute('next'));
    foreach $wnod (@{$xc->findnodes('.//*[local-name()="w"]',$snod)}) {
      $wid = $wnod->getAttribute('id') || $wnod->getAttribute('xml:id') || ("teiws_w_".++$wi);
      $w   = $id2w{$wid} = $fmt->parseNode($wnod);
      @$w{qw(id teixp teitext)} = ($wid,$wnod->nodePath,$wnod->textContent);
      $id2prev{$wid} = $wnod->getAttribute('prev') if ($wnod->hasAttribute('prev'));
      $id2next{$wid} = $wnod->getAttribute('next') if ($wnod->hasAttribute('next'));
      push(@{$s->{wids}},$wid);
    }
    push(@sids,$sid);
  }

  ##-- construct output document, de-fragmenting as we go
  my @body = qw();
  my ($snxt,$wnxt,$tokens);
  foreach $sid (grep {!exists $id2prev{$_}} @sids) {
    push(@body, $s = $id2s{$sid});
    while (($sid=$id2next{$sid})) {
      $sid  =~ s/^\#//;
      $snxt = $id2s{$sid};
      $s->{teixp} .= "|$snxt->{teixp}";
      push(@{$s->{wids}},@{$snxt->{wids}});
    }
    $tokens = $s->{tokens} = [];
    foreach $wid (grep {!exists $id2prev{$_}} @{$s->{wids}}) {
      push(@$tokens, $w = $id2w{$wid});
      while (($wid=$id2next{$wid})) {
	$wid  =~ s/^\#//;
	$wnxt = $id2w{$wid};
	$w->{teitext} .= $wnxt->{teitext};
	$w->{teixp}  .= "|$wnxt->{teixp}";
      }
      delete @$w{qw(prev next part ref XMLNS)};
      if (0 && !defined($w->{text})) {
	##-- hack for tei without //w/@t or //w/@text: heuristically analyze raw text content
	($w->{text}=$w->{teitext}) =~ s/[\-¬⁊‒–—]?\s+["'«»٬ۥ‘’‚‛“”„‟′″]*//g;
      }
    }
    delete @$s{qw(wids prev next part ref XMLNS)};
  }

  ##-- finalize document
  my $doc = bless {(map {($_->name=>$_->value)} grep {$_->isa('XML::LibXML::Attr')} $teiroot->attributes), body=>\@body}, 'DTA::CAB::Document';
  $doc->{teibufr} = $fmt->{teibufr} if ($fmt->{spliceback});

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
  return 'teiws';
}

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format (default='.cab')
sub defaultExtension { return '.tei+ws.xml'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush any buffered output to selected output source
sub flush {
  my $fmt = shift;
  #$fmt->buf2fh(\$fmt->{outbuf}, $fmt->{fh}) if (defined($fmt->{outbuf}) && defined($fmt->{fh}));
  #$fmt->SUPER::flush(@_); ##-- not here, since this writes literal {xdoc} to the output file!
  $fmt->{fh}->flush() if (defined($fmt->{fh}));
  delete @$fmt{qw(outbuf xdoc teidoc)};
  return $fmt;
}

## $fmt = $fmt->toString(\$str)
## $fmt = $fmt->toString(\$str,$formatLevel)
##  + select output to byte-string
##  + override reverts to DTA::CAB::Format::toString()
sub toString {
  return $_[0]->DTA::CAB::Format::toString(@_[1..$#_]);
}

## $fmt_or_undef = $fmt->toFile($filename, $formatLevel)
##  + select output to $filename
##  + override reverts to DTA::CAB::Format::toFile()
sub toFile {
  return $_[0]->DTA::CAB::Format::toFile(@_[1..$#_]);
}

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + select output to filehandle $fh
##  + override reverts to DTA::CAB::Format::toFh()
sub toFh {
  return $_[0]->DTA::CAB::Format::toFh(@_[1..$#_]);
}

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putDocument($doc)
##  + override respects local 'keepc' and 'spliceback' flags
sub putDocument {
  my ($fmt,$doc) = @_;

  ##-- call superclass (XmlTokWrap) method
  my $rc = $fmt->DTA::CAB::Format::XmlTokWrap::putDocument($doc);
  if (!$fmt->{spliceback}) {
    $fmt->{xdoc}->toFH($fmt->{fh},($fmt->{level}||0));
    return $rc;
  }

  ##-- get original TEI-XML buffer
  my $teibufr = $doc->{teibufr} || $fmt->{teibufr};
  if (!defined($teibufr) || !$$teibufr) {
    $fmt->logwarn("spliceback mode requested but no 'teibufr' document property - using XmlTokWrap format");
    $fmt->{xdoc}->toFH($fmt->{fh},($fmt->{level}||0));
    return $rc;
  }
  $$teibufr =~ s|(<[^>]*)\sXMLNS=|$1 xmlns=|g; ##-- decode default namespaces (hack)

  ##-- splice in analysis data
  my $splicer = DTA::TokWrap::Processor::idsplice->new(%{$fmt->{spliceopts}||{}});
  my $sobuf   = $fmt->{xdoc}->toString(0);
  $splicer->splice_so(base=>$teibufr,so=>\$sobuf,out=>$fmt->{fh});

  return $fmt;
}





1; ##-- be happy

__END__
