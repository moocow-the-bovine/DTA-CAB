## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MootSub.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: post-processing for moot PoS tagger in DTA chain
##  + instantiates $tok->{moot}{word}, $tok->{moot}{lemma}

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

## $doc = $anl->Sentences($doc,\%opts)
##  + post-processing for 'moot' object
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

    ##-- populate $tok->{moot}{word}
    $m->{word} = (defined($tok->{dmoot}) ? $tok->{dmoot}{tag}
		  : (defined($tok->{xlit}) ? $tok->{xlit}{latin1Text}
		     : $tok->{text}));

    ##-- hack: bash NE analyses to raw (transliterated) text
    if ($t eq 'NE') {
      $m->{word} = $m->{lemma} = (defined($tok->{xlit}) ? $tok->{xlit}{latin1Text} : $tok->{text});
      substr($m->{lemma},1) = lc(substr($m->{lemma},1));
      $m->{lemma} =~ s/\s+/_/g;
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
	substr($l,1) = lc(substr($l,1));
      }
      $m->{lemma} = $l;
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
