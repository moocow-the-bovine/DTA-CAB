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
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlCommon);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-native|xml\-dta\-cab|(?:dta[\-\._]cab[\-\._]xml)|xml)$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'xml');
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
##     ignoreKeys => \%key2undef,              ##-- keys to ignore for i/o
##     key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
##     xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
##     ##
##     ##-- output: inherited
##     #encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
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
					  #'id' => 'id',
					  'xml:id' => 'id',
					  #'base' => 'base',
					  'xml:base' => 'base',
					  #'text' => 't', ##-- for TokWrap .t.xml
					 },
			      xml2key => {
					  'xml:id' => 'id',
					  'xml:base' => 'base',
					  't' => 'text', ##-- for TokWrap .t.xml
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
						    'a'=>undef,
						   },
			      ignoreKeys => {
					     'teibufr'=>undef,
					    },

			      ##-- user args
			      @_
			     );
  $fmt->xmlparser->keep_blanks(0);
  return $fmt;
}

##==============================================================================
## Methods: I/O: Block-wise
##==============================================================================

## \%head = blockScanHead(\$buf,\%opts)
##  + gets header (ihead) offset, length from (mmaped) \$buf
##  + %opts are as for blockScan()
sub blockScanHead {
  my ($fmt,$bufr,$opts) = @_;
  my $elt = $opts->{xmlelt} || $opts->{eob} || 'w';
  return $$bufr =~ m(\Q<$elt\E\b) ? [0,$-[0]] : [0,0];
}

