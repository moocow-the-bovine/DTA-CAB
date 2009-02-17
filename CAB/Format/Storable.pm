## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Storable.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser using Storable::freeze() & co.

package DTA::CAB::Format::Storable;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use DTA::CAB::Token;
use DTA::CAB::Sentence;
use DTA::CAB::Document;
use Storable;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:sto|bin)/);
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
##     docbuf   => $obj,               ##-- an output object buffer (DTA::CAB::Document object)
##     netorder => $bool,              ##-- if true (default), then store in network order
##
##     ##---- INHERITED from DTA::CAB::Format
##     #encoding => $encoding,         ##-- n/a
##     #level    => $formatLevel,      ##-- sets Data::Dumper->Indent() option
##     #outbuf   => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   #doc => undef,

		   ##-- output
		   docbuf   => DTA::CAB::Document->new(),
		   netorder => 1,

		   ##-- i/o common
		   encoding => undef, ##-- not applicable

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
##  + default just returns empty list
sub noSaveKeys {
  return qw(doc); #docbuf
}

##=============================================================================
## Methods: Parsing
##==============================================================================

##--------------------------------------------------------------
## Methods: Parsing: Input selection

## $fmt = $fmt->close()
sub close {
  delete($_[0]{doc});
  return $_[0];
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($fh)
sub fromFh {
  my ($fmt,$fh) = @_;
  $fmt->close;
  $fmt->{doc} = Storable::retrieve_fd($fh)
    or $fmt->logconfess("fromFh(): Storable::retrieve_fd() failed: $!");
  return $fmt;
}

## $fmt = $fmt->fromString( $string)
## $fmt = $fmt->fromString(\$string)
##  + requires perl 5.8 or better with PerlIO layer for "real" string I/O handles
sub fromString {
  my $fmt = shift;
  my $fh  = IO::Handle->new();
  my $str = shift;
  CORE::open($fh,'<',(ref($str) ? $str : \$str))
      or $fmt->logconfess("could not open() filehandle for string ref");
  #$fh->binmode();
  my $rc = $fmt->fromFh($fh);
  $fh->close();
  return $fmt;
}
sub fromString_freeze {
  my $fmt = shift;
  $fmt->close;
  $fmt->{doc} = Storable::thaw($_[0])
    or $fmt->logconfess("fromString(): Storable::thaw() failed: $!");
  return $fmt;
}


##--------------------------------------------------------------
## Methods: Parsing: Generic API

## $doc = $fmt->parseDocument()
##   + just returns buffered object in $fmt->{doc}
sub parseDocument { return $_[0]->forceDocument( $_[0]{doc} ); }


##==============================================================================
## Methods: Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  $_[0]{docbuf} = DTA::CAB::Document->new();
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel=!$netorder)
##  + flush buffered output in $fmt->{docbuf} to byte-string (using Storable::freeze())
sub toString {
  my $fmt = shift;
  my $fh  = IO::Handle->new();
  my $str = '';
  CORE::open($fh,'>',\$str)
      or $fmt->logconfess("could not open() filehandle for string ref");
  #$fh->binmode();
  my $rc = $fmt->toFh($fh,@_);
  $fh->close();
  return $str;
}
sub toString_freeze {
  my $fmt = shift;
  return $fmt->{netorder} ? Storable::nfreeze($fmt->{docbuf}) : Storable::freeze($fmt->{docbuf});
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + default delegates to formatString()
sub toFh {
  my ($fmt,$fh) = @_;
  if ($fmt->{netorder}) {
    Storable::nstore_fd($fmt->{docbuf},$fh);
  } else {
    Storable::store_fd($fmt->{docbuf}, $fh);
  }
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Formatting: Recommended API

## $fmt = $fmt->putToken($tok)
sub putToken { $_[0]->putTokenRaw(Storable::dclone($_[1])); }
sub putTokenRaw {
  my ($fmt,$tok) = @_;
  my $buf = $fmt->{docbuf};
  if (@{$buf->{body}}) {
    push(@{$buf->{body}[$#{$buf->{body}}]}, $tok);
  } else {
    push(@{$buf->{body}}, toSentence([$tok]));
  }
}

## $fmt = $fmt->putSentence($sent)
sub putSentence { $_[0]->putSentenceRaw(Storable::dclone($_[1])); }
sub putSentenceRaw {
  my ($fmt,$sent) = @_;
  push(@{$fmt->{docbuf}{body}}, $sent);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Formatting: Required API

## $fmt = $fmt->putDocument($doc)
sub putDocument { $_[0]->putDocumentRaw(Storable::dclone($_[1])); }
sub putDocumentRaw {
  my ($fmt,$doc) = @_;
  my $buf = $fmt->{docbuf};
  if (scalar(keys(%$buf))==1 && !@{$buf->{body}}) {
    ##-- steal $doc
    $fmt->{docbuf} = $doc;
  } else {
    ##-- append $doc->{body} onto $buf->{body}
    push(@{$buf->{body}}, @{$doc->{body}});
    foreach (grep {$_ ne 'body'} keys(%$doc)) {
      $buf->{$_} = $doc->{$_}; ##-- clobber existing keys
    }
  }
  return $fmt;
}

##==============================================================================
## Package Aliases
##==============================================================================
package DTA::CAB::Format::Freeze;
our @ISA = qw(DTA::CAB::Format::Storable);

1; ##-- be happy

__END__
