## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Moot::DynLex.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: Moot analysis API for word n-gram disambiguation using dynamic lexicon

package DTA::CAB::Analyzer::Moot1::DynLex;
use DTA::CAB::Analyzer::Moot1;

use moot;
use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Moot1);

## $DEFAULT_DYN_ANALYZE_TEXT_GET
##  + default coderef or eval-able string for {analyzeTextGet}
#our $DEFAULT_DYN_ANALYZE_TEXT_GET = '$_[0]{xlit} ? $_[0]{xlit}{latin1Text} : $_[0]{text}';
our $DEFAULT_DYN_ANALYZE_TEXT_GET = '$_[0]{text}';

## $DEFAULT_DYN_ANALYZE_TAGS_GET
##  + default coderef or eval-able string for {analyzeTagsGet}
##  + parameters:
##      $_[0] => token object being analyzed
##  + closure vars:
##      $moot => analyzer object
##  + should return a list of hash-refs ({tag=>$tag,details=>$details,cost=>$cost,src=>$whereFrom}, ...) given token
#our $DEFAULT_DYN_ANALYZE_TAGS_GET = 'parseMorphAnalyses';
#our $DEFAULT_DYN_ANALYZE_TAGS_GET = __PACKAGE__ . '::parseDynAnalyses';
our $DEFAULT_DYN_ANALYZE_TAGS_GET = __PACKAGE__ . '::parseDynAnalysesSafe';

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- new in Analyzer::Moot::DynLex
##     #?
##
##     ##==== Inherited from Analyzer::Moot
##     ##-- Filename Options
##     hmmFile => $filename,     ##-- default: none (REQUIRED)
##
##     ##-- Analysis Options
##     hmmArgs        => \%args, ##-- clobber moot::HMM->new() defaults (default: verbose=>$moot::HMMvlWarnings)
##     hmmEnc         => $enc,   ##-- encoding of model file(s) (default='latin1')
##     analyzeTextGet => $code,  ##-- pseudo-closure: token 'text' (default=$DEFAULT_DYN_ANALYZE_TEXT_GET)
##     analyzeTagsGet => $code,  ##-- pseudo-closure: token 'analyses' (defualt=$DEFAULT_DYN_ANALYZE_TAGS_GET)
##     ##
##     analyzeCostFuncs =>\%fnc, ##-- maps source 'analyses' key(s) to cost-munging functions
##                               ##     %fnc = ($akey=>$perlcode_str, ...)
##                               ##   + evaluates $perlcode_str as subroutine body to derive analysis
##                               ##     'weights' from source-key weights
##                               ##   + $perlcode_str may use variables:
##                               ##       $moot    ##-- current Analyzer::Moot object
##                               ##       $tag     ##-- source analysis tag
##                               ##       $details ##-- source analysis 'details' "$hi <$w>"
##                               ##       $cost    ##-- source analysis weight
##                               ##       $text    ##-- source token text
##                               ##   + Default:
##                                        xlit   => 2/length($text)
##                                        eqpho  => 1/length($text)
##                                        eqphox => .5*$cost/length($text)
##                                        rw     => $cost/length($text)
##     requireAnalyses => $bool, ##-- if true all tokens MUST have non-empty analyses (useful for DynLex; default=0)
##     prune          => $bool,  ##-- if true, prune analyses after tagging (default (override)=false)
##     uniqueAnalyses => $bool,  ##-- if true, only cost-minimal analyses for each tag will be added (default=1)
##
##
##     ##-- Analysis Objects
##     hmm            => $hmm,   ##-- a moot::HMM object
##
##     ##-- OBSOLETE (use analyzeTextGet, analyzeTagsGet pseudo-closure accessors)
##     #analyzeTextSrc => $src,   ##-- source token 'text' key (default='text')
##     #analyzeTagSrcs => \@srcs, ##-- source token 'analyses' key(s) (default=['morph'], undef for none)
##     #analyzeLiteralFlag=>$key, ##-- if ($tok->{$key}), only literal analyses are allowed (default='dmootLiteral')
##     #analyzeLiteralSrc =>$key, ##-- source key for literal analyses (default='xlit')
##    )
sub new {
  my $that = shift;
  my $moot = $that->SUPER::new(
			       ##-- options (override)
			       hmmargs   => {
					     verbose=>$moot::HMMvlWarnings,
					     newtag_str=>'@NEW',
					     newtag_f=>0.5,
					     Ftw_eps =>0.0,  ##-- moot default=0.5
					     invert_lexp=>1,
					     hash_ngrams=>1,
					     relax=>0,
					     dynlex_base=>2,
					     dynlex_beta=>1,
					    },
			       uniqueAnalyses=>1,
			       wantTaggedWord=>0,

			       ##-- analysis I/O
			       #analysisClass => 'DTA::CAB::Analyzer::Moot::Analysis',
			       label => 'dmoot',
			       analyzeTextGet => $DEFAULT_DYN_ANALYZE_TEXT_GET,
			       analyzeTagsGet => $DEFAULT_DYN_ANALYZE_TAGS_GET,
			       requireAnalyses => 1,
			       prune => 0,
			       analyzeLiteralFlag=>'dmootLiteral',
			       analyzeLiteralSrc=>'text',
			       analyzeCostFuncs => {
						    xlit=>'2.0/length($text)',
						    eqpho=>'1.0/length($text)',
						    eqphox=>'(1+0.1*$cost)/length($text)',
						    rw=>'$cost/length($text)',
						   },

			       ##-- analysis objects
			       #hmm => undef,

			       ##-- user args
			       @_
			      );
  return $moot;
}

## $moot = $moot->clear()
##  + inherited from DTA::CAB::Analyzer::Moot

