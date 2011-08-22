## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Morph::Latin.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: latin pseudo-morphology (top-level alias)

##==============================================================================
## Package: Analyzer::Morph::Latin
##==============================================================================
package DTA::CAB::Analyzer::Morph::Latin;
#use DTA::CAB::Analyzer::Morph::Latin::FST;
#use DTA::CAB::Analyzer::Morph::Latin::Dict;
use DTA::CAB::Analyzer::Morph::Latin::BDB;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Morph::Latin::BDB);

##==============================================================================
## Analysis Formatting
##==============================================================================


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl
=pod

=cut

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Morph::Latin - latin pesudo-morphology analysis (wrapper)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Morph::Latin;
 
 $morph = DTA::CAB::Analyzer::Morph::Latin->new(%args);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Morph::Latin
is a just a wrapper for
L<DTA::CAB::Analyzer::Morph::Latin::BDB|DTA::CAB::Analyzer::Morph::Latin::BDB>.

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

Copyright (C) 2009-2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut