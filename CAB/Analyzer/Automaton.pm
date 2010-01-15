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

## $DEFAULT_ANALYZE_GET
##  + default coderef or eval-able string for {analyzeGet}
##  + eval()d in list context, may return multiples
##  + parameters:
##      $_[0] => token object being analyzed
##  + closure vars:
##      $anl  => analyzer (automaton)
our $DEFAULT_ANALYZE_GET = '$_[0]{xlit} ? $_[0]{xlit}{latin1Text} : $_[0]{text}';

## $DEFAULT_ANALYZE_SET
##  + default coderef or eval-able string for {analyzeSet}
##  + parameters:
##      $_[0] => token object being analyzed
##      $_[1] => blessed analyses (array-ref, maybe blessed)
##  + closure vars:
##      $anl  => analyzer (automaton)
our $DEFAULT_ANALYZE_SET = '$_[0]{$anl->{label}}=$_[1]';

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
##     ##-- Analysis Output
##     aclass         => $class, ##-- analysis class (OVERRIDE default: 'DTA::CAB::Analysis::Automaton')
##     analyzeGet     => $code,  ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET; return undef for no analysis)
##     analyzeSet     => $code,  ##-- accessor: coderef or string: set analyses (default=$DEFAULT_ANALYZE_SET)
##     wantAnalysisLo => $bool,  ##-- set to true to include 'lo' keys in analyses (default: true)
##
##     ##-- Analysis Options
##     eow            => $sym,  ##-- EOW symbol for analysis FST
##     check_symbols  => $bool, ##-- check for unknown symbols? (default=1)
##     labenc         => $enc,  ##-- encoding of labels file (default='latin1')
##     dictenc        => $enc,  ##-- dictionary encoding (default='UTF-8')
##     auto_connect   => $bool, ##-- whether to call $result->_connect() after every lookup   (default=0)
##     tolower        => $bool, ##-- if true, all input words will be bashed to lower-case (default=0)
##     tolowerNI      => $bool, ##-- if true, all non-initial characters of inputs will be lower-cased (default=0)
##     toupperI       => $bool, ##-- if true, initial character will be upper-cased (default=0)
##     bashWS         => $str,  ##-- if defined, input whitespace will be bashed to '$str' (default='_')
##     attInput       => $bool, ##-- if true, respect AT&T lextools-style escapes in input (default=0)
##     allowTextRegex => $re,   ##-- if defined, only tokens with matching 'text' will be analyzed (default: none)
##                              ##   : useful: /(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)/
##     allowWordRegex => $re,   ##-- if defined, only source strings matching $re will be analyzed (default: none)
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
##     ##-- INHERITED from DTA::CAB::Analyzer
##     label => $label,    ##-- analyzer label (default: from analyzer class name)
##     aclass => $class,   ##-- analysis class (default: from analyzer class name)
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
			      dictenc        => 'utf8',
			      auto_connect   => 0,
			      tolower        => 0,
			      tolowerNI      => 0,
			      toupperI       => 0,
			      bashWS         => '_',
			      attInput       => 0,
			      allowTextRegex => undef, #'(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)',
			      allowWordRegex => undef,

			      ##-- analysis I/O
			      aclass     => undef,
			      analyzeSrc => 'text',
			      wantAnalysisLo => 1,

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
sub dictOk { return defined($_[0]{dict}) && scalar(%{$_[0]{dict}}); }

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

  my $enc  = $aut->{dictenc};
  $enc     = $aut->{labenc} if (!defined($enc));
  #$enc     = 'UTF-8' if (!defined($enc));  ##-- default encoding (use perl native if commented out)

  my $dict = $aut->{dict};
  my ($line,$word,@analyses,$entry,$aw,$a,$w);
  while (defined($line=<$dictfh>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^\s*%/);
    $line = decode($enc, $line) if ($enc);
    ($word,@analyses) = split(/\t+/,$line);
    if    ($aut->{tolower})   { $word = lc($word); }
    elsif ($aut->{tolowerNI}) { $word =~ s/^(.)(.*)$/$1\L$2\E/; }
    if    ($aut->{toupperI})  { $word = ucfirst($word); }
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
      push(@$entry, {hi=>$a,w=>$w});
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
## Methods: Analysis: Generic

## $bool = $anl->canAnalyze()
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
sub canAnalyze {
  return $_[0]->dictOk || ($_[0]->labOk && $_[0]->fstOk);
}


##==============================================================================
## Methods: Analysis: v1.x
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Closure Utilities (optional)

## $closure = $anl->getAnalyzeWordClosure()
##  + re-computes closure $closure for analyzing single words
##  + returned closure is callable as:
##      $analyses = $closure->($textString,\%analyzeOpts)
##  + returned analyses have the form:
##      [ \%analysis1, ..., \%analysisN ]
##    - each \%analysisI is a HASH:
##      \%analysisI = { lo=>$analysisLowerString, hi=>$analysisUpperString, w=>$analysisWeight, ... }
##    - if $opts->{wantAnalysisLo} is true, 'lo' key will be included in any %analysisI, otherwise not (default)
##  + implicitly loads analysis data (automaton and labels)
sub getAnalyzeWordClosure {
  my $aut = shift;

  ##-- load
  $aut->ensureLoaded();

  ##-- setup common variables
  my $aclass = $aut->analysisClass;
  my $dict   = $aut->{dict};
  my $fst    = $aut->{fst};
  my $fst_ok = $aut->fstOk();
  my $result = $aut->{result};
  my $lab    = $aut->{lab};
  my $labc   = $aut->{labc};
  my $laba   = $aut->{laba};
  my $labenc = $aut->{labenc};
  my @eowlab = (defined($aut->{eow}) && $aut->{eow} ne '' ? ($aut->{labh}{$aut->{eow}}) : qw());

  my $allowWordRegex = defined($aut->{allowWordRegex}) ? qr($aut->{allowWordRegex}) : undef;

  ##-- ananalysis options
  my @analyzeOptionKeys = (qw(check_symbols auto_connect),
			   qw(tolower tolowerNI toupperI bashWS attInput),
			   qw(wantAnalysisLo max_paths max_weight max_ops),
			  );

  my ($w,$opts,$uword,$ulword,@wlabs, $analyses);
  return sub {
    ($w,$opts) = @_;

    ##-- maybe ignore this token
    return undef if (defined($allowWordRegex) && $w !~ $allowWordRegex);

    $opts = $opts ? {%$opts} : {}; ##-- ensure $opts hash exists: copy / create
    $opts->{src} = $w;             ##-- set $opts->{src} (hack for setLookupOptions())

    ##-- set default options
    $opts->{$_} = $aut->{$_} foreach (grep {!defined($opts->{$_})} @analyzeOptionKeys);
    $aut->setLookupOptions($opts) if ($aut->can('setLookupOptions'));
    $analyses = [];

    ##---- analyze
    ##-- normalize word
    $uword = $w;
    if    ($opts->{tolower})   { $uword = lc($uword); }
    elsif ($opts->{tolowerNI}) { $uword =~ s/^(.)(.*)$/$1\L$2\E/; }
    if    ($opts->{toupperI})  { $uword = ucfirst($uword); }
    if    (defined($opts->{bashWS})) { $uword =~ s/\s+/$opts->{bashWS}/g; }

    ##-- check for (normalized) word in dict
    if ($dict && exists($dict->{$uword})) {
      push(@$analyses, @{$dict->{$uword}});
    }
    elsif ($fst_ok) {
      ##-- not in dict: fst lookup (if fst is kosher)

      ##-- get labels
      if ($opts->{attInput}) {
	##-- get labels: att-style (requires gfsm v0.0.10-pre11, gfsm-perl v0.0217)
	$ulword = $uword;
	utf8::downgrade($ulword);
	@wlabs = (@{$lab->string_to_labels($ulword, $opts->{check_symbols}, 1)}, @eowlab);
      }
      elsif ($opts->{check_symbols}) {
	##-- get labels: by character: verbose
	@wlabs = (@$labc[unpack('U0U*',$uword)],@eowlab);
	foreach (grep { !defined($wlabs[$_]) } (0..$#wlabs)) {
	  $aut->warn("ignoring unknown character '", substr($uword,$_,1), "' in word '$w' (normalized to '$uword').\n");
	}
	@wlabs = grep {defined($_)} @wlabs;
      }
      else {
	##-- get labels: by character: quiet
	@wlabs = grep {defined($_)} (@$labc[unpack('U0U*',$uword)],@eowlab);
      }

      ##-- fst lookup
      $aut->{fst}->lookup(\@wlabs, $result);
      $result->_connect() if ($opts->{auto_connect});
      #$result->_rmepsilon() if ($opts->{auto_rmeps});

      ##-- parse analyses
      push(@$analyses,
	   map {
	     {(
	       ($opts->{wantAnalysisLo} ? (lo=>$uword) : qw()),
	       'hi'=> (defined($labenc)
		       ? decode($labenc,$lab->labels_to_string($_->{hi},0,1))
		       : $lab->labels_to_string($_->{hi},0,1)),
	       'w' => $_->{w},
	      )}
	   } @{$result->paths($Gfsm::LSUpper)}
	  );
    }
    #else { ; } ##-- no dictionary entry and no FST: do nothing

    return undef if (!@$analyses);
    return $aclass ? bless($analyses,$aclass) : $analyses;
  };
}


## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in %types (= %{$doc->{types}})
##  + calls $anl->getAnalyzeWordClosure()->($_) foreach values(%types)
sub analyzeTypes {
  my ($aut,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);

  ##-- common variables
  my $aword = $aut->analyzeClosure('Word') or return $doc; ##-- can't analyze?
  my $aget  = $aut->accessClosure(defined($aut->{analyzeGet}) ? $aut->{analyzeGet} :  $DEFAULT_ANALYZE_GET);
  my $aset  = $aut->accessClosure(defined($aut->{analyzeSet}) ? $aut->{analyzeSet} :  $DEFAULT_ANALYZE_SET);

  my $allowTextRegex = defined($aut->{allowTextRegex}) ? qr($aut->{allowTextRegex}) : undef;

  my ($tok,@w,$w,$wa,$a);
  foreach $tok (values(%$types)) {
    next if (defined($allowTextRegex) && $tok->{text} !~ $allowTextRegex); ##-- text-sensitive regex
    @w = grep {defined($_)} $aget->($tok);
    next if (!@w);  ##-- accessor returned undef: skip this token
    $a = [];
    foreach $w (@w) {
      $wa = $aword->($w,$opts);
      push(@$a,@$wa) if ($wa);
    }
    undef($a) if (!@$a);
    $aset->($tok,$a);
  }

  return $doc;
}


##==============================================================================
## PACKAGE: Analysis::Automaton
##==============================================================================
package DTA::CAB::Analysis::Automaton;
use strict;
our @ISA = qw(DTA::CAB::Analysis);

## \@text = $a->text()
sub text { return map {$_->{hi}} @{$_[0]}; }


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Automaton - generic analysis automaton API

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Automaton;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 $aut = $aut->clear();
 
 ##========================================================================
 ## Methods: Generic
 
 $class = $aut->fstClass();
 $class = $aut->labClass();
 $bool = $aut->fstOk();
 $bool = $aut->labOk();
 $bool = $aut->dictOk();
 
 ##========================================================================
 ## Methods: I/O
 
 $bool = $aut->ensureLoaded();
 $aut = $aut->load(fst=>$fstFile, lab=>$labFile);
 $aut = $aut->loadFst($fstfile);
 $aut = $aut->loadLabels($labfile);
 $aut = $aut->parseLabels();
 $aut = $aut->loadDict($dictfile);
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 ##========================================================================
 ## Methods: Analysis
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::Automaton
inherits from
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $aut = CLASS_OR_OBJ->new(%args);

Constuctor.

%args, %$aut:

 ##-- Filename Options
 fstFile => $filename,    ##-- default: none
 labFile => $filename,    ##-- default: none
 dictFile=> $filename,    ##-- default: none
 ##
 ##-- Analysis Output
 analysisClass  => $class, ##-- default: none (ARRAY)
 analyzeSrc     => $key,   ##-- source key for analysis (default: 'text')
 analyzeDst     => $key,   ##-- token output key (default: from __PACKAGE__)
 wantAnalysisLo => $bool,  ##-- set to true to include 'lo' keys in analyses (default: true)
 ##
 ##-- Analysis Options
 eow            => $sym,  ##-- EOW symbol for analysis FST
 check_symbols  => $bool, ##-- check for unknown symbols? (default=1)
 labenc         => $enc,  ##-- encoding of labels file (default='latin1')
 dictenc        => $enc,  ##-- dictionary encoding (default='utf8')
 auto_connect   => $bool, ##-- whether to call $result->_connect() after every lookup   (default=0)
 tolower        => $bool, ##-- if true, all input words will be bashed to lower-case (default=0)
 tolowerNI      => $bool, ##-- if true, all non-initial characters of inputs will be lower-cased (default=0)
 toupperI       => $bool, ##-- if true, initial character will be upper-cased (default=0)
 bashWS         => $str,  ##-- if defined, input whitespace will be bashed to '$str' (default='_')
 attInput       => $bool, ##-- if true, respect AT&T lextools-style escapes in input (default=0)
 allowTextRegex => $re,   ##-- if defined, only tokens with matching 'text' will be analyzed (default: none)
 ##
 ##-- Analysis objects
 fst  => $gfst,      ##-- (child classes only) e.g. a Gfsm::Automaton object (default=new)
 lab  => $lab,       ##-- (child classes only) e.g. a Gfsm::Alphabet object (default=new)
 labh => \%sym2lab,  ##-- (?) label hash:  $sym2lab{$labSym} = $labId;
 laba => \@lab2sym,  ##-- (?) label array:  $lab2sym[$labId]  = $labSym;
 labc => \@chr2lab,  ##-- (?)chr-label array: $chr2lab[ord($chr)] = $labId;, by unicode char number (e.g. unpack('U0U*'))
 result=>$resultfst, ##-- (child classes only) e.g. result fst
 dict => \%dict,     ##-- exception lexicon / static cache of analyses

=item clear

 $aut = $aut->clear();

Clears the object.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Methods: Generic
=pod

=head2 Methods: Generic

=over 4

=item fstClass

 $class = $aut->fstClass();

Returns default FST class for L</loadFst>() method.
Used by sub-classes.

=item labClass

 $class = $aut->labClass();

Returns default alphabet class for L</loadLabels>() method.
Used by sub-classes.

=item fstOk

 $bool = $aut->fstOk();

Should return false iff fst is undefined or "empty".

=item labOk

 $bool = $aut->labOk();

Should return false iff alphabet (label-set) is undefined or "empty".

=item dictOk

 $bool = $aut->dictOk();

Should return false iff dict is undefined or "empty".

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $aut->ensureLoaded();

Ensures automaton data is loaded from default files.

=item load

 $aut = $aut->load(fst=>$fstFile, lab=>$labFile);

Loads specified files.

=item loadFst

 $aut = $aut->loadFst($fstfile);

Loads automaton from $fstfile.

=item loadLabels

 $aut = $aut->loadLabels($labfile);

Loads labels from $labfile.

=item parseLabels

 $aut = $aut->parseLabels();

Parses some information from a (newly loaded) alphabet.

=over 4

=item *

sets up $aut-E<gt>{labh}, $aut-E<gt>{laba}, $aut-E<gt>{labc}

=item *

fixes encoding difficulties in $aut-E<gt>{labh}, $aut-E<gt>{laba}

=back


=item loadDict

 $aut = $aut->loadDict($dictfile);

Loads dictionary from $dictfile.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Methods: Persistence: Perl
=pod

=head2 Methods: Persistence: Perl

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Returns list of keys not to be saved

This implementation returns:

 qw(dict fst lab laba labc labh result)


=item loadPerlRef

 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);

Implicitly calls $obj-E<gt>clear()

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item canAnalyze

 $bool = $anl->canAnalyze();

Returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
This implementation just returns:

 $anl->dictOk || ($anl->labOk && $anl->fstOk)

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut


=cut
