## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Phonix.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: phonetic digest analysis using Text::Phonetic::Phonix

package DTA::CAB::Analyzer::Phonix;
use DTA::CAB::Analyzer::TextPhonetic;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::TextPhonetic);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args
##    alg => $alg,            ##-- Text::Phonetic subclass, e.g. 'Soundex','Koeln','Metaphone' (default='Metaphone')
##    tpo => $obj,            ##-- underlying Text::Phonetic::Whatever object
##    analyzeGet => $codestr, ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET)
sub new {
  my $that = shift;
  my $tp = $that->SUPER::new(
			     ##-- defaults
			     alg => 'Phonix',

			     ##-- analysis selection
			     label => 'phonix',

			     ##-- user args
			     @_
			    );
  return $tp;
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

DTA::CAB::Analyzer::Phonix - phonetic digest analysis using Text::Phonetic::Phonix

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::Phonix;
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Phonix is
a L<DTA::CAB::Analyzer::TextPhonetic|DTA::CAB::Analyzer::TextPhonetic>
analyzer class using the I<Phonix> algorithm, and storing
digests by default in the field 'phonix'.

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

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2019 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer::TextPhonetic(3pm)|DTA::CAB::Analyzer::TextPhonetic>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