## \%head = blockScanFoot(\$buf,\%opts)
##  + gets footer (ifoot) offset, length from (mmaped) \$buf
##    - override works from and may alter last body block in $opts->{ibody}
##    - also uses $opts->{ifsize} to compute footer length
##  + %opts are as for blockScan()
sub blockScanFoot {
  my ($fmt,$bufr,$opts) = @_;
  return [0,0] if (!$opts || !$opts->{ibody} || !@{$opts->{ibody}});
  my $blk = $opts->{ibody}[$#{$opts->{ibody}}];
  my $elt = $opts->{xmlelt} || $opts->{eob} || 'w';
  pos($$bufr) = $blk->{ioff}; ##-- set to offset of final body block
  if ($$bufr =~ m((?:</\Q$elt\E>|<\Q$elt\E[^>]*/>)(?!.*(?:</\Q$elt\E>|<\Q$elt\E[^>]*/>)))sg) {
    my $end      = $+[0];
    $blk->{ilen} = $end - $blk->{ioff};
    return [$end, $opts->{ifsize}-$end];
  }
  return [0,0];
}

## \@blocks = $fmt->blockScanBody(\$buf,\%opts)
##  + scans $filename for block boundaries according to \%opts
sub blockScanBody {
  my ($fmt,$bufr,$opts) = @_;

  ##-- scan blocks into head, body, foot
  my $bsize  = $opts->{size};
  my $fsize  = $opts->{ifsize};
  my $elt    = $opts->{xmlelt} || $opts->{eob} || 'w';
  my $eos    = $elt eq 's' ? 1 : 0;
  my $re_s   = '(?s:<'.quotemeta($elt).'\b)';
  my $re     = qr($re_s);
  my $blocks = [];

  my ($off0,$off1,$blk);
  for ($off0=$opts->{ihead}[0]+$opts->{ihead}[1]; $off0 < $fsize; $off0=$off1) {
    push(@$blocks, $blk={ioff=>$off0, eos=>$eos});
    pos($$bufr) = ($off0+$bsize < $fsize ? $off0+$bsize : $fsize);
    if ($$bufr =~ m($re)g) {
      $off1 = $-[0];
#      if (!$eos) {
#	##-- check for eos : SLOW !!!
#	pos($$bufr) -= length($elt)+1;
#	$blk->{eos} = $$bufr =~ m((?:</?s\b[^>]*+>)(?:\s*+)\G)s ? 1 : 0;
#      }

    } else {
      $off1 = $fsize;
      $blk->{eos} = 1; ##-- for tt 
    }
    $blk->{ilen} = $off1-$off0;
  }

  return $blocks;
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

  my @stack = ([$top]);
  while (@stack) {
    ($nod,$cur) = @{pop @stack};
    $name = $nod->nodeName;
    $name = $xml2key->{$name} if (defined($xml2key->{$name}));
    next if (exists($fmt->{ignoreKeys}{$name}));

    if (isa($nod,'XML::LibXML::Element')) {
      ##-- Element
      if ($name eq 'doc') {
	##-- Element: special: DTA::CAB::Document
	$nxt = $cd = DTA::CAB::Document->new;
      }
      elsif ($name eq 's') {
	##-- Element: special: DTA::CAB::Sentence
	#$nxt = $cs = DTA::CAB::Sentence->new;
	$nxt = $cs = {tokens=>[]};
	push(@{$cd->{body}},$cs);
      }
      elsif ($name eq 'w') {
	##-- Element: special: DTA::CAB::Token
	#$nxt = $cw = DTA::CAB::Token->new;
	$nxt = $cw = {text=>undef};
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
      push(@stack, map {[$_,$nxt]} reverse($nod->childNodes), $nod->attributes);

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

## $short = $fmt->shortName()
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

    if (exists($fmt->{ignoreKeys}{$key})) {
      ;##-- ignored: skip it
    }
    elsif (!defined($val)) {
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
      $nod = $mom->addNewChild(undef,$key);
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
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::XmlNative - Datum parser|formatter: XML (native)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::XmlNative;
 
 ##========================================================================
 ## Methods
 
 $fmt = DTA::CAB::Format::XmlNative->new(%args);
 $obj = $fmt->parseNode($nod);
 $doc = $fmt->parseDocument();
 $fmt = $fmt->putDocument($doc);
 
 ##========================================================================
 ## Utilities
 
 $nod = $fmt->xmlNode($thingy,$name);
 $val = PACKAGE::_pushValue(\%hash,  $key, $val); ##-- $hash{$key}=$val;
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::XmlNative
is a L<DTA::CAB::Format|DTA::CAB::Format> subclass for document I/O
using a native XML dialect.
It inherits from L<DTA::CAB::Format::XmlCommon|DTA::CAB::Format::XmlCommon>.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlNative: Constructors etc.
=pod

=head2 Methods

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

%$fmt, %args:

 ##-- input: inherited
 xdoc => $xdoc,                          ##-- XML::LibXML::Document
 xprs => $xprs,                          ##-- XML::LibXML parser
 ##
 ##-- output: new
 arrayEltKeys => \%akey2ekey,            ##-- maps array keys to element keys for output
 arrayImplicitKeys => \%akey2undef,      ##-- pseudo-hash of array keys NOT mapped to explicit elements
 key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
 xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
 ##
 ##-- output: inherited
 encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
 level => $level,                        ##-- output formatting level (default=0)
 ##
 ##-- common: safety
 safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)

=item parseDocument

 $doc = $fmt->parseDocument();

Parses buffered XML::LibXML::Document into a buffered L<DTA::CAB::Document|DTA::CAB::Document>.

=item shortName

Returns "official" short name for this format, here just 'xml'.

=item putDocument

 $fmt = $fmt->putDocument($doc);

Formats the L<DTA::CAB::Document|DTA::CAB::Document> $doc as XML
to the in-memory buffer $fmt-E<gt>{xdoc}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::XmlNative: Package: Xml (alias)
=pod

=head2 Utilities

=over 4

=item parseNode

 $obj = $fmt->parseNode($nod);

Returns a perl object represented by the XML::LibXML::Node $nod;
attempting to map xml to perl structure "sensibly".

DTA::CAB::Datum nodes (document, sentence, token) get some additional baggage:

 _xmldata  => $data,    ##-- unparsed content (raw string)

=item xmlNode

 $nod = $fmt->xmlNode($thingy,$name);

Returns an xml node for the perl scalar $thingy using $name as its key,
used in constructing XML output documents.

=item _pushValue

 $val = PACKAGE::_pushValue(\%hash,  $key, $val); ##-- $hash{$key}=$val;
 $val = PACKAGE::_pushValue(\@array, $key, $val); ##-- push(@array,$val)

Convenience routine used by parseNode() when constructing perl data structures
from XML input.

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
L<DTA::CAB::Format::XmlCommon(3pm)|DTA::CAB::Format::XmlCommon>,
L<DTA::CAB::Format::Builtin(3pm)|DTA::CAB::Format::Builtin>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
