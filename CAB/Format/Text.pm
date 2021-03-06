## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Text.pm
## Author: Bryan Jurish <moocow@cpan.org>
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

## \@blocks = $fmt->blockScanBody(\$buf,\%opts)
##  + scans $filename for block boundaries according to \%opts
sub blockScanBody {
  my ($fmt,$bufr,$opts) = @_;

  ##-- scan blocks into head, body, foot
  my $bsize  = $opts->{bsize} // $opts->{size} // 1048576;
  my $fsize  = $opts->{ifsize};
  my $eob    = $opts->{eob} =~ /^s/i ? 's' : 'w';
  my $blocks = [];

  my ($off0,$off1,$blk);
  for ($off0=$opts->{ihead}[0]+$opts->{ihead}[1]; $off0 < $fsize; $off0=$off1) {
    push(@$blocks, $blk={ioff=>$off0});
    pos($$bufr) = ($off0+$bsize < $fsize ? $off0+$bsize : $fsize);
    if ($eob eq 's' ? $$bufr=~m/\n{2,}/sg : $$bufr=~m/\n{1,}(?!\t)/sg) {
      $off1 = $+[0];
      $blk->{eos} = $+[0]-$-[0] > 1 ? 1 : 0;
    } else {
      $off1       = $fsize;
      $blk->{eos} = 1;
    }
    $blk->{ilen} = $off1-$off0;
  }

  return $blocks;
}

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

=encoding utf8

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

 %% $s:lang=de
 wie
 	+[exlex] wie
 	+[errid] ec
 	+[lang] de
 	+[xlit] l1=1 lx=1 l1s=wie
 	+[hasmorph] 1
 	+[morph/safe] 1
 	+[moot/word] wie
 	+[moot/tag] PWAV
 	+[moot/lemma] wie
 oede
 	+[xlit] l1=1 lx=1 l1s=oede
 	+[morph/safe] 0
 	+[moot/word] ??de
 	+[moot/tag] ADJD
 	+[moot/lemma] ??de
 !
 	+[exlex] !
 	+[errid] ec
 	+[xlit] l1=1 lx=1 l1s=!
 	+[morph/safe] 1
 	+[moot/word] !
 	+[moot/tag] $.
 	+[moot/lemma] !
 

=cut

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2019 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.




=cut
