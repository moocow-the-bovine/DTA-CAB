##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::Builtin.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description:
##  + DTA::CAB::Server::HTTP::Handler: built-in classes
##======================================================================

package DTA::CAB::Server::HTTP::Handler::Builtin;
use strict;

use DTA::CAB::Server::HTTP::Handler;
use DTA::CAB::Server::HTTP::Handler::Alias;
use DTA::CAB::Server::HTTP::Handler::File;
use DTA::CAB::Server::HTTP::Handler::Directory;
use DTA::CAB::Server::HTTP::Handler::Response;
use DTA::CAB::Server::HTTP::Handler::CGI;
use DTA::CAB::Server::HTTP::Handler::Query;
use DTA::CAB::Server::HTTP::Handler::QueryFormats;
use DTA::CAB::Server::HTTP::Handler::QueryList;
use DTA::CAB::Server::HTTP::Handler::Template;
use DTA::CAB::Server::HTTP::Handler::XmlRpc;

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Server::HTTP::Handler::Builtin - DTA::CAB::Server::HTTP::Handler: built-in classes

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Server::HTTP::Handler::Builtin;

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Server::HTTP::Handler::Builtin just loads the common
built-in L<DTA::CAB::Server::HTTP::Handler|DTA::CAB::Server::HTTP::Handler>
subclasses.

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<DTA::CAB::Server::HTTP(3pm)|DTA::CAB::Server::HTTP>,
L<DTA::CAB::Server::HTTP::Handler(3pm)|DTA::CAB::Server::HTTP::Handler>,
L<DTA::CAB::Server::HTTP::Handler::CGI(3pm)|DTA::CAB::Server::HTTP::Handler::CGI>
L<DTA::CAB::Server::HTTP::Handler::Directory(3pm)|DTA::CAB::Server::HTTP::Handler::Directory>
L<DTA::CAB::Server::HTTP::Handler::File(3pm)|DTA::CAB::Server::HTTP::Handler::File>
L<DTA::CAB::Server::HTTP::Handler::Query(3pm)|DTA::CAB::Server::HTTP::Handler::Query>
L<DTA::CAB::Server::HTTP::Handler::Response(3pm)|DTA::CAB::Server::HTTP::Handler::Response>
L<DTA::CAB::Server::HTTP::Handler::XmlRpc(3pm)|DTA::CAB::Server::HTTP::Handler::XmlRpc>
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...


=cut
