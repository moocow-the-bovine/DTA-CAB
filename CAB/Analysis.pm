## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analysis.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for (token-level) analyses
#   + Nothing here (yet), just an abstract base class

package DTA::CAB::Analysis;
use DTA::CAB::Datum;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Datum);

##==============================================================================
## Constructors etc.
##==============================================================================


1; ##-- be happy

__END__
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
