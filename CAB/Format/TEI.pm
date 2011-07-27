## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TEI.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: XML: TEI (with or without //c elements), using DTA::TokWrap
##  + uses DTA::CAB::Format::XmlTokWrap for output

package DTA::CAB::Format::TEI;
use DTA::CAB::Format::XmlTokWrap;
use DTA::CAB::Datum ':all';
use DTA::CAB::Utils ':temp';
use DTA::TokWrap;
use DTA::TokWrap::Utils qw();
use File::Path;
use XML::LibXML;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlTokWrap);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:(?:c|chr|txt|tei)\.xml)$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_)
      foreach (qw(c-xml cxml tei-xml teixml tei));
}

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
}

##-- HACK for broken tokenizer on services.dwds.de (2011-07-27)
$DTA::TokWrap::Document::TOKENIZE_CLASS = 'http';

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- new in TEI
##     tmpdir => $dir,                         ##-- temporary directory for this object (default: new)
##     keeptmp => $bool,                       ##-- keep temporary directory open
##     addc => $bool_or_guess,                 ##-- (input) whether to add //c elements (slow no-op if already present; default='guess')
##     spliceback => $bool,                    ##-- (output) if true (default), return .cws.cab.xml ; otherwise just .cab.t.xml [requires doc 'teibufr' attribute]
##     keepc => $bool,                         ##-- (output) whether to include //c elements in spliceback-mode output (default=0)
##     tw => $tw,                              ##-- underlying DTA::TokWrap object
##     twopen => \%opts,                       ##-- options for $tw->open()
##     teibufr => \$buf,                       ##-- raw tei+c buffer, for spliceback mode
##
##     ##-- input: inherited from XmlNative
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output: inherited from XmlTokWrap
##     arrayEltKeys => \%akey2ekey,            ##-- maps array keys to element keys for output
##     arrayImplicitKeys => \%akey2undef,      ##-- pseudo-hash of array keys NOT mapped to explicit elements
##     key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
##     xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
##     ##
##     ##-- output: inherited from XmlNative
##     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common: safety
##     safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- local
			      tmpdir => undef,
			      keeptmp=>0,
			      ##
			      addc => 'guess',
			      keepc => 0,
			      spliceback => 1,

			      ##-- tokwrap
			      tw => undef,
			      twopen => {},

			      ##-- overrides (XmlTokWrap, XmlNative, XmlCommon)
			      ignoreKeys => {
					     teibufr=>undef,
					    },

			      ##-- user args
			      @_
			     );

  ##-- temp dir
  my $tmpdir = $fmt->{tmpdir};
  $tmpdir    = $fmt->{tmpdir} = mktmpfsdir("cab_tei_XXXX", CLEAN=>(!$fmt->{keeptmp}))
    if (!defined($tmpdir));

  ##-- TokWrap object
  my $tw = $fmt->{tw};
  if (!defined($tw)) {
    $tw = $fmt->{tw} = DTA::TokWrap->new();
  }
  $tw->{keeptmp} = $fmt->{keeptmp};
  $tw->{tmpdir}  = $tw->{outdir} = $fmt->{tmpdir};
  $tw->init();

  return $fmt;
}

## $fmt->DESTROY()
##  + destructor implicitly calls $fmt->rmtmpdir()
sub DESTROY {
  my $fmt = shift;
  $fmt->rmtmpdir();
  $fmt->SUPER::DESTROY();
}


##=============================================================================
## Methods: Generic

## $dir = $fmt->tmpdir()
sub tmpdir {
  return $_[0]{tmpdir};
}

## $tmpdir = $fmt->mktmpdir()
##  + ensures $fmt->{tmpdir} exists
sub mktmpdir {
  my $fmt = shift;
  my $tmpdir = $fmt->{tmpdir};
  mkdir($tmpdir,0700) if (!-d $tmpdir);
  (-d $tmpdir) or $fmt->logconfess("could not create directory '$tmpdir': $!");
  return $tmpdir;
}

