## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Moot.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: generic Moot analysis API

package DTA::CAB::Analyzer::Moot;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Datum ':all';

use Moot;
use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Closure stuff

## $DEFAULT_ANALYZE_CODE
##  + default analysis code
##  + available variables:
##     $anl     # Analyzer::Moot object
##     $_       # sentence to be analyzed
our $DEFAULT_ANALYZE_CODE = '
package '. __PACKAGE__ .';
my $moot=$anl;
my $lab =$moot->{label};
my $hmm =$moot->{hmm};
my $tagx=$moot->{tagx};
my $utf8=$moot->{hmmUtf8};
my $prune=$moot->{prune};
my $lctext=$moot->{lctext};
my ($msent,$w,$mw,$t,$at);
sub {
 $msent = [map {
   $w  = $_;
   $mw = $w->{$lab} ? $w->{$lab} : ($w->{$lab}={});
   $mw->{text} = (defined($mw->{word}) ? $mw->{word} : '._am_tag('$_->{dmoot}', _am_xlit).') if (!defined($mw->{text}));
   $mw->{text} = lc($mw->{text}) if ($lctext);
   $mw->{analyses} = ['._am_tagh_list2moota('map {$_ ? @$_ : qw()}
			    @$w{qw(mlatin tokpp toka)},
			    ($w->{dmoot} ? $w->{dmoot}{morph}
                             : ($w->{morph}, ($w->{rw} ? (map {$_->{morph}} @{$w->{rw}}) : qw())))'
			   ).'
     ] if (!defined($mw->{analyses}));
   $mw
 } @{$_->{tokens}}];
 return if (!@$msent); ##-- ignore empty sentences

 $hmm->tag_sentence($msent, $utf8);

 foreach (@$msent) {
   $_->{word}=$_->{text};
   delete($_->{text});
   foreach (@{$_->{analyses}}) {
     #$_->{mtag} = $_->{tag};
     $_->{tag}  = $t if (defined($t=$tagx->{$_->{tag}}));
   }
   $_->{tag} = $t if (defined($t=$tagx->{$_->{tag}}));
   if ($prune) {
     $t = $_->{tag};
     @{$_->{analyses}} = grep {$_->{tag} eq $t} @{$_->{analyses}};
   }
 }
}
';


##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     hmmFile => $filename,     ##-- default: none (REQUIRED)
##     tagxFile  => $tagxFile,   ##-- tag-translation file (hack)
##
##     ##-- Analysis Options
##     hmmArgs        => \%args, ##-- clobber Moot::HMM->new() defaults (default: none)
##     hmmUtf8        => $bool,  ##-- use hmm utf8 mode? (default=true)
##
##     analyzeCode => $code,     ##-- pseudo-closure: analyze current sentence $_
##     label       => $lab,      ##-- destination key (default='moot')
##     prune       => $bool,     ##-- if true (default), prune analyses after tagging
##     lctext      => $bool,     ##-- if true, input text will be bashed to lower-case (default: false)
##
##     ##-- Analysis Objects
##     hmm         => $hmm,   ##-- a moot::HMM object
##     tagx        => \%tagx,      ##-- tag-translation table (loaded via DTA::CAB::Analyzer::Dict from $tagxFile)
##    )
sub new {
  my $that = shift;
  my $moot = $that->SUPER::new(
			       ##-- filenames
			       hmmFile => undef,
			       tagxFile => undef,

			       ##-- options
			       hmmArgs   => {
					     #verbose=>Moot::vlWarnings,
					     #relax => 1,
					    },
			       hmmUtf8  => 1,

			       #prune => 1,
			       #uniqueAnalyses=>0,

			       ##-- analysis I/O
			       #analysisClass => 'DTA::CAB::Analyzer::Moot::Analysis',
			       label => 'moot',
			       analyzeCode => $DEFAULT_ANALYZE_CODE,
			       lctext => 0,

			       #analyzeCostFuncs => {},
			       #requireAnalyses => 0,
			       #wantTaggedWord => 1,

			       ##-- analysis objects
			       #hmm => undef,

			       ##-- user args
			       @_
			      );
  return $moot;
}

## $moot = $moot->clear()
sub clear {
  my $moot = shift;

  ##-- analysis sub(s)
  $moot->dropClosures();

  ##-- analysis objects
  delete($moot->{hmm});
  delete($moot->{tagx});

  return $moot;
}

