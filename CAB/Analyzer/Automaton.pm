## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Automaton.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: generic analysis automaton API

package DTA::CAB::Analyzer::Automaton;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Unify ':all';
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
our $DEFAULT_ANALYZE_GET = '$_->{$lab} ? qw() : '._am_xlit;

## $DEFAULT_ANALYZE_SET
##  + default coderef or eval-able string for {analyzeSet}
##  + vars:
##     $anl  => analyzer (automaton)
##     $lab  => analyzer label
##     $_    => token
##     $wa   => analyses (array-ref)
our $DEFAULT_ANALYZE_SET = '$_->{$lab} = ($wa && @$wa ? [@$wa] : undef);';

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     fstFile => $filename,     ##-- source FST file (default: none)
##     labFile => $filename,     ##-- source labels file (default: none)
##
##     ##-- Exception lexicon options (OBSOLETE for CAB >=v1.15)
##     #dictFile => $filename,    ##-- source dict file (default: none): clobbers $dict->{dictFile} if defined
##     #dict      => $dict,       ##-- exception lexicon as a DTA::CAB::Analyzer::Dict object or option hash
##     #                          ##   + default=undef
##     #dictClass => $class,      ##-- fallback class for new dict (default='DTA::CAB::Analyzer::Dict')
##
##     ##-- Analysis Output
##     analyzeGet     => $code,  ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET; return undef for no analysis)
##     analyzeSet     => $code,  ##-- accessor: coderef or string: set analyses (default=$DEFAULT_ANALYZE_SET)
##     wantAnalysisLo => $bool,     ##-- set to true to include 'lo'    keys in analyses (default: true)
##     wantAnalysisLemma => $bool,  ##-- set to true to include 'lemma' keys in analyses (default: false)
##
##     ##-- Analysis Options
##     eow            => $sym,  ##-- EOW symbol for analysis FST
##     check_symbols  => $bool, ##-- check for unknown symbols? (default=1)
##     labenc         => $enc,  ##-- encoding of labels file (default='latin1')
##     #dictenc        => $enc,  ##-- dictionary encoding (default='UTF-8') (set $aut->{dict}{encoding} instead)
##     auto_connect   => $bool, ##-- whether to call $result->_connect() after every lookup   (default=0)
##     tolower        => $bool, ##-- if true, all input words will be bashed to lower-case (default=0)
##     tolowerNI      => $bool, ##-- if true, all non-initial characters of inputs will be lower-cased (default=0)
##     toupperI       => $bool, ##-- if true, initial character will be upper-cased (default=0)
##     bashWS         => $str,  ##-- if defined, input whitespace will be bashed to '$str' (default='_')
##     attInput       => $bool, ##-- if true, respect AT&T lextools-style escapes in input (default=0)
##     attOutput      => $bool, ##-- if true, generate AT&T escapes in output (default=1)
##     allowTextRegex => $re,   ##-- if defined, only tokens with matching 'text' will be analyzed (default: none)
##                              ##   : useful: /(?:^[[:alpha:]\-\@]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-\@]+$)/
##
##     ##-- Analysis objects
##     fst  => $gfst,      ##-- (child classes only) e.g. a Gfsm::Automaton object (default=new)
##     lab  => $lab,       ##-- (child classes only) e.g. a Gfsm::Alphabet object (default=new)
##     labh => \%sym2lab,  ##-- (?) label hash:  $sym2lab{$labSym} = $labId;
##     laba => \@lab2sym,  ##-- (?) label array:  $lab2sym[$labId]  = $labSym;
##     labc => \@chr2lab,  ##-- (?)chr-label array: $chr2lab[ord($chr)] = $labId;, by unicode char number (e.g. unpack('U0U*'))
##
##     ##-- INHERITED from DTA::CAB::Analyzer
##     label => $label,    ##-- analyzer label (default: from analyzer class name)
##     typeKeys => \@keys, ##-- type-wise keys to expand
##    )
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- filenames
			      fstFile => undef,
			      labFile => undef,

			      ##-- analysis objects
			      fst=>undef,
			      lab=>undef,
			      result=>undef,
			      labh=>{},
			      laba=>[],
			      labc=>[],

			      ##-- options
			      eow            =>'',
			      check_symbols  => 1,
			      labenc         => 'latin1',
			      auto_connect   => 0,
			      tolower        => 0,
			      tolowerNI      => 0,
			      toupperI       => 0,
			      bashWS         => '_',
			      attInput       => 0,
			      attOutput      => 1,
			      allowTextRegex => undef, #'(?:^[[:alpha:]\-\@\x{ac}]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-\@\x{ac}]+$)',

			      ##-- analysis I/O
			      analyzeSrc => 'text',
			      wantAnalysisLo => 1,
			      wantAnalysisLemma => 0,

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
  delete($aut->{result}); ##-- should be undef anyways
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
  return $rc;
}

