## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlNative.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: XML (native)

package DTA::CAB::Format::XmlNative;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Format::XmlXsl;
use DTA::CAB::Datum ':all';
use XML::LibXML;
#use XML::LibXML::Iterator;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlXsl);

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
##     ##-- common: safety
##     safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(@_);
  $fmt->initStyles();
  return $fmt;
}

## $fmt = $fmt->initStyles()
sub initStyles {
  my $fmt = shift;

  ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## stylesheet: input
  $fmt->{iwhich} = 'string';
  $fmt->{ixsl} = q(<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:cab="http://www.deutschestextarchiv.de/cab/1.0/xsl"
		>

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
  <xsl:strip-space elements="*"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Variables -->
  <!--
      hashElt : element name to use for hashes   (HASH  H hash  h   MAP  M map  m)
      listElt : element name to use for lists    (ARRAY   array     LIST L list l)
      atomElt : element name to use for atoms    (VALUE V value v   ATOM A atom a)
  -->
  <xsl:param name='listElt' select="'l'"/>
  <xsl:param name='hashElt' select="'m'"/>
  <xsl:param name='atomElt' select="'a'"/>

  <xsl:param name="useTypes" select="1"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: root: recurse -->
  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: document (no body) -->
  <xsl:template match="doc">
    <xsl:element name="{$hashElt}">
      <xsl:if test="$useTypes"><xsl:attribute name="ref">DTA::CAB::Document</xsl:attribute></xsl:if>
      <xsl:attribute name="key">doc</xsl:attribute>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="*[local-name() != 's']|text()"/>
      <xsl:element name="{$listElt}">
	<xsl:attribute name="key">body</xsl:attribute>
	<xsl:apply-templates select="./s"/>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: sentence -->
  <xsl:template match="s">
    <xsl:element name="{$hashElt}">
      <xsl:if test="$useTypes"><xsl:attribute name="ref">DTA::CAB::Sentence</xsl:attribute></xsl:if>
      <xsl:attribute name="key">s</xsl:attribute>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="*[local-name() != 'w']|text()"/>
      <xsl:element name="{$listElt}">
	<xsl:attribute name="key">tokens</xsl:attribute>
	<xsl:apply-templates select="./w"/>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: token -->
  <xsl:template match="w">
    <xsl:element name="{$hashElt}">
      <xsl:if test="$useTypes"><xsl:attribute name="ref">DTA::CAB::Token</xsl:attribute></xsl:if>
      <xsl:attribute name="key">w</xsl:attribute>
      <xsl:attribute name="attr">1</xsl:attribute>
      <xsl:apply-templates select="@*|*|text()"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: overrides: w/@t -->
  <xsl:template match="w/@t">
    <xsl:element name="{$atomElt}">
      <xsl:attribute name="key">text</xsl:attribute>
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: overrides: w/xlit/@t -->
  <xsl:template match="w/xlit/@t">
    <xsl:element name="{$atomElt}">
      <xsl:attribute name="key">latin1Text</xsl:attribute>
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: overrides: w/msafe -->
  <xsl:template match="w/msafe">
    <xsl:element name="{$atomElt}">
      <xsl:attribute name="key">msafe</xsl:attribute>
      <xsl:value-of select="@safe"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: default: attribute -->
  <xsl:template match="@*" priority="-1">
    <xsl:element name="{$atomElt}">
      <xsl:attribute name="key"><xsl:value-of select="name(.)"/></xsl:attribute>
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: default: element with attrs: map -->
  <xsl:template match="*[@*]" priority="-1">
    <xsl:element name="{$hashElt}">
      <xsl:attribute name="key"><xsl:value-of select="name(.)"/></xsl:attribute>
      <xsl:apply-templates select="@*|*|text()"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: default: element with no attrs: list -->
  <xsl:template match="*[not(@*)]" priority="-1">
    <xsl:element name="{$listElt}">
      <xsl:attribute name="key"><xsl:value-of select="name(.)"/></xsl:attribute>
      <xsl:apply-templates select="@*|*|text()"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: default: text -->
  <xsl:template match="text()" priority="-1">
    <xsl:element name="{$atomElt}">
      <xsl:attribute name="key">#text</xsl:attribute>
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- Templates: default: copy -->
  <xsl:template match="comment()|processing-instruction()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
);

  ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## stylesheet: output
  $fmt->{owhich} = 'string';
  $fmt->{oxsl} = q(
);

  return $fmt;
}

1; ##-- be happy

__END__
