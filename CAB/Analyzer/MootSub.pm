## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MootSub.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: post-processing for moot PoS tagger in DTA chain
##  + tweaks $tok->{moot}{word}, instantiates $tok->{moot}{lemma}

package DTA::CAB::Analyzer::MootSub;
use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Lemmatizer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

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
our %LITERAL_WORD_TAGS = (map {($_=>undef)} qw(FM XY CARD)); #NE
sub analyzeSentences {
  my ($asub,$doc,$opts) = @_;
  return $doc if (!$asub->enabled($opts));

  ##-- common variables
  my $mlabel = $asub->{mootLabel};
  my $lz     = $asub->{lz};
  my $toks   = [map {@{$_->{tokens}}} @{$doc->{body}}];

  ##-- Step 1: populate $tok->{moot}{word}
  my ($tok,$m);
  foreach $tok (@$toks) {
    ##-- ensure that $tok->{moot}, $tok->{moot}{tag} are defined
    $m = $tok->{$mlabel} = {} if (!defined($m=$tok->{$mlabel}));
    $m->{tag} = '@UNKNOWN' if (!defined($m->{tag}));

    ##-- ensure $tok->{moot}{word} is defined (should already be populated by Moot with wantTaggedWord=>1)
    $m->{word} = (defined($tok->{dmoot}) ? $tok->{dmoot}{tag}
		  : (defined($tok->{xlit}) ? $tok->{xlit}{latin1Text}
		     : $tok->{text})) if (!defined($m->{word}));
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
	|| exists($LITERAL_WORD_TAGS{$t})
        #|| ($t eq 'NE' && !$tok->{msafe})
        ) {

      ##-- hack: bash FM,XY,CARD-tagged elements to raw (possibly transliterated) text
      $l = $m->{word} = (defined($tok->{xlit}) && $tok->{xlit}{isLatinExt} ? $tok->{xlit}{latin1Text} : $tok->{text});
      $l =~ s/\s+/_/g;
      $l =~ s/^(.)(.*)$/$1\L$2\E/ ;#if (length($l) > 3 || $l =~ /[[:lower:]]/);
      $m->{lemma} = $l;
    }
    else {
      ##-- extract lemma from best analysis
      $m->{lemma} = (sort {$a->{cost}<=>$b->{cost} || $a->{lemma} cmp $b->{lemma}} @a)[0]{lemma};
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
