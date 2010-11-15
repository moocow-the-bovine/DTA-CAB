## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Lemmatizer.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: lemma extractor for TAGH analyses or bare text

package DTA::CAB::Analyzer::Lemmatizer;
use DTA::CAB::Analyzer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Globals

## $GET_MORPH
##  + code string: \@morph_analyses = "$GET_MORPH"->()
##  + available vars: $tok, $lz
our $GET_MORPH = '$tok->{morph}';

## $GET_DMOOT_MORPH
##  + code string: \@morph_analyses = "$GET_DMOOT_MORPH"->()
##  + available vars: $tok, $lz
our $GET_DMOOT_MORPH = '$tok->{dmoot} ? $tok->{dmoot}{morph} : undef';

## $GET_TEXT
##  + code string: get text for analysis $_
##  + available vars: $tok, $tokm (array of analyses), $ma (current analysis), $lz (analyzer obj),
our $GET_TEXT = '$tok->{xlit} ? $tok->{xlit}{latin1Text} : $tok->{text};';


## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args:
##     analyzeGet   => $code,    ##-- pseudo-accessor: @morph_analyses = "$code"->(\@toks)
##     analyzeWhich => $which,   ##-- e.g. 'Types','Tokens','Sentences','Local': default=Types
##                               ##   + the underlying analysis is always performed by the analyzeTypes() method! (default='Types')
sub new {
  my $that = shift;
  my $lz = $that->SUPER::new(
			     ##-- analysis selection
			     label => 'lemma',
			     analyzeGet => $GET_MORPH,
			     analyzeGetText => $GET_TEXT,
			     analyzeWhich => 'Types',
			     #typeKeys => undef,

			     ##-- user args
			     @_
			    );
  return $lz;
}

## @keys = $anl->typeKeys()
##  + returns list of type-wise keys to be expanded for this analyzer by expandTypes()
##  + override returns @{$lt->{typeKeys}}
sub typeKeys {
  return @{$_[0]{typeKeys}} if ($_[0]{typeKeys} && @{$_[0]{typeKeys}});
  return qw();
}

## $bool = $anl->doAnalyze(\%opts, $name)
##  + override: only allow analyzeSentences()
sub doAnalyze {
  my $anl = shift;
  return 0 if (defined($_[1]) && $_[1] ne $anl->{analyzeWhich});
  return $anl->SUPER::doAnalyze(@_);
}

## \@toks = $anl->_analyzeGuts(\@toks,\%opts)
##  + guts: analyze all tokens in \@toks
sub _analyzeGuts {
  my ($lz,$toks,$opts) = @_;

  ##-- common vars
  my $lab = $lz->{label};
  my $lab_txt = $lab."_text";
  my $lab_key = $lab."_key";

  ##-- prepare map $key2a = { "$text\t$hi" => $analysis, ... }
  my $key2a = {};
  my ($tok,$tokm,$ma,$txt,$key);
  my $prep_code =
    'foreach $tok (@$toks) {
       next if (!($tokm='.$lz->{analyzeGet}.'));
       foreach (grep {defined($_)} @$tokm) {
         $txt = $_->{$lab_txt} = '.$lz->{analyzeGetText}.';
         $key = $_->{$lab_key} = $txt."\t".$_->{hi};
         next if (exists($key2a->{$key}));
         $key2a->{$key} = $_;
       }
     }';
  my $prep_sub = eval "sub { $prep_code }";
  $lz->logcluck("_analyzeGuts(): could not compile preprocessing sub {$prep_code}: $@") if (!$prep_sub);
  $prep_sub->();

  ##-- lemmatize, type-wise by (text+analysis)-pair
  my ($lemma);
  foreach (values %$key2a) {
    $lemma = $_->{hi};
    if (defined($lemma) && $lemma ne '' && $lemma =~ /^[^\]]+\[/) { ##-- tagh analysis (vs. tokenizer-supplied analysis)
      $lemma =~ s/\[.*$//; ##-- trim everything after first non-character symbol
      $lemma =~ s/(?:\/\w+)|(?:[\\\�\~\|\=\+\#])//g;
      $lemma =~ s/^(.)(.*)$/$1\L$2\E/ if ($lemma =~ /[[:lower:]]/);
      ;
    } else {
      $lemma = $_->{$lab_txt};
    }
    $lemma =~ s/^\s+//;
    $lemma =~ s/\s+$//;
    $lemma =~ s/\s+/_/g;
    $_->{$lab} = $lemma;
  }

  ##-- postprocessing: re-expand types
  my $postp_code =
    'foreach $tok (@$toks) {
       next if (!($tokm='.$lz->{analyzeGet}.'));
       foreach (grep {defined($_)} @$tokm) {
         $_->{$lab} = $key2a->{$_->{$lab_key}}{$lab};
         delete(@$_{$lab_key,$lab_txt});
       }
     }';
  my $postp_sub = eval "sub { $postp_code }";
  $lz->logcluck("_analyzeGuts(): could not compile postprocessing sub {$postp_code}: $@") if (!$postp_sub);
  $postp_sub->();

  return $toks;
}


## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
sub analyzeTypes {
  my ($lz,$doc,$types,$opts) = @_;
  return $doc if ($lz->{analyzeWhich} ne 'Types');
  $lz->_analyzeGuts([values %$types],$opts);
  return $doc;
}

## $doc = $anl->analyzeOther($which, $doc,\%opts)
##  + analyze all tokens in $doc
sub analyzeOther {
  my ($anl,$which,$doc,$opts) = @_;
  return $doc if (defined($which) && $which ne $anl->{analyzeWhich});
  $anl->_analyzeGuts([map {@{$_->{tokens}}} @{$doc->{body}}],$opts);
  return $doc;
}

sub analyzeTokens { return $_[0]->analyzeOther('Tokens',@_[1..$#_]); }
sub analyzeSentences { return $_[0]->analyzeOther('Sentences',@_[1..$#_]); }
sub analyzeLocal { return $_[0]->analyzeOther('Local',@_[1..$#_]); }
sub analyzeClean { return $_[0]->analyzeOther('Clean',@_[1..$#_]); }



1; ##-- be happy

__END__
