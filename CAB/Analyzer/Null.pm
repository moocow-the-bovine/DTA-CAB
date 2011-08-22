## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Null.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: null analyzer (dummy)

package DTA::CAB::Analyzer::Null;
use DTA::CAB::Analyzer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args
##    alg => $alg,            ##-- Text::Phonetic subclass, e.g. 'Soundex','Koeln','Metaphone' (default='Koeln')
##    tpo => $obj,            ##-- underlying Text::Phonetic::Whatever object
##    analyzeGet => $codestr, ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET)
sub new {
  my $that = shift;
  my $a = $that->SUPER::new(
			    ##-- analysis selection
			    label => 'null',
			    ##-- user args
			    @_
			   );
  return $a;
}


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

DTA::CAB::Analyzer::Null - null analyzer (dummy)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::Null;
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

Just a dummy analyzer for testing purposes.

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod



=cut

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut