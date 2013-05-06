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
			      defaultLang => 'de',

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
      if    ($_->{text} =~ /^\p{Greek}+$/)  { push(@l, 'el'); }
      elsif ($_->{text} =~ /^\p{Hebrew}+$/) { push(@l, 'he'); }
      elsif ($_->{text} =~ /^\p{Arabic}+$/) { push(@l, 'ar'); }
      elsif ($_->{text} =~ /[[:alpha:]]/ && $_->{text} !~ /\p{Latin}/) { push(@l,'xy'); }
    }
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
  my $l0     = $lid->{defaultLang};
  my $nil    = [];

  ##-- ye olde loope
  my (%ln,$s,$l,$n);
  foreach $s (@{$doc->{body}}) {
    ##-- count number of stopwords per language
    %ln = qw();
    ++$ln{$_} foreach (map {@{$_->{$label}//$nil}} @{$s->{tokens}});

    ##-- get top-ranked language for this sentence
    ($l,$n) = ($l0,0);
    foreach ($l0, sort keys %ln) {
      ($l,$n)=($_,$ln{$_}) if ($n < ($ln{$_}//0));
    }
    $s->{$slabel} = $l;
    #$s->{"${slabel}_counts"} = {%ln}; ##-- DEBUG
  }

  return $doc;
}


1; ##-- be happy
