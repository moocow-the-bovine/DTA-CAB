## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Moot::Boltzmann.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Moot analysis API for word n-gram disambiguation using dynamic lexicon

package DTA::CAB::Analyzer::Moot::Boltzmann;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Moot;
use Moot;

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
##     ##-- new in Analyzer::Moot::Boltzmann
##     #?
##
##     ##==== Inherited from Analyzer::Moot
##     ##-- Filename Options
##     hmmFile => $filename,     ##-- default: none (REQUIRED)
##
##     ##-- Analysis Options
##     hmmArgs        => \%args, ##-- clobber moot::HMM->new() defaults (default: verbose=>$moot::HMMvlWarnings)
##     hmmUtf8        => $bool,  ##-- use hmm utf8 mode? (default=true)
##     ##
##     analyzeCostFuncs =>\%fnc, ##-- maps source 'analyses' key(s) to cost-munging functions
##                               ##     @fnc = ($akey=>$perlcode_str, ...)
##                               ##   + used by $dmoot->analysisCode() method
##                               ##   + evaluates $perlcode_str as subroutine body to derive analysis
##                               ##     'weights' from source-key weights
##                               ##   + $perlcode_str may use variables:
##                               ##       #$moot    ##-- current Analyzer::Moot object
##                               ##       #$tag     ##-- source analysis tag
##                               ##       #$details ##-- source analysis 'details' "$hi <$w>"
##                               ##       $cost    ##-- source analysis weight (munged to "$_->{w}")
##                               ##       $text    ##-- source token text
##                               ##       $_        ##-- source analysis
##                               ##   + Default:
##                               ##       xlit   => 2/length($text)
##                               ##       eqpho  => 1/length($text)
##                               ##       eqphox => .5*$_->{w}/length($text)
##                               ##       rw     => $_->{w}/length($text)
##
##     #uniqueAnalyses  => $bool, ##-- if true, only cost-minimal analyses for each tag will be added (default=1)
##     #requireAnalyses => $bool, ##-- if true all tokens MUST have non-empty analyses (useful for Boltzmann; default=0)
##     #prune           => $bool, ##-- if true, prune analyses after tagging (default (override)=false)
##
##     ##-- Analysis Objects
##     hmm            => $hmm,   ##-- a moot::HMM object
sub new {
  my $that = shift;
  my $dmoot = $that->SUPER::new(
			       ##-- options (override)
				hmmArgs => {
					    newtag_str=>'@NEW',
					    newtag_f=>0.5,
					    Ftw_eps =>0.0, ##-- moot default=0.5
					    invert_lexp=>1,
					    hash_ngrams=>1,
					    relax=>0,
					    dynlex_base=>2,
					    dynlex_beta=>1,
					   },

				##-- these flow into analysisCode()
				#uniqueAnalyses  =>1,
				#requireAnalyses =>1,
				#prune           =>0,
				analyzeCostFuncs => {
						     xlit=>'2.0/length($text)',
						     eqpho=>'1.0/length($text)',
						     eqphox=>'(1+0.1*$cost)/length($text)',
						     rw=>'$cost/length($text)',
						    },

				##-- analysis I/O
				label => 'dmoot',
				analyzeCode => undef, ##-- see analysisCode() method, below

				##-- analysis objects
				#hmm => undef,

				##-- user args
				@_
			       );
  return $dmoot;
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
  return defined($_[0]{hmm}) && $_[0]{hmm}->n_tags()>1;
}

## $class = $moot->hmmClass()
##  + returns class for $moot->{hmm} object
##  + default just returns 'moot::HMM::Boltzmann'
sub hmmClass { return 'Moot::HMM::Boltzmann'; }

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Closure Utilities

## $asub_code = $dmoot->analysisCode()
##  + analysis closure for passing to Analyzer::accessClosure()
sub analysisCode {
  my $dmoot = shift;
  return $dmoot->analyzeDebug() if (0 || $dmoot->{analyzeDebug}); ##-- DEBUG

  my %acfunc = %{$dmoot->{analyzeCostFuncs}};
  foreach (keys %acfunc) {
    $acfunc{$_} =~ s/\$cost/\$_->{w}/g;
    $acfunc{$_} =~ s/\$\{cost\}/\$_->{w}/g;
  }

  return '
package '. __PACKAGE__ .';
my $dmoot=$anl;
my $lab  =$dmoot->{label};
my $hmm  =$dmoot->{hmm};
my $utf8 =$dmoot->{hmmUtf8};
my ($msent,$w,$mw,$text,$tmp, $analysesOk);
sub {
 $msent = [map {
   $w  = $_;
   $analysesOk=1;
   $mw = $w->{$lab} ? $w->{$lab} : ($w->{$lab}={});
   $text = $mw->{text} = (defined($mw->{word}) ? $mw->{word} : $w->{text}) if (!defined($text=$mw->{text}));
   if (!$mw->{analyses}) {
     if ($w->{exlex}) {
       $mw->{analyses} = [{tag=>$w->{exlex}, prob=>0}];
     } elsif ($w->{msafe}) {
       $mw->{analyses} = [{tag=>'._am_xlit('$w').', prob=>0}];
     } else {
       $tmp=undef;
       $mw->{analyses} = [
        '._am_dmoot_list2moota(_am_fst_sort(
					    _am_fst_uniq( ##-- only include cost-minimal unique analyses
							 '('.join(",\n\t",
								  _am_xlit_fst('$w',"($acfunc{xlit})"),
								  _am_fst_wcp_listref('$w->{eqphox}',"($acfunc{eqphox})"),
								  _am_fst_wcp_listref('$w->{rw}',"($acfunc{rw})"),
								 )
							 .')',
							 '$tmp'
							)
					   )
			      ).'
        ];
        foreach (@{$mw->{analyses}}) {
          $_->{tag} =~ s/\[(.[^\]]*)\]/$1/g;  ##-- un-escape: brackets
          $_->{tag} =~ s/\\\\(.)/$1/g;        ##-- un-escape: backslashes
        }
        $analysesOk=0 if (!@{$mw->{analyses}});
     }
     $_->{details} = $_->{tag} foreach (@{$mw->{analyses}});
   }
   $mw
 } @{$_->{tokens}}];

 if (!$analysesOk) {
   $dmoot->logwarn("no candidate analyses found for token text \\"$text\\": skipping sentence!");
   return;
 }
 $hmm->tag_sentence($msent, $utf8);

 foreach (@$msent) {
   delete($_->{text});
 }
}
';
}

