## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Moot::DynLex.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Moot analysis API for word n-gram disambiguation using dynamic lexicon

package DTA::CAB::Analyzer::Moot::DynLex;
use DTA::CAB::Analyzer::Moot;

use moot;
use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Moot);

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
##     modelFile => $filename,  ##-- default: none
##
##     ##-- Analysis Options
##     hmmargs        => \%args, ##-- clobber moot::HMM->new() defaults (default: verbose=>$moot::HMMvlWarnings)
##     modelenc       => $enc,   ##-- encoding of model file (default='latin1')
##     analyzeTextSrc => $src,   ##-- source token 'text' key (default='text')
##     analyzeTagSrcs => \@srcs, ##-- source token 'analyses' key(s) (default=['morph'], undef for none)
##     analyzeDst     => $dst,   ##-- destination key (default='dmoot')
##     prune          => $bool,  ##-- if true (default), prune analyses after tagging
##
##     ##-- Analysis Objects
##     hmm            => $hmm,   ##-- a moot::DynLexHMM_Boltzmann object
##    )
sub new {
  my $that = shift;
  my $moot = $that->SUPER::new(
			       ##-- options (override)
			       hmmargs   => {
					     verbose=>$moot::HMMvlWarnings,
					     hash_ngrams=>1,
					     relax=>0,
					     dynlex_base=>2,
					     dynlex_beta=>1,
					    },

			       ##-- analysis I/O
			       #analysisClass => 'DTA::CAB::Analyzer::Moot::Analysis',
			       analyzeTextSrc => 'text',
			       #analyzeTagSrcs => [qw(eqpho rewrite)],
			       analyzeTagSrcs => [qw(eqpho)],
			       analyzeDst => 'dmoot',

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
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Generic

## $bool = $anl->canAnalyze()
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
##  + inherited from DTA::CAB::Analyzer::Moot

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##     $tok = $coderef->($tok,\%opts)
##  + dummy version, does nothing
##  + inherited from DTA::CAB::Analyzer::Moot


##------------------------------------------------------------------------
## Methods: Analysis: Sentence

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + returned sub is callable as:
##     $sent = $coderef->($sent,\%opts)
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
 
 ##========================================================================
 ## Methods: Analysis
 
 $coderef = $anl->getAnalyzeSentenceSub();
 

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

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot::DynLex: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item getAnalyzeSentenceSub

 $coderef = $anl->getAnalyzeSentenceSub();


=over 4

=item *

guts for $anl-E<gt>analyzeSentenceSub()

=item *

returned sub is callable as:
$sent = $coderef-E<gt>($sent,\%opts)

=item *

calls tagger on $sent, populating $tok-E<gt>{ $moot-E<gt>{analyzeDst} } keys

=item *

input text for index "$i" may be passed as one of the following:

=over 4


=item *

$sent-E<gt>{tokens}[$i]{ $moot-E<gt>{analyzeTextSrc} }

=item *

$sent-E<gt>{tokens}[$i]{ $moot-E<gt>{analyzeTextSrc} }{hi}

=item *

$opts-E<gt>{src   }[$i]{ $moot-E<gt>{analyzeTextSrc} }

=item *

$opts-E<gt>{src   }[$i]{ $moot-E<gt>{analyzeTextSrc} }{hi}

=back


=item *

input analyses are assumed to be automaton-like, passed either in $src or $tok

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
