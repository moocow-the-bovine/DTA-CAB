## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlTokWrap.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: XML (tokwrap), fast quick & dirty output

package DTA::CAB::Format::XmlTokWrapFast;
use DTA::CAB::Format::XmlTokWrap;
use DTA::CAB::Datum ':all';
use Encode qw(encode_utf8 decode_utf8);
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlTokWrap);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/(?:\.(?i:f[tuws](?:\.?)xml))$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_) foreach (qw(ftxml ft-xml ftwxml ftw-xml));
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
##     ##-- output: inherited from TokWrapXml
##     arrayEltKeys => \%akey2ekey,            ##-- maps array keys to element keys for output
##     arrayImplicitKeys => \%akey2undef,      ##-- pseudo-hash of array keys NOT mapped to explicit elements
##     key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
##     xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
##     ##
##     ##-- output: inherited from TokWrapXml
##     encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common: safety
##     safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(@_);
  return $fmt;
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
  return 'ftxml';
}

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format (default='.ft.xml')
sub defaultExtension { return '.ft.xml'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  delete($_[0]{outbuf});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
sub toString {
  $_[0]{outbuf} = '' if (!defined($_[0]{outbuf}));
  return encode($_[0]{encoding},$_[0]{outbuf}) if (utf8::is_utf8($_[0]{outbuf}));
  return $_[0]{outbuf};
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
sub toFh {
  my ($fmt,$fh,$level) = @_;
  return $fmt if (!defined($fmt->{outbuf}));
  binmode($fh, (utf8::is_utf8($fmt->{outbuf}) ? ':utf8' : ':raw'));
  $fh->print($fmt->{outbuf}) || return undef;
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Output: quick and dirty

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  my ($fmt,$doc) = @_;

  ##--------------------
  ## local subs

  my $nil = [];

  ##-- $escaped = xmlesc($str) : xml escape (single string)
  my ($_esc);
  my $xmlescape = sub {
    $_esc=shift;
    $_esc=~s/([\&\'\"\<\>])/'&#'.ord($1).';'/ge;
    return $_esc;
  };

  ##-- $str = xmlattrs(%attrs)
  my $xmlattrs = sub {
    return join('', map {' '.$_[$_].'="' . $xmlescape->($_[$_+1]).'"'} grep {defined($_[$_+1])} map {$_*2} (0..$#{_}/2));
  };

  ##-- $str = xmlstart($name,%attrs)
  my $xmlstart = sub {
    return "<$_[0]" . $xmlattrs->(@_[1..$#_]) . ">";
  };

  ##-- $str = xmlempty($name,%attrs)
  my $xmlempty = sub {
    return "<$_[0]" . $xmlattrs->(@_[1..$#_]) . "/>";
  };

  ##-- $str = xmlelt($name,\@attrs,@content_strings)
  my $xmlelt = sub {
    return $xmlempty->($_[0], @{$_[1]||$nil}) if (@_ < 3);
    return $xmlstart->($_[0], @{$_[1]||$nil}) . join('',@_[2..$#_]) . "</$_[0]>";
  };

  ##-- $str = fstelt($name,$aname,\@analyses)
  my ($_fsta);
  my $fstelt = sub {
    return '' if (!$_[2]);
    return $xmlelt->($_[0],$nil,
		     map {
		       $_fsta=$_;
		       $xmlempty->(($_[1]||'a'), map {($_=>$_fsta->{$_})} qw(lo lemma hi w))
		     } @{$_[2]}
		    );
  };

  ##-- $str = mootelt($name,$aname,\%data)
  my ($_moota);
  my $mootelt = sub {
    return '' if (!$_[2]);
    return $xmlelt->($_[0],[word=>$_[2]{word},tag=>$_[2]{tag},lemma=>$_[2]{lemma}],
		     #$fstelt->('morph', 'a', $_[2]{morph})
		     ##
		     #(!$_[2]{analyses} || !@{$_[2]{analyses}} ? qw()
		     # : $xmlelt->('analyses',$nil,
		     #	  map {
		     #	    $_moota=$_;
		     #	    $xmlempty->(($_[1]||'a'), map {($_=>$_moota->{$_})} qw(tag lemma prob details))
		     #	  } @{$_[2]{analyses}}))
		    );
  };


  ##--------------------
  ## output buffer
  my $outbufr = \$fmt->{outbuf};
  $$outbufr = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";

  ##--------------------
  ## guts
  my ($s,$w);
  $$outbufr .= "\n" . $xmlstart->('doc', base=>$doc->{base});
  foreach $s (@{$doc->{body}}) {
    $$outbufr .= "\n\t" . $xmlstart->('s',id=>$s->{id});
    foreach $w (@{$s->{tokens}}) {
      $$outbufr .= ("\n\t\t"
		    . $xmlelt->('w',
				[
				 ##-- word attributes: literals
				 (t=>$w->{text}),
				 (map {$_=>$w->{$_}} qw(u id exlex pnd mapclass errid xc xr xp pb lb bb c coff clen b boff blen msafe)),
				],
				##
				##-- content: tokenizer analyses
				#(map {$xmlelt->('a',$nil,$xmlescape->($w->{$_}))} @{$w->{toka}||$nil}),
				#($w->{tokpp} && @{$w->{tokpp}} ? $xmlelt->('tokpp',$nil,map {xmlelt('a',$nil,$xmlescape->($_))} @{$w->{tokpp}}) : qw()),
				##
				##-- content: xlit
				#($w->{xlit} ? $xmlempty->('xlit',%{$w->{xlit}}) : qw()),
				##
				##-- content: fsts
				#(map {$fstelt->($_,'a',$w->{$_})} qw(lts morph rw mlatin eqpho eqrw)),
				##
				##-- content: moot
				#$mootelt->('dmoot','a',$w->{dmoot}),
				$mootelt->('moot','a',$w->{moot}),
			       ));
    }
    $$outbufr .= "\n\t</s>";
  }
  $$outbufr .= "\n</doc>\n";

  return $fmt;
}


1; ##-- be happy

__END__
