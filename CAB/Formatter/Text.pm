## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::Text.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: verbose human-readable text

package DTA::CAB::Formatter::Text;
use DTA::CAB::Formatter;
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
  my $out = $tok->{text}."\n";

  ##-- Transliterator ('xlit')
  $out .= ("\txlit:"
	   ." isLatin1=".$tok->{"xlit.isLatin1"}
	   ." isLatinExt=".$tok->{"xlit.isLatinExt"}
	   ." latin1Text=".$tok->{"xlit.latin1Text"}
	   ."\n")
    if (defined($tok->{"xlit.latin1Text"}));

  ##-- Morph ('morph')
  $out .= join('', map { "\tmorph: $_->[0] <$_->[1]>\n" } @{$tok->{morph}}) if ($tok->{morph});

  ##-- MorphSafe ('morph.safe')
  $out .= "\tmorph.safe: ".($tok->{"morph.safe"} ? 1 : 0)."\n" if (exists($tok->{"morph.safe"}));

  ##-- Rewrites + analyses
  $out .= join('',
	       map {
		 ("\trw: $_->[0] <$_->[1]>\n",
		  ($_->[2] ? map { "\t\tmorph/rw: $_->[0] <$_->[1]>\n" } @{$_->[2]} : qw()))
	       } @{$tok->{rw}})
    if ($tok->{rw});

  ##-- ... ???
  return $out;
}

## $out = $fmt->formatSentence($sent)
##  + default version just concatenates formatted tokens
sub formatSentence {
  my ($fmt,$sent) = @_;
  return join('', map {$fmt->formatToken($_)} @$sent[1..$#$sent])."\n";
}

## $out = $fmt->formatDocument($doc)
##  + default version just concatenates formatted sentences
sub formatDocument {
  my ($fmt,$doc) = @_;
  return join('', map {$fmt->formatSentence($_)} @$doc[1..$#$doc]);
}


1; ##-- be happy

__END__
