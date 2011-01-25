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
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::XmlXsl - Datum parser|formatter: XML via XmlPerl and XSLT

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::XmlXsl;
 
 ##========================================================================
 ## Methods
 
 $fmt = DTA::CAB::Format::XmlXsl->new(%args);
 $style = $fmt->stylesheet($i_or_o);
 $doc = $fmt->parseDocument();
 $str = $fmt->_xmlDocument();
 $str = $fmt->toString();
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

B<UNSTABLE>

DTA::CAB::Format::XmlXsl is a
L<DTA::CAB::Format|DTA::CAB::Format>
subclass for I/O of XML document data
using XSL stylesheets to map these to and from
the
L<DTA::CAB::Format::XmlPerl|DTA::CAB::Format::XmlPerl>
format class, from which it inherits.

This class is currently unused, unstable, unsupported, and unreccommended
for general use.  It may be revived in the future e.g. for (X)HTML
pretty-printing of analyzed L<DTA::CAB::Document|DTA::CAB::Document> objects.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlXsl: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

object structure: HASH ref

    {
     ##-- new
     iwhich   => $which,                    ##-- input: xsl source type (default='file'; see DTA::CAB::Utils::xsl_stylesheet())
     ixsl     => $src,                      ##-- input: xsl source      (default=undef; see DTA::CAB::Utils::xsl_stylesheet())
     owhich   => $which,                    ##-- output: xsl source type (default='file'; see DTA::CAB::Utils::xsl_stylesheet())
     oxsl     => $src,                      ##-- output: xsl source      (default=undef; see DTA::CAB::Utils::xsl_stylesheet())
     ##
     xslt  => $xslt,                         ##-- xslt compiler object
     istyle => $stylesheet,                  ##-- input: xslt stylesheet object
     ostyle => $stylesheet,                  ##-- output: xslt stylesheet object
     ##-- input
     xdoc => $xdoc,                          ##-- XML::LibXML::Document
     xprs => $xprs,                          ##-- XML::LibXML parser
     ##-- output
     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
     level => $level,                        ##-- output formatting level (default=0)
    }

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlXsl: Methods: XSL Utilities
=pod

=head2 Methods: XSL Utilities

=over 4

=item stylesheet

 $style = $fmt->stylesheet($i_or_o);

(undocumented)

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlXsl: Methods: Input: Generic API
=pod

=head2 Methods: Input: Generic API

=over 4

=item parseDocument

 $doc = $fmt->parseDocument();

parses buffered XML::LibXML::Document

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlXsl: Methods: Output: API
=pod

=head2 Methods: Output: API

=over 4

=item _xmlDocument

 $str = $fmt->_xmlDocument();

(undocumented)

=item toString

 $str = $fmt->toString();

$str = $fmt-E<gt>toString($formatLevel)
flush buffered output document to byte-string

=item toFh

 $fmt_or_undef = $fmt->toFh($fh,$formatLevel)

flush buffered output document to filehandle $fh

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod



=cut

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<DTA::CAB::Format::XmlPerl(3pm)|DTA::CAB::Format::XmlPerl>,
L<DTA::CAB::Format::Builtin(3pm)|DTA::CAB::Format::Builtin>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
