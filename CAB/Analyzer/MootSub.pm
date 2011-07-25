## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MootSub.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: post-processing for moot PoS tagger in DTA chain
##  + tweaks $tok->{moot}{word}, instantiates $tok->{moot}{lemma}

package DTA::CAB::Analyzer::MootSub;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Lemmatizer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

##======================================================================
## Methods

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args:
##     mootLabel => $label,    ##-- label for Moot tagger object (default='moot')
##     lz => $lemmatizer,      ##-- DTA::CAB::Analyzer::Lemmatizer sub-object
sub new {
  my $that = shift;
  my $asub = $that->SUPER::new(
			       ##-- analysis selection
			       label => 'mootsub',
			       mootLabel => 'moot',
			       lz => DTA::CAB::Analyzer::Lemmatizer->new(analyzeGet    =>$DTA::CAB::Analyzer::Lemmatizer::GET_MOOT_ANALYSES,
									 analyzeGetText=>$DTA::CAB::Analyzer::Lemmatizer::GET_MOOT_TEXT,
									 analyzeWhich  =>'Sentences',
									),
			       xyTags => {map {($_=>undef)} qw(XY FM)}, #CARDNE ##-- if these tags are assigned, use literal text and not dmoot normalization

			       ##-- user args
			       @_
			      );
  $asub->{lz}{label} = $asub->{label}."_lz";
  return $asub;
}

## $bool = $anl->doAnalyze(\%opts, $name)
##  + override: only allow analyzeSentences()
sub doAnalyze {
  my $anl = shift;
  return 0 if (defined($_[1]) && $_[1] ne 'Sentences');
  return $anl->SUPER::doAnalyze(@_);
}

## $doc = $anl->Sentences($doc,\%opts)
##  + post-processing for 'moot' object
sub analyzeSentences {
  my ($asub,$doc,$opts) = @_;
  return $doc if (!$asub->enabled($opts));

  ##-- common variables
  my $mlabel = $asub->{mootLabel};
  my $lz     = $asub->{lz};
  my $xytags = $asub->{xyTags};
  my $toks   = [map {@{$_->{tokens}}} @{$doc->{body}}];

  ##-- Step 1: populate $tok->{moot}{word}
  my ($tok,$m);
  foreach $tok (@$toks) {
    ##-- ensure that $tok->{moot}, $tok->{moot}{tag} are defined
    $m = $tok->{$mlabel} = {} if (!defined($m=$tok->{$mlabel}));
    $m->{tag} = '@UNKNOWN' if (!defined($m->{tag}));

#    ##-- ensure $tok->{moot}{word} is defined (should already be populated by Moot with wantTaggedWord=>1)
#    $m->{word} = (defined($tok->{dmoot}) ? $tok->{dmoot}{tag}
#		  : (defined($tok->{xlit}) ? $tok->{xlit}{latin1Text}
#		     : $tok->{text})) if (!defined($m->{word}));
  }

  ##-- Step 2: run lemmatizer (populates $tok->{moot}{analyses}[$i]{lemma}
  $lz->_analyzeGuts($toks,$opts) if ($lz->enabled($opts));

  ##-- Step 3: lemma-extraction & tag-sensitive lemmatization hacks
  my ($t,$l,@a);
  foreach $tok (@$toks) {
    $m = $tok->{$mlabel};
    $t = $m->{tag};
    @a = $m->{analyses} ? grep {$_->{tag} eq $t} @{$m->{analyses}} : qw();
    @a = ($m->{analyses}[0]) if (!@a && $m->{analyses} && @{$m->{analyses}}); ##-- hack: any analysis is better than none!
    if (!@a
	|| exists($xytags->{$t})
        #|| ($t eq 'NE' && !$tok->{msafe})
        ) {

      ##-- hack: bash XY-tagged elements to raw (possibly transliterated) text
      $l = $m->{word} = (defined($tok->{xlit}) && $tok->{xlit}{isLatinExt} ? $tok->{xlit}{latin1Text} : $tok->{text});
      $l =~ s/\s+/_/g;
      $l =~ s/^(.)(.*)$/$1\L$2\E/ ;#if (length($l) > 3 || $l =~ /[[:lower:]]/);
      $m->{lemma} = $l;
    }
    else {
      ##-- extract lemma from best analysis
      $m->{lemma} = (sort {($a->{prob}||0)<=>($b->{prob}||0) || ($a->{lemma}||'') cmp ($b->{lemma}||'')} @a)[0]{lemma};
    }
  }

  ##-- return
  return $doc;
}

## @keys = $anl->typeKeys()
##  + returns list of type-wise keys to be expanded for this analyzer by expandTypes()
##  + override returns @$anl{qw(mootLabel)}
sub typeKeys {
  return ($_[0]{mootLabel});
}

1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::MootSub - post-processing for moot PoS tagger in DTA chain

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::MootSub;
 
 ##========================================================================
 ## Methods
 
 $obj = CLASS_OR_OBJ->new(%args);
 $bool = $anl->doAnalyze(\%opts, $name);
 @keys = $anl->typeKeys();
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

This class provides a
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> implementation
for post-processing of moot PoS tagger output in the DTA analysis chain
L<DTA::CAB::Chain::DTA|DTA::CAB::Chain::DTA>.  In particular,
this class tweaks $tok->{moot}{word} and instantiates $tok->{moot}{lemma}.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MootSub: Methods
=pod

=head2 Methods

=over 4

=item Variable: %LITERAL_WORD_TAGS

(undocumented)

=item new

 $obj = CLASS_OR_OBJ->new(%args);

object structure, %args:

 mootLabel => $label,    ##-- label for Moot tagger object (default='moot')
 lz => $lemmatizer,      ##-- DTA::CAB::Analyzer::Lemmatizer sub-object

=item doAnalyze

 $bool = $anl->doAnalyze(\%opts, $name);

override: only allow analyzeSentences()

=item analyzeSentences

Actual analysis guts.

=item typeKeys

 @keys = $anl->typeKeys();

Returns list of type-wise keys to be expanded for this analyzer by expandTypes()
Override returns @$anl{qw(mootLabel)}.

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

Copyright (C) 2011 by Bryan Jurish

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