## @keys = $anl->typeKeys(\%opts)
##  + returns list of type-wise keys to be expanded for this analyzer by expandTypes()
##  + override returns empty list
sub typeKeys {
  return qw();
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $bool = $moot->hmmOk()
##  + should return false iff HMM is undefined or "empty"
##  + default version checks for non-empty 'lexprobs' and 'n_tags'
sub hmmOk {
   return defined($_[0]{hmm}) && $_[0]{hmm}->n_tags()>1 && $_[0]{hmm}->n_toks()>1;
    #&& $_[0]{hmm}{lexprobs}->size > 1;
}

## $class = $moot->hmmClass()
##  + returns class for $moot->{hmm} object
##  + default just returns 'Moot::HMM'
sub hmmClass { return 'Moot::HMM'; }

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $moot->ensureLoaded()
##  + ensures model data is loaded from default files (if available)
sub ensureLoaded {
  my $moot = shift;
  my $rc = 1; ##-- allow empty models

  ##-- ensure: hmm
  $rc &&= $moot->loadHMM($moot->{hmmFile}) if (defined($moot->{hmmFile}) && !$moot->hmmOk);

  ##-- ensure: dict: tagx
  $rc &&= $moot->ensureDict('tagx',{}) if (!$moot->{tagx});

  return $rc;
}

##--------------------------------------------------------------
## Methods: I/O: Input: HMM

## $moot = $moot->loadHMM($model_file)
BEGIN { *loadHMM = *loadHmm = \&loadHMM; }
sub loadHMM {
  my ($moot,$model) = @_;
  my $hmmClass = $moot->hmmClass;
  $moot->info("loading HMM model file '$model' using HMM class '$hmmClass'");
  if (!defined($moot->{hmm})) {
    $moot->{hmm} = $hmmClass->new()
      or $moot->logconfess("could not create HMM object of class '$hmmClass': $!");
    $moot->{hmm}->config($moot->{hmmArgs}) if ($moot->{hmmArgs});
  }
  $moot->{hmm}->load($model)
    or $moot->logconfess("loadHMM(): load failed for '$model': $!");
  $moot->dropClosures();
  return $moot;
}

##--------------------------------------------------------------
## Methods: I/O: Input: Dictionaries: generic

## $bool = $a->ensureDict($dictName,\%dictDefault)
sub ensureDict {
  my ($a,$name,$default) = @_;
  return 1 if ($a->{$name}); ##-- already defined
  return $a->loadDict($name,$a->{"${name}File"}) if ($a->{"${name}File"});
  $a->{$name} = $default ? {%$default} : {};
  return 1;
}

## \%dictHash_or_undef = $a->loadDict($dictName,$dictFile)
sub loadDict {
  my ($a,$name,$dfile) = @_;
  delete($a->{$name});
  my $dclass = 'DTA::CAB::Analyzer::Dict';
  $a->info("loading map from '$dfile' as $dclass");

  ##-- hack: generate a temporary dict object
  my $dict = $dclass->new(label=>($a->{label}.".dict.$name"), dictFile=>$dfile);
  $dict->ensureLoaded();
  return undef if (!$dict->dictOk);

  ##-- clobber dict
  $a->{$name} = $dict->dictHash;
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
  return ($that->SUPER::noSaveKeys, qw(hmm));
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
  return $_[0]->hmmOk();
}


##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $bool = $anl->doAnalyze(\%opts, $name)
##  + override: only allow analyzeSentences()
sub doAnalyze {
  my $anl = shift;
  return 0 if (defined($_[1]) && $_[1] ne 'Sentences');
  return $anl->SUPER::doAnalyze(@_);
}

## $doc = $anl->analyzeSentences($doc,\%opts)
##  + perform sentence-wise analysis of all sentences $doc->{body}[$si]
##  + no default implementation
sub analyzeSentences {
  my ($moot,$doc,$opts) = @_;
  return undef if (!$moot->ensureLoaded()); ##-- uh-oh...
  return $doc if (!$moot->canAnalyze);      ##-- ok...
  $doc = toDocument($doc);

  ##-- setup access closures
  my $acode_str  = $moot->analysisCode();
  my $acode_sub  = $moot->accessClosure($acode_str);

  ##-- ye olde loope
  foreach (@{$doc->{body}}) {
    $acode_sub->();
  }

  return $doc;
}

##------------------------------------------------------------------------
## Methods: Analysis: Closure Utilities

## $asub_code = $moot->analysisCode()
##  + analysis closure for passing to Analyzer::accessClosure()
##  + default just returns $moot->{analyzeCode} || $DEFAULT_ANALYZE_CODE
sub analysisCode {
  my $moot = shift;
  return $moot->{analyzeCode} || $DEFAULT_ANALYZE_CODE;
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Moot - generic Moot HMM tagger/disambiguator analysis API

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::Moot;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 $moot = $moot->clear();
 
 ##========================================================================
 ## Methods: Generic
 
 $bool = $moot->hmmOk();
 $class = $moot->hmmClass();
 
 ##========================================================================
 ## Methods: I/O
 
 $bool = $moot->ensureLoaded();
 $moot = $moot->loadHMM($model_file);
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 ##========================================================================
 ## Methods: Analysis
 
 $bool = $anl->canAnalyze();
 $bool = $anl->doAnalyze(\%opts, $name);
 $doc = $anl->analyzeSentences($doc,\%opts);
 


=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::Moot
inherits from
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

Object structure, %args:

 ##-- Filename Options
 hmmFile => $filename,     ##-- default: none (REQUIRED)
 ##
 ##-- Analysis Options
 hmmArgs        => \%args, ##-- clobber moot::HMM->new() defaults (default: verbose=>$moot::HMMvlWarnings)
 hmmEnc         => $enc,   ##-- encoding of model file(s) (default='UTF-8')
 analyzeTextGet => $code,  ##-- pseudo-closure: token 'text' (default=$DEFAULT_ANALYZE_TEXT_GET)
 analyzeTagsGet => $code,  ##-- pseudo-closure: token 'analyses' (defualt=$DEFAULT_ANALYZE_TAGS_GET)
 analyzeCostFuncs =>\%fnc, ##-- maps source 'analyses' key(s) to cost-munging functions
                           ##     %fnc = ($akey=>$perlcode_str, ...)
                           ##   + evaluates $perlcode_str as subroutine body to derive analysis
                           ##     'weights' from source-key weights
                           ##   + $perlcode_str may use variables:
                           ##       $moot    ##-- current Analyzer::Moot object
                           ##       $tag     ##-- source analysis tag
                           ##       $details ##-- source analysis 'details' "$hi <$w>"
                           ##       $cost    ##-- source analysis weight
                           ##       $text    ##-- source token text
                           ##   + Default just returns $cost (identity function)
 label           =>$lab,   ##-- destination key (default='moot')
 requireAnalyses => $bool, ##-- if true all tokens MUST have non-empty analyses (useful for DynLex; default=1)
 prune          => $bool,  ##-- if true (default), prune analyses after tagging
 uniqueAnalyses => $bool,  ##-- if true, only cost-minimal analyses for each tag will be added (default=false)
 wantTaggedWord => $bool,  ##-- if true, output field will contain top-level 'word' element (default=true)
 ##
 ##-- Analysis Objects
 hmm            => $hmm,   ##-- a moot::HMM object


OBSOLETE fields (use analyzeTextGet, analyzeTagsGet pseudo-closure accessors):

 #analyzeTextSrc => $src,   ##-- source token 'text' key (default='text')
 #analyzeTagSrcs => \@srcs, ##-- source token 'analyses' key(s) (default=['morph'], undef for none)
 #analyzeLiteralFlag=>$key, ##-- if ($tok->{$key}), only literal analyses are allowed (default='dmootLiteral')
 #analyzeLiteralSrc =>$key, ##-- source key for literal analyses (default='xlit')

The 'hmmFile' argument can be specified in any format accepted by mootHMM::load_model().

=item clear

 $moot = $moot->clear();

Clears the object.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot: Methods: Generic
=pod

=head2 Methods: Generic

=over 4

=item hmmOk

 $bool = $moot->hmmOk();

Should return false iff HMM is undefined or "empty".
Default version checks for non-empty 'lexprobs' and 'n_tags'

=item hmmClass

 $class = $moot->hmmClass();

Returns class for $moot-E<gt>{hmm} object.
Default just returns 'moot::HMM'.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $moot->ensureLoaded();

Ensures model data is loaded from default files.

=item loadHMM

 $moot = $moot->loadHMM($model_file);

Loads HMM model from $model_file.  See mootfiles(5).

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot: Methods: Persistence: Perl
=pod

=head2 Methods: Persistence: Perl

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Returns list of keys not to be saved

=item loadPerlRef

 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);

Implicitly calls $obj-E<gt>clear()

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item typeKeys

 @keys = $anl->typeKeys(\%opts);

Returns list of type-wise keys to be expanded for this analyzer by expandTypes().
Override returns empty list.

=item canAnalyze

 $bool = $anl->canAnalyze();

Returns true if analyzer can perform its function (e.g. data is loaded & non-empty)

=item doAnalyze

 $bool = $anl->doAnalyze(\%opts, $name);

Override: only allow analyzeSentences().

=item analyzeSentences

 $doc = $anl->analyzeSentences($doc,\%opts);

Perform sentence-wise analysis of all sentences $doc-E<gt>{body}[$si].

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

Copyright (C) 2009,2010,2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer::Moot::DynLex(3pm)|DTA::CAB::Analyzer::Moot::DynLex>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
L<mootutils(1)|mootutils>,
L<moot(1)|moot>,
...

=cut
