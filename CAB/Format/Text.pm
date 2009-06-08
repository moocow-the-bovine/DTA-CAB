## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Text.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: verbose human-readable text

package DTA::CAB::Format::Text;
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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:txt|text)$/);
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
##     outbuf    => $stringBuffer,     ##-- buffered output
##
##     ##---- Common
##     encoding  => $encoding,         ##-- default: 'UTF-8'
##     defaultFieldName => $name,      ##-- default name for unnamed fields; parsed into @{$tok->{other}{$name}}; default=''
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   doc => undef,

		   ##-- output
		   outbuf  => '',

		   ##-- common
		   encoding => 'UTF-8',
		   defaultFieldName => '',

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

## $fmt = $fmt->fromFh($fh)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parseTextString($_[0]);
}

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseTextString($string)
sub parseTextString {
  my ($fmt,$src) = @_;
  $src = decode($fmt->{encoding},$src) if ($fmt->{encoding} && !utf8::is_utf8($src));

  my (@sents,$tok,$rw,$line);
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
    elsif ($line =~ /^(\S.*)/) {
      ##-- new token: text
      push(@$s, $tok=bless({text=>$1},'DTA::CAB::Token'));
    }
    elsif ($line =~ /^^\t\+\[loc\] off=(\d+) len=(\d+)$/) {
      ##-- token: location
      $tok->{loc} = { off=>$1, len=>$2 };
    }
    elsif ($line =~ m/^\t\+\[xlit\] isLatin1=(\d) isLatinExt=(\d) latin1Text=(.*)$/) {
      ##-- token: xlit
      $tok->{xlit} = { isLatin1=>$1, isLatinExt=>$2, latin1Text=>$3 };
    }
    elsif ($line =~ m/^\t\+\[lts\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: lts analysis
      $tok->{lts} = [] if (!$tok->{lts});
      push(@{$tok->{lts}}, {(defined($1) ? (lo=>$1) : qw()),hi=>$2,w=>$3});
    }
    elsif ($line =~ m/^\t\+\[eqpho\] (.*)$/) {
      ##-- token: field: phonetic equivalent
      $tok->{eqpho} = [] if (!$tok->{eqpho});
      push(@{$tok->{eqpho}}, $1);
    }
    elsif ($line =~ m/^\t\+\[morph\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: morph analysis
      $tok->{morph} = [] if (!$tok->{morph});
      push(@{$tok->{morph}}, {(defined($1) ? (lo=>$1) : qw()),hi=>$2,w=>$3});
    }
    elsif ($line =~ m/^\t\+\[morph\/safe] (\d)$/) {
      ##-- token: field: morph-safety check
      $tok->{msafe} = $1;
    }
    elsif ($line =~ m/^\t\+\[rw\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: rewrite target
      $tok->{rw} = [] if (!$tok->{rw});
      push(@{$tok->{rw}}, $rw={(defined($1) ? (lo=>$1) : qw()),hi=>$2,w=>$3});
    }
    elsif ($line =~ m/^\t+\+\[rw\/lts\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: LTS analysis of rewrite target
      $tok->{rw} = [ {} ] if (!$tok->{rw});
      $rw        = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
      $rw->{lts} = [] if (!$rw->{lts});
      push(@{$rw->{lts}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
    }
    elsif ($line =~ m/^\t+\+\[rw\/morph\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: morph analysis of rewrite target
      $tok->{rw}   = [ {} ] if (!$tok->{rw});
      $rw          = $tok->{rw}[$#{$tok->{rw}}] if (!$rw);
      $rw->{morph} = [] if (!$rw->{morph});
      push(@{$rw->{morph}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
    }
    elsif ($line =~ m/^\t\+\[([^\]]*)\]\s?(.*)$/) {
      ##-- token: field: unknown named field "+[$name] $val", parse into $tok->{other}{$name} = \@vals
      push(@{$tok->{other}{$1}}, $2);
    }
    else {
      ##-- token: field: unnamed field
      #$fmt->warn("parseTextString(): could not parse line '$line'");
      $line =~ s/^\t//;
      push(@{$tok->{other}{$fmt->{defaultFieldName}||''}}, $line);
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
##  + appends $tok to output buffer
sub putToken {
  my ($fmt,$tok) = @_;
  my $out = $tok->{text}."\n";

  ##-- Location ('loc')
  $out .= "\t+[loc] off=$tok->{loc}{off} len=$tok->{loc}{len}\n"
    if (defined($tok->{loc}));

  ##-- Transliterator ('xlit')
  $out .= "\t+[xlit] isLatin1=$tok->{xlit}{isLatin1} isLatinExt=$tok->{xlit}{isLatinExt} latin1Text=$tok->{xlit}{latin1Text}\n"
    if (defined($tok->{xlit}));

  ##-- LTS ('lts')
  $out .= join('', map { "\t+[lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>\n" } @{$tok->{lts}})
    if ($tok->{lts});

  ##-- Phonetic Equivalents ('eqpho')
  $out .= join('', map { "\t+[eqpho] $_\n" } grep {defined($_)} @{$tok->{eqpho}})
    if ($tok->{eqpho});

  ##-- Morph ('morph')
  $out .= join('', map { "\t+[morph] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>\n" } @{$tok->{morph}})
    if ($tok->{morph});

  ##-- MorphSafe ('morph.safe')
  $out .= "\t+[morph/safe] ".($tok->{msafe} ? 1 : 0)."\n" if (exists($tok->{msafe}));

  ##-- Rewrites + analyses
  $out .= join('',
	       map {
		 ("\t+[rw] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>\n",
		  (##-- rw/lts
		   $_->{lts}
		   ? map { "\t+[rw/lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>\n" } @{$_->{lts}}
		   : qw()),
		  (##-- rw/morph
		   $_->{morph}
		   ? map { "\t+[rw/morph] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>\n" } @{$_->{morph}}
		   : qw()),
		 )
	       } @{$tok->{rw}})
    if ($tok->{rw});

  ##-- unparsed fields
  if ($tok->{other}) {
    my ($name);
    $out .= ("\t"
	     .join("\n\t",
		   (map { $name=$_; map { "+[$name] $_" } @{$tok->{other}{$name}} }
		    sort grep {$_ ne $fmt->{defaultFieldName}} keys %{$tok->{other}}
		   ),
		   ($tok->{other}{$fmt->{defaultFieldName}}
		    ? @{$tok->{other}{$fmt->{defaultFieldName}}}
		    : qw()
		   ))
	     ."\n");
  }

  $fmt->{outbuf} .= $out;
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

## $out = $fmt->formatDocument($doc)
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
 ## Methods: Persistence
 
 @keys = $class_or_obj->noSaveKeys();
 
 ##========================================================================
 ## Methods: Input
 
 $fmt = $fmt->close();
 $doc = $fmt->parseDocument();
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->flush();
 $str = $fmt->toString();
 $fmt = $fmt->putToken($tok);
 $fmt = $fmt->putSentence($sent);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::Text
inherits from
L<DTA::CAB::Format|DTA::CAB::Format>.

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
## DESCRIPTION: DTA::CAB::Format::Text: Methods: Persistence
=pod

=head2 Methods: Persistence

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Override: returns list of keys not to be saved.
Just returns C<qw(doc)>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close current input source.
Deletes $fmt-E<gt>{doc}.

=item fromString

 $fmt = $fmt->fromString( $string)

Select input from string $string.
Calls L</parseTextString>().

=item parseTextString

 $fmt = $fmt->parseTextString($string)

Low-level document parsing routine.
Populates
document buffer $fmt-E<gt>{doc}
with parsed data from $string.

=item parseDocument

 $doc = $fmt->parseDocument();

Just returns document buffer $fmt-E<gt>{doc}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Methods: Output
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
Just encodes string in $fmt-E<gt>{outbuf}

=item putToken

 $fmt = $fmt->putToken($tok);

Override: append formatted token $tok to output buffer.

=item putSentence

 $fmt = $fmt->putSentence($sent);

Override: append formatted sentence to output buffer.

=item putDocument

Override: append formatted document to output buffer.

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

 wie
	+[xlit] isLatin1=1 isLatinExt=1 latin1Text=wie
	+[lts] vi <0>
	+[eqpho] Wie
	+[eqpho] wie
	+[morph] wie[_ADV] <0>
	+[morph] wie[_KON] <0>
	+[morph] wie[_KOKOM] <0>
	+[morph] wie[_KOUS] <0>
	+[morph/safe] 1
 oede
	+[xlit] isLatin1=1 isLatinExt=1 latin1Text=oede
	+[lts] ?2de <0>
	+[eqpho] Oede
	+[eqpho] Öde
	+[eqpho] öde
	+[morph/safe] 0
	+[rw] öde <1>
	+[rw/lts] ?2de <0>
	+[rw/morph] öde[_ADJD] <0>
	+[rw/morph] öde[_ADJA][pos][sg][nom]*[weak] <0>
	+[rw/morph] öde[_ADJA][pos][sg][nom][fem][strong_mixed] <0>
	+[rw/morph] öde[_ADJA][pos][sg][acc][fem]* <0>
	+[rw/morph] öde[_ADJA][pos][sg][acc][neut][weak] <0>
	+[rw/morph] öde[_ADJA][pos][pl][nom_acc]*[strong] <0>
	+[rw/morph] öd~en[_VVFIN][first][sg][pres][ind] <0>
	+[rw/morph] öd~en[_VVFIN][first][sg][pres][subjI] <0>
	+[rw/morph] öd~en[_VVFIN][third][sg][pres][subjI] <0>
	+[rw/morph] öd~en[_VVIMP][sg] <0>
 !
	+[xlit] isLatin1=1 isLatinExt=1 latin1Text=!
	+[lts]  <0>
	+[morph/safe] 1
 


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
