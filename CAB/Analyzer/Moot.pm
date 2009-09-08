## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Moot.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic Moot analysis API

package DTA::CAB::Analyzer::Moot;
use DTA::CAB::Analyzer;

use moot;
use Encode qw(encode decode);
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
##     modelFile => $filename,  ##-- default: none
##
##     ##-- Analysis Options
##     hmmargs        => \%args, ##-- clobber moot::HMM->new() defaults (default: verbose=>$moot::HMMvlWarnings)
##     modelenc       => $enc,   ##-- encoding of model file (default='latin1')
##     analyzeTextSrc => $src,   ##-- source token 'text' key (default='text')
##     analyzeTagSrc  => $src,   ##-- source token 'analyses' key (default='morph', undef for none)
##     analyzeDst     => $dst,   ##-- destination key (default='moot')
##     prune          => $bool,  ##-- if true (default), prune analyses after tagging
##
##     ##-- Analysis Objects
##     hmm            => $hmm,   ##-- a moot::HMM object
##    )
sub new {
  my $that = shift;
  my $moot = $that->SUPER::new(
			      ##-- filenames
			       modelFile => undef,

			       ##-- options
			       hmmargs   => {
					     verbose=>$moot::HMMvlWarnings,
					    },
			       modelenc  => 'latin1',
			       prune => 1,

			       ##-- analysis I/O
			       #analysisClass => 'DTA::CAB::Analyzer::Moot::Analysis',
			       analyzeTextSrc => 'text',
			       analyzeTagSrc => 'morph',
			       analyzeDst => 'moot',

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

  return $moot;
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $bool = $moot->hmmOk()
##  + should return false iff HMM is undefined or "empty"
##  + default version checks for non-empty 'lexprobs' and 'n_tags'
sub hmmOk {
  return defined($_[0]{hmm}) && $_[0]{hmm}{n_tags}>1 && $_[0]{hmm}{lexprobs}->size > 1;
}

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $moot->ensureLoaded()
##  + ensures model data is loaded from default files
sub ensureLoaded {
  my $moot = shift;
  ##-- ensure: hmm
  if ( defined($moot->{modelFile}) && !$moot->hmmOk ) {
    return $moot->loadHMM($moot->{modelFile});
  }
  return $moot->hmmOk;
}

##--------------------------------------------------------------
## Methods: I/O: Input: HMM

## $moot = $moot->loadHMM($model_file)
BEGIN { *loadHMM = *loadHmm = \&loadHMM; }
sub loadHMM {
  my ($moot,$model) = @_;
  $moot->info("loading HMM model file '$model'");
  if (!defined($moot->{hmm})) {
    $moot->{hmm} = moot::HMM->new();
    @{$moot->{hmm}}{keys(%{$moot->{hmmargs}})} = values(%{$moot->{hmmargs}});
  }
  $moot->{hmm}->load_model($model)
    or $moot->logconfess("loadHMM(): load failed for '$model': $!");
  $moot->dropClosures();
  return $moot;
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
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##     $tok = $coderef->($tok,\%opts)
##  + dummy version, does nothing
sub _analyzeTokenSub { $_[0]; }
sub getAnalyzeTokenSub { return \&_analyzeTokenSub; }

##------------------------------------------------------------------------
## Methods: Analysis: Sentence

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + returned sub is callable as:
##     $sent = $coderef->($sent,\%opts)
##  + calls tagger on $sent, populating $tok->{ $moot->{analyzeDst} } keys
##  + input text for index "$i" may be passed as one of the following:
##    - $sent->{tokens}[$i]{ $moot->{analyzeTextSrc} }
##    - $sent->{tokens}[$i]{ $moot->{analyzeTextSrc} }{hi}
##    - $opts->{src   }[$i]{ $moot->{analyzeTextSrc} }
##    - $opts->{src   }[$i]{ $moot->{analyzeTextSrc} }{hi}
##  + input analyses are assumed to be automaton-like, passed either in $src or $tok
sub getAnalyzeSentenceSub {
  my $moot = shift;

  ##-- setup common variables
  my $aclass = $moot->{analysisClass};
  my $atxt   = $moot->{analyzeTextSrc};
  my $atags  = $moot->{analyzeTagSrc};
  my $adst   = $moot->{analyzeDst};
  my $prune  = $moot->{prune};
  my $hmm    = $moot->{hmm};
  my $modelenc = $moot->{modelenc};
  my $msent  = moot::Sentence->new();

  ##-- common moot variables
  my $toktyp_vanilla = $moot::TokTypeVanilla;

  my ($sent,$opts, $i,$src,$tok,$text, $mtok, $ta,$tag,$details, $tmoot,$mtas,$mta);
  return sub {
    ($sent,$opts) = @_;
    $sent = DTA::CAB::Datum::toSentence($sent) if (!UNIVERSAL::isa($_,'DTA::CAB::Sentence'));

    ##-- ensure $opts hash exists
    $opts = $opts ? {%$opts} : {}; ##-- copy / create

    ##-- get source text-array ([$w1,...,$wN]), ensure $opts->{src} is defined
    $src = defined($opts->{src}) ? $opts->{src} : $sent->{tokens};

    ##-- wrap into moot::Sentence $msent
    $msent->clear();
    foreach $i (0..$#$src) {
      $tok  = defined($src->[$i]) ? $src->[$i] : $sent->{tokens}[$i];
      $text = $tok;
      $text = $text->{$atxt} if (ref($text) && exists($text->{$atxt}));
      $text = $text->{hi}    if (ref($text) && exists($text->{hi}));
      $text = '' if (!defined($text));

      $msent->push_back(moot::Token->new($toktyp_vanilla));
      $mtok = $msent->back;
      $mtok->{text} = encode($modelenc,$text);

      ##-- insert analyses
      if (defined($atags) && ref($tok->{$atags}) && @{$tok->{$atags}}) {
	foreach $ta (@{$tok->{$atags}}) {
	  if (UNIVERSAL::isa($ta,'HASH')) {
	    ($tag,$details)=(@$ta{qw(tag details)});
	    if (!defined($tag) && defined($ta->{hi})) {
	      $details = $ta->{hi}.(defined($ta->{w}) ? " <$ta->{w}>" : '');
	      if ($details =~ /\[\_?([^\s\]]*)/) {
		$tag = $1;
	      } else {
		($tag,$details) = ($details,'');
	      }
	    }
	  } else {
	    ($tag,$details) = ($ta,'');
	  }
	  $mtok->insert(encode($modelenc,$tag),encode($modelenc,$details));
	}
      }
    }

    ##-- call underlying tagger
    $hmm->tag_sentence($msent);

    ##-- unwrap moot::Sentence back into CAB::Sentence
    foreach $i (0..$#$src) {
      $tok  = $sent->{tokens}[$i];
      $mtok = $msent->front;
      #$mtok->prune() if ($prune); ##-- prune() is BROKEN: Tue, 08 Sep 2009 16:49:41 +0200: *** glibc detected *** /usr/bin/perl: double free or corruption (fasttop): 0x09f74300 ***

      $tmoot = {
		#text => decode($modelenc,$mtok->{text}),
		tag  => decode($modelenc,$mtok->{tag}),
	       };

      ##-- unwrap analyses
      $mtas = $mtok->{analyses};
      foreach (0..($mtas->size-1)) {
	$mta = $mtas->front;
	($tag,$details) = map {decode($modelenc,$_)} @$mta{qw(tag details)};
	next if ($prune && $tag ne $tmoot->{tag});
	push(@{$tmoot->{analyses}}, { tag=>$tag, details=>$details });
	$mtas->rotate(1);
      }

      ##-- rotate: sentence
      $msent->rotate(1);

      ##-- bless & assign analyses
      bless($tmoot, $aclass) if (defined($aclass));
      $tok->{$adst} = $tmoot;
    }

    ##-- cleanup
    undef($mtok);
    undef($mtas);
    undef($mta);

    return $sent;
  };
}

##==============================================================================
## Methods: Output Formatting: OBSOLETE
##==============================================================================

1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Moot - generic Moot analysis API

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


=over 4


=item *

object structure:

    (
     ##-- Filename Options
     modelFile => $filename,  ##-- default: none
     ##
     ##-- Analysis Options
     hmmargs        => \%args, ##-- clobber moot::HMM->new() defaults (default: verbose=>$moot::HMMvlWarnings)
     modelenc       => $enc,   ##-- encoding of model file (default='latin1')
     analyzeTextSrc => $src,   ##-- source token 'text' key (default='text')
     analyzeTagSrc  => $src,   ##-- source token 'analyses' key (default='morph', undef for none)
     analyzeDst     => $dst,   ##-- destination key (default='moot')
     prune          => $bool,  ##-- if true (default), prune analyses after tagging
     ##
     ##-- Analysis Objects
     hmm            => $hmm,   ##-- a moot::HMM object
    )

=back

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

=item canAnalyze

 $bool = $anl->canAnalyze();

Returns true if analyzer can perform its function (e.g. data is loaded & non-empty)

=item getAnalyzeTokenSub

Returns dummy no-op sub.

=item getAnalyzeSentenceSub


=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod



=cut

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
...

=cut


=cut
