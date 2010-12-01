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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:sto|bin)$/);
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
sub noSaveKeys {
  return qw(doc); #docbuf
}

##=============================================================================
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
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##   + just returns buffered object in $fmt->{doc}
sub parseDocument { return $_[0]->forceDocument( $_[0]{doc} ); }


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'application/octet-stream'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.bin'; }


##--------------------------------------------------------------
## Methods: Output: output selection

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
## Methods: Output: Recommended API

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
## Methods: Output: Required API

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

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::Storable - Datum parser using Storable::freeze() & co.

=cut


##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::Storable;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::Storable->new(%args);
 
 ##========================================================================
 ## Methods: Persistence
 
 @keys = $class_or_obj->noSaveKeys();
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $fmt = $fmt->fromString($string);
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

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Storable: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::Storable
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

=item Filenames

This module registers the filename regex:

 /\.(?i:sto|bin)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Storable: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$fmt:

 ##---- Input
 doc      => $doc,               ##-- buffered input document
 ##
 ##---- Output
 docbuf   => $obj,               ##-- an output object buffer (DTA::CAB::Document object)
 netorder => $bool,              ##-- if true (default), then store in network order
 ##
 ##---- INHERITED from DTA::CAB::Format
 #encoding => $encoding,         ##-- n/a
 #level    => $formatLevel,      ##-- sets Data::Dumper->Indent() option
 #outbuf   => $stringBuffer,     ##-- buffered output

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Storable: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Override: returns list of keys not to be saved.
This implementation just returns C<qw(doc)>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Storable: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close current input source, if any.

=item fromString

 $fmt = $fmt->fromString( $string);
 $fmt = $fmt->fromString(\$string)

Override: select input from string $string.

Requires perl 5.8 or better with PerlIO layer for "real" string I/O handles.

=item fromString_freeze

Like L</fromString>(), but uses Storable::thaw() internally.
This is actually a Bad Idea, since freeze() and thaw() do not
write headers compatible with store() and retrieve() ... annoying
but true.

=item parseDocument

 $doc = $fmt->parseDocument();

Just returns buffered object in $fmt-E<gt>{doc}

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Storable: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item flush

 $fmt = $fmt->flush();

Override: flush accumulated output

=item toString

 $str = $fmt->toString();
 $str = $fmt->toString($formatLevel=!$netorder)

Override: flush buffered output in $fmt-E<gt>{docbuf} to byte-string using Storable::nstore()
or Storable::store().  If $formatLevel is given and true, native-endian Storable::store()
will be used, otherwise (the default) network-order nstore() will be used.

=item toString_freeze

Like L</toString>(), but uses Storable::nfreeze() and Storable::freeze() internally.
See L</fromString_freeze> for some hints regarding why this is a Bad Idea.

=item toFh

 $fmt_or_undef = $fmt->toFh($fh,$formatLevel)

Override: dump buffered output to filehandle $fh.
Calls Storable::nstore() or Storable::store() as indicated by $formatLevel,
whose semantics are as for L</toString>().


=item putToken , putTokenRaw

 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putTokenRaw($tok);

Non-destructive / destructive token append.

=item putSentence , putSentenceRaw

 $fmt = $fmt->putSentence($sent);
 $fmt = $fmt->putSentenceRaw($sent);

Non-destructive / destructive sentence append.

=item putDocument , putDocumentRaw

 $fmt = $fmt->putDocument($doc);
 $fmt = $fmt->putDocumentRaw($doc);

Non-destructive / destructive document append.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Storable: Package Aliases
=pod

=head2 Package Aliases

This module provides
a backwards-compatible
C<DTA::CAB::Format::Freeze> class
which is a trivial subclass of
C<DTA::CAB::Format::Storable>.

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Example
##======================================================================
=pod

=head1 EXAMPLE

No example file for this format is present, since the format
is determined by the perl C<Storable> module.  However,
the reference stored (rsp. retrieved) should be identical to that
in the example perl code in L<DTA::CAB::Format::Perl/EXAMPLE>.

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
