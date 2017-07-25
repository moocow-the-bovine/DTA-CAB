## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Raw::Waste.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: Datum parser: raw untokenized text (using moot/waste)

package DTA::CAB::Format::Raw::Waste;
use DTA::CAB::Format;
use DTA::CAB::Format::TT;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Moot::Waste;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'raw-waste', filenameRegex=>qr/\.(?i:raw-waste|txt-waste)$/);
}

our @DEFAULT_WASTERC_PATHS =
  (
   ($ENV{TOKWRAP_RCDIR} ? "$ENV{TOKWRAP_RCDIR}/waste/waste.rc" : qw()),
   (defined($DTA::TokWrap::VersionVERSION) ? "$DTA::TokWrap::Version::RCDIR/waste/waste.rc" : qw()),
   "$ENV{HOME}/.wasterc",
   "/etc/wasterc",
   "/etc/default/wasterc"
  );

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    {
##     ##-- Input
##     doc => $doc,                    ##-- buffered input document
##     wasterc => $rcFile,             ##-- waste .rc file; default: "$HOME/.wasterc" || "/etc/wasterc" || "/etc/default/waste"
##
##     ##-- Runtime
##     wscanner => $scanner,           ##-- waste scanner
##     wlexer   => $lexer,             ##-- waste lexer
##     wtagger  => $tagger,            ##-- waste tagger
##     wdecoder => $decoder,           ##-- waste decoder
##     wannotator => $wannot,          ##-- waste annotator
##
##     ##-- Runtime HACKS
##     wwriter => $wwriter,            ##-- native-format writer (hack)
##
##     ##-- Common
##     #utf8 => $bool,		       ##-- utf8 mode always on
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- common
		   utf8 => 1,

		   ##-- inputz
		   doc => undef,
		   wasterc => undef,

		   ##-- runtime
		   wscanner => undef,
		   wlexer   => undef,
		   wtagger  => undef,
		   wdecoder => undef,
		   wannotator => undef,
		   wwriter  => undef,

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
  return (shift->SUPER::noSaveKeys(), qw(doc wscanner wlexer wtagger wdecoder wannotator wwriter));
}

##==============================================================================
## Methods: Model I/O

## $fmt_or_undef = $fmt->ensureLoaded()
sub ensureLoaded {
  my $fmt = shift;
  return $fmt if ($fmt->{wtagger});

  ##-- get rc file
  if (!$fmt->{wasterc}) {
    $fmt->{wasterc} = (grep {-f $_} @DEFAULT_WASTERC_PATHS)[0];
    $fmt->logconfess("cannot tokenize without a model -- specify wasterc!") if (!$fmt->{wasterc});
  }
  $fmt->trace("using waste model configuration $fmt->{wasterc}");

  return $fmt->loadModel();
}