##==============================================================================
## Methods: Generic
##==============================================================================

## $bool = $moot->hmmOk()
##  + should return false iff HMM is undefined or "empty"
##  + default version checks for non-empty 'n_tags'
sub hmmOk {
  return defined($_[0]{hmm}) && $_[0]{hmm}{n_tags}>1;
}

## $class = $moot->hmmClass()
##  + returns class for $moot->{hmm} object
##  + default just returns 'moot::HMM'
sub hmmClass { return 'moot::DynLexHMM_Boltzmann'; }

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Utilities

BEGIN { *parseAnalysis = \&DTA::CAB::Analyzer::Moot1::parseAnalysis; }

BEGIN { *_parseAnalysis = \&DTA::CAB::Analyzer::Moot1::parseAnalysis; }

## @analyses = CLASS::parseDynAnalysesSafe($tok)
##  + pseudo-accessor utility for disambiguation using @$tok{qw(text xlit msafe eqphox rw)} fields (NOT 'eqpho'!)
##  + returns only $tok->{xlit} field if "$tok->{msafe}" flag is true
sub parseDynAnalysesSafe {
  return
    ($_[0]{xlit} ? (_parseAnalysis($_[0]{xlit}{latin1Text},src=>'xlit')) : _parseAnalysis($_[0]{text},src=>'text'))
      if ($_[0]{msafe} || ($_[0]{toka} && @{$_[0]{toka}}));
  return
    (($_[0]{xlit}  ? (_parseAnalysis($_[0]{xlit}{latin1Text},src=>'xlit')) : _parseAnalysis($_[0]{text},src=>'text')),
     #($_[0]{eqpho} ? (map {_parseAnalysis($_,src=>'eqpho')} @{$_[0]{eqpho}}) : qw()),
     ($_[0]{eqphox} ? (map {_parseAnalysis($_,src=>'eqphox')} @{$_[0]{eqphox}}) : qw()),
     ($_[0]{rw}    ? (map {_parseAnalysis($_,src=>'rw')} @{$_[0]{rw}}) : qw()),
    );
}

## @analyses = CLASS::parseDynAnalyses($tok)
##  + pseudo-accessor utility for disambiguation using @$tok{qw(text xlit eqpho rw)} fields
##  + always returns all analyses
sub parseDynAnalyses {
  return
    (($_[0]{xlit}  ? (_parseAnalysis($_[0]{xlit}{latin1Text},src=>'xlit')) : _parseAnalysis($_[0]{text},src=>'text')),
     ($_[0]{eqpho} ? (map {_parseAnalysis($_,src=>'eqpho')} @{$_[0]{eqpho}}) : qw()),
     ($_[0]{rw}    ? (map {_parseAnalysis($_,src=>'rw')} @{$_[0]{rw}}) : qw()),
    );
}


##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $moot->ensureLoaded()
##  + ensures model data is loaded from default files
##  + inherited from DTA::CAB::Analyzer::Moot

##--------------------------------------------------------------
## Methods: I/O: Input: HMM

## $moot = $moot->loadHMM($model_file)
##  + inherited from DTA::CAB::Analyzer::Moot

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + inherited from DTA::CAB::Analyzer::Moot

## $saveRef = $obj->savePerlRef()
##  + inherited from DTA::CAB::Persistent

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + implicitly calls $obj->clear()
##  + inherited from DTA::CAB::Analyzer::Moot

##==============================================================================
## Methods: Analysis
##  + inherited from DTA::CAB::Analyzer::Moot


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Moot::DynLex - Moot analysis API for word n-gram disambiguation using dynamic lexicon

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::Moot::DynLex;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 
 ##========================================================================
 ## Methods: Generic
 
 $bool = $moot->hmmOk();
 $class = $moot->hmmClass();
 
=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot::DynLex: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::Moot::DynLex
inherits from
L<DTA::CAB::Analyzer::Moot|DTA::CAB::Analyzer::Moot>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot::DynLex: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

Object structure, %args

    (
     ##-- new in Analyzer::Moot::DynLex
     #(nothing new here)
     #
     ##==== Inherited from Analyzer::Moot
     ##
     ##-- Filename Options
     modelFile => $filename,  ##-- default: none
     ##
     ##-- Analysis Options
     hmmargs        => \%args, ##-- clobber moot::HMM->new() defaults (default: verbose=>$moot::HMMvlWarnings)
     modelenc       => $enc,   ##-- encoding of model file (default='latin1')
     analyzeTextSrc => $src,   ##-- source token 'text' key (default='text')
     analyzeTagSrcs => \@srcs, ##-- source token 'analyses' key(s) (default=['morph'], undef for none)
     analyzeDst     => $dst,   ##-- destination key (default='dmoot')
     prune          => $bool,  ##-- if true (default), prune analyses after tagging
     ##
     ##-- Analysis Objects
     hmm            => $hmm,   ##-- a moot::DynLexHMM_Boltzmann object
    )

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot::DynLex: Methods: Generic
=pod

=head2 Methods: Generic

=over 4

=item hmmOk

 $bool = $moot->hmmOk();

Should return false iff HMM is undefined or "empty".
Default version checks for non-empty 'n_tags'.

=item hmmClass

 $class = $moot->hmmClass();

Returns class for $moot-E<gt>{hmm} object.
Default just returns 'moot::HMM'.

=back

=cut


##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<dta-cab-cachegen.perl(1)|dta-cab-cachegen.perl>,
L<dta-cab-xmlrpc-server.perl(1)|dta-cab-xmlrpc-server.perl>,
L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<RPC::XML(3pm)|RPC::XML>,
L<perl(1)|perl>,
L<mootutils(1)|mootutils>,
L<mootdyn(1)|mootdyn>,
...

=cut
