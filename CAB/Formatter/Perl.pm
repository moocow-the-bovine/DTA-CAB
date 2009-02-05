## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::Perl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: perl code

package DTA::CAB::Formatter::Perl;
use DTA::CAB::Formatter;
use Data::Dumper;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Formatter);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- INHERITED from DTA::CAB::Formatter
##     ##-- output file (optional)
##     #outfh => $output_filehandle,  ##-- for default toFile() method
##     #outfile => $filename,         ##-- for determining whether $output_filehandle is local
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

## $out = $fmt->formatToken($tok)
##  + returns formatted token $tok
sub formatToken {
  my ($fmt,$tok) = @_;
  return Data::Dumper->Dump([$tok]);
}

## $out = $fmt->formatSentence($sent)
##  + default version just concatenates formatted tokens
sub formatSentence {
  my ($fmt,$sent) = @_;
  return Data::Dumper->Dump([$sent]);
}

## $out = $fmt->formatDocument($doc)
##  + default version just concatenates formatted sentences
sub formatDocument {
  my ($fmt,$doc) = @_;
  return Data::Dumper->Dump([$doc]);
}


1; ##-- be happy

__END__
