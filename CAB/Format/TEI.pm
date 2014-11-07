## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TEI.pm
## Author: Bryan Jurish <moocow@cpan.org>
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
#use File::Copy qw();
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlTokWrap);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:(?:c|chr|txt|tei(?:[\.\-_]?p[45])?)[\.\-_]xml|xml)$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_)
      foreach (qw(chr-xml c-xml cxml tei-xml teixml tei xml));
}

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
}

##-- HACK for broken tokenizer on services.dwds.de (2011-07-27)
$DTA::TokWrap::Document::TOKENIZE_CLASS = 'http';
#$DTA::TokWrap::Document::TOKENIZE_CLASS = 'auto';  ##-- fixed (?) 2013-06-21

##-- default parser/formatter for *.t.xml files
our $TXML_CLASS_DEFAULT = 'DTA::CAB::Format::XmlTokWrap';
#our $TXML_CLASS_DEFAULT = 'DTA::CAB::Format::XmlTokWrapFast'; ##-- ca. 2x faster, but doesn't support all data-keys

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- new in TEI
##     tmpdir => $dir,                         ##-- temporary directory for this object (default: new)
##     keeptmp => $bool,                       ##-- keep temporary directory open
##     addc => $bool_or_guess,                 ##-- (input) whether to add //c elements (slow no-op if already present; default=0)
##     spliceback => $bool,                    ##-- (output) if true (default), return .cws.cab.xml ; otherwise just .cab.t.xml [requires doc 'teibufr' attribute]
##     keeptext => $bool,                      ##-- (input) if true (default), include 'textbufr' element for extract TEI text
##     keepc => $bool,                         ##-- (output) whether to include //c elements in spliceback-mode output (default=0)
##     tw => $tw,                              ##-- underlying DTA::TokWrap object
##     twopen => \%opts,                       ##-- options for $tw->open()
##     teibufr => \$buf,                       ##-- raw tei+c buffer, for spliceback mode
##     textbufr => \$buf,                      ##-- raw text buffer, for keeptext mode
##
##     txmlfmt   => $fmt,                      ##-- classname or object for parsing tokwrap *.t.xml files (default: DTA::CAB::Format::TokWrap)
##
##     ##-- input: inherited from XmlNative
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output: new
##     #outfile => $filename,			##-- final output file (flushed with File::Copy::copy)
##
##     ##-- output: inherited from XmlTokWrap
##     arrayEltKeys => \%akey2ekey,            ##-- maps array keys to element keys for output
##     arrayImplicitKeys => \%akey2undef,      ##-- pseudo-hash of array keys NOT mapped to explicit elements
##     key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
##     xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
##     ##
##     ##-- output: inherited from XmlNative
##     #encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common: safety
##     safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- local
			      tmpdir => undef, ##-- see tmpdir() method
			      keeptmp=>0,
			      teilog => 'off', ##-- tei format debug log level
			      ##
			      addc => 0,
			      keepc => 0,
			      spliceback => 1,
			      keeptext => 1,
			      ##
			      txmlfmt => $TXML_CLASS_DEFAULT,

			      ##-- tokwrap
			      tw => undef, ##-- see tw() method
			      twopts => {procOpts=>{soIgnoreAttrs=>[qw(c xb)], spliceInfo=>'off',addwsInfo=>'off'}},
			      twopen => {},
			      twTokenizeClass => $DTA::TokWrap::Document::TOKENIZE_CLASS,

			      ##-- overrides (XmlTokWrap, XmlNative, XmlCommon)
			      ignoreKeys => {
					     teibufr=>undef,
					     textbufr=>undef,
					    },

			      ##-- user args
			      @_
			     );

  if (0) {
    ##-- DEBUG: also consider setting $DTA::CAB::Logger::defaultLogOpts{twLevel}='TRACE', e.g. with '-lo twLevel=TRACE' on the command-line
    $fmt->{twopen}{"trace$_"}    = 'debug' foreach (qw(Proc Open Close Load Gen Subproc Run));
    $fmt->{twopts}{procOpts}{$_} = 'debug' foreach (qw(traceLevel));
    $DTA::TokWrap::Utils::TRACE_RUNCMD = 'debug';
    $fmt->{twopts}{$_} = 'DEBUG' foreach (qw(addwsInfo spliceInfo));
    $fmt->{tmpdir} = "cab_tei_tmp";
    $fmt->{keeptmp} = 1;
  }

  ##-- tmpdir: see tmpdir() method

  ##-- tw: TokWrap object : depends on tmpdir(): see tw() method

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
##  + get/generate name of temporary directory, ensures $fmt->{tmpdir} is set
sub tmpdir {
  return $_[0]{tmpdir} if (defined($_[0]{tmpdir}));
  return $_[0]{tmpdir} = mktmpfsdir("cab_tei_${$}_XXXX", CLEAN=>(!$_[0]{keeptmp}))
}

