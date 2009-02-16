## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Text.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: verbose human-readable text

package DTA::CAB::Format::Text;
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

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- Input
##     doc => $doc,                    ##-- buffered input document
##
##     ##---- Output
##     #level    => $formatLevel,      ##-- output formatting level: n/a
##     outbuf    => $stringBuffer,     ##-- buffered output
##
##     ##---- Common
##     encoding  => $encoding,         ##-- default: 'UTF-8'
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   doc => undef,

		   ##-- output
		   outbuf  => '',

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

## $fmt = $fmt->fromFh($fh)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parseTextString($_[0]);
}

##--------------------------------------------------------------
## Methods: Parsing: Local

sub parseTextString {
  my ($fmt,$src) = @_;
  $src = decode($fmt->{encoding},$src) if ($fmt->{encoding} && !utf8::is_utf8($src));

  my (@sents,$tok,$rw,$line);
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
    elsif ($line =~ /^(\S.*)/) {
      ##-- new token: text
      push(@$s, $tok=bless({text=>$1},'DTA::CAB::Token'));
    }
    elsif ($line =~ m/^\txlit: isLatin1=(\d) isLatinExt=(\d) latin1Text=(.*)$/) {
      ##-- token: xlit
      $tok->{xlit} = [$3,$1,$2];
    }
    elsif ($line =~ m/^\tmorph: (.*\S) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: morph analysis
      $tok->{morph} = [] if (!$tok->{morph});
      push(@{$tok->{morph}}, [$1,$2]);
    }
    elsif ($line =~ m/^\tlts: (.*\S) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: lts analysis
      $tok->{lts} = [] if (!$tok->{lts});
      push(@{$tok->{lts}}, [$1,$2]);
    }
    elsif ($line =~ m/^\tmorph.safe: (\d)$/) {
      ##-- token: field: morph-safety check
      $tok->{msafe} = $1;
    }
    elsif ($line =~ m/^\trw: (.*\S) <([\d\.\+\-eE]+)>$/) {
      ##-- token: field: rewrite target
      $tok->{rw} = [] if (!$tok->{rw});
      push(@{$tok->{rw}}, $rw=[$1,$2]);
    }
    elsif ($line =~ m/^\t\tmorph\/rw: (.*\S) <([\d\.\+\-eE]+)>$/) {
      ##-- token: field: morph analysis of rewrite target
      $tok->{rw} = [ [] ] if (!$tok->{rw});
      $rw        = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
      $rw->[2]   = [] if (!$rw->[2]);
      push(@{$rw->[2]}, [$1,$2]);
    }
    else {
      ##-- unknown
      $fmt->warn("parseTextString(): could not parse line '$line'");
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
##  + returns formatted token $tok
sub putToken {
  my ($fmt,$tok) = @_;
  my $out = $tok->{text}."\n";

  ##-- Transliterator ('xlit')
  $out .= ("\txlit:"
	   ." isLatin1=".$tok->{xlit}[1]
	   ." isLatinExt=".$tok->{xlit}[2]
	   ." latin1Text=".$tok->{xlit}[0]
	   ."\n")
    if (defined($tok->{xlit}));

  ##-- LTS ('lts')
  $out .= join('', map { "\tlts: $_->[0] <$_->[1]>\n" } @{$tok->{lts}}) if ($tok->{lts});

  ##-- Morph ('morph')
  $out .= join('', map { "\tmorph: $_->[0] <$_->[1]>\n" } @{$tok->{morph}}) if ($tok->{morph});

  ##-- MorphSafe ('morph.safe')
  $out .= "\tmorph.safe: ".($tok->{msafe} ? 1 : 0)."\n" if (exists($tok->{msafe}));

  ##-- Rewrites + analyses
  $out .= join('',
	       map {
		 ("\trw: $_->[0] <$_->[1]>\n",
		  ($_->[2] ? map { "\t\tmorph/rw: $_->[0] <$_->[1]>\n" } @{$_->[2]} : qw()))
	       } @{$tok->{rw}})
    if ($tok->{rw});

  $fmt->{outbuf} .= $out;
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

## $out = $fmt->formatDocument($doc)
##  + default version just concatenates formatted sentences
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->putSentence($_) foreach (@{toDocument($doc)->{body}});
  return $fmt;
}

1; ##-- be happy

__END__
