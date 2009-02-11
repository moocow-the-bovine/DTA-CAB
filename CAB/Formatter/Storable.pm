## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::Storable.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter using Storable::freeze(), etc.

package DTA::CAB::Formatter::Storable;
use DTA::CAB::Formatter;
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

our @ISA = qw(DTA::CAB::Formatter);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- NEW
##     docbuf   => $obj,               ##-- an output object buffer (DTA::CAB::Document object)
##     netorder => $bool,              ##-- if true (default), then store/retrieve in network order
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     #encoding => $encoding,         ##-- n/a
##     #level    => $formatLevel,      ##-- n/a
##     #docbuf   => $stringBuffer,     ##-- n/a
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- output buffer
			   docbuf   => DTA::CAB::Document->new(),
			   netorder => 1,

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
  $_[0]{docbuf} = DTA::CAB::Document->new();
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel=!$netorder)
##  + flush buffered output in $fmt->{docbuf} to byte-string (using Storable::freeze())
sub toString {
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


##==============================================================================
## Methods: Formatting: Recommended API
##==============================================================================

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

##==============================================================================
## Methods: Formatting: Required API
##==============================================================================

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
## Aliases
##==============================================================================
package DTA::CAB::Formatter::Freeze;
our @ISA = qw(DTA::CAB::Formatter::Storable);

1; ##-- be happy

__END__