## $tmpdir = $fmt->mktmpdir()
##  + ensures $fmt->tmpdir() exists
sub mktmpdir {
  my $fmt = shift;
  my $tmpdir = $fmt->tmpdir();
  $fmt->vlog($fmt->{teilog}, "mktmpdir $tmpdir");
  mkdir($tmpdir,0700) if (!-d $tmpdir);
  (-d $tmpdir) or $fmt->logconfess("could not create directory '$tmpdir': $!");
  return $tmpdir;
}

## $fmt = $fmt->rmtmpdir()
##  + removes $fmt->{tmpdir} unless $fmt->{keeptmp} is true
sub rmtmpdir {
  my $fmt = shift;
  if (defined($fmt->{tmpdir}) && -d $fmt->{tmpdir} && !$fmt->{keeptmp}) {
    $fmt->vlog($fmt->{teilog}, "rmtree $fmt->{tmpdir}") if (Log::Log4perl->initialized);;
    File::Path::rmtree($fmt->{tmpdir})
	or $fmt->logconfess("could not rmtree() temp directory '$fmt->{tmpdir}': $!");
  }
  return $fmt;
}

## $txmlfmt = $fmt->txmlfmt()
##  + gets cached $fmt->{txmlfmt} or creates it
sub txmlfmt {
  return $_[0]{txmlfmt} if (ref $_[0]{txmlfmt});
  my %txmlopts = %{$_[0]};
  delete @txmlopts{qw(xdoc xprs txmlfmt fh tmpfh)};
  return $_[0]{txmlfmt} = $_[0]->txmlclass->new(%txmlopts);
}

## $class = $fmt->txmlclass()
sub txmlclass {
  return ref($_[0]{txmlfmt}) if (ref($_[0]{txmlfmt}));
  return "DTA::CAB::Format::$_[0]{txmlfmt}" if (UNIVERSAL::isa("DTA::CAB::Format::$_[0]{txmlfmt}",'DTA::CAB::Format'));
  return $_[0]{txmlfmt} || $TXML_CLASS_DEFAULT;
}

## $tw = $fmt->tw()
##  + returns DTA::TokWrap object for $fmt
##  + calls $fmt->tmpdir()
sub tw {
  return $_[0]{tw} if (defined($_[0]{tw}));
  my $tw = $_[0]{tw} = DTA::TokWrap->new(%{$_[0]{twopts}||{}}, tokenizeClass=>$_[0]{twTokenizeClass});
  $tw->{keeptmp} = $_[0]{keeptmp};
  $tw->{tmpdir}  = $tw->{outdir} = $_[0]->tmpdir();
  $tw->init();

  return $tw;
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
  $fmt->{txmlfmt}->close(@_) if (ref($fmt->{txmlfmt}));
  delete @$fmt{qw(teibufr textbufr)};
  $fmt->rmtmpdir();
  return $fmt->SUPER::close(@_);
}

