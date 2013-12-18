## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::TokPP.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: heuristic text-based analyzer (for punctutation, numbers, etc): top-level

package DTA::CAB::Analyzer::TokPP;

use DTA::CAB::Analyzer::TokPP::Perl;
use DTA::CAB::Analyzer::TokPP::Waste;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::TokPP::Waste);
#our @ISA = qw(DTA::CAB::Analyzer::TokPP::Perl);


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::TokPP - type-level heuristic token preprocessor (for punctuation etc): high-level wrapper

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::TokPP;
 
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

DTA::CAB::Analyzer::TokPP
provides a
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>
interface to some simple text-based type-wise
word analysis heuristics, e.g. for detection of punctutation,
numeric strings, etc.
It wraps DTA::CAB::Analyzer::TokPP::Waste.

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

Copyright (C) 2010-2013 by Bryan Jurish

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
