## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Transliterator.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: latin-1 approximator

package DTA::CAB::Analyzer::Transliterator;

use DTA::CAB::Analyzer;
use DTA::CAB::Token;

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
##    analysisPrefix => $key,   ##-- token analysis prefix (default='xlit')
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   analysisPrefix => 'xlit',

			   ##-- formatting: XML
			   #xmlAnalysisElt => 'xlit',

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

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeSub()
##  + returned sub is callable as:
##      $tok = $coderef->($tok,\%analyzeOptions)
##  + alters %$token, for ${prefix}=$anl->{analysisPrefix}
##      $tok->{"${prefix}.latin1Text"} = $str,    ##-- best latin-1 approximation of $token->{text}
##      $tok->{"${prefix}.isLatin1"}   = $bool,   ##-- true iff $token->{text} is losslessly encodable as latin1
##      $tok->{"${prefix}.isLatinExt"} = $bool,   ##-- true iff $token->{text} is losslessly encodable as latin-extended
sub getAnalyzeTokenSub {
  my $xlit = shift;
  my $aprf = $xlit->{analysisPrefix};

  my ($tok, $w,$uc,$l0,$l, $isLatin1,$isLatinExt);
  return sub {
    $tok = toToken(shift);
    $w   = $tok->{text};
    $uc  = Unicode::Normalize::NFKC($w); ##-- compatibility(?) decomposition + canonical composition

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
	  carp(ref($xlit)."::analyzeToken(): transliteration resulted in non-latin-1 string: '$l' for utf-8 '$w'");
	}

	##-- set properties
	$isLatin1 = 0;
	$isLatinExt = ($uc =~ m([^\p{Latin}]) ? 0 : 1);
      } else {
	$l = $uc;
	$isLatin1 = $isLatinExt = 1;
      }

    ##-- return
    #return [ $l, $isLatin1, $isLatinExt ];
    #
    $tok->{"${aprf}.latin1Text"} = $l;
    $tok->{"${aprf}.isLatin1"}   = $isLatin1;
    $tok->{"${aprf}.isLatinExt"} = $isLatinExt;
    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting --> OBSOLETE ?!
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: Perl

## $str = $anl->analysisPerl($out,\%opts)
##  + inherited from DTA::CAB::Analyzer

##--------------------------------------------------------------
## Methods: Formatting: Text

## $str = $anl->analysisText($out,\%opts)
##  + text string for output $out with options \%opts
sub analysisText {
  return (
	  '['
	  .($_[1][1] ? '+' : '-').'latin1'
	  .','
	  .($_[1][2] ? '+' : '-').'latinx'
	  .'] '
	  .$_[1][0]
	 );
}

##--------------------------------------------------------------
## Methods: Formatting: Verbose Text

## @lines = $anl->analysisVerbose($out,\%opts)
##  + verbose text line(s) for output $out with options \%opts
##  + default version just calls analysisText()
sub analysisVerbose {
  return "isLatin1=$_[1][1] isLatinExt=$_[1][2] latin1Text=$_[1][0]";
}

##--------------------------------------------------------------
## Methods: Formatting: XML

## $nod = $anl->analysisXmlNode($out,\%opts)
##  + XML node for output $out with options \%opts
##  + returns new XML element:
##    <$anl->{xmlAnalysisElt} isLatin1="$bool" isLatinExt="$bool" latin1Text="$str"/>
sub analysisXmlNode {
  my $nod = XML::LibXML::Element->new($_[0]{xmlAnalysisElt} || DTA::CAB::Utils::xml_safe_string(ref($_[0])));
  $nod->setAttribute('isLatin1', $_[1][1]);
  $nod->setAttribute('isLatinExt', $_[1][2]);
  $nod->setAttribute('latin1Text', $_[1][0]);
  return $nod;
}

## $nod = $anl->defaultXmlNode($val)
##  + default XML node generator
##  + inherited from DTA::CAB::Analyzer

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
