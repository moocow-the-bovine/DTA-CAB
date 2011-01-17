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
#BEGIN {
#  local $^W=0;
#  require XML::LibXML::Iterator;
#}
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlCommon);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-native|xml\-dta\-cab|(?:dta[\-\._]cab[\-\._]xml)|xml)$/);
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
##     ##-- input: inherited
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output: new
##     arrayEltKeys => \%akey2ekey,            ##-- maps array keys to element keys for output
##     arrayImplicitKeys => \%akey2undef,      ##-- pseudo-hash of array keys NOT mapped to explicit elements
##     key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
##     xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
##     ##
##     ##-- output: inherited
##     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common: safety
##     safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(
			      ##-- defaults: output
			      #xmlns =>
			      #{
			      # 'cab' => 'http://www.deutschestextarchiv.de/cab/spec/1.0/XmlNative',
			      # ''    => 'http://www.deutschestextarchiv.de/cab/spec/1.0/XmlNative',
			      #},

			      key2xml => {
					  'id' => 'xml:id',
					  'base' => 'xml:base',
					 },
			      xml2key => {
					  'xml:id' => 'id',
					  'xml:base' => 'base',
					 },

			      arrayEltKeys => {
					       'body' => 's',
					       'tokens' => 'w',
					       #'analyses' => 'an',
					       'DEFAULT' => 'a',
					      },

			      arrayImplicitKeys => {
						    body=>undef,
						    tokens=>undef,
						   },

			      ##-- user args
			      @_
			     );
  $fmt->{xprs}->keep_blanks(0);
  return $fmt;
}

##=============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Local

## $obj = $fmt->parseNode($nod)
##  + returns a perl object represented by the XML::LibXML::Node $nod
##  + attempts to map xml to perl structure "sensibly"
##  + DTA::CAB::Datum nodes (documen,sentence,token) get some additional baggage:
##     _xmldata  => $data,    ##-- unparsed content (raw string)
sub parseNode {
  my ($fmt,$top) = @_;
  return undef if (!defined($top));

  my $xml2key = $fmt->{xml2key};
  my ($cd,$cs,$cw);
  my ($nod,$cur,$name,$nxt);
  my ($topval);

  my @queue = ([$top]);
  while (@queue) {
    ($nod,$cur) = @{shift @queue};
    $name = $nod->nodeName;
    $name = $xml2key->{$name} if (defined($xml2key->{$name}));

    if (isa($nod,'XML::LibXML::Element')) {
      ##-- Element
      if ($name eq 'doc') {
	##-- Element: special: DTA::CAB::Document
	$nxt = $cd = DTA::CAB::Document->new;
      }
      elsif ($name eq 's') {
	##-- Element: special: DTA::CAB::Sentence
	$nxt = $cs = DTA::CAB::Sentence->new;
	push(@{$cd->{body}},$cs);
      }
      elsif ($name eq 'w') {
	##-- Element: special: DTA::CAB::Token
	$nxt = $cw = DTA::CAB::Token->new;
	push(@{$cs->{tokens}},$cw);
      }
      elsif ($name eq 'msafe') {
	##-- Element: special: msafe (backwards-compatible)
	$cur->{msafe} = $nod->getAttribute('safe');
      }
      elsif ($nod->hasAttributes) {
	##-- Element: default: +attributes: HASH
	$nxt = _pushValue($cur,$name,{});
      }
      elsif ($nod->hasChildNodes) {
	##-- Element: default: -attributes, +dtrs: ARRAY
	$nxt = _pushValue($cur,$name,[]);
      }
      else {
	##-- Element: default: -attributes, -dtrs: append to _xmldata
	$cur->{_xmldata} .= $nod->toString if (isa($cur,'HASH'));
      }
      ##-- Element: common: enqueue child nodes
      push(@queue, map {[$_,$nxt]} $nod->attributes, $nod->childNodes);

      ##-- Element: save top value
      $topval = $nxt if (!defined($topval));
    }
    elsif (isa($nod,'XML::LibXML::Attr')) {
      ##-- Attribute (hash only)
      $cur->{$name} = $nod->value if (isa($cur,'HASH'));
    }
    elsif (isa($nod,'XML::LibXML::Text')) {
      ##-- Text
      if (isa($cur,'HASH')) {
	##-- Text: to hash: append to _xmldata
	$cur->{'_xmldata'} .= $nod->toString;
      }
      elsif (isa($cur,'ARRAY')) {
	##-- Text: to array: append to array
	push(@$cur,$nod->toString);
      }
    }
    else {
      warn("$0: cannot handle XML node of class ", ref($nod), " - skipping\n");
    }
  }##--/while (@queue)

  return $topval;
}

