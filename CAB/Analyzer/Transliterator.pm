## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Transliterator.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: latin-1 approximator

package DTA::CAB::Analyzer::Transliterator;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Transliterator::Analysis ':const';

use Unicode::Normalize; ##-- compatibility decomposition 'KD' (see Unicode TR #15)
use Unicode::UCD;       ##-- unicode character names, info, etc.
use Unicode::CharName;  ##-- ... faster access to character name, block
use Text::Unidecode;    ##-- last-ditch effort: transliterate to ASCII

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
##  + object structure, new:
##    analysisKey => $key,   ##-- token analysis key (default='xlit')
##  + object structure, inherited from DTA::CAB::Analyzer:
##     ##-- errors etc
##     errfh   => $fh,       ##-- FH for warnings/errors (default=\*STDERR; requires: "print()" method)
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   analysisKey => 'xlit',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $aut->ensureLoaded()
##  + ensures analysis data is loaded
sub ensureLoaded { return 1; }

##==============================================================================
## Methods: Analysis
##==============================================================================

## $token = $anl->analyze($token_or_text,\%analyzeOptions)
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->analyzeSub()
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->getAnalyzeSub()
##  + returned sub is callable as:
##     $token = $coderef->($token_or_text,\%analyzeOptions)
##  + sets $token->{$anl->{analysisKey}} : a DTA::CAB::Token with:
##     isLatin1   => $bool,    ##-- true iff $token->{text} is losslessly encodable as latin1
##     isLatinExt => $bool,    ##-- true iff $token->{text} is losslessly encodable as latin-extended
##     text       => $l1text,  ##-- best latin-1 approximation of $token->{text}
sub getAnalyzeSub {
  my $xlit = shift;
  my $akey = $xlit->{analysisKey};

  my ($tok,$uc,$l0,$l);
  return sub {
    $tok = DTA::CAB::Token->toToken(shift);
    $uc  = Unicode::Normalize::NFKC($tok->{text}); ##-- compatibility(?) decomposition + canonical composition

    ##-- construct latin-1 approximation
    if (
	$uc =~ m([^\p{inBasicLatin}\p{inLatin1Supplement}]) #)
       )
      {
	$l0 = $uc;

	##-- special handling for some character sequences
	$l0 =~ s/\x{0363}/a/g;	##-- COMBINING LATIN SMALL LETTER A
	$l0 =~ s/\x{0364}/e/g;	##-- COMBINING LATIN SMALL LETTER E
	$l0 =~ s/\x{0365}/i/g;	##-- COMBINING LATIN SMALL LETTER I
	$l0 =~ s/\x{0366}/o/g;	##-- COMBINING LATIN SMALL LETTER O

	##-- default: copy plain latin-1 characters, transliterate rest with Text::Unidecode::unidecode()
	$l  = join('',
		   map {
		     ($_ =~ m(\p{inBasicLatin}|\p{InLatin1Supplement}) #)
		      ? $_	##-- Latin-1 character: just copy
		      : Text::Unidecode::unidecode($_) ##-- Non-Latin-1: transliterate
		     )
		   } split(//,$l0)
		  );
	$l = decode('latin1',$l);

	if (
	    $l =~ m([^\p{inBasicLatin}\p{inLatin1Supplement}]) #)
	   ) {
	  ##-- sanity check
	  carp(ref($xlit)."::analyze(): transliteration resulted in non-latin-1 string: '$l' for utf-8 '$tok->{text}'");
	}

	##-- properties
	$tok->{$akey} = bless({text=>$l, isLatin1=>0, isLatinExt=>($uc =~ m([^\p{Latin}]) ? 0 : 1) }, 'DTA::CAB::Token');
      } else {
	$tok->{$akey} = bless({text=>$uc, isLatin1=>1, isLatinExt=>1 }, 'DTA::CAB::Token');
      }
    ##-- return
    return $tok;
  };
}


##==============================================================================
## Methods: Debug
##==============================================================================

## $humanReadableString = $xlit->analysisHuman($analysis)
#BEGIN { *analysisHuman = \&analysisString; }
#sub analysisString {
#  return (defined($_[1]) ? $_[1] : $_[0])->textString();
#}


1; ##-- be happy

__END__
