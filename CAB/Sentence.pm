## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Sentence.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for sentences passed to/from DTA::CAB::Analyzer

package DTA::CAB::Sentence;
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



## $s = CLASS_OR_OBJ->new(\@tokens,%args)
##  + object structure: HASH
##    {
##     tokens => \@tokens,   ##-- DTA::CAB::Token objects
##     ##
##     ##-- dta-tokwrap attributes
##     xmlid => $id,
##    }
sub new {
  return bless({
		tokens => ($#_>=1 ? $_[1] : []),
		@_[2..$#_],
	       }, ref($_[0])||$_[0]);
}


##==============================================================================
## Methods: Misc
##==============================================================================



1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl & edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Sentence - generic API for sentences passed to/from DTA::CAB::Analyzer

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Sentence;
 
 $s = CLASS_OR_OBJ->new(\@tokens,%args);


=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Sentence: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Sentence
inherits from
L<DTA::CAB::Datum|DTA::CAB::Datum>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Sentence: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $s = CLASS_OR_OBJ->new(\@tokens,%args);


%args, %$s:

 tokens => \@tokens,   ##-- array of DTA::CAB::Token objects

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


=cut