## $fmt = $fmt->rmtmpdir()
##  + removes $fmt->{tmpdir} unless $fmt->{keeptmp} is true
sub rmtmpdir {
  my $fmt = shift;
  if (-d $fmt->{tmpdir} && !$fmt->{keeptmp}) {
    File::Path::rmtree($fmt->{tmpdir})
	or $fmt->logconfess("could not rmtree() temp directory '$fmt->{tmpdir}': $!");
  }
  return $fmt;
}

##=============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Generic API

## $fmt = $fmt->close()
##  + close current input source, if any
sub close {
  my $fmt = shift;
  $fmt->{twdoc}->close() if ($fmt->{twdoc});
  delete $fmt->{teibufr};
  $fmt->rmtmpdir();
  return $fmt->SUPER::close();
}

## $doc = $fmt->parseDocument()
##  + parses buffered XML::LibXML::Document
##  + INHERITED from Format::XmlTokWrap

## $fmt = $fmt->fromString($string)
##  + select input from string $string
sub fromString {
  my ($fmt,$str) = @_;
  $fmt->close();

  ##-- ensure tmpdir exists
  my $tmpdir = $fmt->mktmpdir;

  ##-- prepare tei buffer with //c elements
  $str = encode_utf8($str) if (utf8::is_utf8($str));

  if (!$fmt->{addc}) {
    ##-- dump document with predefined //c elements
    DTA::TokWrap::Utils::ref2file(\$str,"$tmpdir/tmp.chr.xml")
	or $fmt->logdie("couldn't create temporary file $tmpdir/tmp.chr.xml: $!");
    $fmt->{teibufr} = \$str if ($fmt->{spliceback});
  }
  else {
    ##-- dump raw document
    DTA::TokWrap::Utils::ref2file(\$str,"$tmpdir/tmp.raw.xml")
	or $fmt->logdie("couldn't create temporary file $tmpdir/tmp.raw.xml: $!");

    ##-- ensure //c elements
    my $addc_args = $fmt->{addc} eq 'guess' ? '-guess' : '-noguess';
    DTA::TokWrap::Utils::runcmd("dtatw-add-c.perl $addc_args $tmpdir/tmp.raw.xml > $tmpdir/tmp.chr.xml")==0
	or $fmt->logdie("dtatw-add-c.perl failed: $!");

    ##-- grab tei buffer
    $fmt->{teibufr} = DTA::TokWrap::Utils::slurp_file("$tmpdir/tmp.chr.xml")
      if ($fmt->{spliceback});
  }

  ##-- run tokwrap
  my $twdoc = $fmt->{tw}->open("$tmpdir/tmp.chr.xml",%{$fmt->{twopen}||{}})
    or $fmt->logdie("could not open $tmpdir/tmp.chr.xml as TokWrap document: $!");
  $twdoc->genKey('all')
    or $fmt->logdie("could generate $tmpdir/tmp.chr.t.xml with DTA::TokWrap: $!");
  $twdoc->close();

  ##-- now process the tokwrap document
  my $rc = $fmt->SUPER::fromFile("$tmpdir/tmp.chr.t.xml");

  ##-- ... and remove the temp dir
  $fmt->rmtmpdir();

  return $rc;
}


## $fmt = $fmt->fromFile($filename_or_handle)
##  + calls $fmt->fromFh()
sub fromFile {
  my $fmt = shift;
  return $fmt->DTA::CAB::Format::fromFile(@_);
}

## $fmt = $fmt->fromFh($handle)
##  + just calls $fmt->fromString()
sub fromFh {
  my $fmt = shift;
  return $fmt->DTA::CAB::Format::fromFh(@_);
}

