## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Text.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser: verbose human-readable text

package DTA::CAB::Format::Text;
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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:txt|text|cab\-txt|cab\-text)$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'txt');
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
##     #outbuf    => $stringBuffer,     ##-- buffered output
##
##     ##---- Common
##     utf8 => $bool,                  ##-- default: 1
##     defaultFieldName => $name,      ##-- default name for unnamed fields; parsed into @{$tok->{other}{$name}}; default=''
##    )
## + inherited from DTA::CAB::Format::TT

##==============================================================================
## Methods: Persistence
##==============================================================================

##==============================================================================
## Methods: I/O: Block-wise
##==============================================================================

## \@blocks = $fmt->blockScan($filename, %opts)
##  + scans $filename for block boundaries according to $bspec
##  + override pukes
sub blockScan {
  $_[0]->logconfess("blockScan(): not implemented");
}

## $fmt_or_undef = $fmt->blockMerge($block,$filename)
##  + append a block $block to a file $filename
##  + $block is a HASH-ref as returned by blockScan()
##  + inherited from TT

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseTextString(\$string)
BEGIN { *parseTTString = \&parseTextString; }
sub parseTextString {
  my ($fmt,$src) = @_;
  $$src =~ s/\r?\n\t\+?/\t/sg;
  return DTA::CAB::Format::TT::parseTTString($fmt,$src);
}

##--------------------------------------------------------------
## Methods: Input: Generic API


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Generic

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.txt'; }

##--------------------------------------------------------------
## Methods: Output: output selection

## \$buf = $fmt->token2buf($tok,\$buf)
##  + buffer output for a single token
##  + override converts from TT->Text
sub token2buf {
  my $bufr = DTA::CAB::Format::TT::token2buf(@_);
  $$bufr =~ s/(?<!\n)\t/\n\t/sg;
  $$bufr =~ s/^\t\[/\t+\[/mg;
  return $bufr;
}

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
