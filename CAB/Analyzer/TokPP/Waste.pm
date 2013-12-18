## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::TokPP::Waste.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: heuristic text-based analyzer (for punctutation, numbers, etc): moot/waste version

package DTA::CAB::Analyzer::TokPP::Waste;

use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
use DTA::CAB::Token;
use Moot;
use Moot::Waste::Annotator;

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
##  + %$obj, %args:
##    (
##     label => 'tokpp',       ##-- analyzer label
##     annot => $annot,        ##-- underlying Moot::Waste::Annotator object
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   label => 'tokpp',
			   annot => Moot::Waste::Annotator->new(),

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $anl->ensureLoaded()
##  + ensures analysis data is loaded
##  + returns 1 iff $anl->{annot} is defined
sub ensureLoaded {
  my $anl = shift;
  return defined($anl->{annot}) && ($anl->{loaded}=1);
}

##==============================================================================
## Methods: Analysis
##==============================================================================

## $doc = $tpp->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in values(%types)
##  + sets:
##      $tok->{$anl->{label}} = \@morphHiStrings
sub analyzeTypes {
  my ($tpp,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);
  my $akey  = $tpp->{label};
  my $annot = $tpp->{annot};

  my ($tok,$a);
  foreach $tok (values(%$types)) {
    next if (defined($tok->{$akey})); ##-- avoid re-analysis
    $a = $annot->annotate($tok)->{analyses};

    delete($tok->{$akey});
    $tok->{$akey} = [map {$_->{tag}} @$a] if ($a && @$a);
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

DTA::CAB::Analyzer::TokPP::Waste - type-level heuristic token preprocessor (for punctuation etc) using Moot::Waste::Annotator

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::TokPP::Perl;
 
 ##========================================================================
 ## Methods
 
 $obj = CLASS_OR_OBJ->new(%args);
 $bool = $anl->ensureLoaded();
 $doc = $tpp->analyzeTypes($doc,\%types,\%opts);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::TokPP::Waste
provides a
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>
interface to some simple text-based type-wise
word analysis heuristics, e.g. for detection of punctutation,
numeric strings, etc.
It is implemented as a thin wrapper around the Moot::Waste::Annotator class.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::TokPP: Methods
=pod

=head2 Methods

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

%$obj, %args:

 label => $label,       ##-- analyzer label; default='tokpp'


=item ensureLoaded

 $bool = $anl->ensureLoaded();

Ensures analysis data is loaded.
Always returns 1.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::TokPP: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item analyzeTypes

 $doc = $tpp->analyzeTypes($doc,\%types,\%opts);

Perform type-wise analysis of all (text) types in values(%types).
Override sets:

 $tok->{$anl->{label}} = \@morphHiStrings

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

Copyright (C) 2013 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
