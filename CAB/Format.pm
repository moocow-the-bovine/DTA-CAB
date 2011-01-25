## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Base class for datum I/O

package DTA::CAB::Format;
use DTA::CAB::Utils;
use DTA::CAB::Persistent;
use DTA::CAB::Logger;
use DTA::CAB::Datum;
use DTA::CAB::Token;
use DTA::CAB::Sentence;
use DTA::CAB::Document;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Persistent DTA::CAB::Logger);

our $CLASS_DEFAULT = 'DTA::CAB::Format::TT'; ##-- default class for newFormat()

## @classreg = (\%registeredClass1, ... )
## + registered classes: see $CLASS->registerFormat()
our @classreg = qw();

## %short2reg = ($shortName => \%registeredClass, ...)
## + registered short classes; see $CLASS->registerFormat()
our %short2reg = qw();

## %base2reg = ($baseName => \%registeredClass, ...)
## + registered long (base) classes; see $CLASS->registerFormat()
our %base2reg = qw();

##==============================================================================
## Constructors etc.
##==============================================================================


## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    {
##     ##-- DTA::CAB::IO: common
##     encoding => $inputEncoding,  ##-- default: UTF-8, where applicable
##
##     ##-- DTA::CAB::IO: input parsing
##     #(none)
##
##     ##-- DTA::CAB::IO: output formatting
##     level    => $formatLevel,      ##-- formatting level, where applicable
##     outbuf   => $stringBuffer,     ##-- output buffer, where applicable
##    }
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- DTA::CAB::IO: common
		   encoding => 'UTF-8',

		   ##-- DTA::CAB::IO: input parsing
		   #(none)

		   ##-- DTA::CAB::IO: output formatting
		   #level    => undef,
		   #outbuf   => undef,

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $fmt;
}

## $fmt = CLASS->newFormat($class_or_short_or_class_suffix, %opts)
##  + allows additional opt 'filename'
sub newFormat {
  my ($that,$class,%opts) = @_;
  $class = $short2reg{lc($class)}{name} if ($short2reg{lc($class)});
  $class = $base2reg{$class}{name} if ($base2reg{$class});
  $class = "DTA::CAB::Format::${class}"
    if (!UNIVERSAL::isa($class,'DTA::CAB::Format'));
  $that->logconfess("newFormat(): cannot create unknown format class '$class'")
    if (!UNIVERSAL::isa($class,'DTA::CAB::Format'));
  return $class->new(%opts);
}

## $fmt = CLASS->newReader(%opts)
##  + special %opts:
##     class => $class,    ##-- classname or DTA::CAB::Format:: suffix
##     file  => $filename, ##-- attempt to guess format from filename
sub newReader {
  my ($that,%opts) = @_;
  my $class = $opts{file} && !$opts{class} ? $that->fileReaderClass($opts{file}) : $opts{class};
  delete($opts{file});
  return $that->newFormat( ($class||$CLASS_DEFAULT), %opts );
}

## $fmt = CLASS->newWriter(%opts)
##  + special %opts:
##     class => $class,    ##-- classname or DTA::CAB::Format suffix
##     file  => $filename, ##-- attempt to guess format from filename
sub newWriter {
  my ($that,%opts) = @_;
  my $class = $opts{file} && !$opts{class} ? $that->fileWriterClass($opts{file}) : $opts{class};
  delete($opts{file});
  return $that->newFormat( ($class||$CLASS_DEFAULT), %opts );
}

##==============================================================================
## Methods: Child Class registration
##==============================================================================

