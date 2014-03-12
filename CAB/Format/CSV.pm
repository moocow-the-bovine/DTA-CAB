## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::CSV.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: Datum parser: concise minimal-output human-readable text

package DTA::CAB::Format::CSV;
use DTA::CAB::Format;
use DTA::CAB::Format::TT;
use DTA::CAB::Datum ':all';
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::TT);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:csv|cab\-csv)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- Input
##     doc => $doc,                    ##-- buffered input document
##
##     ##---- Output
##     level    => $formatLevel,      ##-- output formatting level:
##                                    ##   0: text, xlit, canon, tag, lemma
##                                    ##   1: text, xlit, canon, tag, lemma, details
##     #outbuf    => $stringBuffer,     ##-- buffered output
##
##     ##---- Common
##     utf8  => $bool,                 ##-- default: 1
##    )
## + inherited from DTA::CAB::Format::TT

##==============================================================================
## Methods: Persistence
##==============================================================================

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseTextString(\$string)
BEGIN { *parseTTString = \&parseCsvString; }
sub parseCsvString {
  my ($fmt,$src) = @_;
  no warnings qw(uninitialized);
  $$src =~ s|^([^\t]+)(?:\t([^\t]*))?\t([^\t]*)\t([^\t]*)\t([^\t\r\n]*)(?:\t([^\t\r\n]*))?$|$1\t[xlit] $2\t[dmoot/tag] $3\t[moot/word] $3\t[moot/tag] $4\t[moot/lemma] $5\t[moot/details] $6|mg;
  return DTA::CAB::Format::TT::parseTTString($fmt,$src);
}

##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Generic

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.csv'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## \$buf = $fmt->token2buf($tok,\$buf)
##  + buffer output for a single token
##  + override implements CSV format
sub token2buf {
  my $bufr = ($_[2] ? $_[2] : \(my $buf=''));
  $$bufr = join("\t",
		$_[1]{text},
		($_[1]{xlit} ? $_[1]{xlit}{latin1Text} : ''),
		($_[1]{moot} ? (@{$_[1]{moot}}{qw(word tag lemma)}) : ('','','')),
		(($_[0]{level}//0) >= 1
		 ? ($_[1]{moot} && $_[1]{moot}{details} ? ($_[1]{moot}{details}{details}//'*') : '')
		 : qw())
	       )."\n";
  return $bufr;
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::CSV - Datum I/O: concise minimal-output human-readable text

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::CSV;
 
 ##========================================================================
 ## Methods: Constructors etc.
 
 $fmt = CLASS_OR_OBJ->new(%args)
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->parseCsvString($string);
 
 ##========================================================================
 ## Methods: Output
 
 $type = $fmt->mimeType();
 $ext = $fmt->defaultExtension();
 $fmt = $fmt->putToken($tok);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::CSV
is a L<DTA::CAB::Format|DTA::CAB::Format> subclass
for representing the minimal "interesting" results of a
L<DTA::CAB::Chain::DTA|DTA::CAB::Chain::DTA> canonicalization
in a (more or less) human- and machine-friendly TAB-separated format.
As for L<DTA::CAB::Format::TT|DTA::CAB::Format::TT> (from which this class inherits),
each token is represented by a single line and sentence boundaries
are represented by blank lines.  Token lines have the format:

 OLD_TEXT   XLIT_TEXT   NEW_TEXT    POS_TAG    LEMMA	?DETAILS

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::CSV: Methods: Constructors etc.
=pod

=head2 Methods: Constructors etc.

=over 4

=item new

  $fmt = CLASS_OR_OBJECT->new(%args);

Recognized %args:

 ##---- Input
 doc => $doc,                    ##-- buffered input document
 
 ##---- Output
 level    => $formatLevel,      ##-- output formatting level:
                                ##   0: text, xlit, canon, tag, lemma
                                ##   1: text, xlit, canon, tag, lemma, details
 
 #outbuf    => $stringBuffer,     ##-- buffered output
 
 ##---- Common
 utf8  => $bool,                 ##-- default: 1

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::CSV: Methods: Input: Local
=pod

=head2 Methods: Input: Local

=over 4

=item parseCsvString

 $fmt = $fmt->parseCsvString($string);

Hack which converts a CSV string to a TT string and passes it to
L<DTA::CAB::Format::TT::parseTTString|DTA::CAB::Format::TT/parseTTString>().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::CSV: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item mimeType

 $type = $fmt->mimeType();

Default returns text/plain.

=item defaultExtension

 $ext = $fmt->defaultExtension();

Deturns default filename extension for this format.
Override returns '.csv'.

=item putToken

 $fmt = $fmt->putToken($tok);

Appends $tok to output buffer.

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

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<DTA::CAB::Format::TT(3pm)|DTA::CAB::Format::TT>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
