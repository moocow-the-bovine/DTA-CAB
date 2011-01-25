## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::JSON.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: YML code (generic)

package DTA::CAB::Format::JSON;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

our $WRAP_CLASS = undef;
BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'json', filenameRegex=>qr/\.(?i:json|jsn)$/);
}

foreach my $pmfile (map {"DTA/CAB/Format/JSON/$_.pm"} qw(XS Syck)) {
  if (eval {require($pmfile)} && !$@ && !defined($WRAP_CLASS)) {
    $WRAP_CLASS = $pmfile;
    $WRAP_CLASS =~ s/\//::/g;
    $WRAP_CLASS =~ s/\.pm$//;
  }
}
$WRAP_CLASS = __PACKAGE__ if (!defined($WRAP_CLASS)); ##-- dummy

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- Input
##     doc => $doc,                    ##-- buffered input document
##     raw => $bool,                   ##-- if true, format parses raw data
##
##     ##---- INHERITED from DTA::CAB::Format
##     #encoding => $encoding,         ##-- n/a: always UTF-8 octets
##     level     => $formatLevel,      ##-- 0:raw, 1:typed, ...
##     outbuf    => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  if ($that eq __PACKAGE__ && $WRAP_CLASS ne __PACKAGE__) {
    return $WRAP_CLASS->new(@_);
  }
  my $fmt = bless({
		   ##-- I/O common
		   encoding => undef,
		   raw => 0,

		   ##-- Input
		   #doc => undef,

		   ##-- Output
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
  return $fmt->parseJsonString($_[0]);
}

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseJsonString($str, raw=>$rawMode)
##  + must be defined by child classes!
##  + if $rawMode is true, no document massaging will be performed
sub parseJsonString {
  my $fmt = shift;
  $fmt->logconfess("parseJsonString() not implemented!");
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument { return $_[0]{doc}; }

##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME

## $type = $fmt->mimeType()
##  + override
sub mimeType { return 'application/json'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.json'; }

## $short = $fmt->formatName()
##  + returns "official" short name for this format
##  + default just returns package suffix
sub shortName {
  return 'json';
}


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
##  + default implementation removes typing if ($level < 1)
sub toString {
  $_[0]->formatLevel($_[1]) if (defined($_[1]));
  return $_[0]{outbuf};
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
sub putToken {
  $_[0]->logconfess("putToken() not implemented!");
}

## $fmt = $fmt->putSentence($sent)
sub putSentence {
  $_[0]->logconfess("putSentence() not implemented!");
}

## $fmt = $fmt->putDocument($doc)
sub putDocument {
  $_[0]->logconfess("putDocument() not implemented!");
}

## $fmt = $fmt->putData($data)
##  + puts raw data
sub putData {
  return $_[0]->putDocument($_[1]);
}

1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::JSON - Datum parser|formatter: JSON code (generic)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::JSON;
 
 $fmt = DTA::CAB::Format::JSON->new(%args);
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $doc = $fmt->parseDocument();
 $fmt = $fmt->parseJsonString($str);   ##-- abstract
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->flush();
 $str = $fmt->toString();
 $fmt = $fmt->putToken($tok);         ##-- abstract
 $fmt = $fmt->putSentence($sent);     ##-- abstract
 $fmt = $fmt->putDocument($doc);      ##-- abstract


=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::JSON is a L<DTA::CAB::Format|DTA::CAB::Format> datum parser/formatter
which reads & writes data as JSON code.  It really acts as a wrapper for the first available
subclass among:

=over 4

=item L<DTA::CAB::Format::JSON::XS|DTA::CAB::Format::JSON::XS>

=item L<DTA::CAB::Format::JSON::Syck|DTA::CAB::Format::JSON::Syck>

=item L<DTA::CAB::Format::JSON::JSON|DTA::CAB::Format::JSON::JSON>

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::JSON
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

=item Filenames

DTA::CAB::Format::JSON registers the filename regex:

 /\.(?i:yaml|yml)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::JSON: Constructors etc.
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
## DESCRIPTION: DTA::CAB::Format::JSON: Methods: Persistence
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
## DESCRIPTION: DTA::CAB::Format::JSON: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close currently selected input source.

=item fromString

 $fmt = $fmt->fromString($string)

Override: select input from the string $string.

=item parseJSONString

 $fmt = $fmt->parseJsonString($str);

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
## DESCRIPTION: DTA::CAB::Format::JSON: Methods: Output
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
which should already be a UTF-8 byte-string, and has no need of encoding.

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

 {
    "body" : [
       {
          "tokens" : [
             {
                "lts" : [
                   {
                      "w" : 0,
                      "hi" : "vi"
                   }
                ],
                "msafe" : "1",
                "text" : "wie",
                "xlit" : {
                   "latin1Text" : "wie",
                   "isLatin1" : "1",
                   "isLatinExt" : "1"
                },
                "morph" : [
                   {
                      "w" : 0,
                      "hi" : "wie[_ADV]"
                   },
                   {
                      "w" : 0,
                      "hi" : "wie[_KON]"
                   },
                   {
                      "w" : 0,
                      "hi" : "wie[_KOKOM]"
                   },
                   {
                      "w" : 0,
                      "hi" : "wie[_KOUS]"
                   }
                ],
                "eqpho" : [
                   {
                      "w" : 0,
                      "hi" : "Wie"
                   },
                   {
                      "w" : 0,
                      "hi" : "wie"
                   }
                ]
             },
             {
                "lts" : [
                   {
                      "w" : 0,
                      "hi" : "?2de"
                   }
                ],
                "msafe" : "0",
                "text" : "oede",
                "xlit" : {
                   "latin1Text" : "oede",
                   "isLatin1" : "1",
                   "isLatinExt" : "1"
                },
                "eqpho" : [
                   {
                      "w" : 0,
                      "hi" : "Oede"
                   },
                   {
                      "w" : 0,
                      "hi" : "Öde"
                   },
                   {
                      "w" : 0,
                      "hi" : "öde"
                   }
                ],
                "rw" : [
                   {
                      "w" : "1",
                      "hi" : "öde",
                      "lts" : [
                         {
                            "w" : 0,
                            "hi" : "?2de"
                         }
                      ],
                      "morph" : [
                         {
                            "w" : 0,
                            "hi" : "öde[_ADJD]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öde[_ADJA][pos][sg][nom]*[weak]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öde[_ADJA][pos][sg][nom][fem][strong_mixed]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öde[_ADJA][pos][sg][acc][fem]*"
                         },
                         {
                            "w" : 0,
                            "hi" : "öde[_ADJA][pos][sg][acc][neut][weak]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öde[_ADJA][pos][pl][nom_acc]*[strong]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öd~en[_VVFIN][first][sg][pres][ind]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öd~en[_VVFIN][first][sg][pres][subjI]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öd~en[_VVFIN][third][sg][pres][subjI]"
                         },
                         {
                            "w" : 0,
                            "hi" : "öd~en[_VVIMP][sg]"
                         }
                      ]
                   }
                ]
             },
             {
                "lts" : [
                   {
                      "w" : 0,
                      "hi" : ""
                   }
                ],
                "msafe" : "1",
                "text" : "!",
                "xlit" : {
                   "latin1Text" : "!",
                   "isLatin1" : "1",
                   "isLatinExt" : "1"
                }
             }
          ]
       }
    ]
 }


=cut

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