## $aut = $aut->load(fst=>$fstFile, lab=>$labFile)
sub load {
  my ($aut,%args) = @_;
  return 0 if (!grep {defined($_)} @args{qw(fst lab dict)});
  my $rc = $aut;
  $rc &&= $aut->loadFst($args{fst}) if (defined($args{fst}));
  $rc &&= $aut->loadLabels($args{lab}) if (defined($args{lab}));
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
  delete($aut->{result});
  #$aut->{result} = $aut->{fst}->shadow; #if (defined($aut->{result}) && $aut->{fst}->can('shadow'));
  delete($aut->{_analyze});
  return $aut;
}

## $result = $aut->resultFst()
##  + returns empty result FST
sub resultFst {
  return $_[0]{fst}->shadow;
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
  return ($_[0]->labOk && $_[0]->fstOk);
}


##==============================================================================
## Methods: Analysis: v1.x
##==============================================================================


## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in %types (= %{$doc->{types}})
sub analyzeTypes {
  my ($aut,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);

  ##-- setup common variables
  my $fst    = $aut->{fst};
  my $fst_ok = $aut->fstOk();
  my $result = $aut->resultFst();
  my $lab    = $aut->{lab};
  my $labc   = $aut->{labc};
  my $laba   = $aut->{laba};
  my $labenc = $aut->{labenc};
  my @eowlab = (defined($aut->{eow}) && $aut->{eow} ne '' ? ($aut->{labh}{$aut->{eow}}) : qw());
  my $allowTextRegex = defined($aut->{allowTextRegex}) ? qr($aut->{allowTextRegex}) : undef;

  ##-- closures
  my (@wa);
  my $aget_code = defined($aut->{analyzeGet}) ? $aut->{analyzeGet} :  $DEFAULT_ANALYZE_GET;
  my $aset_code = defined($aut->{analyzeSet}) ? $aut->{analyzeSet} :  $DEFAULT_ANALYZE_SET;
  my $ax_pre    = join('',
		       map {"my $_;\n"}
		       '$lab=$anl->{label}',
		       '$wa=$opts{wa}',
		      );
  my $aget   = $aut->accessClosure($aget_code, pre=>$ax_pre, wa=>\@wa);
  my $aset   = $aut->accessClosure($aset_code, pre=>$ax_pre, wa=>\@wa);

  ##-- object analysis options
  my $check_symbols = $aut->{check_symbols};
  my $auto_connect = $aut->{auto_connect};
  my $tolower = $aut->{tolower};
  my $tolowerNI = $aut->{tolowerNI};
  my $toupperI = $aut->{toupperI};
  my $bashWS = $aut->{bashWS};
  my $attInput = $aut->{attInput};
  my $attOutput = $aut->{attOutput};
  my $wantAnalysisLo = $aut->{wantAnalysisLo};
  my $wantAnalysisLemma = $aut->{wantAnalysisLemma};

  ##-- ananalysis options
  ##    + we use a local options hash \%wopts to safely clobber 'src' key, needed by setLookupOptions()
  my @userOptions = (
		     ##-- "safe" runtime options
		     #(none)
		    );
  my @objectOptions = (
		       #qw(check_symbols auto_connect),
		       #qw(tolower tolowerNI toupperI bashWS attInput attOutput),
		       #qw(wantAnalysisLo wantAnalysisLemma),
		       qw(max_paths max_weight max_ops),
		      );

  ##-- local options hash (we clobber 'src' key for use in setLookupOptions())
  my $wopts    = { %{$opts||{}} };
  $wopts->{$_} = $aut->{$_} foreach (@objectOptions, grep {!defined($opts->{$_})} @userOptions);

  my (@w,$w,$uword,$ulword,@wlabs,$ua,$lemma);
  foreach (values(%$types)) {
    next if (defined($allowTextRegex) && $_->{text} !~ $allowTextRegex); ##-- text-sensitive regex
    @w=$aget->();
    #$aut->trace("analyzeTypes(): w=(", join(' ', @w), ")") if ($aut->{label} eq 'eqphox'); ##-- DEBUG

    next if (!@w); ##-- no lookup-inputs for token (e.g. if $_->{$label} was already populated, e.g. from exlex)
    @wa = qw();
    foreach $w (@w) {
      ##-------- BEGIN analyzeWord
      $wopts->{src} = $w;            ##-- set $wopts->{src} (hack for setLookupOptions())
      $aut->setLookupOptions($wopts) if ($aut->can('setLookupOptions'));

      ##---- analyze
      ##-- normalize
      $uword = $w;
      if    ($tolower)   { $uword = lc($uword); }
      elsif ($tolowerNI) { $uword =~ s/^(.)(.*)$/$1\L$2\E/; }
      if    ($toupperI)  { $uword = ucfirst($uword); }
      if    (defined($bashWS)) { $uword =~ s/\s+/$bashWS/g; }

      if ($fst_ok) {
	##-- fst lookup (if fst available and no previous analysis was found)

	##-- fst: get labels
	if ($attInput) {
	  ##-- fst: labels: att-style (requires gfsm v0.0.10-pre11, gfsm-perl v0.0217)
	  $ulword = $uword;
	  utf8::downgrade($ulword);
	  @wlabs = (@{$lab->string_to_labels($ulword, $check_symbols, 1)}, @eowlab);
	}
	elsif ($check_symbols) {
	  ##-- fst: labels: by character: verbose
	  @wlabs = (@$labc[unpack('U0U*',$uword)],@eowlab);
	  foreach (grep { !defined($wlabs[$_]) } (0..$#wlabs)) {
	    $aut->warn("ignoring unknown character '", substr($uword,$_,1), "' in word '$w' (normalized to '$uword').\n");
	  }
	  @wlabs = grep {defined($_)} @wlabs;
	}
	else {
	  ##-- fst: labels: by character: quiet
	  @wlabs = grep {defined($_)} (@$labc[unpack('U0U*',$uword)],@eowlab);
	}

	##-- fst: lookup
	$aut->{fst}->lookup(\@wlabs, $result);
	$result->_connect() if ($auto_connect);
	#$result->_rmepsilon() if ($wopts->{auto_rmeps});

	##-- parse analyses
	push(@wa,
	     map {
	       {(
		 ($wantAnalysisLo ? (lo=>$uword) : qw()),
		 'hi'=> (defined($labenc)
			 ? decode($labenc,$lab->labels_to_string($_->{hi},0,1))
			 : $lab->labels_to_string($_->{hi},0,1)),
		 'w' => $_->{w},
		)}
	     } @{$result->paths($Gfsm::LSUpper)}
	    );

      }
    }##-- /foreach $w (@w)

    ##-- un-escape output
    if (!$attOutput) {
      foreach (@wa) {
	$_->{hi} =~ s/\\(.)/$1/g;
	$_->{hi} =~ s/\[([^\]]+)\]/$1/g;
      }
    }

    ##-- parse lemmata
    if ($wantAnalysisLemma) {
      foreach (@wa) {
	$lemma = $_->{hi};
	if (defined($lemma) && $lemma ne '') {
	  $lemma =~ s/\[.*$//; ##-- trim everything after first non-character symbol
	  $lemma =~ s/(?:\/\w+)|(?:[\\\¬\~\|\=\+\#])//g;
	  substr($lemma,1) = lc(substr($lemma,1));
	} else {
	  $lemma = $uword;
	}
	$lemma =~ s/^\s*//;
	$lemma =~ s/\s*$//;
	$lemma =~ s/\s+/_/g;
	$_->{lemma} = $lemma;
      }
    }
    ##-------- END analyzeWord

    ##-- set analyses
    $aset->();
  }

  return $doc;
}


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
 
 ##========================================================================
 ## Methods: I/O
 
 $bool = $aut->ensureLoaded();
 $aut = $aut->load(fst=>$fstFile, lab=>$labFile);
 $aut = $aut->loadFst($fstfile);
 $aut = $aut->loadLabels($labfile);
 $aut = $aut->parseLabels();
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 ##========================================================================
 ## Methods: Analysis
 
 $bool = $anl->canAnalyze();
 $doc = $anl->analyzeTypes($doc,\%types,\%opts);
 

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
 fstFile => $filename,     ##-- source FST file (default: none)
 labFile => $filename,     ##-- source labels file (default: none)
 ##
 ##-- Analysis Output
 analyzeGet     => $code,  ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET; return undef for no analysis)
 analyzeSet     => $code,  ##-- accessor: coderef or string: set analyses (default=$DEFAULT_ANALYZE_SET)
 wantAnalysisLo => $bool,     ##-- set to true to include 'lo'    keys in analyses (default: true)
 wantAnalysisLemma => $bool,  ##-- set to true to include 'lemma' keys in analyses (default: false)
 ##
 ##-- Analysis Options
 eow            => $sym,  ##-- EOW symbol for analysis FST
 check_symbols  => $bool, ##-- check for unknown symbols? (default=1)
 labenc         => $enc,  ##-- encoding of labels file (default='latin1')
 auto_connect   => $bool, ##-- whether to call $result->_connect() after every lookup   (default=0)
 tolower        => $bool, ##-- if true, all input words will be bashed to lower-case (default=0)
 tolowerNI      => $bool, ##-- if true, all non-initial characters of inputs will be lower-cased (default=0)
 toupperI       => $bool, ##-- if true, initial character will be upper-cased (default=0)
 bashWS         => $str,  ##-- if defined, input whitespace will be bashed to '$str' (default='_')
 attInput       => $bool, ##-- if true, respect AT&T lextools-style escapes in input (default=0)
 attOutput      => $bool, ##-- if true, generate AT&T escapes in output (default=1)
 allowTextRegex => $re,   ##-- if defined, only tokens with matching 'text' will be analyzed (default: none)
                          ##   : useful: /(?:^[[:alpha:]\-\x{ac}]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-\x{ac}]+$)/
 ##-- Analysis objects
 fst  => $gfst,      ##-- (child classes only) e.g. a Gfsm::Automaton object (default=new)
 lab  => $lab,       ##-- (child classes only) e.g. a Gfsm::Alphabet object (default=new)
 labh => \%sym2lab,  ##-- (?) label hash:  $sym2lab{$labSym} = $labId;
 laba => \@lab2sym,  ##-- (?) label array:  $lab2sym[$labId]  = $labSym;
 labc => \@chr2lab,  ##-- (?)chr-label array: $chr2lab[ord($chr)] = $labId;, by unicode char number (e.g. unpack('U0U*'))
 ##
 ##-- INHERITED from DTA::CAB::Analyzer
 label => $label,    ##-- analyzer label (default: from analyzer class name)
 typeKeys => \@keys, ##-- type-wise keys to expand

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

 ($anl->labOk && $anl->fstOk)

=item analyzeTypes

 $doc = $anl->analyzeTypes($doc,\%types,\%opts);

Perform type-wise analysis of all (text) types in %types (= %{$doc-E<gt>{types}}).

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

Copyright (C) 2009-2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...

=cut