##-- DEBUG
sub analyzeDebug {
  my $anl = shift;
return sub {

my $dmoot=$anl;
my $lab  =$dmoot->{label};
my $hmm  =$dmoot->{hmm};
my $utf8 =$dmoot->{hmmUtf8};
my ($msent,$w,$mw,$text,$tmp);

 $msent = [map {
   $w  = $_;
   $mw = $w->{$lab} ? $w->{$lab} : ($w->{$lab}={});
   $text = $mw->{text} = (defined($mw->{word}) ? $mw->{word} : $w->{text}) if (!defined($text=$mw->{text}));
   if (!$mw->{analyses}) {
     if ($w->{exlex}) {
       $mw->{analyses} = [{tag=>$w->{exlex}, prob=>0}];
     } elsif ($w->{msafe}) {
       $mw->{analyses} = [{tag=>($w->{xlit} ? $w->{xlit}{latin1Text} : $w->{text}) ##== _am_xlit
, prob=>0}];
     } else {
       $mw->{analyses} = [
        (map {{tag=>$_->{hi}, prob=>($_->{w}||0)} ##-- _am_dmoot_fst2moota
} (map {$tmp && $tmp->{hi} eq $_->{hi} ? qw() : ($tmp=$_)} sort {($a->{hi}||"") cmp ($b->{hi}||"") || ($a->{w}||0) <=> ($b->{w}||0)} ({hi=>($w->{xlit} ? $w->{xlit}{latin1Text} : $w->{text}) ##== _am_xlit
, w=>(2/length($text))} ##== _am_id_fst
,
	($w->{eqphox} ? (map {{ %{$_}, w=>((1+0.1*$_->{w})/length($text)) } ##-- _am_fst_wcp
} @{$w->{eqphox}}) ##-- _am_fst_wcp_list
 : qw()) ##-- _am_fst_wcp_listref
,
	($w->{rw} ? (map {{ %{$_}, w=>($_->{w}/length($text)) } ##-- _am_fst_wcp
} @{$w->{rw}}) ##-- _am_fst_wcp_list
 : qw()) ##-- _am_fst_wcp_listref
)) ##== _am_fst_uniq
) ##-- _am_dmoot_list2moota

        ];
        foreach (@{$mw->{analyses}}) {
          $_->{tag} =~ s/\[(.[^\]]*)\]/$1/g;  ##-- un-escape: brackets
          $_->{tag} =~ s/\\(.)/$1/g;        ##-- un-escape: backslashes
        }
     }
     $_->{details} = $_->{tag} foreach (@{$mw->{analyses}});
   }
   $mw
 } @{$_->{tokens}}];

 $hmm->tag_sentence($msent, $utf8);

 foreach (@$msent) {
   delete($_->{text});
 }
}}


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

DTA::CAB::Analyzer::Moot::Boltzmann - Moot analysis API for word n-gram disambiguation using dynamic lexicon

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::Moot::Boltzmann;
 
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
## DESCRIPTION: DTA::CAB::Analyzer::Moot::Boltzmann: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::Moot::Boltzmann
inherits from
L<DTA::CAB::Analyzer::Moot|DTA::CAB::Analyzer::Moot>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot::Boltzmann: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

Object structure, %args

    (
     ##-- new in Analyzer::Moot::Boltzmann
     analyzeCostFuncs => [
     #
     ##==== Inherited from Analyzer::Moot
     ##...
     ##
     ##-- Analysis Objects
     hmm            => $hmm,   ##-- a moot::HMM::Boltzmann object
    )

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Moot::Boltzmann: Methods: Generic
=pod

=head2 Methods: Generic

=over 4

=item hmmOk

 $bool = $moot->hmmOk();

Should return false iff HMM is undefined or "empty".
Default version checks for non-zero 'n_tags'.

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

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009,2010,2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer::Moot(3pm)|DTA::CAB::Analyzer::Moot>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<Moot(3pm)|Moot>,
L<mootutils(1)|mootutils>,
L<mootdyn(1)|mootdyn>,
L<perl(1)|perl>,
...

=cut
