## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Raw.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: one-token-per-line text

package DTA::CAB::Format::Raw;
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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:raw)$/);
}

## %ABBREVS
##  + default abbreviations
##  + set below
our (%ABBREVS);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    {
##     ##-- Input
##     doc => $doc,                    ##-- buffered input document
##     abbrevs => \%abbrevs,           ##-- hash of known abbrevs (default: \%ABBREVS)
##
##     ##-- Output
##     outbuf    => $stringBuffer,     ##-- buffered output: DISABLED
##     #level    => $formatLevel,      ##-- n/a
##
##     ##-- Common
##     encoding => $inputEncoding,     ##-- default: UTF-8, where applicable
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   doc => undef,
		   abbrevs => \%ABBREVS,

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
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

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
##  + select input from string $string
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parseRawString($_[0]);
}

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseRawString($str)
##  + guts for fromString(): parse string $str into local document buffer.
sub parseRawString {
  my ($fmt,$src) = @_;
  $src = decode($fmt->{encoding},$src) if ($fmt->{encoding} && !utf8::is_utf8($src));

  ##-- step 1: basic tokenization
  my (@toks);
  while ($src =~ m/(
		     (?:([[:alpha:]\-\#]+)[\-\¬](?:\n\s*)([[:alpha:]\-\#]+))   ##-- line-broken alphabetics
		   | (?i:[IVXLCDM\#]+\.)                           ##-- dotted roman numerals (hack)
		   | (?:[[:alpha:]\#]\.)                           ##-- dotted single-letter abbreviations
		   | (?:[[:digit:]\#]+[[:alpha:]\#]+)              ##-- numbers with optional alphabetic suffixes
		   | (?:[\-\+]?[[:digit:]\#]*[[:digit:]\,\.\#]+)   ##-- comma- and\/or dot-separated numbers
		   | (?:\,\,|\`\`|\'\'|\-+|\_+|\.\.+)              ##-- special punctuation sequences
		   | (?:[[:alpha:]\-\¬\#]+)                        ##-- "normal" alphabetics (with "#" ~= unknown)
		   | (?:[[:punct:]]+)                              ##-- "normal" punctuation characters
		   | (?:[^[:punct:][:digit:][:space:]]+)           ##-- "normal" alphabetic tokens
		   | (?:\S+)                                       ##-- HACK: anything else
		   )
		  /xsg)
    {
      push(@toks, (defined($2) ? "$2$3" : $1));
    }

  ##-- step 2: abbreviation & eos detection
  my $abbrevs = $fmt->{abbrevs};
  my $s     = [];
  my @sents = ($s);
  my ($toki);
  for ($toki=0; $toki <= $#toks; $toki++) {
    if (exists($abbrevs->{$toks[$toki]}) && $toki < $#toks && $toks[$toki+1] eq '.') {
      ##-- abbreviation
      push(@$s, "$toks[$toki].");
      $toki++;
    }
    elsif ($toks[$toki] =~ /^[\.\?\!]+$/) {
      ##-- sentence-final punctuation
      push(@$s, $toks[$toki]);
      push(@sents, $s=[]);
    }
    else {
      ##-- normal token
      push(@$s, $toks[$toki]);
    }
  }
  pop(@sents) if (!@{$sents[$#sents]});

  ##-- step 3: build doc
  foreach (@sents) {
    @$_ = map {bless({text=>$_},'DTA::CAB::Token')} @$_;
  }
  $fmt->{doc} = bless({body=>[map {bless({tokens=>$_},'DTA::CAB::Sentence')} @sents]}, 'DTA::CAB::Document');
  return $fmt;
}


##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument { return $_[0]{doc}; }


##==============================================================================
## Methods: Output
##  + nothing here
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.raw'; }


##==============================================================================
## Initialization
BEGIN {
  ## @ABBREVS: most frequent 128 abbreviations from DTA (as of Wed, 01 Dec 2010 11:26:04 +0100)
  ##  + derived from file ../automata/eqlemma/dta-abbrevs.nontrivial.tfa
  ##    - itself derived by hand from ../automata/eqlemma/cab.toka.db, ../automata/words/dta-words.tf
  ##      using Lingua::TT hackery and Data::Dumper
  my @ABBREVS =
    (
     'Abb',
     "Ab\x{17f}",
     'Anm',
     'Ann',
     'Arch',
     'Art',
     'Aufl',
     'Bd',
     'Bde',
     'Br',
     'Cap',
     'Ch',
     'Chr',
     'Co',
     'Cod',
     'Ctr',
     "Di\x{17f}\x{17f}",
     'Dr',
     'Ew',
     'Fig',
     'Fr',
     "Ge\x{17f}",
     "Ge\x{17f}ch",
     'Gr',
     'Hist',
     'Hr',
     'Hrn',
     'Jahrh',
     'Journ',
     'Kap',
     'Kilogr',
     "K\x{f6}nigl",
     'Lib',
     'Lit',
     'Matth',
     'Mill',
     'Mr',
     'No',
     'Nov',
     'Nr',
     'Num',
     'Ol',
     'Pal',
     'Pf',
     'Pfd',
     'Pfr',
     'Plut',
     'Prof',
     'Proz',
     "Re\x{17f}cr",
     'Sal',
     'Sept',
     'Sr',
     'St',
     'StGB',
     'Staatsr',
     'Str',
     'Tab',
     'Taf',
     'Th',
     'Thl',
     'Thlr',
     'Tit',
     'Tom',
     'Verf',
     'Vergl',
     'Vgl',
     'Vol',
     'Zeitschr',
     'Ziff',
     'acc',
     'adj',
     "ag\x{17f}",
     'ahd',
     'altn',
     "angel\x{17f}",
     'art',
     'betr',
     'cap',
     'cit',
     'dat',
     'dergl',
     'dgl',
     'diss',
     'ed',
     'engl',
     'eod',
     'etc',
     'fem',
     'ff',
     'fg',
     'fig',
     'fl',
     'fr',
     'geb',
     'gl',
     'goth',
     'gr',
     'griech',
     'jun',
     'ker',
     'lat',
     'lib',
     'lit',
     "ma\x{17f}c",
     'med',
     'mhd',
     'min',
     'nat',
     'neutr',
     'nhd',
     'nom',
     'pag',
     'part',
     'pl',
     'pr',
     'praes',
     'praet',
     "prae\x{17f}",
     'resp',
     'sing',
     'tab',
     'urspr',
     'vergl',
     'vgl',
     "zu\x{17f}",
     "\x{17f}t",
     "\x{17f}ub\x{17f}t",

     "usw",
    );

  %ABBREVS = map {($_=>undef)} @ABBREVS;
}



1; ##-- be happy

__END__
