## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Common.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: XML (common)

package DTA::CAB::Format::XmlCommon;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##-- input
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output
##     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   xprs => XML::LibXML->new,
		   xdoc => undef,

		   ##-- output
		   encoding => 'UTF-8',
		   level => 0,

		   ##-- common

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $fmt;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
sub noSaveKeys {
  return qw(xdoc xprs);
}

##=============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
sub close {
  delete($_[0]{xdoc});
  return $_[0];
}

## $fmt = $fmt->fromFile($filename_or_handle)
sub fromFile {
  my ($fmt,$file) = @_;
  return $fmt->fromFh($file) if (ref($file));
  $fmt->{xdoc} = $fmt->{xprs}->parse_file($file)
    or $fmt->logconfess("XML::LibXML::parse_file() failed for '$file': $!");
  return $fmt;
}

## $fmt = $fmt->fromFh($handle)
sub fromFh {
  my ($fmt,$fh) = @_;
  $fmt->{xdoc} = $fmt->{xprs}->parse_fh($fh)
    or $fmt->logconfess("XML::LibXML::parse_fh() failed for handle '$fh': $!");
  return $fmt;
}

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->{xdoc} = $fmt->{xprs}->parse_string($_[0])
    or $fmt->logconfess("XML::LibXML::parse_string() failed for '$_[0]': $!");
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##  + nothing here



##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME

