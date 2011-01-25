## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Builtin
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Load known DTA::CAB::Format subclasses

package DTA::CAB::Format::Builtin;
use DTA::CAB::Format;

#use DTA::CAB::Format::Freeze;
use DTA::CAB::Format::CSV;
use DTA::CAB::Format::Null;
use DTA::CAB::Format::Perl;
use DTA::CAB::Format::Storable;
use DTA::CAB::Format::Raw;      ##-- raw untokenized (input only)
use DTA::CAB::Format::Text;
#use DTA::CAB::Format::Text1; ##-- test v1.x
use DTA::CAB::Format::TT;
use DTA::CAB::Format::YAML;
use DTA::CAB::Format::JSON;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Format::XmlNative; ##-- load first to avoid clobbering '.xml' extension
use DTA::CAB::Format::XmlPerl;
use DTA::CAB::Format::XmlRpc;
#use DTA::CAB::Format::XmlVz;
use strict;

1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::Builtin - load built-in DTA::CAB::Format subclasses

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::Builtin;

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

The DTA::CAB::Format::Builtin module just loads all built-in
L<DTA::CAB::Format|DTA::CAB::Format> subclasses.  It is not
a format class in and of itself.

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
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
