## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Perl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser|formatter: perl code via Data::Dumper, eval()

package DTA::CAB::Format::Perl;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use Data::Dumper;
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:prl|pl|perl|dump)$/);
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
##     dumper => $dumper,              ##-- underlying Data::Dumper object
##
##     ##---- INHERITED from DTA::CAB::Format
##     #encoding => $encoding,         ##-- n/a
##     level     => $formatLevel,      ##-- sets Data::Dumper->Indent() option
##     outbuf    => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- I/O common
		   encoding => undef,

		   ##-- Input
		   #doc => undef,

		   ##-- Output
		   dumper => Data::Dumper->new([])->Purity(1)->Terse(0)->Deepcopy(1),
		   level  => 0,
		   outbuf => '',

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $fmt;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
sub noSaveKeys {
  return qw(doc outbuf);
}

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
sub close {
  delete($_[0]{doc});
  return $_[0];
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($filename_or_handle)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parsePerlString($_[0]);
}

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parsePerlString($str)
sub parsePerlString {
  my $fmt = shift;
  my ($doc);
  $doc = eval "no strict; $_[0];";
  $fmt->warn("parsePerlString(): error in eval: $@") if ($@);
  $doc = DTA::CAB::Utils::deep_utf8_upgrade($doc);
  $fmt->{doc} = $fmt->forceDocument($doc);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument { return $_[0]{doc}; }


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: output selection

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
sub toString { return $_[0]{outbuf}; }

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putToken($tok)
sub putToken {
  $_[0]{outbuf} .= $_[0]{dumper}->Reset->Indent($_[0]{level})->Names(['token'])->Values([$_[1]])->Dump."\$token\n";
  return $_[0];
}

## $fmt = $fmt->putSentence($sent)
sub putSentence {
  $_[0]{outbuf} .= $_[0]{dumper}->Reset->Indent($_[0]{level})->Names(['sentence'])->Values([$_[1]])->Dump."\$sentence\n";
  return $_[0];
}

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  $_[0]{outbuf} .= $_[0]{dumper}->Reset->Indent($_[0]{level})->Names(['document'])->Values([$_[1]])->Dump."\$document\n";
  return $_[0];
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::Perl - Datum parser|formatter: perl code via Data::Dumper, eval()

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::Perl;
 
 $fmt = DTA::CAB::Format::Perl->new(%args);
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $fmt = $fmt->parsePerlString($str);
 $doc = $fmt->parseDocument();
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->flush();
 $str = $fmt->toString();
 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putSentence($sent);
 $fmt = $fmt->putDocument($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::perl is a L<DTA::CAB::Format|DTA::CAB::Format> datum parser/formatter
which reads & writes data as perl code via eval() and Data::Dumper respectively.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Perl: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::Perl
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

=item Filenames

DTA::CAB::Format::Perl registers the filename regex:

 /\.(?i:prl|pl|perl|dump)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Perl: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$fmt:

 ##---- Input
 doc    => $doc,                 ##-- buffered input document
 ##
 ##---- Output
 dumper => $dumper,              ##-- underlying Data::Dumper object
 ##
 ##---- INHERITED from DTA::CAB::Format
 #encoding => $encoding,         ##-- n/a
 level     => $formatLevel,      ##-- sets Data::Dumper->Indent() option
 outbuf    => $stringBuffer,     ##-- buffered output

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Perl: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Override returns list of keys not to be saved.
This implementation returns C<qw(doc outbuf)>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Perl: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close currently selected input source.

=item fromString

 $fmt = $fmt->fromString($string)

Override: select input from the string $string.

=item parsePerlString

 $fmt = $fmt->parsePerlString($str);

Evaluates $str as perl code, which is expected to
return a L<DTA::CAB::Document|DTA::CAB::Document>
object (or something which can be massaged into one),
and sets $fmt-E<gt>{doc} to this new document object.

=item parseDocument

 $doc = $fmt->parseDocument();

Returns the current contents of $fmt-E<gt>{doc},
e.g. the most recently parsed document.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Perl: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item flush

 $fmt = $fmt->flush();

Override: flush accumulated output.

=item toString

 $str = $fmt->toString();
 $str = $fmt->toString($formatLevel)

Override: flush buffered output document to byte-string.
This implementation just returns $fmt-E<gt>{outbuf},
which should already be a byte-string, and has no need of encoding.

=item putToken

 $fmt = $fmt->putToken($tok);

Override: writes a token to the output buffer (non-destructive on $tok).

=item putSentence

 $fmt = $fmt->putSentence($sent);

Override: write a sentence to the outupt buffer (non-destructive on $sent).

=item putDocument

 $fmt = $fmt->putDocument($doc);

Override: write a document to the outupt buffer (non-destructive on $doc).

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

 $document = bless( {
  'body' => [
    bless( {
      'tokens' => [
        bless( {
          'msafe' => 1,
          'lts' => [
            {
              'w' => '0',
              'hi' => 'vi'
            }
          ],
          'xlit' => {
            'isLatin1' => 1,
            'latin1Text' => 'wie',
            'isLatinExt' => 1
          },
          'text' => 'wie',
          'morph' => [
            {
              'w' => '0',
              'hi' => 'wie[_ADV]'
            },
            {
              'w' => '0',
              'hi' => 'wie[_KON]'
            },
            {
              'w' => '0',
              'hi' => 'wie[_KOKOM]'
            },
            {
              'w' => '0',
              'hi' => 'wie[_KOUS]'
            }
          ],
          'eqpho' => [
            'Wie',
            'wie'
          ]
        }, 'DTA::CAB::Token' ),
        bless( {
          'msafe' => 0,
          'lts' => [
            {
              'w' => '0',
              'hi' => '?2de'
            }
          ],
          'xlit' => {
            'isLatin1' => 1,
            'latin1Text' => 'oede',
            'isLatinExt' => 1
          },
          'text' => 'oede',
          'morph' => [],
          'eqpho' => [
            'Oede',
            "\x{d6}de",
            "\x{f6}de"
          ],
          'rw' => [
            {
              'w' => '1',
              'hi' => "\x{f6}de",
              'lts' => [
                {
                  'w' => '0',
                  'hi' => '?2de'
                }
              ],
              'morph' => [
                {
                  'w' => '0',
                  'hi' => "\x{f6}de[_ADJD]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}de[_ADJA][pos][sg][nom]*[weak]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}de[_ADJA][pos][sg][nom][fem][strong_mixed]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}de[_ADJA][pos][sg][acc][fem]*"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}de[_ADJA][pos][sg][acc][neut][weak]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}de[_ADJA][pos][pl][nom_acc]*[strong]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}d~en[_VVFIN][first][sg][pres][ind]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}d~en[_VVFIN][first][sg][pres][subjI]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}d~en[_VVFIN][third][sg][pres][subjI]"
                },
                {
                  'w' => '0',
                  'hi' => "\x{f6}d~en[_VVIMP][sg]"
                }
              ]
            }
          ]
        }, 'DTA::CAB::Token' ),
        bless( {
          'msafe' => 1,
          'lts' => [
            {
              'w' => '0',
              'hi' => ''
            }
          ],
          'xlit' => {
            'isLatin1' => 1,
            'latin1Text' => '!',
            'isLatinExt' => 1
          },
          'text' => '!',
          'morph' => []
        }, 'DTA::CAB::Token' )
      ]
    }, 'DTA::CAB::Sentence' )
  ]
 }, 'DTA::CAB::Document' );

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