## $fmt_or_undef = $fmt->loadModel()
## $fmt_or_undef = $fmt->loadModel($rcfile)
sub loadModel {
  my ($fmt,$rcfile) = @_;
  $rcfile //= $fmt->{wasterc};
  $fmt->{wasterc} = $rcfile;

  ##-- create waste objects
  $fmt->{wscanner} = Moot::Waste::Scanner->new( $Moot::ioFormat{text}|$Moot::ioFormat{location} );
  $fmt->{wlexer}   = Moot::Waste::Lexer->new( $Moot::ioFormat{wd}|$Moot::ioFormat{location} );
  $fmt->{wtagger}  = Moot::HMM->new();
  $fmt->{wdecoder} = Moot::Waste::Decoder->new( $Moot::ioFormat{m}|$Moot::ioFormat{location} );
  $fmt->{wannotator} = Moot::Waste::Annotator->new( $Moot::ioFormat{mr}|$Moot::ioFormat{location} );
  $fmt->{wwriter}  = Moot::TokenWriter::Native->new( $Moot::ioFormat{mr}|$Moot::ioFormat{location} );

  ##-- load waste model
  open(my $rc,"<$rcfile")
    or $fmt->logconfess("open failed for waste-rc $rcfile: $!");
  while (defined($_=<$rc>)) {
    next if (/^\#/ || /^\s*$/);
    chomp;
    my ($opt,$val) = split(/\s/,$_,2);
    if    ($opt =~ /^abbr/) { $fmt->{wlexer}->abbrevs->load($val); }
    elsif ($opt =~ /^conj/) { $fmt->{wlexer}->conjunctions->load($val); }
    elsif ($opt =~ /^stop/) { $fmt->{wlexer}->stopwords->load($val); }
    elsif ($opt =~ /^dehyph/) { $fmt->{wlexer}->dehyphenate(1); }
    elsif ($opt =~ /^no-dehyph/) { $fmt->{wlexer}->dehyphenate(0); }
    elsif ($opt =~ /^(?:hmm|model)/) {
      $fmt->{wtagger}->load($val) or $fmt->logconfess("failed to load waste model '$val'");
    }
    else {
      ; ##-- ignore other options
    }
  }
  close($rc);

  return $fmt;
}

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
sub close {
  delete($_[0]{doc});
  return $_[0]->SUPER::close(@_[1..$#_]);
}

## $fmt = $fmt->fromString( $string)
## $fmt = $fmt->fromString(\$string)
##  + select input from string $string
##  + default calls fromFh()

## $fmt = $fmt->fromFh($fh)
sub fromFh {
  my ($fmt,$fh) = @_;
  $fmt->ensureLoaded();

  my ($ttstr);
  $fmt->{wlexer}->close();
  $fmt->{wscanner}->close();
  $fmt->{wscanner}->from_fh($fh);
  $fmt->{wlexer}->scanner($fmt->{wscanner});
  $fmt->{wwriter}->to_string($ttstr);
  $fmt->{wdecoder}->sink($fmt->{wannotator});
  $fmt->{wannotator}->sink($fmt->{wwriter});
  $fmt->{wtagger}->tag_stream($fmt->{wlexer},$fmt->{wdecoder});
  $fmt->{wdecoder}->close();
  $fmt->{wannotator}->close();
  $fmt->{wwriter}->close();

  ##-- construct & buffer document
  $fmt->{doc} = DTA::CAB::Format::TT->parseTokenizerString(\$ttstr);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument {
  return $_[0]{doc};
}


##==============================================================================
## Methods: Output
##  + output not supported
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Generic

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.raw'; }


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl
=pod

=cut

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::Raw::Waste - Document parser: raw untokenized text using Moot::Waste

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::Raw::Waste;
 
 ##========================================================================
 ## Methods
 
 $fmt = DTA::CAB::Format::Raw::Waste->new(%args);
 @keys = $class_or_obj->noSaveKeys();
 $fmt = $fmt->close();
 $fmt = $fmt->parseRawString(\$str);
 $doc = $fmt->parseDocument();
 $type = $fmt->mimeType();
 $ext = $fmt->defaultExtension();
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::Raw::Waste
is an input-only L<DTA::CAB::Format|DTA::CAB::Format> subclass
for untokenized raw string intput using pure perl.


=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Raw::Waste: Constructors etc.
=pod

=head2 Methods

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

%$fmt, %args:

 ##-- Input
 doc => $doc,                    ##-- buffered input document

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();


Returns list of keys not to be saved
Override returns qw(doc outbuf).

=item close

 $fmt = $fmt->close();

Deletes buffered input document, if any.

=item fromString

 $fmt = $fmt->fromString($string)

Select input from string $string.

=item parseRawString

 $fmt = $fmt->parseRawString(\$str);

Guts for fromString(): parse string $str into local document buffer.

=item parseDocument

 $doc = $fmt->parseDocument();

Wrapper for $fmt-E<gt>{doc}.

=item mimeType

 $type = $fmt->mimeType();

Default returns text/plain.

=item defaultExtension

 $ext = $fmt->defaultExtension();

Returns default filename extension for this format, here '.raw'.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<DTA::CAB::Format::Builtin(3pm)|DTA::CAB::Format::Builtin>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
