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
	if ($field =~ m/^\+xlit: isLatin1=(\d) isLatinExt=(\d) latin1Text=(.*)$/) {
	  ##-- token: field: xlit
	  $tok->{xlit} = [$3,$1,$2];
	}
	elsif ($field =~ m/^\+lts: (.*) \<([\d\.\+\-eE]+)\>$/) {
	  ##-- token: field: lts analysis
	  $tok->{lts} = [] if (!$tok->{lts});
	  push(@{$tok->{lts}}, [$1,$2]);
	}
	elsif ($field =~ m/^\+lts\/text: (.*)$/) {
	  ##-- token: field: lts input text (normalized)
	  $tok->{ltsText} = $1;
	}
	elsif ($field =~ m/^\+morph: (.*) \<([\d\.\+\-eE]+)\>$/) {
	  ##-- token: field: morph analysis
	  $tok->{morph} = [] if (!$tok->{morph});
	  push(@{$tok->{morph}}, [$1,$2]);
	}
	elsif ($field =~ m/^\+morph.safe: (\d)$/) {
	  ##-- token: field: morph-safety check
	  $tok->{msafe} = $1;
	}
	elsif ($field =~ m/^\+rw: (.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: field: rewrite target
	  $tok->{rw} = [] if (!$tok->{rw});
	  push(@{$tok->{rw}}, $rw=[$1,$2]);
	}
	elsif ($field =~ m/^\+rw\/morph: (.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: morph analysis of rewrite target
	  $tok->{rw} = [ [] ] if (!$tok->{rw});
	  $rw        = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
	  $rw->[2]   = [] if (!$rw->[2]);
	  push(@{$rw->[2]}, [$1,$2]);
	}
	elsif ($field =~ m/^\+rw\/lts: (.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: LTS analysis of rewrite target
	  $tok->{rw} = [ [] ] if (!$tok->{rw});
	  $rw        = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
	  $rw->[3]   = [] if (!$rw->[3]);
	  push(@{$rw->[3]}, [$1,$2]);
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

  my $PR='+';
  my $EQ=': ';
  my $SUBEQ='=';
  my $SP=' ';

  ##-- Transliterator ('xlit')
  $out .= "\t+xlit: isLatin1=$tok->{xlit}[1] isLatinExt=$tok->{xlit}[2] latin1Text=$tok->{xlit}[0]"
    if (defined($tok->{xlit}));

  ##-- LTS ('lts')
  $out .= "\t+lts/text: $tok->{ltsText}" if (defined($tok->{ltsText}));
  $out .= join('', map { "\t+lts: $_->[0] <$_->[1]>" } @{$tok->{lts}}) if ($tok->{lts});

  ##-- Morph ('morph')
  $out .= join('', map { "\t+morph: $_->[0] <$_->[1]>" } @{$tok->{morph}}) if ($tok->{morph});

  ##-- MorphSafe ('morph.safe')
  $out .= "\t/morph.safe=".($tok->{msafe} ? 1 : 0) if (exists($tok->{msafe}));

  ##-- Rewrites + analyses
  $out .= join('',
	       map {
		 ("\t+rw: $_->[0] <$_->[1]>",
		  ($_->[3] ? map { "\t+rw/lts: $_->[0] <$_->[1]>" } @{$_->[3]} : qw()),
		  ($_->[2] ? map { "\t+rw/morph: $_->[0] <$_->[1]>" } @{$_->[2]} : qw()),
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
