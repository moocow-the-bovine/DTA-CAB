## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MorphSafe.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: safety checker for analyses output by DTA::CAB::Analyzer::Morph (TAGH)

package DTA::CAB::Analyzer::MorphSafe;

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
##    ##-- analysis selection
##    analysisSrcKey => $srcKey,    ##-- input token key   (default: 'morph')
##    analysisKey    => $key,       ##-- output key        (default: 'msafe')
##
##    auxSrcKey      => $srcKey,    ##-- auxilliary token key (e.g. 'mlatin'); always "safe" if present & true; default=none
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   analysisSrcKey => 'morph',
			   analysisKey    => 'msafe',
			   #auxSrcKey      => 'mlatin',

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
##     $tok = $coderef->($tok,\%opts)
##  + tests safety of morphological analyses in $tok->{morph}
##  + sets $tok->{ $anl->{analysisKey} } = $bool
sub getAnalyzeTokenSub {
  my $ms = shift;

  my $srcKey = $ms->{analysisSrcKey};
  my $akey   = $ms->{analysisKey};
  my $auxkey = $ms->{auxSrcKey};
  my ($tok,$opts,$analyses,$safe);
  return sub {
    ($tok,$opts) = @_;
    $analyses = $tok->{$srcKey};
    $safe = ($tok->{text}    =~ m/^[[:digit:][:punct:]]*$/ ##-- punctuation, digits are (almost) always "safe"
	     && $tok->{text} !~ m/\#/                      ##-- unless they contain '#' (placeholder for unrecognized char)
	    );
    $safe ||= ($tok->{$auxkey} && @{$tok->{$auxkey}}) if ($auxkey); ##-- always consider 'aux' analyses (e.g. latin) "safe"
    $safe ||=
      (
       $analyses                 ##-- defined & true
       && @$analyses > 0         ##-- non-empty
       && (
	   grep {                ##-- at least one non-"unsafe" analysis:
	     ($_                     ##-- only "unsafe" if defined
	      && $_->{hi}            ##-- only "unsafe" if upper labels are defined & non-empty
	      && $_->{hi} !~ m(
                   (?:               ##-- unsafe: regexes
                       \[_FM\]       ##-- unsafe: tag: FM: foreign material
                     | \[_XY\]       ##-- unsafe: tag: XY: non-word (abbreviations, etc)
                     | \[_ITJ\]      ##-- unsafe: tag: ITJ: interjection
                     | \[_NE\]       ##-- unsafe: tag: NE: proper name

                     ##-- unsafe: verb roots
                     | \b te    (?:\/V|\~)
                     | \b gel   (?:\/V|\~)
                     | \b �l    (?:\/V|\~)

                     ##-- unsafe: noun roots
                     | \b Bus   (?:\/N|\[_NN\])
                     | \b Ei    (?:\/N|\[_NN\])
                     | \b Eis   (?:\/N|\[_NN\])
                     | \b Gel   (?:\/N|\[_NN\])
                     | \b Gen   (?:\/N|\[_NN\])
                     | \b �l    (?:\/N|\[_NN\])
                     | \b Reh   (?:\/N|\[_NN\])
                     | \b Tee   (?:\/N|\[_NN\])
                     | \b Teig  (?:\/N|\[_NN\])
                   )
                 )x)
	   } @$analyses
	  )
      );

    ##-- output
    $tok->{$akey} = $safe ? 1 : 0;
  };
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::MorphSafe - safety checker for analyses output by DTA::CAB::Analyzer::Morph (TAGH)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::MorphSafe;
 
 $msafe = CLASS_OR_OBJ->new(%args);
 
 $bool = $msafe->ensureLoaded();
 
 $coderef = $msafe->getAnalyzeTokenSub();

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MorphSafe: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::MorphSafe inherits from
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MorphSafe: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $msafe = CLASS_OR_OBJ->new(%args);

%args, %$msafe:

 ##-- analysis selection
 analysisSrcKey => $srcKey,    ##-- input token key   (default: 'morph')
 analysisKey    => $key,       ##-- output key        (default: 'msafe')

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MorphSafe: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $msafe->ensureLoaded();

Override: ensures analysis data is loaded

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MorphSafe: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item getAnalyzeTokenSub

 $coderef = $anl->getAnalyzeTokenSub();

Override.

=over 4


=item *

returned sub is callable as:

 $tok = $coderef->($tok,\%opts)

=item *

tests safety of morphological analyses in $tok-E<gt>{morph}

=item *

sets $tok-E<gt>{ $anl-E<gt>{analysisKey} } = $bool

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
