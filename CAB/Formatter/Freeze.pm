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
##     outbuf   => $obj,               ##-- an output object buffer (DTA::CAB::Document or similar)
##     netorder => $bool,              ##-- if true (default), then store/retrieve in network order
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     #encoding => $encoding,         ##-- n/a
##     #level    => $formatLevel,      ##-- n/a
##     #outbuf   => $stringBuffer,     ##-- n/a
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- output buffer
			   outbuf   => undef,
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
  delete($_[0]{outbuf});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel=!$netorder)
##  + flush buffered output in $fmt->{outbuf} to byte-string (using Storable::freeze())
sub toString {
  my $fmt = shift;
  return $fmt->{netorder} ? Storable::nfreeze($fmt->{outbuf}) : Storable::freeze($fmt->{outbuf});
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + default delegates to formatString()
sub toFh {
  my ($fmt,$fh) = @_;
  if ($fmt->{netorder}) {
    Storable::nstore_fd($fmt->{outbuf},$fh);
  } else {
    Storable::store_fd($fmt->{outbuf}, $fh);
  }
  return $fmt;
}


##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

## $fmt = $fmt->putToken($tok)
sub putToken { $_[0]->putTokenRaw(Storable::dclone($_[1])); }
sub putTokenRaw {
  my ($fmt,$tok) = @_;
  my ($buf);
  if (!defined($buf=$fmt->{outbuf})) {
    $fmt->{outbuf} = $tok;
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Token')) {
    $fmt->{outbuf} = toSentence([$fmt->{outbuf},$tok]);
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Sentence')) {
    push(@{$buf->{tokens}}, $tok);
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Document')) {
    if (@{$buf->{body}}) {
      push(@{$buf->{body}[$#{$buf->{body}}]}, $tok);
    } else {
      push(@{$buf->{body}}, toSentence([$tok]));
    }
  }
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
sub putSentence { $_[0]->putSentenceRaw(Storable::dclone($_[1])); }
sub putSentenceRaw {
  my ($fmt,$sent) = @_;
  my ($buf);
  if (!defined($buf=$fmt->{outbuf})) {
    $fmt->{outbuf} = $sent;
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Token')) {
    $fmt->{outbuf} = DTA::CAB::Document->new([ toSentence([$buf]), $sent ]);
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Sentence')) {
    $fmt->{outbuf} = DTA::CAB::Document->new([ $buf, $sent ]);
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Document')) {
    push(@{$buf->{body}}, $sent);
  }
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
sub putDocument { $_[0]->putDocumentRaw(Storable::dclone($_[1])); }
sub putDocumentRaw {
  my ($fmt,$doc) = @_;
  my ($buf);
  if (!defined($buf=$fmt->{outbuf})) {
    $fmt->{outbuf} = $doc;
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Token')) {
    splice(@{$doc->{body}},0,0, toSentence([$buf]));
    $fmt->{outbuf} = $doc;
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Sentence')) {
    splice(@{$doc->{body}},0,0, $buf);
    $fmt->{outbuf} = $doc;
  } elsif (UNIVERSAL::isa($buf,'DTA::CAB::Document')) {
    push(@{$buf->{body}}, @{$doc->{body}});
    foreach (grep {$_ ne 'body'} keys(%$doc)) {
      $buf->{$_} = $doc->{$_}; ##-- clobber existing keys
    }
  }
  return $fmt;
}


1; ##-- be happy

__END__
