## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::LangId::Simple.pm
## Author: Bryan Jurish <jurish@bbaw.de>
## Description: language identification using stopword lists

##==============================================================================
package DTA::CAB::Analyzer::LangId::Simple;
use DTA::CAB::Analyzer::Dict::Json;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Dict::Json);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Dict::Json
sub new {
  my $that = shift;
  my $lid = $that->SUPER::new(
			      ##-- analysis selection
			      label      => 'lang',
			      #slabel     => 'lang', ##-- sentence-level label
			      #vlabel     => 'lang_counts', ##-- DEBUG: verbose sentence-level counts, empty or undef for none
			      defaultLang => 'de',
			      defaultCount => 0.1,  ##-- bonus count for default lang (characters)
			      minSentLen   => 2,    ##-- minimum number of tokens in sentence required before guessing
			      minSentChars => 8,    ##-- minimum number of text characters in sentence required begore guessing

			      ##-- user args
			      @_
			     );
  return $lid;
}

##==============================================================================
## Methods: Prepare

## $bool = $dic->ensureLoaded()
##  + ensures analyzer data is loaded from default files
sub ensureLoaded {
  my $lid = shift;
  return $lid->SUPER::ensureLoaded(@_) && $lid->decodeDictValues();
}


##==============================================================================
## Methods: Analysis

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
sub analyzeTypes {
  my ($lid,$doc,$types,$opts) = @_;

  ##-- common vars
  my $label  = $lid->{label} || $lid->defaultLabel;
  my $slabel = $lid->{slabel} || $label;
  my $swd    = $lid->{ttd}{dict};
  my $allow_re = defined($lid->{allowRegex}) ? qr($lid->{allowRegex}) : undef;
  my $l0     = $lid->{defaultLang};
  my (@l);

  ##-- word-wise analysis
  my ($l,$prev);
  foreach (values %$types) {
    next if (defined($allow_re) && $_->{text} !~ $allow_re);

    ##-- list check
    @l = (defined($l=$swd->{lc($_->{text})}) ? @$l : qw());

    ##-- local analysis check(s)
    if (!$_->{xlit} || !$_->{xlit}{isLatinExt}) {
      if    ($_->{text} =~ /^\p{Greek}{2,}$/)  { push(@l, 'el'); }
      elsif ($_->{text} =~ /^\p{Hebrew}{2,}$/) { push(@l, 'he'); }
      elsif ($_->{text} =~ /^\p{Arabic}{2,}$/) { push(@l, 'ar'); }
      elsif ($_->{text} =~ /[[:alpha:]]{2,}/ && $_->{text} !~ /\p{Latin}/) { push(@l,'xy'); } ##-- combination of latin and non-latin characters
    }
    if    ($_->{text} =~ /[\p{InMathematicalOperators}]/) { push(@l,'xy'); }
    elsif ($_->{text} =~ /[[:alpha:]](?:.?)[[:digit:]]/) { push(@l,'xy'); }

    push(@l, 'la') if ($_->{mlatin});
    push(@l, $l0) if ($l0 && $_->{morph} && $_->{msafe} && grep {$_->{hi} !~ /\[_(?:FM|NE)\]/} @{$_->{morph}});
    #push(@l, 'de','exlex') if (($_->{exlex} && $_->{exlex} ne $_->{text}));

    ##-- make unique
    if (@l) {
      $prev = '';
      $_->{$label} = [map {$prev eq $_ ? qw() : ($prev=$_)} sort @l];
    } else {
      $_->{$label} = undef;
    }
  }

  return $doc;
}


## $doc = $anl->analyzeSentences($doc,\%opts)
sub analyzeSentences {
  my ($lid,$doc,$opts) = @_;

  ##-- common vars
  my $label  = $lid->{label} || $lid->defaultLabel;
  my $slabel = $lid->{slabel} || $label;
  my $vlabel = $lid->{vlabel};
  my $l0     = $lid->{defaultLang} // '';
  my $n0     = $l0 ? ($lid->{defaultCount}//0) : 0;
  my $minlen = $lid->{minSentLen} // 0;
  my $minchrs= $lid->{minSentChars} // 0;
  my $nil    = [];

  ##-- ye olde loope
  my (%ln,$s,$nchrs,$l,$n,$w);
  foreach $s (@{$doc->{body}}) {
    ##-- check minimum sentence length in tokens
    next if (@{$s->{tokens}} < $minlen);

    ##-- count number of stopword-CHARACTERS per language
    %ln = ($l0=>$n0);
    $nchrs = 0;
    foreach $w (@{$s->{tokens}}) {
      $nchrs  += length($w->{text});
      $ln{$_} += length($w->{text}) foreach (@{$w->{$label}//$nil});
    }
    next if ($nchrs < $minchrs);

    ##-- get top-ranked language for this sentence
    ($l,$n) = ($l0,$n0);
    foreach (sort keys %ln) {
      ($l,$n)=($_,$ln{$_}) if ($n < $ln{$_});
    }
    $s->{$slabel} = $l;
    $s->{$vlabel} = {%ln} if ($vlabel); ##-- DEBUG
  }

  return $doc;
}


1; ##-- be happy
