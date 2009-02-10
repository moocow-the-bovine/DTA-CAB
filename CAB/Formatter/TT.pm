## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::TT.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: one-word-per line text format

package DTA::CAB::Formatter::TT;
use DTA::CAB::Formatter;
use DTA::CAB::Datum ':all';
use Encode qw(encode decode);
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
			   ##-- encoding
			   encoding => 'UTF-8',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

## $out = $fmt->formatToken($tok)
sub formatToken {
  my ($fmt,$tok) = @_;
  my $out = $tok->{text};

  ##-- Transliterator ('xlit')
  $out .= ("\t+xlit:"
	   ." isLatin1=".$tok->{xlit}[1]
	   ." isLatinExt=".$tok->{xlit}[2]
	   ." latin1Text=".$tok->{xlit}[0]
	  )
    if (defined($tok->{xlit}));

  ##-- Morph ('morph')
  $out .= join('', map { "\t+morph: $_->[0] <$_->[1]>" } @{$tok->{morph}}) if ($tok->{morph});

  ##-- MorphSafe ('morph.safe')
  $out .= "\t+morph.safe: ".($tok->{msafe} ? 1 : 0) if (exists($tok->{msafe}));

  ##-- Rewrites + analyses
  $out .= join('',
	       map {
		 ("\t+rw: $_->[0] <$_->[1]>",
		  ($_->[2] ? map { "\t+morph/rw: $_->[0] <$_->[1]>" } @{$_->[2]} : qw()))
	       } @{$tok->{rw}})
    if ($tok->{rw});

  ##-- ... ???
  return $out."\n";
}

## $out = $fmt->formatSentence($sent)
##  + default version just concatenates formatted tokens
sub formatSentence {
  my ($fmt,$sent) = @_;
  return join('', map {$fmt->formatToken($_)} @{toSentence($sent)->{tokens}})."\n";
}

## $out = $fmt->formatDocument($doc)
##  + default version just concatenates formatted sentences
sub formatDocument {
  my ($fmt,$doc) = @_;
  return join('', map {$fmt->formatSentence($_)} @{toDocument($doc)->{body}})."\n";
}


1; ##-- be happy

__END__
