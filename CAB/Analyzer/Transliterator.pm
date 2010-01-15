## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Transliterator.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: latin-1 approximator (old)

package DTA::CAB::Analyzer::Transliterator;

use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
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
##    label => $key,   ##-- token analysis key (default='xlit')
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   label => 'xlit',

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
## Methods: Analysis: v1.x
##==============================================================================

## $doc = $xlit->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in values(%types)
##  + sets
##      $tok->{$anl->{label}} = { latin1Text=>$latin1Text, isLatin1=>$isLatin1, isLatinExt=>$isLatinExt }
##    with:
##      $latin1Text = $str     ##-- best latin-1 approximation of $token->{text}
##      $isLatin1   = $bool    ##-- true iff $token->{text} is losslessly encodable as latin1
##      $isLatinExt = $bool,   ##-- true iff $token->{text} is losslessly encodable as latin-extended
sub analyzeTypes {
  my ($xlit,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);
  my $akey = $xlit->{label};

  my ($tok, $w,$uc, $ld, $isLatin1,$isLatinExt);
  foreach $tok (values(%$types)) {
    $w   = $tok->{text};
    $uc  = Unicode::Normalize::NFKC($w); ##-- compatibility(?) decomposition + canonical composition

    ##-- construct latin-1 approximation
    if (
	#$uc =~ m([^\p{inBasicLatin}\p{inLatin1Supplement}]) #)
	$uc  =~ m([^\x{00}-\x{ff}]) #)
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
		     (
		      #$_ =~ m(\p{inBasicLatin}|\p{InLatin1Supplement}) #)
		      $_  =~ m([\x{00}-\x{ff}]) #)
		      ? $_	##-- Latin-1 character: just copy
		      : Text::Unidecode::unidecode($_) ##-- Non-Latin-1: transliterate
		     )
		   } split(//,$l0)
		  );
	$l = decode('latin1',$l);

	if (
	    #$l =~ m([^\p{inBasicLatin}\p{inLatin1Supplement}]) #)
	    $l  =~ m([^\x{00}-\x{ff}]) #)
	   ) {
	  ##-- sanity check
	  $xlit->logwarn("analyzeToken(): transliteration resulted in non-latin-1 string: '$l' for utf-8 '$w'");
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
    #$tok->{$akey} = [ $l, $isLatin1, $isLatinExt ];
    $tok->{$akey} = { latin1Text=>$l, isLatin1=>$isLatin1, isLatinExt=>$isLatinExt };
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

DTA::CAB::Analyzer::Transliterator - latin-1 approximator (old, pure-perl implementation)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Transliterator;
 
 $xl = DTA::CAB::Analyzer::Transliterator->new(%args);
  
 $bool = $xl->ensureLoaded();
 
 $xl->analyzeToken($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Transliterator: Globals
=pod

=head2 Globals

=over 4

=item @ISA

DTA::CAB::Analyzer::Transliterator
inherits from
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Transliterator: Constructors etc.
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
## DESCRIPTION: DTA::CAB::Analyzer::Transliterator: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $aut->ensureLoaded();

Override: ensures analysis data is loaded

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
