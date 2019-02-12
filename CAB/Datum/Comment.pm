## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Comment.pm
## Author: Bryan Jurish <jurish@uni-potsdam..de>
## Description: DTA::CAB data: comments

package DTA::CAB::Comment;
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

## $cmt = CLASS_OR_OBJ->new($comment_text)
##  + object structure:
##     + SCALAR ref: \$comment_text
sub new {
  my $text = $_[1];
  $text = '' if (!defined($text));
  return bless(\$text, ref($_[0])||$_[0]);
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

DTA::CAB::Comment - DTA::CAB data: comments

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Comment;
 
 ##========================================================================
 ## Constructors etc.
 
 $cmt = CLASS_OR_OBJ->new($comment_text);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

B<DEPRECATED>

Abandoned attempt at representing comments from document data files
as specialized L<DTA::CAB::Datum|DTA::CAB::Datum> objects.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Comment: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $cmt = CLASS_OR_OBJ->new($comment_text);


=over 4


=item *

object structure:

=over 4


=item *

SCALAR ref: \$comment_text

=back


=back

=back

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
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<dta-cab-http-server.perl(1)|dta-cab-http-server.perl>,
L<dta-cab-http-client.perl(1)|dta-cab-http-client.perl>,
L<dta-cab-xmlrpc-server.perl(1)|dta-cab-xmlrpc-server.perl>,
L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl>,
L<DTA::CAB::Server(3pm)|DTA::CAB::Server>,
L<DTA::CAB::Client(3pm)|DTA::CAB::Client>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