## \%registered = $CLASS_OR_OBJ->registerFormat(%opts)
##  + %opts:
##      name          => $basename,      ##-- basename for the class (package name)
##      short         => $shortname,     ##-- short name for the class (default = package name suffix, lower-cased)
##      readerClass   => $readerClass,   ##-- default: $base   ##-- NYI
##      writerClass   => $writerClass,   ##-- default: $base   ##-- NYI
##      filenameRegex => $regex,
sub registerFormat {
  my ($that,%opts) = @_;
  $opts{name} = (ref($that)||$that) if (!defined($opts{name}));
  $opts{readerClass} = $opts{name} if (!defined($opts{readerClass}));
  $opts{writerClass} = $opts{name} if (!defined($opts{writerClass}));
  if (!defined($opts{short})) {
    $opts{short} = lc($opts{name});
    $opts{short} =~ s/.*\:\://;
  }
  my $reg = {%opts};
  #@classreg = grep { $_->{name} ne $opts{name} } @classreg; ##-- un-register any old class by this name
  unshift(@classreg, $reg);
  $short2reg{$opts{short}} = $reg;
  $base2reg{$opts{name}} = $reg;
  return $reg;
}

## \%registered_or_undef = $CLASS_OR_OBJ->guessFilenameFormat($filename)
sub guessFilenameFormat {
  my ($that,$filename) = @_;
   foreach (@classreg) {
    return $_ if (defined($_->{filenameRegex}) && $filename =~ $_->{filenameRegex});
  }
  return undef;
}

## $readerClass_or_undef = $CLASS_OR_OBJ->fileReaderClass($filename)
##  + attempts to guess reader class name from $filename
sub fileReaderClass {
  my ($that,$filename) = @_;
  my $reg = $that->guessFilenameFormat($filename);
  return defined($reg) ? $reg->{readerClass} : undef;
}

## $readerClass_or_undef = $CLASS_OR_OBJ->fileWriterClass($filename)
##  + attempts to guess writer class name from $filename
sub fileWriterClass {
  my ($that,$filename) = @_;
  my $reg = $that->guessFilenameFormat($filename);
  return defined($reg) ? $reg->{writerClass} : undef;
}

## $registered_or_undef = $CLASS_OR_OBJ->short2reg($shortname)
sub short2reg {
  return $short2reg{$_[1]};
}

## $registered_or_undef = $CLASS_OR_OBJ->base2reg($basename)
sub base2reg {
  return $base2reg{$_[1]};
}


## $class_or_undef = $CLASS_OR_OBJ->shortReaderClass($shortname)
sub shortReaderClass {
  my ($that,$short) = @_;
  return $short2reg{$short} ? $short2reg{$short}{readerClass} : undef;
}

