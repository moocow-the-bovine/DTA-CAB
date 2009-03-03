## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TT.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: one-token-per-line text

package DTA::CAB::Format::TT;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:t|tt|ttt)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    {
##     ##-- Input
##     doc => $doc,                    ##-- buffered input document
##
##     ##-- Output
##     outbuf    => $stringBuffer,     ##-- buffered output
##     #level    => $formatLevel,      ##-- n/a
##
##     ##-- Common
##     encoding => $inputEncoding,     ##-- default: UTF-8, where applicable
##    }
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   doc => undef,

		   ##-- output
		   #outbuf => '',

		   ##-- common
		   encoding => 'UTF-8',

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
##  + default just returns empty list
sub noSaveKeys {
  return qw(doc outbuf);
}

##==============================================================================
## Methods: Parsing
##==============================================================================

##--------------------------------------------------------------
## Methods: Parsing: Input selection

## $fmt = $fmt->close()
sub close {
  delete($_[0]{doc});
  return $_[0];
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($filename_or_handle)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parseTTString($_[0]);
}

##--------------------------------------------------------------
## Methods: Parsing: Local

sub parseTTString {
  my ($fmt,$src) = @_;
  $src = decode($fmt->{encoding},$src) if ($fmt->{encoding} && !utf8::is_utf8($src));

  my (@sents,$tok,$rw,$line);
  my ($text,@fields,$field);
  my $s = [];
  while ($src =~ m/^(.*)$/mg) {
    $line = $1;
    if ($line =~ /^\%\%/) {
      ##-- comment line; skip
      next;
    }
    elsif ($line eq '') {
      ##-- blank line: eos
      push(@sents,$s) if (@$s);
      $s = [];
    }
    else {
      ##-- token
      ($text,@fields) = split(/\t/,$line);
      push(@$s, $tok=bless({text=>$text},'DTA::CAB::Token'));
      foreach $field (@fields) {
	if ($field =~ m/^\[xlit\] (?:isLatin1|l1)=(\d) (?:isLatinExt|lx)=(\d) (?:latin1Text|l1s)=(.*)$/) {
	  ##-- token: field: xlit
	  $tok->{xlit} = [$3,$1,$2];
	}
	elsif ($field =~ m/^\[lts\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
	  ##-- token: field: lts analysis (no lower)
	  $tok->{lts} = [] if (!$tok->{lts});
	  push(@{$tok->{lts}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[eqpho\] (.*)$/) {
	  ##-- token: field: phonetic equivalent
	  $tok->{eqpho} = [] if (!$tok->{eqpho});
	  push(@{$tok->{eqpho}}, $1);
	}
	elsif ($field =~ m/^\[morph\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
	  ##-- token: field: morph analysis
	  $tok->{morph} = [] if (!$tok->{morph});
	  push(@{$tok->{morph}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[morph\/safe\] (\d)$/) {
	  ##-- token: field: morph-safety check (morph/safe)
	  $tok->{msafe} = $1;
	}
	elsif ($field =~ m/^\[rw\] (?:((?:\\.|[^:])*) : )?(.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: field: rewrite target
	  $tok->{rw} = [] if (!$tok->{rw});
	  push(@{$tok->{rw}}, $rw={(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[rw\/lts\] (?:((?:\\.|[^:])*) : )?(.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: LTS analysis of rewrite target
	  $tok->{rw} = [ {} ] if (!$tok->{rw});
	  $rw        = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
	  $rw->{lts} = [] if (!$rw->{lts});
	  push(@{$rw->{lts}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[rw\/morph\] (?:((?:\\.|[^:])*) : )?(.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: morph analysis of rewrite target
	  $tok->{rw}   = [ {} ] if (!$tok->{rw});
	  $rw          = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
	  $rw->{morph} = [] if (!$rw->{morph});
	  push(@{$rw->{morph}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	else {
	  ##-- unknown
	  $fmt->warn("parseDocument(): could not parse token field '$field' for token '$text'");
	}
      }
    }
  }
  push(@sents,$s) if (@$s); ##-- final sentence

  ##-- construct & buffer document
  $fmt->{doc} = bless({body=>[ map { bless({tokens=>$_},'DTA::CAB::Sentence') } @sents ]}, 'DTA::CAB::Document');
  return $fmt;
}


##--------------------------------------------------------------
## Methods: Parsing: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument { return $_[0]{doc}; }


##==============================================================================
## Methods: Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  delete($_[0]{outbuf});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
sub toString {
  return encode($_[0]{encoding},$_[0]{outbuf})
    if ($_[0]{encoding} && defined($_[0]{outbuf}) && utf8::is_utf8($_[0]{outbuf}));
  return $_[0]{outbuf};
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)


##--------------------------------------------------------------
## Methods: Formatting: Generic API

## $fmt = $fmt->putToken($tok)
sub putToken {
  my ($fmt,$tok) = @_;
  my $out = $tok->{text};

  ##-- Transliterator ('xlit')
  $out .= "\t[xlit] l1=$tok->{xlit}[1] lx=$tok->{xlit}[2] l1s=$tok->{xlit}[0]"
    if (defined($tok->{xlit}));

  ##-- LTS ('lts')
  $out .= join('', map { "\t[lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{lts}})
    if ($tok->{lts});

  ##-- Phonetic Equivalents ('eqpho')
  $out .= join('', map { "\t[eqpho] $_" } grep {defined($_)} @{$tok->{eqpho}})
    if ($tok->{eqpho});

  ##-- Morph ('morph')
  $out .= join('', map { "\t[morph] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{morph}})
    if ($tok->{morph});

  ##-- MorphSafe ('morph/safe')
  $out .= "\t[morph/safe] ".($tok->{msafe} ? 1 : 0) if (exists($tok->{msafe}));

  ##-- Rewrites + analyses
  $out .= join('',
	       map {
		 ("\t[rw] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>",
		  (##-- rw/lts
		   $_->{lts}
		   ? map { "\t[rw/lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$_->{lts}}
		   : qw()),
		  (##-- rw/morph
		   $_->{morph}
		   ? map { "\t[rw/morph] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$_->{morph}}
		   : qw()),
		 )
	       } @{$tok->{rw}})
    if ($tok->{rw});

  ##-- ... ???
  $fmt->{outbuf} .= $out."\n";
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
##  + default version just concatenates formatted tokens
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->putToken($_) foreach (@{toSentence($sent)->{tokens}});
  $fmt->{outbuf} .= "\n";
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
##  + default version just concatenates formatted sentences
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->putSentence($_) foreach (@{toDocument($doc)->{body}});
  return $fmt;
}


1; ##-- be happy

__END__
