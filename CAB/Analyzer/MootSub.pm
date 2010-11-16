## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MootSub.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: post-processing for moot PoS tagger in DTA chain
##  + tweaks $tok->{moot}{word}, instantiates $tok->{moot}{lemma}

package DTA::CAB::Analyzer::MootSub;
use DTA::CAB::Analyzer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args:
##     mootLabel => $label,    ##-- label for Moot tagger object (default='moot')
sub new {
  my $that = shift;
  my $tp = $that->SUPER::new(
			     ##-- analysis selection
			     label => 'mootsub',
			     mootLabel => 'moot',

			     ##-- user args
			     @_
			    );
  return $tp;
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

  ##-- get dmoot target types
  my $mlabel = $asub->{mootLabel};

  my ($tok,$m,$t,$l);
  foreach $tok (map {@{$_->{tokens}}} @{$doc->{body}}) {
    ##-- ensure that $tok->{moot}, $tok->{moot}{tag} are defined
    $m = $tok->{$mlabel} = {} if (!defined($m=$tok->{$mlabel}));
    $t = $m->{tag} = '@UNKNOWN' if (!defined($t=$m->{tag}));

    ##-- ensure $tok->{moot}{word} is defined (should already be populated by Moot with wantTaggedWord=>1)
    $m->{word} = (defined($tok->{dmoot}) ? $tok->{dmoot}{tag}
		  : (defined($tok->{xlit}) ? $tok->{xlit}{latin1Text}
		     : $tok->{text}));

    if (exists($LITERAL_WORD_TAGS{$t}) || ($t eq 'NE' && !$tok->{msafe})) {
      ##-- hack: bash FM,XY,CARD-tagged elements to raw (possibly transliterated) text
      $m->{word} = $l = (defined($tok->{xlit}) && $tok->{xlit}{isLatinExt} ? $tok->{xlit}{latin1Text} : $tok->{text});
      $l =~ s/\s+/_/g;
      $l =~ s/^(.)(.*)$/$1\L$2\E/ if ($l =~ /[[:lower:]]/);
    }
    else {
      ##-- populate $tok->{moot}{lemma}
      $l = undef;
      foreach (sort {$a->{cost} <=> $b->{cost}} grep {defined($_->{tag}) && $_->{tag} eq $t} @{$m->{analyses}||[]}) {
	next if (!defined($l = $_->{details}));
	$l =~ s/^\s*\~\s*//;
	$l =~ s/\s* \@ .*$//;
	$l =~ s/\s+/_/g;
	last if (defined($l) && $l ne '');
      }
      if (!defined($l) || $l eq '') {
	$l = $m->{word};
	$l =~ s/^(.)(.*)$/$1\L$2\E/ if ($l =~ /[[:lower:]]/);
      }
    }
    #$l = ucfirst($l) if ($t eq 'NE' || $t eq 'NN');
    $m->{lemma} = $l;
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
