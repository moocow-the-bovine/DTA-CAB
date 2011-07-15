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

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- new in TEI
##     tmpdir => $dir,                         ##-- temporary directory for this object (default: new)
##     keeptmp => $bool,                       ##-- keep temporary directory open
##     tw => $tw,                              ##-- underlying DTA::TokWrap object
##     twopen => \%opts,                       ##-- options for $tw->open()
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

			      ##-- tokwrap
			      tw => undef,
			      twopen => {},

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

##=============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Local

## $dir = $fmt->tmpdir()
sub tmpdir {
  return $_[0]{tmpdir};
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $fmt = $fmt->close()
##  + close current input source, if any
sub close {
  my $fmt = shift;
  $fmt->{tw}->close($fmt->{twdoc}) if ($fmt->{twdoc});
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
  my $tmpdir = $fmt->tmpdir();
  mkdir($tmpdir,0700) if (!-d $tmpdir);

  ##-- dump raw document string to tmpdir
  $str = encode_utf8($str) if (utf8::is_utf8($str));
  DTA::TokWrap::Utils::ref2file(\$str,"$tmpdir/tmp.raw.xml")
      or $fmt->logdie("couldn't create temporary file $tmpdir/tmp.raw.xml: $!");

  ##-- remove any //c elements
  DTA::TokWrap::Utils::runcmd("dtatw-rm-c.perl $tmpdir/tmp.raw.xml > $tmpdir/tmp.noc.xml")==0
      or $fmt->logdie("dtatw-rm-c.perl failed: $!");

  ##-- re-add //c elements
  DTA::TokWrap::Utils::runcmd("dtatw-add-c.perl $tmpdir/tmp.noc.xml > $tmpdir/tmp.chr.xml")==0
      or $fmt->logdie("dtatw-add-c.perl failed: $!");

  ##-- run tokwrap
  my $twdoc = $fmt->{tw}->open("$tmpdir/tmp.chr.xml",%{$fmt->{twopen}||{}})
    or $fmt->logdie("could not open $tmpdir/tmp.chr.xml as TokWrap document: $!");
  $twdoc->genKey('all')
    or $fmt->logdie("could generate $tmpdir/tmp.chr.t.xml with DTA::TokWrap: $!");
  $twdoc->close();

  ##-- now process the tokwrap document
  my $rc = $fmt->SUPER::fromFile("$tmpdir/tmp.chr.t.xml");

  ##-- ... and remove the temp dir
  File::Path::rmtree($tmpdir) if (-d $tmpdir && !$fmt->{keeptmp});

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

##=============================================================================
## Methods: Output
##==============================================================================

1; ##-- be happy

__END__
