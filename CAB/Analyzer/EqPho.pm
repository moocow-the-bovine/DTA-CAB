## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::EqPho
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: phonetic-equivalence class expander: default

##==============================================================================
## Package
##==============================================================================
package DTA::CAB::Analyzer::EqPho;
use strict;
#use DTA::CAB::Analyzer::EqPho::FST;
#our @ISA = qw(DTA::CAB::Analyzer::EqPho::FST);
##
#use DTA::CAB::Analyzer::EqPho::BDB;
#our @ISA = qw(DTA::CAB::Analyzer::EqPho::BDB);
##
#use DTA::CAB::Analyzer::EqPho::CDB;
#our @ISA = qw(DTA::CAB::Analyzer::EqPho::CDB);
##
use DTA::CAB::Analyzer::EqPho::JsonCDB;
our @ISA = qw(DTA::CAB::Analyzer::EqPho::JsonCDB);

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited
=pod

=cut

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::EqPho - phonetic equivalence class expander

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::EqPho;

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

Default phonetic equivalence class expander.
Just a wrapper for L<DTA::CAB::Analyzer::EqPho::JsonCDB|DTA::CAB::Analyzer::EqPho::JsonCDB>.

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

Copyright (C) 2009-2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer::EqPho::BDB(3pm)|DTA::CAB::Analyzer::EqPho::BDB>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...

=cut

