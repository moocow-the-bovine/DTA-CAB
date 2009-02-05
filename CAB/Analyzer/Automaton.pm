## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Automaton.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analysis automaton API

package DTA::CAB::Analyzer::Automaton;

use DTA::CAB::Analyzer;

use Gfsm;
use Encode qw(encode decode);
use IO::File;
#use File::Basename qw();
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     fstFile => $filename,    ##-- default: none
##     labFile => $filename,    ##-- default: none
##     dictFile=> $filename,    ##-- default: none
##
##     ##-- Analysis Options
##     eow            => $sym,  ##-- EOW symbol for analysis FST
##     check_symbols  => $bool, ##-- check for unknown symbols? (default=1)
##     labenc         => $enc,  ##-- encoding of labels file (default='latin1')
##     auto_connect   => $bool, ##-- whether to call $result->_connect() after every lookup   (default=0)
##     tolower        => $bool, ##-- if true, all input words will be bashed to lower-case (default=0)
##     tolowerNI      => $bool, ##-- if true, all non-initial characters of inputs will be lower-cased (default=0)
##     toupperI       => $bool, ##-- if true, initial character will be upper-cased (default=0)
##
##     ##-- Analysis objects
##     fst  => $gfst,      ##-- (child classes only) e.g. a Gfsm::Automaton object (default=new)
##     lab  => $lab,       ##-- (child classes only) e.g. a Gfsm::Alphabet object (default=new)
##     labh => \%sym2lab,  ##-- (?) label hash:  $sym2lab{$labSym} = $labId;
##     laba => \@lab2sym,  ##-- (?) label array:  $lab2sym[$labId]  = $labSym;
##     labc => \@chr2lab,  ##-- (?)chr-label array: $chr2lab[ord($chr)] = $labId;, by unicode char number (e.g. unpack('U0U*'))
##     result=>$resultfst, ##-- (child classes only) e.g. result fst
##     dict => \%dict,     ##-- exception lexicon / static cache of analyses
##
##     ##-- Profiling data
##     profile => $bool,     ##-- track profiling data? (default=0)
##     ntoks   => $ntokens,  ##-- #/tokens processed
##     ndict  = > $ndict,    ##-- #/known tokens (dict-analyzed)
##     nknown  => $nknown,   ##-- #/known tokens (dict- or fst-analyzed)
##    )
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- filenames
			      fstFile => undef,
			      labFile => undef,
			      dictFile => undef,

			      ##-- analysis objects
			      fst=>undef,
			      lab=>undef,
			      result=>undef,
			      labh=>{},
			      laba=>[],
			      labc=>[],
			      dict=>{},

			      ##-- options
			      eow            =>'',
			      check_symbols  => 1,
			      labenc         => 'latin1',
			      auto_connect   => 0,
			      tolower        => 0,
			      tolowerNI      => 0,
			      toupperI       => 0,

			      ##-- profiling
			      profile => 0,

			      ntoks   => 0,
			      ndict   => 0,
			      nknown  => 0,
			      #ncache  => 0,

			      ntoksa  => 0,
			      ndicta  => 0,
			      nknowna => 0,
			      #ncachea  => 0,

			      ##-- analysis selection
			      #analysisClass => 'DTA::CAB::Analyzer::Automaton::Analysis',
			      analyzeDst => (DTA::CAB::Utils::xml_safe_string(ref($that)||$that).'.Analysis'), ##-- default output key

			      ##-- user args
			      @_
			     );
  return $aut;
}

## $aut = $aut->clear()
sub clear {
  my $aut = shift;

  ##-- analysis sub(s)
  $aut->dropClosures();

  ##-- analysis objects
  delete($aut->{fst});
  delete($aut->{lab});
  delete($aut->{result});
  %{$aut->{labh}} = qw();
  @{$aut->{laba}} = qw();
  @{$aut->{labc}} = qw();

  ##-- profiling
  return $aut->resetProfilingData();
}

## $aut = $aut->resetProfilingData()
sub resetProfilingData {
  my $aut = shift;
  $aut->{profile} = 0;
  $aut->{ntoks} = 0;
  $aut->{ndict} = 0;
  $aut->{nknown} = 0;
  $aut->{ntoksa} = 0;
  $aut->{ndicta} = 0;
  $aut->{nknowna} = 0;
  return $aut;
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $class = $aut->fstClass()
##  + default FST class for loadFst() method
sub fstClass { return 'Gfsm::Automaton'; }

## $class = $aut->labClass()
##  + default labels class for loadLabels() method
sub labClass { return 'Gfsm::Alphabet'; }

## $bool = $aut->fstOk()
##  + should return false iff fst is undefined or "empty"
sub fstOk { return defined($_[0]{fst}) && $_[0]{fst}->n_states>0; }

## $bool = $aut->labOk()
##  + should return false iff label-set is undefined or "empty"
sub labOk { return defined($_[0]{lab}) && $_[0]{lab}->size>0; }

## $bool = $aut->dictOk()
##  + should return false iff dict is undefined or "empty"
sub dictOk { return defined($_[0]{dict}) && %{$_[0]{dict}}; }

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $aut->ensureLoaded()
##  + ensures automaton data is loaded from default files
sub ensureLoaded {
  my $aut = shift;
  my $rc  = 1;
  ##-- ensure: fst
  if ( defined($aut->{fstFile}) && !$aut->fstOk ) {
    $rc &&= $aut->loadFst($aut->{fstFile});
  }
  ##-- ensure: lab
  if ( defined($aut->{labFile}) && !$aut->labOk ) {
    $rc &&= $aut->loadLabels($aut->{labFile});
  }
  ##-- ensure: dict
  if ( defined($aut->{dictFile}) && !$aut->dictOk ) {
    $rc &&= $aut->loadDict($aut->{dictFile});
  }
  return $rc;
}

## $aut = $aut->load(fst=>$fstFile, lab=>$labFile)
sub load {
  my ($aut,%args) = @_;
  return 0 if (!grep {defined($_)} @args{qw(fst lab dict)});
  my $rc = $aut;
  $rc &&= $aut->loadFst($args{fst}) if (defined($args{fst}));
  $rc &&= $aut->loadLabels($args{lab}) if (defined($args{lab}));
  $rc &&= $aut->loadDict($args{dict}) if (defined($args{dict}));
  return $rc;
}

##--------------------------------------------------------------
## Methods: I/O: Input: FST

## $aut = $aut->loadFst($fstfile)
sub loadFst {
  my ($aut,$fstfile) = @_;
  $aut->info("loading FST file '$fstfile'");
  $aut->{fst} = $aut->fstClass->new() if (!defined($aut->{fst}));
  $aut->{fst}->load($fstfile)
    or $aut->logconfess("loadFst(): load failed for '$fstfile': $!");
  $aut->{result} = $aut->{fst}->shadow; #if (defined($aut->{result}) && $aut->{fst}->can('shadow'));
  delete($aut->{_analyze});
  return $aut;
}

##--------------------------------------------------------------
## Methods: I/O: Input: Labels

## $aut = $aut->loadLabels($labfile)
sub loadLabels {
  my ($aut,$labfile) = @_;
  $aut->info("loading labels file '$labfile'");
  $aut->{lab} = $aut->labClass->new() if (!defined($aut->{lab}));
  $aut->{lab}->load($labfile)
    or $aut->logconfess("loadLabels(): load failed for '$labfile': $!");
  $aut->parseLabels();
  delete($aut->{_analyze});
  return $aut;
}

## $aut = $aut->parseLabels()
##  + sets up $aut->{labh}, $aut->{laba}, $aut->{labc}
##  + fixes encoding difficulties in $aut->{labh}, $aut->{laba}
sub parseLabels {
  my $aut = shift;
  my $laba = $aut->{laba};
  @$laba = @{$aut->{lab}->asArray};
  my ($i);
  foreach $i (grep { defined($laba->[$_]) } 0..$#$laba) {
    $laba->[$i] = decode($aut->{labenc}, $laba->[$i]) if ($aut->{labenc});
    $aut->{labh}{$laba->[$i]} = $i;
  }
  ##-- setup labc: $labId  = $labc->[ord($c)];             ##-- single unicode characater
  ##             : @labIds = @$labc[unpack('U0U*',$s)];    ##-- batch lookup for strings (fast)
  my @csyms = grep {defined($_) && length($_)==1} @$laba;  ##-- @csyms = ($sym1, ...) s.t. each sym has len==1
  @{$aut->{labc}}[map {ord($_)} @csyms] = @{$aut->{labh}}{@csyms};
  ##
  return $aut;
}

##--------------------------------------------------------------
## Methods: I/O: Input: Dictionary

## $aut = $aut->loadDict($dictfile)
sub loadDict {
  my ($aut,$dictfile) = @_;
  $aut->info("loading dictionary file '$dictfile'");
  my $dictfh = IO::File->new("<$dictfile")
    or $aut->logconfess("::loadDict() open failed for dictionary file '$dictfile': $!");

  my $dict = $aut->{dict};
  my ($line,$word,@analyses,$entry,$aw,$a,$w);
  while (defined($line=<$dictfh>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^\s*%/);
    $line = decode($aut->{labenc}, $line) if ($aut->{labenc});
    if    ($aut->{tolower})   { $word = lc($word); }
    elsif ($aut->{tolowerNI}) { $word =~ s/^(.)(.*)$/$1\L$2\E/; }
    if    ($aut->{toupperI})  { $word = ucfirst($word); }
    ($word,@analyses) = split(/\t+/,$line);
    $dict->{$word} = $entry = [];
    foreach $aw (@analyses) {
      $a = $aw;
      if ($aw =~ /\<([\deE\+\-\.]+)\>\s*$/) {
	$w = $1;
	$a =~ s/\s*\<[\deE\+\-\.]+\>\s*$//;
      } else {
	$a = $aw;
	$w = 0;
      }
      push(@$entry, [$a,$w]);
    }
  }
  $dictfh->close;

  $aut->dropClosures();
  return $aut;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns empty list
sub noSaveKeys {
  my $that = shift;
  return ($that->SUPER::noSaveKeys, qw(dict fst lab laba labc labh result));
}

## $saveRef = $obj->savePerlRef()
##  + inherited from DTA::CAB::Persistent

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + implicitly calls $obj->clear()
sub loadPerlRef {
  my ($that,$ref) = @_;
  my $obj = $that->SUPER::loadPerlRef($ref);
  $obj->clear();
  return $obj;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##     $tok = $coderef->($tok,\%opts)
##  + analyses text $opts{src}, defaults to $tok->{text}
##  + sets output ${ $opts{dst} } = $out = [ \@analysis1, ..., \@analysisN ]
##    + $opts{dst} defaults to \$tok->{ $anl->{analyzeDst} }
##    - each \@analysisI is an array:
##      \@analysisI = [ $analysisUpperString, $analysisWeight ]
##  + if $anl->analysisClass() returned defined, $out is blessed into it
##  + implicitly loads analysis data (automaton and labels)
sub getAnalyzeTokenSub {
  my $aut = shift;

  ##-- setup common variables
  my $aclass = $aut->{analysisClass};
  my $adst   = $aut->{analyzeDst};
  my $dict   = $aut->{dict};
  my $fst    = $aut->{fst};
  my $result = $aut->{result};
  my $labc = $aut->{labc};
  my $laba = $aut->{laba};
  my @eowlab = (defined($aut->{eow}) && $aut->{eow} ne '' ? ($aut->{labh}{$aut->{eow}}) : qw());

  ##-- ananalysis options
  my @analyzeOptionKeys = qw(check_symbols auto_connect tolower tolowerNI toupperI max_paths max_weight max_ops); #)
  my $doprofile = $aut->{profile};

  my ($tok, $w,$opts,$uword,@wlabs, $isdict, $analyses);
  return sub {
    ($tok,$opts) = @_;

    ##-- set default options
    $opts->{$_} = $aut->{$_} foreach (grep {!defined($opts->{$_})} @analyzeOptionKeys);
    $aut->setLookupOptions($opts) if ($aut->can('setLookupOptions'));

    ##-- get source text ($w)
    $w = defined($opts->{src}) ? $opts->{src} : $tok->{text};

    ##-- normalize word
    $uword = $w;
    if    ($opts->{tolower})   { $uword = lc($uword); }
    elsif ($opts->{tolowerNI}) { $uword =~ s/^(.)(.*)$/$1\L$2\E/; }
    if    ($opts->{toupperI})  { $uword = ucfirst($uword); }

    ##-- check for word in dict
    if ($dict && exists($dict->{$uword})) {
      $analyses = $dict->{$uword};
      $isdict   = 1;
    }
    else {
      ##-- not in dict: fst lookup

      ##-- get labels
      if ($opts->{check_symbols}) {
	##-- verbosely
	@wlabs = (@$labc[unpack('U0U*',$uword)],@eowlab);
	foreach (grep { !defined($wlabs[$_]) } (0..$#wlabs)) {
	  $aut->warn("ignoring unknown character '", substr($uword,$_,1), "' in word '$w' (normalized to '$uword').\n");
	}
	@wlabs = grep {defined($_)} @wlabs;
      } else {
	##-- quietly
	@wlabs = grep {defined($_)} (@$labc[unpack('U0U*',$uword)],@eowlab);
      }

      ##-- fst lookup
      $aut->{fst}->lookup(\@wlabs, $result);
      $result->_connect() if ($opts->{auto_connect});
      #$result->_rmepsilon() if ($opts->{auto_rmeps});

      ##-- parse analyses
      $analyses = [
		   map {
		     [join('',
			   map {
			     length($laba->[$_]) > 1 ? "[$laba->[$_]]" : $laba->[$_]
			   } @{$_->{hi}}
			  ),
		      $_->{w}]
		   } @{$result->paths($Gfsm::LSUpper)}
		  ];
    }

    ##-- profiling
    if ($doprofile) {
      ++$aut->{ntoks};
      if (@$analyses) {
	++$aut->{nknown};
	++$aut->{ndict} if ($isdict);
      }
    }

    ##-- bless analyses
    $analyses = bless($analyses,$aclass) if (defined($aclass));

    ##-- set output
    if (defined($opts->{dst})) { ${ $opts->{dst} } = $analyses; }
    else { $tok->{$adst} = $analyses; }

    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting: OBSOLETE
##==============================================================================

1; ##-- be happy

__END__
