## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlXsl.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: XML via XmlPerl and XSLT

package DTA::CAB::Format::XmlXsl;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Format::XmlPerl;
use DTA::CAB::Datum ':all';
use DTA::CAB::Utils ':libxml', ':libxslt';
use XML::LibXML;
use XML::LibXSLT;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlPerl);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- new
##     iwhich   => $which,                    ##-- input: xsl source type (default='file'; see DTA::CAB::Utils::xsl_stylesheet())
##     ixsl     => $src,                      ##-- input: xsl source      (default=undef; see DTA::CAB::Utils::xsl_stylesheet())
##     owhich   => $which,                    ##-- output: xsl source type (default='file'; see DTA::CAB::Utils::xsl_stylesheet())
##     oxsl     => $src,                      ##-- output: xsl source      (default=undef; see DTA::CAB::Utils::xsl_stylesheet())
##     ##
##     xslt  => $xslt,                         ##-- xslt compiler object
##     istyle => $stylesheet,                  ##-- input: xslt stylesheet object
##     ostyle => $stylesheet,                  ##-- output: xslt stylesheet object
##
##     ##-- input
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output
##     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- new
			      xslt => DTA::CAB::Utils::xsl_xslt(),
			      istyle => undef,
			      ostyle => undef,
			      iwhich=> 'file',
			      owhich=>'file',
			      ixsl => undef,
			      oxsl => undef,

			      ##-- input
			      xprs => undef,
			      xdoc => undef,

			      ##-- output
			      encoding => 'UTF-8',
			      level => 0,

			      ##-- common: safety
			      safe => 1,

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
## Methods: XSL Utilities

## $style = $fmt->stylesheet($i_or_o)
sub stylesheet {
  my ($fmt,$io) = @_;
  return $fmt->{"${io}style"} if (defined($fmt->{"${io}style"}));
  my $xslt = $fmt->{xslt};
  my $which  = $fmt->{"${io}which"};
  my $src    = $fmt->{"${io}xsl"};
  return $fmt->{"${io}style"} = xsl_stylesheet($which=>$src);
}

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
  $fmt->{xdoc} = $fmt->stylesheet('i')->transform($fmt->{xdoc})
    or $fmt->logconfess("parseDocument(): could not transform input document: $!");
  return $fmt->SUPER::parseDocument();
}

##=============================================================================
## Methods: Output
##==============================================================================


##--------------------------------------------------------------
## Methods: Output: API

## $str = $fmt->_xmlDocument()
sub _xmlDocument {
  my $fmt = shift;
  my $xdoc0 = $fmt->xmlDocument;
  return $fmt->stylesheet('o')->transform($fmt->xmlDocument)
    or $fmt->logconfess("_xmlDocument(): could not transform document for output: $!");
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
sub toString {
  my $xdoc = $_[0]->_xmlDocument;
  $xdoc->setEncoding($_[0]{encoding}) if ($_[0]{encoding} ne $xdoc->encoding);
  return $xdoc->toString(defined($_[1]) ? $_[1] : $_[0]{level});
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
sub toFh {
  my $xdoc = $_[0]->_xmlDocument;
  $xdoc->setEncoding($_[0]{encoding}) if ($_[0]{encoding} ne $xdoc->encoding);
  $xdoc->toFH($_[1], (defined($_[2]) ? $_[2] : $_[0]{level}));
  return $_[0];
}



1; ##-- be happy

__END__
