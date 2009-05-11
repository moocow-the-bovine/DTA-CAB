## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TT.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: one-token-per-line text

package DTA::CAB::Format::TT;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:t|tt|ttt)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    {
##     ##-- Input
##     doc => $doc,                    ##-- buffered input document
##
##     ##-- Output
##     outbuf    => $stringBuffer,     ##-- buffered output
##     #level    => $formatLevel,      ##-- n/a
##
##     ##-- Common
##     encoding => $inputEncoding,     ##-- default: UTF-8, where applicable
##    }
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   doc => undef,

		   ##-- output
		   #outbuf => '',

		   ##-- common
		   encoding => 'UTF-8',

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
##  + select input from string $string
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parseTTString($_[0]);
}

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseTTString($str)
##  + guts for fromString(): parse string $str into local document buffer.
sub parseTTString {
  my ($fmt,$src) = @_;
  $src = decode($fmt->{encoding},$src) if ($fmt->{encoding} && !utf8::is_utf8($src));

  my (@sents,$tok,$rw,$line);
  my ($text,@fields,$field);
  my $s = [];
  while ($src =~ m/^(.*)$/mg) {
    $line = $1;
    if ($line =~ /^\%\%/) {
      ##-- comment line; skip
      next;
    }
    elsif ($line eq '') {
      ##-- blank line: eos
      push(@sents,$s) if (@$s);
      $s = [];
    }
    else {
      ##-- token
      ($text,@fields) = split(/\t/,$line);
      push(@$s, $tok=bless({text=>$text},'DTA::CAB::Token'));
      foreach $field (@fields) {
	if ($field =~ m/^\[xlit\] (?:isLatin1|l1)=(\d) (?:isLatinExt|lx)=(\d) (?:latin1Text|l1s)=(.*)$/) {
	  ##-- token: field: xlit
	  #$tok->{xlit} = [$3,$1,$2];
	  $tok->{xlit} = { isLatin1=>$1, isLatinExt=>$2, latin1Text=>$3 };
	}
	elsif ($field =~ m/^\[lts\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
	  ##-- token: field: lts analysis (no lower)
	  $tok->{lts} = [] if (!$tok->{lts});
	  push(@{$tok->{lts}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[eqpho\] (.*)$/) {
	  ##-- token: field: phonetic equivalent
	  $tok->{eqpho} = [] if (!$tok->{eqpho});
	  push(@{$tok->{eqpho}}, $1);
	}
	elsif ($field =~ m/^\[morph\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
	  ##-- token: field: morph analysis
	  $tok->{morph} = [] if (!$tok->{morph});
	  push(@{$tok->{morph}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[morph\/safe\] (\d)$/) {
	  ##-- token: field: morph-safety check (morph/safe)
	  $tok->{msafe} = $1;
	}
	elsif ($field =~ m/^\[rw\] (?:((?:\\.|[^:])*) : )?(.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: field: rewrite target
	  $tok->{rw} = [] if (!$tok->{rw});
	  push(@{$tok->{rw}}, $rw={(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[rw\/lts\] (?:((?:\\.|[^:])*) : )?(.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: LTS analysis of rewrite target
	  $tok->{rw} = [ {} ] if (!$tok->{rw});
	  $rw        = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
	  $rw->{lts} = [] if (!$rw->{lts});
	  push(@{$rw->{lts}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	elsif ($field =~ m/^\[rw\/morph\] (?:((?:\\.|[^:])*) : )?(.*) <([\d\.\+\-eE]+)>$/) {
	  ##-- token: morph analysis of rewrite target
	  $tok->{rw}   = [ {} ] if (!$tok->{rw});
	  $rw          = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
	  $rw->{morph} = [] if (!$rw->{morph});
	  push(@{$rw->{morph}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
	}
	else {
	  ##-- unknown
	  $fmt->warn("parseTTString(): could not parse token field '$field' for token '$text'");
	}
      }
    }
  }
  push(@sents,$s) if (@$s); ##-- final sentence

  ##-- construct & buffer document
  $fmt->{doc} = bless({body=>[ map { bless({tokens=>$_},'DTA::CAB::Sentence') } @sents ]}, 'DTA::CAB::Document');
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
sub toString {
  return encode($_[0]{encoding},$_[0]{outbuf})
    if ($_[0]{encoding} && defined($_[0]{outbuf}) && utf8::is_utf8($_[0]{outbuf}));
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
  my ($fmt,$tok) = @_;
  my $out = $tok->{text};

  ##-- Transliterator ('xlit')
  $out .= "\t[xlit] l1=$tok->{xlit}{isLatin1} lx=$tok->{xlit}{isLatinExt} l1s=$tok->{xlit}{latin1Text}"
    if (defined($tok->{xlit}));

  ##-- LTS ('lts')
  $out .= join('', map { "\t[lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{lts}})
    if ($tok->{lts});

  ##-- Phonetic Equivalents ('eqpho')
  $out .= join('', map { "\t[eqpho] $_" } grep {defined($_)} @{$tok->{eqpho}})
    if ($tok->{eqpho});

  ##-- Morph ('morph')
  $out .= join('', map { "\t[morph] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{morph}})
    if ($tok->{morph});

  ##-- MorphSafe ('morph/safe')
  $out .= "\t[morph/safe] ".($tok->{msafe} ? 1 : 0) if (exists($tok->{msafe}));

  ##-- Rewrites + analyses
  $out .= join('',
	       map {
		 ("\t[rw] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>",
		  (##-- rw/lts
		   $_->{lts}
		   ? map { "\t[rw/lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$_->{lts}}
		   : qw()),
		  (##-- rw/morph
		   $_->{morph}
		   ? map { "\t[rw/morph] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$_->{morph}}
		   : qw()),
		 )
	       } @{$tok->{rw}})
    if ($tok->{rw});

  ##-- ... ???
  $fmt->{outbuf} .= $out."\n";
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
##  + default version just concatenates formatted tokens
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->putToken($_) foreach (@{toSentence($sent)->{tokens}});
  $fmt->{outbuf} .= "\n";
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
##  + default version just concatenates formatted sentences
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->putSentence($_) foreach (@{toDocument($doc)->{body}});
  return $fmt;
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::TT - Datum parser: one-token-per-line text

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::TT;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::TT->new(%args);
 
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
## DESCRIPTION: DTA::CAB::Format::TT: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::TT
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

=item Filenames

DTA::CAB::Format::TT registers the filename regex:

 /\.(?i:t|tt|ttt)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::TT: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

%args, %$fmt:

 ##-- Input
 doc => $doc,                    ##-- buffered input document
 ##
 ##-- Output
 outbuf    => $stringBuffer,     ##-- buffered output
 #level    => $formatLevel,      ##-- n/a
 ##
 ##-- Common
 encoding => $inputEncoding,     ##-- default: UTF-8, where applicable

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::TT: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Returns list of keys not to be saved.
This implementation returns C<qw(doc outbuf)>.

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::TT: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close current input source, if any.

=item fromString

 $fmt = $fmt->fromString($string);

Override: select input from string $string.

=item parseTTString

 $fmt = $fmt->parseTTString($str)

Guts for fromString(): parse string $str into local document buffer.

=item parseDocument

 $doc = $fmt->parseDocument();

Override: just returns local document buffer $fmt-E<gt>{doc}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::TT: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item flush

 $fmt = $fmt->flush();

Override: flush accumulated output

=item toString

 $str = $fmt->toString();
 $str = $fmt->toString($formatLevel)

Override: flush buffered output document to byte-string.
Just encodes string in $fmt-E<gt>{outbuf}.

=item putToken

 $fmt = $fmt->putToken($tok);

Override: token output.

=item putSentence

 $fmt = $fmt->putSentence($sent);

Override: sentence output.

=item putDocument

 $fmt = $fmt->putDocument($doc);

Override: document output.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

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


=cut