## $fmt = $fmt->fromString(\$string)
##  + select input from string $string
sub fromString {
  my $fmt = shift;
  my $str = ref($_[0]) ? $_[0] : \$_[0];
  $fmt->close();

  ##-- ensure tmpdir exists
  $fmt->vlog($fmt->{teilog}, "fromString()");
  my $tmpdir = $fmt->mktmpdir;

  ##-- prepare tei buffer with //c elements
  utf8::encode($$str) if (utf8::is_utf8($$str));

  if (!$fmt->{addc}) {
    ##-- dump document with predefined //c elements, or rely on dta-tokwrap >= v0.38 to handle both //c and text()
    $fmt->vlog($fmt->{teilog}, "write $tmpdir/tmp.chr.xml");
    DTA::TokWrap::Utils::ref2file($str,"$tmpdir/tmp.chr.xml")
	or $fmt->logdie("couldn't create temporary file $tmpdir/tmp.chr.xml: $!");
    $fmt->{teibufr} = $str if ($fmt->{spliceback});
  }
  else {
    ##-- dump raw document
    $fmt->vlog($fmt->{teilog}, "add-c: write $tmpdir/tmp.raw.xml");
    DTA::TokWrap::Utils::ref2file($str,"$tmpdir/tmp.raw.xml")
	or $fmt->logdie("couldn't create temporary file $tmpdir/tmp.raw.xml: $!");

    ##-- ensure //c elements
    $fmt->vlog($fmt->{teilog}, "add-c: dtatw-add-c.perl");
    my $addc_args = '-rmns '.($fmt->{addc} eq 'guess' ? '-guess' : '-noguess');
    DTA::TokWrap::Utils::runcmd("dtatw-add-c.perl $addc_args $tmpdir/tmp.raw.xml > $tmpdir/tmp.chr.xml")==0
	or $fmt->logdie("dtatw-add-c.perl failed: $!");

    ##-- grab tei buffer
    $fmt->vlog($fmt->{teilog}, "add-c: slurp tmp.chr.xml");
    $fmt->{teibufr} = DTA::TokWrap::Utils::slurp_file("$tmpdir/tmp.chr.xml")
      if ($fmt->{spliceback});
  }

  ##-- run tokwrap
  $fmt->vlog($fmt->{teilog}, "tokwrap: tmp.chr.xml -> tmp.chr.t.xml");
  my $twdoc = $fmt->tw->open("$tmpdir/tmp.chr.xml",%{$fmt->{twopen}||{}})
    or $fmt->logdie("could not open $tmpdir/tmp.chr.xml as TokWrap document: $!");
  $twdoc->genKey('tei2txml')
    or $fmt->logdie("could generate $tmpdir/tmp.chr.t.xml with DTA::TokWrap: $!");
  if ($fmt->{keeptext}) {
    $fmt->vlog($fmt->{teilog}, "keeptext: slurp textbufr < $tmpdir/tmp.chr.txt");
    $fmt->{textbufr} = DTA::TokWrap::Utils::slurp_file("$tmpdir/tmp.chr.txt");
  }
  $twdoc->close();

  ##-- now process the tokwrap document
  $fmt->vlog($fmt->{teilog}, $fmt->txmlclass()."->fromFile(tmp.chr.t.xml)");
  $fmt->{txmlfmt}->close(@_) if (ref $fmt->{txmlfmt});
  my $rc = $fmt->txmlfmt->fromFile("$tmpdir/tmp.chr.t.xml");

  ##-- ... and cleanup
  $fmt->rmtmpdir();

  $fmt->vlog($fmt->{teilog}, "fromString(): returning");
  return $rc ? $fmt : undef;
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
##  + override inserts $doc->{teibufr}, $doc->{textbufr} attributes for spliceback mode
sub parseDocument {
  my $fmt = shift;
  $fmt->vlog($fmt->{teilog}, "parseDocument()");
  my $doc = $fmt->txmlfmt->parseDocument(@_) or return undef;
  $doc->{teibufr}  = $fmt->{teibufr} if ($fmt->{spliceback});
  $doc->{textbufr} = $fmt->{textbufr} if ($fmt->{keeptext});
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

## $fmt = $fmt->flush()
##  + flush any buffered output to selected output source
##  + override calls $fmt->buf2fh(\$fmt->{outbuf}, $fmt->{fh})
sub flush {
  my $fmt = shift;
  $fmt->vlog($fmt->{teilog}, "flush()") if (Log::Log4perl->initialized);
  #File::Copy::copy($fmt->{outfile},$fmt->{fh}) if (defined($fmt->{outfile}) && defined($fmt->{fh}));
  $fmt->buf2fh(\$fmt->{outbuf}, $fmt->{fh})
    if (defined($fmt->{outbuf}) && defined($fmt->{fh}) && $fmt->{fh}->opened);
  #$fmt->SUPER::flush(@_); ##-- not here, since this writes literal {xdoc} to the output file!
  delete @$fmt{qw(outfile outbuf xdoc)};
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

  ##-- get original TEI-XML buffer
  my $teibufr = $fmt->{spliceback} ? ($doc->{teibufr} || $fmt->{teibufr}) : undef;
  if (!defined($teibufr) || !$$teibufr) {
    $fmt->logwarn("spliceback mode requested but no 'teibufr' document property - using XmlTokWrap format");
    $fmt->vlog($fmt->{teilog}, $fmt->txmlclass."->putDocument()");
    return $fmt->txmlfmt->toString(\$fmt->{outbuf})->putDocument($doc)->flush();
  }

  ##-- get temp directory
  my $tmpdir = $fmt->mktmpdir();

  ##-- dump base data
  $fmt->vlog($fmt->{teilog}, "putDocument(): write $tmpdir/tmp.tei.xml");
  DTA::TokWrap::Utils::ref2file($teibufr,"$tmpdir/tmp.tei.xml")
      or $fmt->logconfess("couldn't create temporary file $tmpdir/tmp.tei.xml: $!");

  ##-- get tokwrap object
  my $twdoc = $fmt->tw->open("$tmpdir/tmp.tei.xml",%{$fmt->{twopen}||{}})
    or $fmt->logdie("could not open $tmpdir/tmp.tei.xml as TokWrap document: $!");
  $twdoc->{xmldata}  = $$teibufr;
  $twdoc->{xtokfile} = "$tmpdir/tmp.cab.t.xml";

  ##-- dump underlying txml data
  my ($rc);
  $fmt->vlog($fmt->{teilog}, "putDocument(): underlying ".$fmt->txmlclass."->putDocument()");
  if ($fmt->txmlfmt->can('putDocument') eq DTA::CAB::Format::XmlNative->can('putDocument')) {
    ##-- XmlNative-style putDocument uses underlying libxml xdoc
    $rc = $fmt->txmlfmt->putDocument($doc);
    $twdoc->{xtokdata} = $fmt->txmlfmt->{xdoc}->toString(0);
  } else {
    ##-- XmlTokWrapFast-style putDocument to buffer
    $rc = $fmt->txmlfmt->toString(\$twdoc->{xtokdata}, 0)->putDocument($doc)->flush;
  }
  return $rc if (!$rc);

  $fmt->vlog($fmt->{teilog}, "putDocument(): splice to $tmpdir/tmp.tei.cws.xml");
  $twdoc->{cwsfile}  = "$tmpdir/tmp.tei.cws.xml";
  #$twdoc->{cwstfile} = "$tmpdir/tmp.tei.cwst.xml";
  #$twdoc->{cwstbufr} = \$fmt->{outbuf}; ##-- output to string
  $twdoc->saveXtokFile()
    or $fmt->logconfess("could not save intermediate cab.t.xml file: $!");
  $twdoc->genKey('addws')
    or $fmt->logconfess("could not generate intermediate cws xml data: $!");

  ##-- optionally remove //c elements
  $fmt->vlog($fmt->{teilog}, "putDocument(): remove //c -> $tmpdir/tmp.tei.cws.noc.xml");
  my $cwsfile = "$tmpdir/tmp.tei.cws.xml";
  if (!$fmt->{keepc}) {
    DTA::TokWrap::Utils::runcmd("dtatw-rm-c.perl $cwsfile > $tmpdir/tmp.tei.cws.noc.xml")==0
	or $fmt->logdie("dtatw-rm-c.perl failed: $!");
    $cwsfile = "$tmpdir/tmp.tei.cws.noc.xml";
  }

  ##-- splice in cab analysis data (should already be there in tokwrap >= v0.37)
  #$twdoc->genKey('idsplice');

  ##-- slurp the buffer back in
  $fmt->vlog($fmt->{teilog}, "putDocument(): re-slurp from $cwsfile");
  DTA::TokWrap::Utils::slurp_file("$cwsfile",\$fmt->{outbuf})
      or $fmt->logdie("slurp_file() failed for '$cwsfile': $!");
  $fmt->{outbuf} =~ s|(<[^>]*)\sXMLNS=|$1 xmlns=|g; ##-- decode default namespaces (hack)

  ##-- cleanup
  $twdoc->close();
  $fmt->rmtmpdir();

  $fmt->vlog($fmt->{teilog}, "putDocument(): returning");
  return $fmt;
}





1; ##-- be happy

__END__
