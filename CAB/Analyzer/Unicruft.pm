## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Unicruft.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: latin-1 approximator

package DTA::CAB::Analyzer::Unicruft;

use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
use DTA::CAB::Token;

use Unicruft;
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

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##      $tok = $coderef->($tok,\%analyzeOptions)
##  + sets (for $key=$anl->{analysisKey}):
##      $tok->{$key} = { latin1Text=>$latin1Text, isLatin1=>$isLatin1, isLatinExt=>$isLatinExt }
##    with:
##      $latin1Text = $str     ##-- best latin-1 approximation of $token->{text}
##      $isLatin1   = $bool    ##-- true iff $token->{text} is losslessly encodable as latin1
##      $isLatinExt = $bool,   ##-- true iff $token->{text} is losslessly encodable as latin-extended
sub getAnalyzeTokenSub {
  my $xlit = shift;
  my $akey = $xlit->{analysisKey};

  my ($tok, $w,$uc, $ld, $isLatin1,$isLatinExt);
  return sub {
    $tok = shift;
    $tok = toToken($tok) if (!ref($tok));
    $w   = $tok->{text};
    $uc  = Unicode::Normalize::NFKC($w); ##-- compatibility(?) decomposition + canonical composition

    ##-- construct latin-1/de approximation
    $ld = decode('latin1',Unicruft::utf8_to_latin1_de($uc));
    if (
	#$uc !~ m([^\p{inBasicLatin}\p{inLatin1Supplement}]) #)
	$uc  =~ m(^[\x{00}-\x{ff}]*$) #)
       )
      {
	$isLatin1 = $isLatinExt = 1;
      }
    elsif ($uc =~ m(^[\p{Latin}]*$))
      {
	$isLatin1 = 0;
	$isLatinExt = 1;
      }
    else
      {
	$isLatin1 = $isLatinExt = 0;
      }

    ##-- return
    #return [ $l, $isLatin1, $isLatinExt ];
    #$tok->{$akey} = [ $l, $isLatin1, $isLatinExt ];
    $tok->{$akey} = { latin1Text=>$ld, isLatin1=>$isLatin1, isLatinExt=>$isLatinExt };

    return $tok;
  };
}

##==============================================================================
## Methods: Analysis: v1.x
##==============================================================================

## $doc = $xlit->analyzeTypes($doc,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + sets (for $key=$anl->{analysisKey}):
##      $tok->{$key} = { latin1Text=>$latin1Text, isLatin1=>$isLatin1, isLatinExt=>$isLatinExt }
##    with:
##      $latin1Text = $str     ##-- best latin-1 approximation of $token->{text}
##      $isLatin1   = $bool    ##-- true iff $token->{text} is losslessly encodable as latin1
##      $isLatinExt = $bool,   ##-- true iff $token->{text} is losslessly encodable as latin-extended
sub analyzeTypes {
  my ($xlit,$doc,$opts) = @_;
  my $akey = $xlit->{analysisKey};

  my ($tok, $w,$uc, $ld, $isLatin1,$isLatinExt);
  foreach $tok (values(%{$doc->{types}})) {
    $w   = $tok->{text};
    $uc  = Unicode::Normalize::NFKC($w); ##-- compatibility(?) decomposition + canonical composition

    ##-- construct latin-1/de approximation
    $ld = decode('latin1',Unicruft::utf8_to_latin1_de($uc));
    if (
	#$uc !~ m([^\p{inBasicLatin}\p{inLatin1Supplement}]) #)
	$uc  =~ m(^[\x{00}-\x{ff}]*$) #)
       )
      {
	$isLatin1 = $isLatinExt = 1;
      }
    elsif ($uc =~ m(^[\p{Latin}]*$))
      {
	$isLatin1 = 0;
	$isLatinExt = 1;
      }
    else
      {
	$isLatin1 = $isLatinExt = 0;
      }

    ##-- return
    #return [ $l, $isLatin1, $isLatinExt ];
    #$tok->{$akey} = [ $l, $isLatin1, $isLatinExt ];
    $tok->{$akey} = { latin1Text=>$ld, isLatin1=>$isLatin1, isLatinExt=>$isLatinExt };
  }

  return $doc;
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Unicruft - latin-1 approximator using libunicruft

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Unicruft;
 
 $xl = DTA::CAB::Analyzer::Unicruft->new(%args);
  
 $bool = $xl->ensureLoaded();
 
 $xl->analyzeToken($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

This module replaces the (now obsolete) DTA::CAB::Analyzer::Transliterator module.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Unicruft: Globals
=pod

=head2 Globals

=over 4

=item @ISA

DTA::CAB::Analyzer::Unicruft
inherits from
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Unicruft: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $xl = CLASS_OR_OBJ->new(%args);

%args, %$xl:

 analysisKey => $key,   ##-- token analysis key (default='xlit')

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Unicruft: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $aut->ensureLoaded();

Override: ensures analysis data is loaded

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Unicruft: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item getAnalyzeTokenSub

Override: see L<DTA::CAB::Analyzer::getAnalyzeTokenSub()|DTA::CAB::Analyzer/getAnalyzeTokenSub>.

=over 4

=item *

returned sub is callable as:

 $tok = $coderef->($tok,\%analyzeOptions)

=item *

sets (for $key=$anl-E<gt>{analysisKey}, by default C<xlit>):

 $tok->{$key} = { latin1Text=>$latin1Text, isLatin1=>$isLatin1, isLatinExt=>$isLatinExt }

with:

 $latin1Text = $str     ##-- best latin-1 approximation of $token-E<gt>{text}
 $isLatin1   = $bool    ##-- true iff $token-E<gt>{text} is losslessly encodable as latin1
 $isLatinExt = $bool,   ##-- true iff $token-E<gt>{text} is losslessly encodable as latin-extended

=back

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
