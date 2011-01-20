## -*- Mode: CPerl -*-
## File: DTA::CAB.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: robust morphological analysis: top-level

package DTA::CAB;

use DTA::CAB::Version;
use DTA::CAB::Common;

eval "use DTA::CAB::Analyzer::Common";

#eval "use DTA::CAB::Server::HTTP";
#eval "use DTA::CAB::Client::HTTP";

#eval "use DTA::CAB::Server::XmlRpc";
#eval "use DTA::CAB::Client::XmlRpc";

use strict;

##==============================================================================
## Constants
##==============================================================================

our @ISA = qw(DTA::CAB::Logger); ##-- for compatibility

1; ##-- be happy

__END__

##==============================================================================
## PODS
##==============================================================================
=pod

=head1 NAME

DTA::CAB - "Cascaded Analysis Broker" for robust linguistic analysis

=head1 SYNOPSIS

 use DTA::CAB;

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

The DTA::CAB suite provides an object-oriented API for
error-tolerant linguistic analysis of tokenized text.
The DTA::CAB package itself just loads the common API
from
L<DTA::CAB::Common|DTA::CAB::Common> and attempts
to load the common analysis modules from
L<DTA::CAB::Analyzer::Common|DTA::CAB::Analyzer::Common>
if present.

Earlier versions of the DTA::CAB suite used the DTA::CAB
package to represent a default analyzer class.  The corresponding
class now lives in L<DTA::CAB::Chain::DTA|DTA::CAB::Chain::DTA>.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Constants
=pod

=head2 Constants

=over 4

=item $VERSION

Module version, imported from L<DTA::CAB::Version|DTA::CAB::Version>.

=item $SVNVERSION

SVN version from which this module was built, imported from L<DTA::CAB::Version|DTA::CAB::Version>.

=back

=cut


##==============================================================================
## Footer
##==============================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Bryan Jurish

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
