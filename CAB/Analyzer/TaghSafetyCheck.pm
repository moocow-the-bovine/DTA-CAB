## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::TaghSafetyCheck.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: safety checker for analyses output by TAGH

package DTA::CAB::Analyzer::TaghSafetyCheck;

use DTA::CAB::Analyzer;

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
##    (none yet)
##  + object structure, inherited from DTA::CAB::Analyzer:
##     ##-- errors etc
##     errfh   => $fh,       ##-- FH for warnings/errors (default=\*STDERR; requires: "print()" method)
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   #(none)

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

## $analysis = $anl->analyze($tagh_analyses,\%analyzeOptions)
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->analyzeSub()
##  + inherited from DTA::CAB::Analyzer

## $coderef = $anl->getAnalyzeSub()
##  + returned sub is callable as:
##     $coderef->($tagh_analyses,\%analyzeOptions)
sub getAnalyzeSub {
  my $xlit = shift;

  my ($w,$uc,$l0,$l, $isLatin1,$isLatinExt,$isNative);
  return sub {
    $w  = shift;
    $uc = Unicode::Normalize::NFKC($w); ##-- compatibility(?) decomposition + canonical composition

    ##-- construct latin-1 approximation
    if ($uc =~ m/[^\p{inBasicLatin}\p{inLatin1Supplement}]/) {
      $l0 = $uc;

      ##-- special handling for some character sequences
      $l0 =~ s/\x{0363}/a/g; ##-- COMBINING LATIN SMALL LETTER A
      $l0 =~ s/\x{0364}/e/g; ##-- COMBINING LATIN SMALL LETTER E
      $l0 =~ s/\x{0365}/i/g; ##-- COMBINING LATIN SMALL LETTER I
      $l0 =~ s/\x{0366}/o/g; ##-- COMBINING LATIN SMALL LETTER O

      ##-- default: copy plain latin-1 characters, transliterate rest with Text::Unidecode::unidecode()
      $l  = join('',
		 map {
		   ($_ =~ /\p{inBasicLatin}|\p{InLatin1Supplement}/
		    ? $_                             ##-- Latin-1 character: just copy
		    : Text::Unidecode::unidecode($_) ##-- Non-Latin-1: transliterate
		   )
		 } split(//,$l0)
		);
      $l = decode('latin1',$l);

      if ($l =~ m/[^\p{inBasicLatin}\p{inLatin1Supplement}]/) {
	##-- sanity check
	carp(ref($xlit)."::analyze(): transliteration resulted in non-latin-1 string: '$l' for utf-8 '$w'");
      }

      ##-- properties
      $isLatin1   = 0;
      $isLatinExt = $w =~ m/[^\p{Latin}]/ ? 0 : 1;
    } else {
      $l=$uc;
      $isLatin1 = $isLatinExt = 1;
    }

    ##-- check for any editing
    #$isNative = $l eq $w ? 1 : 0;

    ##-- return analysis: [ $latin1_string, $isLatin1, $isLatinExt ] #, $isNative
    return bless [$l, $isLatin1,$isLatinExt], 'DTA::CAB::Analyzer::Transliterator::Analysis';
  };
}


##==============================================================================
## Methods: Debug
##==============================================================================

## $humanReadableString = $xlit->analysisHuman($analysis)
BEGIN { *analysisHuman = \&analysisString; }
sub analysisString {
  return (defined($_[1]) ? $_[1] : $_[0])->textString();
}


1; ##-- be happy

__END__
