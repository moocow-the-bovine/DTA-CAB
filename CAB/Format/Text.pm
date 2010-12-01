## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Text.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: verbose human-readable text

package DTA::CAB::Format::Text;
use DTA::CAB::Format;
use DTA::CAB::Format::TT;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::TT);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:txt|text|cab\-txt|cab\-text)$/);
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
##     #level    => $formatLevel,      ##-- output formatting level: n/a
##     outbuf    => $stringBuffer,     ##-- buffered output
##
##     ##---- Common
##     encoding  => $encoding,         ##-- default: 'UTF-8'
##     defaultFieldName => $name,      ##-- default name for unnamed fields; parsed into @{$tok->{other}{$name}}; default=''
##    )
## + inherited from DTA::CAB::Format::TT

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved: qw(doc outbuf)
##  + inherited from DTA::CAB::Format::TT

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
##  + inherited from DTA::CAB::Format::TT

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($fh)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
##  + wrapper for: $fmt->close->parseTTString($_[0])
##  + inherited from DTA::CAB::Format::TT
##  + name is aliased here to parseTextString() !

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseTextString($string)
BEGIN { *parseTTString = \&parseTextString; }
sub parseTextString {
  my ($fmt,$src) = @_;
  $src =~ s/\r?\n\t\+?/\t/sg;
  return DTA::CAB::Format::TT::parseTTString($fmt,$src);
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##  + just returns $fmt->{doc}
##  + inherited from DTA::CAB::Format::TT


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.txt'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
##  + inherited from DTA::CAB::Format::TT

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
##  + override re-formats TT output string
sub toString {
  $_[0]->tt2text(\$_[0]{outbuf});
  return $_[0]->SUPER::toString(@_[1..$#_]);
}

## \$bufr = $fmt->tt2text(\$buffer)
##   + convert TT buffer \$buffer to text
##   + should be a null-op if \$buffer is already text format
sub tt2text {
  my $bufr = $_[1];
  $$bufr =~ s/(?<!\n)\t/\n\t/sg;
  $$bufr =~ s/^\t\[/\t+\[/mg;
  return $bufr;
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putToken($tok)
##  + appends $tok to output buffer
##  + INHERITED from Format::TT

## $fmt = $fmt->putSentence($sent)
##  + concatenates formatted tokens, adding sentence-id comment if available
##  + inherited from DTA::CAB::Format::TT

## $out = $fmt->formatDocument($doc)
##  + concatenates formatted sentences, adding document 'xmlbase' comment if available
##  + inherited from DTA::CAB::Format::TT

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::Text - Datum parser: verbose human-readable text

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::Text;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::Text->new(%args);
 
 ##========================================================================
 ## Methods: Input
 
 $doc = $fmt->parseTextString();
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->putToken($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

Human-readable wrapper for L<DTA::CAB::Format::TT|DTA::CAB::Format::TT>.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::Text
inherits from
L<DTA::CAB::Format|DTA::CAB::Format> via L<DTA::CAB::Format::TT|DTA::CAB::Format::TT>.

=item Filenames

This module registers the filename regex:

 /\.(?i:txt|text)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.
Inherited from L<DTA::CAB::Format::TT|DTA::CAB::Format::TT>.

%args, %$fmt:

 ##---- Input
 doc => $doc,                    ##-- buffered input document
 ##
 ##---- Output
 #level    => $formatLevel,      ##-- output formatting level: n/a
 outbuf    => $stringBuffer,     ##-- buffered output
 ##
 ##---- Common
 encoding  => $encoding,         ##-- default: 'UTF-8'

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item parseTextString

 $fmt = $fmt->parseTextString($str);

Guts for document parsing: parse string $str into local document buffer $fmt-E<gt>{doc}.

=item parseTTString

 $fmt = $fmt->parseTTString($str);

Alias for parseTextString().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item putToken

 $fmt = $fmt->putToken($tok);

Override: append formatted token $tok to output buffer.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Example
##======================================================================
=pod

=head1 EXAMPLE

An example file in the format accepted/generated by this module is:

 wie
	+[xlit] isLatin1=1 isLatinExt=1 latin1Text=wie
	+[lts] vi <0>
	+[eqpho] Wie
	+[eqpho] wie
	+[morph] wie[_ADV] <0>
	+[morph] wie[_KON] <0>
	+[morph] wie[_KOKOM] <0>
	+[morph] wie[_KOUS] <0>
	+[morph/safe] 1
 oede
	+[xlit] isLatin1=1 isLatinExt=1 latin1Text=oede
	+[lts] ?2de <0>
	+[eqpho] Oede
	+[eqpho] Öde
	+[eqpho] öde
	+[morph/safe] 0
	+[rw] öde <1>
	+[rw/lts] ?2de <0>
	+[rw/morph] öde[_ADJD] <0>
	+[rw/morph] öde[_ADJA][pos][sg][nom]*[weak] <0>
	+[rw/morph] öde[_ADJA][pos][sg][nom][fem][strong_mixed] <0>
	+[rw/morph] öde[_ADJA][pos][sg][acc][fem]* <0>
	+[rw/morph] öde[_ADJA][pos][sg][acc][neut][weak] <0>
	+[rw/morph] öde[_ADJA][pos][pl][nom_acc]*[strong] <0>
	+[rw/morph] öd~en[_VVFIN][first][sg][pres][ind] <0>
	+[rw/morph] öd~en[_VVFIN][first][sg][pres][subjI] <0>
	+[rw/morph] öd~en[_VVFIN][third][sg][pres][subjI] <0>
	+[rw/morph] öd~en[_VVIMP][sg] <0>
 !
	+[xlit] isLatin1=1 isLatinExt=1 latin1Text=!
	+[lts]  <0>
	+[morph/safe] 1
 


=cut

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