## $doc = $fmt->parseDocument()
##  + parses buffered XML::LibXML::Document
##  + override inserts $doc->{teibufr} attribute for spliceback mode
sub parseDocument {
  my $fmt = shift;
  my $doc = $fmt->SUPER::parseDocument(@_) or return undef;
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
  return 'tei';
}

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format (default='.cab')
sub defaultExtension { return '.tei.xml'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + override reverts to DTA::CAB::Format::toString()
sub toString {
  my $fmt = shift;
  return $fmt->DTA::CAB::Format::toString(@_);
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + override reverts to DTA::CAB::Format::toFile()
sub toFile {
  my $fmt = shift;
  return $fmt->DTA::CAB::Format::toFile(@_);
}

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + override reverts to DTA::CAB::Format::toFh()
sub toFh {
  my $fmt = shift;
  return $fmt->DTA::CAB::Format::toFh(@_);
}

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putDocument($doc)
##  + override respects local 'keepc' and 'spliceback' flags
sub putDocument {
  my ($fmt,$doc) = @_;

  ##-- call superclass method
  my $rc = $fmt->SUPER::putDocument($doc);
  return $rc if (!$fmt->{spliceback});

  ##-- get original TEI-XML buffer
  my $teibufr = $doc->{teibufr} || $fmt->{teibufr};
  if (!defined($teibufr) || !$$teibufr) {
    $fmt->logwarn("spliceback mode requested but no 'teibufr' document property - using XmlTokWrap format");
    return $rc;
  }

  ##-- get temp directory
  my $tmpdir = $fmt->mktmpdir();

  ##-- dump base data
  DTA::TokWrap::Utils::ref2file($teibufr,"$tmpdir/tmp.tei.xml")
      or $fmt->logconfess("couldn't create temporary file $tmpdir/tmp.tei.xml: $!");

  ##-- dump standoff data
  $fmt->{xdoc}->toFile("$tmpdir/tmp.cab.t.xml")
    or $fmt->logconfess("XML::Document::toFile() failed to $tmpdir/tmp.cab.t.xml: $!");

  ##-- splice in //w elements
  DTA::TokWrap::Utils::runcmd("dtatw-add-w.perl -q $tmpdir/tmp.tei.xml $tmpdir/tmp.cab.t.xml > $tmpdir/tmp.tei.tw0.xml")==0
      or $fmt->logdie("dtatw-add-w.perl failed: $!");

  ##-- optionally remove //c elements
  my $tw_xml = "$tmpdir/tmp.tei.tw0.xml";
  if (!$fmt->{keepc}) {
    DTA::TokWrap::Utils::runcmd("dtatw-rm-c.perl $tmpdir/tmp.tei.tw0.xml > $tmpdir/tmp.tei.tw1.xml")==0
	or $fmt->logdie("dtatw-rm-c.perl failed: $!");
    $tw_xml = "$tmpdir/tmp.tei.tw1.xml";
  }

  ##-- splice in //s elements
  DTA::TokWrap::Utils::runcmd("dtatw-add-s.perl -q $tw_xml $tmpdir/tmp.cab.t.xml > $tmpdir/tmp.tei.tws.xml")==0
      or $fmt->logdie("dtatw-add-s.perl failed: $!");

  ##-- splice in cab analysis data
  DTA::TokWrap::Utils::runcmd("dtatw-splice.perl -q $tmpdir/tmp.tei.tws.xml $tmpdir/tmp.cab.t.xml > $tmpdir/tmp.tei.spliced.xml")==0
      or $fmt->logdie("dtatw-splice.perl failed: $!");

  ##-- slurp in spliced-back output
  $fmt->{outbuf} = '';
  DTA::TokWrap::Utils::slurp_file("$tmpdir/tmp.tei.spliced.xml",\$fmt->{outbuf})
      or $fmt->logdie("could not slurp back spliced temp file '$tmpdir/tmp.tei.spliced.xml': $!");

  ##-- cleanup
  $fmt->rmtmpdir();

  return $fmt;
}





1; ##-- be happy

__END__
