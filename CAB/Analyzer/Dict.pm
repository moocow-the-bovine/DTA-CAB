## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dict.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analysis dictionary API

package DTA::CAB::Analyzer::Dict;

use DTA::CAB::Analyzer;
use DTA::CAB::Format;
use IO::File;
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
##     analyzeSrc     => $key,   ##-- source analysis key (default: $obj->{analyzeDst})
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
  my $dic = $that->SUPER::new(
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
			      analyzeSrc => undef, ##-- default: $obj->{analyzeDst}

			      ##-- user args
			      @_
			     );
  return $dic;
}

## $dic = $dic->clear()
sub clear {
  my $dic = shift;

  ##-- analysis sub(s)
  $dic->dropClosures();

  ##-- analysis objects
  %{$dic->{dict}} = qw();

  return $dic;
}


##==============================================================================
## Methods: Generic
##==============================================================================

## $bool = $dic->dictOk()
##  + should return false iff dict is undefined or "empty"
sub dictOk { return defined($_[0]{dict}) && scalar(%{$_[0]{dict}}); }

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $dic->ensureLoaded()
##  + ensures analyzer data is loaded from default files
sub ensureLoaded {
  my $dic = shift;
  my $rc  = 1;
  ##-- ensure: dict
  if ( defined($dic->{dictFile}) && !$dic->dictOk ) {
    $rc &&= $dic->loadDict($dic->{dictFile});
  }
  return $rc;
}

## $dic = $dic->load(fst=>$fstFile, lab=>$labFile)
sub load {
  my ($dic,%args) = @_;
  return 0 if (!grep {defined($_)} @args{qw(dict)});
  my $rc = $dic;
  $rc &&= $dic->loadDict($args{dict}) if (defined($args{dict}));
  return $rc;
}

##--------------------------------------------------------------
## Methods: I/O: Input: Dictionary File

## $dic = $dic->loadDict($dictfile,%opts)
##  + %opts are passed to DTA::CAB::Format->newReader()
##  + really just a wrapper for $dic->loadDoc( newReader(%opts)->parseFile($dictFile) )
sub loadDict {
  my ($dic,$dictfile,%opts) = @_;

  ##-- delegate load to DTA::CAB::Format & subclasses
  my $ifmt = DTA::CAB::Format->newReader(encoding=>$dic->{encoding},file=>$dictfile,%opts)
    or $dic->confess("could not create input parser for dictionary file '$dictfile'");
  $dic->info("loading dictionary file '$dictfile'");
  $dic->debug("using format class ".ref($ifmt));
  my $ddoc = $ifmt->parseFile($dictfile)
    or $dic->confess(ref($ifmt)."::parseFile() failed for dictionary file '$dictfile'");

  ##-- parse loaded document
  return $dic->loadDictDoc($ddoc,%opts);
}

## $dic = $dic->loadDictDoc($dictDoc)
##  + loads dictionary data from an in-memory DTA::CAB::Document
sub loadDictDoc {
  my ($dic,$ddoc) = @_;

  ##-- parse loaded tokens into dictionary hash
  my $dict = $dic->{dict};
  my $akey = defined($dic->{analyzeSrc}) ? $dic->{analyzeSrc} : $dic->{analyzeDst};
  my ($w,$text);
  foreach $w (map {@{$_->{tokens}}} @{$ddoc->{body}}) {
    next if (!defined($w->{$akey}));
    $text = $w->{text};
    if    ($dic->{tolower})   { $text = lc($text); }
    elsif ($dic->{tolowerNI}) { $text =~ s/^(.)(.*)$/$1\L$2\E/; }
    if    ($dic->{toupperI})  { $text = ucfirst($text); }
    $dict->{$text} = $w->{$akey};
  }

  $dic->dropClosures();
  return $dic;
}

##--------------------------------------------------------------
## Methods: I/O: Output: Dictionary File (as document)

## $doc = $dic->asDocument()
##  + coerces $dic->{dict} into a DTA::CAB::Document, e.g. for saving with
##    one of the DTA::CAB::Format subclasses
##  + may be used by dta-cab-cachegen.perl
sub asDocument {
  my $dic = shift;

  my $dict  = $dic->{dict};
  my $a_dst = $dic->{analyzeDst};
  my $a_src = defined($dic->{analyzeSrc}) ? $dic->{analyzeSrc} : $dic->{analyzeDst};
  my $toks  = [map { bless({text=>$_, $a_src=>$dict->{$_}}, 'DTA::CAB::Token') } sort(keys(%$dict))];

  return toDocument( [toSentence($toks)] );
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
## Methods: Analysis: Generic

## $bool = $anl->canAnalyze()
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
##  + default method always returns true
sub canAnalyze {
  return $_[0]->dictOk();
}


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
  my $dic = shift;

  ##-- setup common variables
  my $adst   = $dic->{analyzeDst};
  my $dict   = $dic->{dict};

  ##-- ananalysis options
  my @analyzeOptionKeys = qw(tolower tolowerNI toupperI); #)

  my ($tok, $w,$opts,$uword, $entry);
  return sub {
    ($tok,$opts) = @_;
    $tok = DTA::CAB::Token::toToken($tok) if (!ref($tok));

    ##-- set default options
    $opts = $opts ? {%$opts} : {}; ##-- copy / create
    $opts->{$_} = $dic->{$_} foreach (grep {!defined($opts->{$_})} @analyzeOptionKeys);

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
 $dict = $dict->loadDictDoc($doc);
 
 $doc = $dict->asDocument();
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 ##========================================================================
 ## Methods: Analysis
 
 $bool = $anl->canAnalyze();
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

 $dict = $dict->loadDict($dictfile,%opts);

Loads dictionary from $dictfile.
%opts are passed to DTA::CAB::Format
L<DTA::CAB::Format-E<gt>newReader()|DTA::CAB::Format/item_newReader>.
Really just a wrapper for the L<loadDictDoc> method (see below).

=item loadDictDoc

 $dict = $dict->loadDictDoc($doc);

Loads dictionary from an in-memory L<DTA::CAB::Document|DTA::CAB::Document> object $doc.

=item asDocument

 $doc = $dict->asDocument();

Coerces $dict-E<gt>{dict} into a DTA::CAB::Document, e.g. for saving with
one of the L<DTA::CAB::Format|DTA::CAB::Format> subclasses
May be used by dta-cab-cachegen.perl

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

 $bool = $anl->canAnalyze();

Returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
Default implementation just wraps $anl-E<gt>dictOk().

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