## $type = $fmt->mimeType()
##  + override returns text/xml
sub mimeType { return 'text/xml'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  delete($_[0]{xdoc});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
sub toString {
  my $xdoc = $_[0]->xmlDocument;
  $xdoc->setEncoding($_[0]{encoding}) if ($_[0]{encoding} ne $xdoc->encoding);
  return $xdoc->toString(defined($_[1]) ? $_[1] : $_[0]{level});
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
sub toFh {
  my $xdoc = $_[0]->xmlDocument;
  $xdoc->setEncoding($_[0]{encoding}) if ($_[0]{encoding} ne $xdoc->encoding);
  $xdoc->toFH($_[1], (defined($_[2]) ? $_[2] : $_[0]{level}));
  return $_[0];
}

##--------------------------------------------------------------
## Methods: Output: local

## $xmldoc = $fmt->xmlDocument()
##  + create or return output buffer $fmt->{xdoc}
sub xmlDocument {
  return $_[0]{xdoc} if (defined($_[0]{xdoc}));
  return $_[0]{xdoc} = XML::LibXML::Document->new("1.0",$_[0]{encoding});
}

## $rootnode = $fmt->xmlRootNode()
## $rootnode = $fmt->xmlRootNode($nodname)
##  + returns root node
##  + $nodname defaults to 'doc'
sub xmlRootNode {
  my ($fmt,$name) = @_;
  my $xdoc = $fmt->xmlDocument;
  my $root = $xdoc->documentElement;
  if (!defined($root)) {
    $xdoc->setDocumentElement($root = XML::LibXML::Element->new(defined($name) ? $name : 'doc'));
  }
  return $root;
}

##--------------------------------------------------------------
## Methods: Output: Generic API

sub putToken { $_[0]->logconfess("putToken(): not implemented"); }
sub putSentence { $_[0]->logconfess("putSentence(): not implemented"); }
sub putDocument { $_[0]->logconfess("putDocument(): not implemented"); }


##--------------------------------------------------------------
## Methods: Output: XML Nodes: Generic

## $nod = $fmt->defaultXmlNode($value,\%opts)
##  + default XML node generator
##  + \%opts is unused
sub defaultXmlNode {
  my ($fmt,$val) = @_;
  my ($vnod);
  if (UNIVERSAL::can($val,'xmlNode') && UNIVERSAL::can($val,'xmlNode') ne \&defaultXmlNode) {
    ##-- xml-aware object (avoiding circularities): $val->xmlNode()
    return $val->xmlNode(@_[2..$#_]);
  }
  elsif (!ref($val)) {
    ##-- non-reference: <VALUE>$val</VALUE> or <VALUE undef="1"/>
    $vnod = XML::LibXML::Element->new("VALUE");
    if (defined($val)) {
      $vnod->appendText($val);
    } else {
      $vnod->setAttribute("undef","1");
    }
  }
  elsif (UNIVERSAL::isa($val,'HASH')) {
    ##-- HASH ref: <HASH ref="$ref"> ... <ENTRY key="$eltKey">defaultXmlNode($eltVal)</ENTRY> ... </HASH>
    $vnod = XML::LibXML::Element->new("HASH");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'HASH');
    foreach (keys(%$val)) {
      my $enod = $vnod->addNewChild(undef,"ENTRY");
      $enod->setAttribute("key",$_);
      $enod->addChild($fmt->defaultXmlNode($val->{$_}));
    }
  }
  elsif (UNIVERSAL::isa($val,'ARRAY')) {
    ##-- ARRAY ref: <ARRAY ref="$ref"> ... xmlNode($eltVal) ... </ARRAY>
    $vnod = XML::LibXML::Element->new("ARRAY");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'ARRAY');
    foreach (@$val) {
      $vnod->addChild($fmt->defaultXmlNode($_));
    }
  }
  elsif (UNIVERSAL::isa($val,'SCALAR')) {
    ##-- SCALAR ref: <SCALAR ref="$ref"> xmlNode($$val) </SCALAR>
    $vnod = XML::LibXML::Element->new("SCALAR");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'SCALAR');
    $vnod->addChild($fmt->defaultXmlNode($$val));
  }
  else {
    ##-- other reference (CODE,etc.): <VALUE ref="$ref" unknown="1">"$val"</VALUE>
    $fmt->logcarp("defaultXmlNode(): default node generator clause called for value '$val'");
    $vnod = XML::LibXML::Element->new("VALUE");
    $vnod->setAttribute("ref",ref($val));
    $vnod->setAttribute("unknown","1");
    $vnod->appendText("$val");
  }
  return $vnod;
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::XmlCommon - Datum parser|formatter: XML: base class

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::XmlCommon;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::XmlCommon->new(%args);
  
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $fmt = $fmt->fromFile($filename_or_handle);
 $fmt = $fmt->fromFh($filename_or_handle);
 $fmt = $fmt->fromString($string);
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->flush();
 $str = $fmt->toString();
 $xmldoc = $fmt->xmlDocument();
 $rootnode = $fmt->xmlRootNode();
 $nod = $fmt->defaultXmlNode($value,\%opts);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::XmlCommon is a base class for XML-formatters
using XML::LibXML, and is not a fully functional format class by itself.
See subclass documentation for details.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlCommon: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::XmlCommon
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlCommon: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$fmt:

 ##-- input
 xdoc => $xdoc,                          ##-- XML::LibXML::Document
 xprs => $xprs,                          ##-- XML::LibXML parser
 ##
 ##-- output
 encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
 level => $level,                        ##-- output formatting level (default=0)
 ##
 ##-- common
 #(nothing here)

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlCommon: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Override: returns list of keys not to be saved.
Here, C<qw(xdoc xprs)>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlCommon: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close current input source.

=item fromFile

 $fmt = $fmt->fromFile($filename_or_handle);

Override: select input from file.

=item fromFh

 $fmt = $fmt->fromFh($fh);

Override: select input from filehandle $fh.

=item fromString

 $fmt = $fmt->fromString($string);

Override: select input from string $string.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlCommon: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item flush

 $fmt = $fmt->flush();

Override: flush accumulated output.

=item toString

 $str = $fmt->toString();
 $str = $fmt->toString($formatLevel);

Override: flush buffered output to byte-string.
$formatLevel is passed to XML::LibXML::Document::toString(),
and defaults to $fmt-E<gt>{level}.

=item toFh

 $fmt_or_undef = $fmt->toFh($fh,$formatLevel);

Override: flush buffered output document to filehandle $fh.

=item xmlDocument

 $xmldoc = $fmt->xmlDocument();

Returns output buffer $fmt-E<gt>{xdoc}, creating it
if not yet defined.

=item xmlRootNode

 $rootnode = $fmt->xmlRootNode();
 $rootnode = $fmt->xmlRootNode($nodname);

Returns output buffer root node, creating one if not yet defined.

$nodname is the name of the root node to create (if required);
default='doc'.

=item putToken

Not implemented here.

=item putSentence

Not implemented here.

=item putDocument

Not implemented here.

=item defaultXmlNode

 $nod = $fmt->defaultXmlNode($value,\%opts);

Default XML node generator, which creates very perl-ish XML.

%opts is unused.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

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
