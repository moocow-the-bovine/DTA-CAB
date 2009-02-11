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
##     ##---- NEW
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     encoding  => $encoding,         ##-- output encoding
##     #level    => $formatLevel,      ##-- n/a
##     outbuf    => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- encoding
			   encoding => 'UTF-8',
			   #outbuf => ''

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: output selection
##==============================================================================

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  delete($_[0]{outbuf});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
sub toString {
  return encode($_[0]{encoding},$_[0]{outbuf})
    if ($_[0]{encoding} && defined($_[0]{outbuf}) && utf8::is_utf8($_[0]{outbuf}));
  return $_[0]{outbuf};
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)


##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

## $fmt = $fmt->putToken($tok)
sub putToken {
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
  $fmt->{outbuf} .= $out."\n";
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
##  + default version just concatenates formatted tokens
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->putToken($_) foreach (@{toSentence($sent)->{tokens}});
  $fmt->{outbuf} .= "\n";
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
##  + default version just concatenates formatted sentences
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->putSentence($_) foreach (@{toDocument($doc)->{body}});
  return $fmt;
}


1; ##-- be happy

__END__
