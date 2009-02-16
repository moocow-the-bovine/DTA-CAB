## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser::Text.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: verbose human-readable text

package DTA::CAB::Parser::Text;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Parser);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- new here
##     doc => $doc,                          ##-- buffered input document
##
##     ##---- INHERITED from DTA::CAB::Parser
##     encoding => $inputEncoding,             ##-- default: UTF-8, where applicable
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   doc => undef,
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
  return qw(doc);
}

##=============================================================================
## Methods: Parsing: Input selection
##==============================================================================

## $prs = $prs->close()
sub close {
  delete($_[0]{doc});
  return $_[0];
}

## $prs = $prs->fromFile($filename_or_handle)
##  + default calls $prs->fromFh()

## $prs = $prs->fromFh($fh)
##  + default calls $prs->fromString() on file contents

## $prs = $prs->fromString($string)
sub fromString {
  my $prs = shift;
  $prs->close();
  return $prs->parseTextString($_[0]);
}

##==============================================================================
## Methods: Parsing: Local
##==============================================================================

sub parseTextString {
  my ($prs,$src) = @_;
  $src = decode($prs->{encoding},$src) if ($prs->{encoding} && !utf8::is_utf8($src));

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
      $prs->warn("parseTextString(): could not parse line '$line'");
    }
  }
  push(@sents,$s) if (@$s); ##-- final sentence

  ##-- construct & buffer document
  $prs->{doc} = bless({body=>[ map { bless({tokens=>$_},'DTA::CAB::Sentence') } @sents ]}, 'DTA::CAB::Document');

  return $prs;
}


##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $doc = $prs->parseDocument()
sub parseDocument { return $_[0]{doc}; }

1; ##-- be happy

__END__
