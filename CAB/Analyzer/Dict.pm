## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dict.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analysis dictionary API

package DTA::CAB::Analyzer::Dict;

use DTA::CAB::Analyzer;

#use Gfsm;
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
##     dictFile=> $filename,    ##-- default: none
##
##     ##-- Analysis Output
##     analyzeDst     => $key,   ##-- token output key (default: from __PACKAGE__)
##
##     ##-- Analysis Options
##     eow            => $sym,  ##-- EOW symbol for analysis FST
##     encoding       => $enc,  ##-- encoding of dict file (default='UTF-8')
##     tolower        => $bool, ##-- if true, all input words will be bashed to lower-case (default=0)
##     tolowerNI      => $bool, ##-- if true, all non-initial characters of inputs will be lower-cased (default=0)
##     toupperI       => $bool, ##-- if true, initial character will be upper-cased (default=0)
##
##     ##-- Analysis objects
##     dict => \%dict,          ##-- dictionary data
##    )
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- filenames
			      dictFile => undef,

			      ##-- analysis objects
			      dict=>{},

			      ##-- options
			      encoding       => 'UTF-8',
			      tolower        => 0,
			      tolowerNI      => 0,
			      toupperI       => 0,

			      ##-- analysis output
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
  %{$aut->{dict}} = qw();

  return $aut;
}


##==============================================================================
## Methods: Generic
##==============================================================================

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
  ##-- ensure: dict
  if ( defined($aut->{dictFile}) && !$aut->dictOk ) {
    $rc &&= $aut->loadDict($aut->{dictFile});
  }
  return $rc;
}

## $aut = $aut->load(fst=>$fstFile, lab=>$labFile)
sub load {
  my ($aut,%args) = @_;
  return 0 if (!grep {defined($_)} @args{qw(dict)});
  my $rc = $aut;
  $rc &&= $aut->loadDict($args{dict}) if (defined($args{dict}));
  return $rc;
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
  my ($line,$word,$entry,$aw,$a,$w);
  while (defined($line=<$dictfh>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^\s*%/);
    $line = decode($aut->{labenc}, $line) if ($aut->{labenc});
    ($word,$entry) = split(/\t/,$line,2);
    if    ($aut->{tolower})   { $word = lc($word); }
    elsif ($aut->{tolowerNI}) { $word =~ s/^(.)(.*)$/$1\L$2\E/; }
    if    ($aut->{toupperI})  { $word = ucfirst($word); }
    $dict->{$word} = $entry;
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
  return ($that->SUPER::noSaveKeys, qw(dict));
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
##  + analyzes text $opts{src}, defaults to $tok->{text}
##  + sets output ${ $opts{dst} } = $out = [ \%analysis1, ..., \%analysisN ]
##    + $opts{dst} defaults to \$tok->{ $anl->{analyzeDst} }
##    - each \%analysisI is a HASH:
##      \%analysisI = { lo=>$analysisLowerString, hi=>$analysisUpperString, w=>$analysisWeight, ... }
##    - if $opts->{wantAnalysisLo} is true, 'lo' key will be included in any %analysisI, otherwise not (default)
##  + if $anl->analysisClass() returned defined, $out is blessed into it
##  + implicitly loads analysis data (automaton and labels)
sub getAnalyzeTokenSub {
  my $aut = shift;

  ##-- setup common variables
  my $adst   = $aut->{analyzeDst};
  my $dict   = $aut->{dict};

  ##-- ananalysis options
  my @analyzeOptionKeys = qw(tolower tolowerNI toupperI); #)

  my ($tok, $w,$opts,$uword, $entry);
  return sub {
    ($tok,$opts) = @_;
    $tok = DTA::CAB::Token::toToken($tok) if (!ref($tok));

    ##-- set default options
    $opts = $opts ? {%$opts} : {}; ##-- copy / create
    $opts->{$_} = $aut->{$_} foreach (grep {!defined($opts->{$_})} @analyzeOptionKeys);

    ##-- get source text ($w)
    $w = defined($opts->{src}) ? $opts->{src} : $tok->{text};

    ##-- normalize word
    $uword = $w;
    if    ($opts->{tolower})   { $uword = lc($uword); }
    elsif ($opts->{tolowerNI}) { $uword =~ s/^(.)(.*)$/$1\L$2\E/; }
    if    ($opts->{toupperI})  { $uword = ucfirst($uword); }

    ##-- check for (normalized) word in dict
    $tok->{$adst} = $dict->{$uword};

    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting: OBSOLETE
##==============================================================================

1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Dict - simple dictionary lookup analyzer

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Dict;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 $dict = $dict->clear();
 
 ##========================================================================
 ## Methods: Generic
 
 $bool = $dict->dictOk();
 
 ##========================================================================
 ## Methods: I/O
 
 $bool = $dict->ensureLoaded();
 $dict = $dict->load(dict=>$dictFile);
 $dict = $dict->loadDict($dictfile);
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 ##========================================================================
 ## Methods: Analysis
 
 $coderef = $anl->getAnalyzeTokenSub();

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

DTA::CAB::Analyzer::Dict
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

 $dict = CLASS_OR_OBJ->new(%args);

Constuctor.

%args, %$dict:

 ##-- Filename Options
 dictFile=> $filename,    ##-- default: none
 ##
 ##-- Analysis Output
 analyzeDst     => $key,   ##-- token output key (default: from __PACKAGE__)
 ##
 ##-- Analysis Options
 encoding       => $enc,  ##-- encoding of dictionary file (default='UTF-8')
 tolower        => $bool, ##-- if true, all input words will be bashed to lower-case (default=0)
 tolowerNI      => $bool, ##-- if true, all non-initial characters of inputs will be lower-cased (default=0)
 toupperI       => $bool, ##-- if true, initial character will be upper-cased (default=0)
 ##
 ##-- Analysis objects
 dict => \%dict,     ##-- exception lexicon / static cache of analyses

=item clear

 $dict = $dict->clear();

Clears the object.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Methods: Generic
=pod

=head2 Methods: Generic

=over 4

=item dictOk

 $bool = $dict->dictOk();

Should return false iff dict is undefined or "empty".

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $dict->ensureLoaded();

Ensures automaton data is loaded from default files.

=item load

 $dict = $dict->load(dict=>$dictFile);

Loads specified file(s).

=item loadDict

 $dict = $dict->loadDict($dictfile);

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

 qw(dict)


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

=item getAnalyzeTokenSub

 $coderef = $dict->getAnalyzeTokenSub();

=over 4

=item *

see L<DTA::TokWrap::Analyzer::getAnalyzeTokenSub()|DTA::TokWrap::Analyzer/item_getAnalyzeTokenSub>.

=item *

returned sub is callable as:

 $tok = $coderef->($tok,\%opts)

=item *

analyzes text $opts{src}, defaults to $tok-E<gt>{text}

=item *

sets output ${ $opts{dst} } = $out = $dictEntry

=over 4

=item *

$opts{dst} defaults to \$tok-E<gt>{ $dict-E<gt>{analyzeDst} }

=back

=item *

implicitly loads dictionary data

=back

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