## $class_or_undef = $CLASS_OR_OBJ->shortWriterClass($shortname)
sub shortWriterClass {
  my ($that,$short) = @_;
  return $short2reg{$short} ? $short2reg{$short}{writerClass} : undef;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default ignores 'outbuf'
sub noSaveKeys {
  return qw(outbuf);
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default inherited from DTA::CAB::Persistent

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
##  + close current input source, if any
sub close { return $_[0]; }

## $fmt = $fmt->fromString($string)
##  + select input from string $string
sub fromString {
  my ($fmt,$str) = @_;
  $fmt->close;
  $fmt->logconfess("fromString(): not implemented");
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()
sub fromFile {
  my ($fmt,$file) = @_;
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  $fmt->logconfess("fromFile(): open failed for file '$file'") if (!$fh);
  my $rc = $fmt->fromFh($fh);
  $fh->close if (!ref($file));
  return $rc;
}

## $fmt = $fmt->fromFh($handle)
##  + default just calls $fmt->fromString()
sub fromFh {
  my ($fmt,$fh) = @_;
  return $fmt->fromString(join('',$fh->getlines));
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##   + parse document from currently selected input source
sub parseDocument {
  my $fmt = shift;
  $fmt->logconfess("parseDocument() not implemented!");
}

## $doc = $fmt->parseString($str)
##   + wrapper for $fmt->fromString($str)->parseDocument()
sub parseString {
  return $_[0]->fromString($_[1])->parseDocument;
}

## $doc = $fmt->parseFile($filename_or_fh)
##   + wrapper for $fmt->fromFile($filename_or_fh)->parseDocument()
sub parseFile {
  return $_[0]->fromFile($_[1])->parseDocument;
}

## $doc = $fmt->parseFh($fh)
##   + wrapper for $fmt->fromFh($filename_or_fh)->parseDocument()
sub parseFh {
  return $_[0]->fromFh($_[1])->parseDocument;
}



##--------------------------------------------------------------
## Methods: Input: Utilties

## $doc = $fmt->forceDocument($reference)
##  + attempt to tweak $reference into a DTA::CAB::Document
##  + a slightly more in-depth version of DTA::CAB::Datum::toDocument()
sub forceDocument {
  my ($fmt,$any) = @_;
  if (UNIVERSAL::isa($any,'DTA::CAB::Document')) {
    ##-- document
    return $any;
  }
  elsif (UNIVERSAL::isa($any,'DTA::CAB::Sentence')) {
    ##-- sentence
    return bless({body=>[$any]},'DTA::CAB::Document');
  }
  elsif (UNIVERSAL::isa($any,'DTA::CAB::Token')) {
    ##-- token
    return bless({body=>[ bless({tokens=>[$any]},'DTA::CAB::Sentence') ]},'DTA::CAB::Document');
  }
  elsif (ref($any) eq 'HASH' && exists($any->{body})) {
    ##-- hash, document-like
    return bless($any,'DTA::CAB::Document');
  }
  elsif (ref($any) eq 'HASH' && exists($any->{tokens})) {
    ##-- hash, sentence-like
    return bless({body=>[ bless($any,'DTA::CAB::Sentence') ]},'DTA::CAB::Document');
  }
  elsif (ref($any) eq 'HASH' && exists($any->{text})) {
    ##-- hash, token-like
    return bless({body=>[ bless({tokens=>[bless($any,'DTA::CAB::Token')]},'DTA::CAB::Sentence') ]},'DTA::CAB::Document');
  }
  else {
    ##-- ?
    $fmt->warn("forceDocument(): cannot massage non-document '".(ref($any)||$any)."'")
  }
  return $any;
}

##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME & HTTP stuff

## $type = $fmt->mimeType()
##  + default returns text/plain
BEGIN { *contentType = \&mimeType; }
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format (default='.cab')
sub defaultExtension { return '.cab'; }

## $short = $fmt->shortName()
##  + returns "official" short name for this format
##  + default just returns package suffix
sub shortName {
  my $short = shift;
  $short = ref($short) || $short;
  $short =~ s/^.*\:\://;
  return lc($short);
}

##--------------------------------------------------------------
## Methods: Output: accessors

## $lvl = $fmt->formatLevel()
## $fmt = $fmt->formatLevel($level)
##  + set output formatting level
sub formatLevel {
  my ($fmt,$level) = @_;
  return $fmt->{level} if (!defined($level));
  $fmt->{level}=$level;
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
##  + default implementation just deletes $fmt->{outbuf}
sub flush {
  delete($_[0]{outbuf});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
sub toString {
  $_[0]->formatLevel($_[1]) if (defined($_[1]));
  return encode($_[0]{encoding},$_[0]{outbuf})
    if ($_[0]{encoding} && defined($_[0]{outbuf}) && utf8::is_utf8($_[0]{outbuf}));
  return $_[0]{outbuf};
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()
sub toFile {
  my ($fmt,$file,$level) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fmt->logdie("toFile(): open failed for file '$file': $!") if (!$fh);
  $fh->binmode();
  my $rc = $fmt->toFh($fh,$level);
  $fh->close() if (!ref($file));
  return $rc;
}

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)
sub toFh {
  my ($fmt,$fh,$level) = @_;
  $fh->print($fmt->toString($level));
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Output: Recommended API

## $fmt = $fmt->putToken($tok)
##  + default implementations of other methods assume output is concatenated onto $fmt->{outbuf}
sub putTokenRaw { return $_[0]->putToken($_[1]); }
sub putToken {
  my $fmt = shift;
  $fmt->logconfess("putToken() not implemented!");
  return undef;
}

## $fmt = $fmt->putSentence($sent)
##  + default implementation just iterates $fmt->putToken() & appends 1 additional "\n" to $fmt->{outbuf}
sub putSentenceRaw { return $_[0]->putSentence($_[1]); }
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->putToken($_) foreach (@{toSentence($sent)->{tokens}});
  $fmt->{outbuf} .= "\n";
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Output: Required API

## $fmt = $fmt->putDocument($doc)
##  + default implementation just iterates $fmt->putSentence()
##  + should be non-destructive for $doc
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->putSentence($_) foreach (@{toDocument($doc)->{body}});
  return $fmt;
}

## $fmt = $fmt->putDocumentRaw($doc)
##  + may copy plain $doc reference
sub putDocumentRaw { return $_[0]->putDocument($_[1]); }


## $fmt = $fmt->putData($data)
##  + put arbitrary raw data (e.g. for YAML, JSON, XmlPerl)
sub putData {
  $_[0]->logconfess("putData() not implemented!");
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, & edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format - Base class for DTA::CAB::Datum I/O

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = $CLASS_OR_OBJ->new(%args);
 $fmt = $CLASS->newFormat($class_or_class_suffix, %opts);
 $fmt = $CLASS->newReader(%opts);
 $fmt = $CLASS->newWriter(%opts);
 
 ##========================================================================
 ## Methods: Child Class registration
 
 \%registered = $CLASS_OR_OBJ->registerFormat(%opts);
 \%registered_or_undef = $CLASS_OR_OBJ->guessFilenameFormat($filename);
 
 $readerClass_or_undef = $CLASS_OR_OBJ->fileReaderClass($filename);
 $readerClass_or_undef = $CLASS_OR_OBJ->fileWriterClass($filename);
 
 $registered_or_undef = $CLASS_OR_OBJ->short2reg($shortname);
 $registered_or_undef = $CLASS_OR_OBJ->base2reg($basename);
 
 $class_or_undef = $CLASS_OR_OBJ->shortReaderClass($shortname);
 $class_or_undef = $CLASS_OR_OBJ->shortWriterClass($shortname);
 
 ##========================================================================
 ## Methods: Persistence
 
 @keys = $class_or_obj->noSaveKeys();
 
 ##========================================================================
 ## Methods: MIME
 
 $short = $fmt->shortName();
 $type = $fmt->mimeType();
 $ext = $fmt->defaultExtension();
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $fmt = $fmt->fromString($string);
 $fmt = $fmt->fromFile($filename_or_handle);
 $fmt = $fmt->fromFh($handle);
 $doc = $fmt->parseDocument();
 $doc = $fmt->parseString($str);
 $doc = $fmt->parseFile($filename_or_fh);
 $doc = $fmt->parseFh($fh);
 $doc = $fmt->forceDocument($reference);
 
 ##========================================================================
 ## Methods: Output
 
 $lvl = $fmt->formatLevel();
 $fmt = $fmt->flush();
 $str = $fmt->toString();
 $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel);
 $fmt_or_undef = $fmt->toFh($fh,$formatLevel);
 $fmt = $fmt->putDocument($doc);
 $fmt = $fmt->putDocumentRaw($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format is an abstract base class and API specification
for objects implementing an I/O format for the
L<DTA::CAB::Datum|DTA::CAB::Datum> subhierarchy in general,
and for L<DTA::CAB::Document|DTA::CAB::Document> objects in particular.

Each I/O format (subclass) has a characteristic abstract `base class' as well as optional
`reader' and `writer' subclasses which perform the actual I/O (although in
the current implementation, all reader/writer classes are identical with
their respective base classes).  Individual formats may be invoked
either directly by their respective classes (SUBCLASS-E<gt>new(), etc.),
or via the DTA::CAB::Format
subclass registry (L</registerFormat>, L</newFormat>, L</newReader>, L</newWriter>, etc.).

See L</SUBCLASSES> for a list of common built-in formats and their registry data.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Globals
=pod

=head2 Globals

=over 4

=item @ISA

DTA::CAB::Format inherits from
L<DTA::CAB::Persistent|DTA::CAB::Persistent>
and
L<DTA::CAB::Logger|DTA::CAB::Logger>.

=item $CLASS_DEFAULT

Default class returned by L</newFormat>()
if no known class is specified.

=item @classreg

List of registered subclasses: see L</registerFormat>().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$fmt:

 ##-- DTA::CAB::Format: common
 encoding => $inputEncoding,  ##-- default: UTF-8, where applicable
 ##
 ##-- DTA::CAB::Format: input parsing
 #(none)
 ##
 ##-- DTA::CAB::Format: output formatting
 level    => $formatLevel,      ##-- formatting level, where applicable
 outbuf   => $stringBuffer,     ##-- output buffer, where applicable


=item newFormat

 $fmt = CLASS->newFormat($class_or_class_suffix, %opts);

Wrapper for L</new>() which allows short class suffixes to
be passed in as format names.

=item newReader

 $fmt = CLASS->newReader(%opts);

Wrapper for L</new>() with additional %opts:

 class => $class,    ##-- classname or DTA::CAB::Format:: suffix
 file  => $filename, ##-- attempt to guess format from filename

=item newWriter

 $fmt = CLASS->newWriter(%opts);

Wrapper for L</new>() with additional %opts:

 class => $class,    ##-- classname or DTA::CAB::Format:: suffix
 file  => $filename, ##-- attempt to guess format from filename


=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Methods: Child Class registration
=pod

=head2 Methods: Child Class registration

=over 4

=item registerFormat

 \%registered = $CLASS_OR_OBJ->registerFormat(%opts);

Registers a new format subclass.

%opts:

 name          => $basename,      ##-- basename for the class
 short         => $shortname,     ##-- short basename for the class (all lower-case)
                                  ##   + default: lower-cased DTA::CAB::Format:: basename suffix
 filenameRegex => $regex,         ##-- filename regex for guessFileNameFormat()
 readerClass   => $readerClass,   ##-- default: $base   ##-- NYI
 writerClass   => $writerClass,   ##-- default: $base   ##-- NYI

=item guessFilenameFormat

 \%registered_or_undef = $CLASS_OR_OBJ->guessFilenameFormat($filename);

Returns registration record for most recently registered format subclass
whose C<filenameRegex> matches $filename.

=item fileReaderClass

 $readerClass_or_undef = $CLASS_OR_OBJ->fileReaderClass($filename);

Attempts to guess reader class name from $filename.

=item fileWriterClass

 $readerClass_or_undef = $CLASS_OR_OBJ->fileWriterClass($filename);

Attempts to guess writer class name from $filename

=item short2reg

 $registered_or_undef = $CLASS_OR_OBJ->short2reg($shortname);

Gets the most recent subclass registry HASH ref for the short class name $shortname.

=item base2reg

 $registered_or_undef = $CLASS_OR_OBJ->base2reg($basename);

Gets the most recent subclass registry HASH ref for the claass basename name $basename.

=item shortReaderClass

 $class_or_undef = $CLASS_OR_OBJ->shortReaderClass($shortname);

Guess appropriate reader class name from $shortname.

=item shortWriterClass

 $class_or_undef = $CLASS_OR_OBJ->shortWriterClass($shortname);

Guess appropriate writer class name from $shortname.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();


Returns list of keys not to be saved
This implementation ignores the key C<outbuf>,
which is used by some many writer subclasses.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Methods: MIME
=pod

=head2 Methods: MIME

=over 4

=item shortName

 $short = $fmt->shortName();

Get short name for $fmt.  Default just returns lower-cased DTA::CAB::Format:: class suffix.
Short names are all lower-case by default.

=item mimeType

 $type = $fmt->mimeType();

Returns MIME type for $fmt.
Default returns 'text/plain'.

=item defaultExtension

 $ext = $fmt->defaultExtension();

Returns default filename extension for $fmt (default='.cab').

=back


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Close current input source, if any.


=item fromString

 $fmt = $fmt->fromString($string);

Select input from the string $string.
No default implementation.

=item fromFile

 $fmt = $fmt->fromFile($filename_or_handle);

Select input from a file or I/O handle $filename_or_handle.
Default calls L<$fmt-E<gt>fromFh|/fromFh>().

=item fromFh

 $fmt = $fmt->fromFh($handle);

Default just calls L<$fmt-E<gt>fromString|/fromString>().

=item parseDocument

 $doc = $fmt->parseDocument();

Parse document from currently selected input source.

=item parseString

 $doc = $fmt->parseString($str);

Wrapper for $fmt-E<gt>fromString($str)-E<gt>parseDocument().

=item parseFile

 $doc = $fmt->parseFile($filename_or_fh);

Wrapper for $fmt-E<gt>fromFile($filename_or_fh)-E<gt>parseDocument()

=item parseFh

 $doc = $fmt->parseFh($fh);

Wrapper for $fmt-E<gt>fromFh($filename_or_fh)-E<gt>parseDocument()


=item forceDocument

 $doc = $fmt->forceDocument($reference);

Attempt to tweak $reference into a L<DTA::CAB::Document|DTA::CAB::Document>.
This is
a slightly more in-depth version of L<DTA::CAB::Datum::toDocument()|DTA::CAB::Datum/item_toDocument>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item formatLevel

 $lvl = $fmt->formatLevel();
 $fmt = $fmt->formatLevel($level)

Get/set output formatting level.

=item flush

 $fmt = $fmt->flush();

Flush accumulated output, if any.
Default implementation just deletes $fmt-E<gt>{outbuf}.

=item toString

 $str = $fmt->toString();
 $str = $fmt->toString($formatLevel)

Flush buffered output document to byte-string, and return it.
Fefault implementation just encodes string in $fmt-E<gt>{outbuf}.

=item toFile

 $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel);

Flush buffered output document to $filename_or_handle.
Fefault implementation calls L<$fmt-E<gt>toFh|/toFh>().

=item toFh

 $fmt_or_undef = $fmt->toFh($fh,$formatLevel);

Flush buffered output document to filehandle $fh.
Fefault implementation calls to $fmt-E<gt>formatString($formatLevel).

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format: Methods: Output: Recommended API
=pod

=head2 Methods: Output: Recommended API

=over 4

=item putToken

 $fmt = $fmt->putToken($tok);

Append a token to the selected output sink.

Should be non-destructive for $tok.

No default implementation,
but default implementations of other methods assume output is concatenated onto $fmt-E<gt>{outbuf}.

=item putTokenRaw

 $fmt = $fmt->putTokenRaw($tok)

Copy-by-reference version of L</putToken>.
Default implementation just calls L<$fmt-E<gt>putToken($tok)|/putToken>.

=item putSentence

 $fmt = $fmt->putSentence($sent)

Append a sentence to the selected output sink.

Should be non-destructive for $sent.

Default implementation just iterates $fmt->putToken() & appends 1 additional "\n" to $fmt->{outbuf}.

=item putSentenceRaw

 $fmt = $fmt->putSentenceRaw($sent)

Copy-by-reference version of L</putSentence>.
Default implementation just calls L</putSentence>.


=item putDocument

 $fmt = $fmt->putDocument($doc);

Append document contents to the selected output sink.

Should be non-destructive for $doc.

Default implementation just iterates $fmt-E<gt>putSentence()


=item putDocumentRaw

 $fmt = $fmt->putDocumentRaw($doc);

Copy-by-reference version of L</putDocument>.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## See Also
##======================================================================
=pod

=head1 SUBCLASSES

The following formats are provided by the default distribution.
In some cases, external dependencies are also required which
may not be available on all systems.

=over 4

=item L<DTA::CAB::Format::Builtin|DTA::CAB::Format::Builtin>

Just a convenience package: load all built-in DTA::CAB::Format subclasses.

=item L<DTA::CAB::Format::Null|DTA::CAB::Format::Null>

Null-op parser/formatter for debugging and testing purposes.
Registered as:

 name=>__PACKAGE__

=item L<DTA::CAB::Format::JSON|DTA::CAB::Format::JSON>

Abstract datum parser|formatter for JSON I/O.
Transparently wraps one of the
L<DTA::CAB::Format::JSON::XS|DTA::CAB::Format::JSON::XS>
or
L<DTA::CAB::Format::JSON::Syck|DTA::CAB::Format::JSON::Syck>
classes, depending on the availability of the underlying Perl modules
(L<JSON::XS|JSON::XS> and L<JSON::Syck|JSON::Syck>, respectively).
If you have the L<JSON::XS|JSON::XS> module installed, this module provides
the fastest I/O of all available human-readable format classes.
Registered as:

 name=>__PACKAGE__, short=>'json', filenameRegex=>qr/\.(?i:json|jsn)$/

=item L<DTA::CAB::Format::Perl|DTA::CAB::Format::Perl>

Datum parser|formatter: perl code via Data::Dumper, eval().
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:prl|pl|perl|dump)$/

=item L<DTA::CAB::Format::Storable|DTA::CAB::Format::Storable>

Binary datum parser|formatter using the L<Storable|Storable> module.
Very fast, but neither human-readable nor easily portable beyond Perl.
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:sto|bin)$/

=item L<DTA::CAB::Format::Null|DTA::CAB::Format::Raw>

Input-only parser for quick and dirty parsing of raw untokenized input.
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:raw)$/

=item L<DTA::CAB::Format::Text|DTA::CAB::Format::Text>

Datum parser|formatter: verbose human-readable text
(deprecated in favor of L<DTA::CAB::Format::YAML|DTA::CAB::Format::YAML>).
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:txt|text|cab\-txt|cab\-text)$/

=item L<DTA::CAB::Format::TT|DTA::CAB::Format::TT>

Datum parser|formatter: "vertical" text, one token per line.
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:t|tt|ttt|cab\-t|cab\-tt|cab\-ttt)$/

=item L<DTA::CAB::Format::YAML|DTA::CAB::Format::YAML>

Abstract datum parser|formatter for YAML I/O.
Transparently wraps one of the
L<DTA::CAB::Format::YAML::XS|DTA::CAB::Format::YAML::XS>,
L<DTA::CAB::Format::YAML::Syck|DTA::CAB::Format::YAML::Syck>,
or
L<DTA::CAB::Format::YAML::Lite|DTA::CAB::Format::YAML::Lite>
classes, depending on the availability of the underlying Perl modules
(L<YAML::XS|YAML::XS>, L<YAML::Syck|YAML::Syck>, and L<YAML::Lite|YAML::Lite>, respectively).
Registered as:

 name=>__PACKAGE__, short=>'yaml', filenameRegex=>qr/\.(?i:yaml|yml)$/

=item L<DTA::CAB::Format::XmlCommon|DTA::CAB::Format::XmlCommon>

Datum parser|formatter: XML: abstract base class.

=item L<DTA::CAB::Format::XmlNative|DTA::CAB::Format::XmlNative>

Datum parser|formatter: XML (native).
Should be compatible with C<.t.xml> files
as created by L<dta-tokwrap.perl(1)|dta-tokwrap.perl>.
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml\-native|xml\-dta\-cab|(?:dta[\-\._]cab[\-\._]xml)|xml)$/

and aliased as:

 name=>__PACKAGE__, short=>'xml'

=item L<DTA::CAB::Format::XmlPerl|DTA::CAB::Format::XmlPerl>

Datum parser|formatter: XML (perl-like).  Not really reccommended.
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml(?:\-?)perl|perl(?:[\-\.]?)xml)$/

=item L<DTA::CAB::Format::XmlRpc|DTA::CAB::Format::XmlRpc>

Datum parser|formatter: XML-RPC data structures using RPC::XML.  Much too bloated
to be of any real practical use.
Registered as:

 name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xml(?:\-?)rpc|rpc(?:[\-\.]?)xml)$/

=back

=cut


##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
