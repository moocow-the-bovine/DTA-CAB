## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::TextPhonetic.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: phonetic digest analysis using Text::Phonetic

package DTA::CAB::Analyzer::TextPhonetic;
use DTA::CAB::Analyzer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

## $DEFAULT_ANALYZE_GET
##  + default coderef or eval-able string for {analyzeGet}
##  + eval()d in list context, may return multiples
##  + parameters:
##      $_[0] => token object being analyzed
##  + closure vars:
##      $anl  => analyzer (automaton)
our $DEFAULT_ANALYZE_GET = '$_[0]{xlit} ? $_[0]{xlit}{latin1Text} : $_[0]{text}';


## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args
##    alg => $alg,            ##-- Text::Phonetic subclass, e.g. 'Soundex','Koeln','Metaphone' (default='Soundex')
##    tpo => $obj,            ##-- underlying Text::Phonetic::Whatever object
##    analyzeGet => $codestr, ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET)
sub new {
  my $that = shift;
  my $tp = $that->SUPER::new(
			     ##-- defaults
			     alg => 'Soundex',
			     tpo => undef, ##-- see ensureLoaded()
			     analyzeGet => $DEFAULT_ANALYZE_GET,

			     ##-- analysis selection
			     label => 'tpho',

			     ##-- user args
			     @_
			    );
  return $tp;
}

## $bool = $anl->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version always returns true
sub ensureLoaded {
  my $tp = shift;
  return 1 if ($tp->{tpo});
  eval "use Text::Phonetic; use Text::Phonetic::$tp->{alg};";
  if ($@ || !$INC{"Text/Phonetic/$tp->{alg}.pm"}) {
    $tp->logwarn("cannot use Text::Phonetic::$tp->{alg}: $@");
    return 0;
  }
  $tp->info("using Text::Phonetic version ", ($Text::Phonetic::VERSION || '-undef-'));
  $tp->{tpo} = "Text::Phonetic::$tp->{alg}"->new();
  return $tp;
}

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just greps for CODE-refs
sub noSaveKeys {
  my $tp = shift;
  return ($tp->SUPER::noSaveKeys, 'tpo');
}

##==============================================================================
## Methods: Analysis: v1.x

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Utils

## $bool = $anl->canAnalyze();
##  + returns true iff analyzer can perform its function (e.g. data is loaded & non-empty)
##  + default implementation always returns true
sub canAnalyze { return $_[0]{tpo} ? 1 : 0; }


## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + default implementation does nothing
sub analyzeTypes {
  my ($tp,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);

  ##-- common variables
  my $tpo   = $tp->{tpo};
  my $label = $tp->{label};
  my $aget  = $tp->accessClosure(defined($tp->{analyzeGet}) ? $tp->{analyzeGet} :  $DEFAULT_ANALYZE_GET);

  my ($tok,$txt,$pho);
  foreach $tok (values(%$types)) {
    $txt = $aget->($tok);
    $pho = $tpo->encode(defined($txt) ? $txt : '');
    $tok->{$label} = $pho;
  }
  return $doc;
}



1; ##-- be happy

__END__