## $val = PACKAGE::_pushValue(\%hash,  $key, $val); ##-- $hash{$key}=$val
## $val = PACKAGE::_pushValue(\@array, $key, $val); ##-- push(@array,$val)
sub _pushValue {
  return $_[0]{$_[1]}=$_[2] if (isa($_[0],'HASH'));
  push(@{$_[0]},$_[2]);
  return $_[2];
}


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
  my $parsed = $fmt->parseNode($fmt->{xdoc}->documentElement);

  ##-- force document
  return $fmt->forceDocument($parsed);
}

##=============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME & HTTP stuff

## $short = $fmt->formatName()
##  + returns "official" short name for this format
##  + default just returns package suffix
sub shortName {
  return 'xml';
}

##--------------------------------------------------------------
## Methods: Output: Local

## $nod = $fmt->xmlNode($thingy,$name)
##  + returns an xml node for $thingy using $name as key
sub xmlNode {
  my ($fmt,$topval,$topkey) = @_;
  my $topmom = XML::LibXML::Element->new('__root__');

  my $akey2ekey = $fmt->{arrayEltKeys};
  my $key2xml   = $fmt->{key2xml};

  my ($val,$key,$mom,$nod, $skey,$sval);
  my @queue = ([$topval,$topkey,$topmom]); ## [$val,$key,$mom], ...
  while (@queue) {
    ($val,$key,$mom) = @{shift @queue};
    $key = $key2xml->{$key} if (defined($key2xml->{$key}));

    if (!defined($val)) {
      ;##-- undefined: skip it
    }
    elsif (!ref($val)) {
      ##-- scalar: raw text
      #$val = '' if (!defined($val));
      if ($key eq '#text') {
	$mom->appendText($val);
      } else {
	$mom->appendTextChild($key,$val);
      }
    }
    elsif (can($val,'xmlNode') && UNIVERSAL::can($val,'xmlNode') ne \&defaultXmlNode) {
      ##-- object: xml-aware (avoid circularities)
      $nod = $val->xmlNode($key,$mom,$fmt);
      $mom->appendChild($nod); ##-- fails if already added
    }
    elsif (isa($val,'HASH')) {
      ##-- hash: map to element
      $nod = $mom->addNewChild(undef,$key);
      $nod->appendWellBalancedChunk($val->{_xmldata}) if (defined($val->{_xmldata}));
      while (($skey,$sval)=each(%$val)) {
	$skey = $key2xml->{$skey} if (defined($key2xml->{$skey}));
	if ($skey eq '_xmldata' || !defined($sval)) {
	  next;
	} elsif (!ref($sval)) {
	  $nod->setAttribute($skey,$sval);
	} else {
	  push(@queue, [$sval,$skey,$nod]);
	}
      }
    }
    elsif (isa($val,'ARRAY')) {
      if (exists($fmt->{arrayImplicitKeys}{$key})) {
	##-- array: implicit
	$nod = $mom;
      } else {
	##-- array: default: map to element
	$nod = $mom->addNewChild(undef,$key);
      }
      ##-- array: append elements
      $skey = $akey2ekey->{$key} || $akey2ekey->{DEFAULT};
      push(@queue, [$_,$skey,$nod]) foreach (@$val);
    }
    else {
      ##-- other: complain
      $fmt->logcarp("xmlNode(): default node generator clause called for key='$key', value='$val'");
      $nod = $mom->addNewChild
    }
  }

  ##-- unbind & return
  my $topnod = $topmom->firstChild();
  $topnod->unbindNode if (defined($topnod));
  return $topnod;
}

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  my ($fmt,$doc) = @_;
  my $xdoc   = $fmt->xmlDocument();
  my $docnod = $fmt->xmlNode($doc,'doc');
  my ($root);
  if (!defined($root=$xdoc->documentElement)) {
    $xdoc->setDocumentElement($docnod);
  } else {
    $root->appendChild($_) foreach ($docnod->childNodes); ##-- hack
  }
  return $fmt;
}

##==============================================================================
## Package: Xml (alias)
package DTA::CAB::Format::Xml;
our @ISA = qw(DTA::CAB::Format::XmlNative);

1; ##-- be happy

__END__
