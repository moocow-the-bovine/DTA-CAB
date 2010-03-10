## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Text1.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: verbose human-readable text (v1.x)

package DTA::CAB::Format::Text1;
use DTA::CAB::Format;
use DTA::CAB::Format::TT;
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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:txt1|text1)$/);
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
## + inherited from DTA::CAB::Format::TT

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
##  + inherited from DTA::CAB::Format

## $fmt = $fmt->fromFh($fh)
##  + default calls $fmt->fromString() on file contents
##  + inherited from DTA::CAB::Format

## $fmt = $fmt->fromString($string)
##  + select input from string $string
##  + wrapper for: $fmt->close->parseTextString($string)
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

  my ($line,$w, $fkey,$fval,$field);
  my $body   = [];   ##-- doc body
  my $s      = [];   ##-- current sentence: token list
  my $sent   = {};   ##-- current sentence: hash
  my $doc    = bless({},'DTA::CAB::Document'); ##-- document buffer
  my @stack  = ($doc); ##-- "current node" stack
  while ($src =~ m/^(.*)$/mg) {
    $line = $1;

    if ($line =~ /^\%\%/) {
      ##-- COMMENTS
      if ($line =~ /^\%\%\!DOC ATTR\s+([^=]*)=(.*)$/) {
	##-- comment: doc attr
	$doc->{_attrs}{$1}=$2;
      }
      elsif ($line =~ /^\%\%!SENT ATTR\s+([^=]*)=(.*)$/) {
	$sent->{_attrs}{$1}=$2;
      }
      elsif ($line =~ /^\%\%!TOK ATTR\s+([^=]*)=(.*)$/) {
	$w->{_attrs}{$1}=$2 if ($w);
      }
      elsif ($line =~ /^\%\% xml\:base=(.*)$/) {
	##-- v0.x: special comment: document attribute: xml:base
	$doc->{xmlbase} = $1;
      }
      elsif ($line =~ /^\%\% Sentence (.*)$/) {
	##-- v0.x: special comment: sentence attribute: xml:id
	$sent->{xmlid} = $1;
      }
      elsif ($line =~ /^\%\%(.*)$/) {
	##-- generic comment
	push(@{$nod->{_dtrs}}, DTA::CAB::Datum::Comment->new($1));
      }
    }##-- /COMMENTS

    elsif ($line eq '') {
      ##-- blank line: eos
      $sent->{tokens} = $s;
      push(@$body,$sent) if (@$s || %$sent);
      $s    = [];
      $sent = {};
      splice(@stack, $#stack-1, 2); ##-- pop 2 elements from the stack (word,sent)
    }
    elsif ($line =~ /^(\S.*)/) {
      ##-- new token: text
      push(@$s, $w=bless({text=>$1},'DTA::CAB::Token'));
      push(@{$sent->{_dtrs}},$w);
      push(@stack,$sent,$w);
    }
    elsif ($line =~ /^\t\+\[([^\]]*)\] (.*)$/) {
      ##-- token property field
      ($fkey,$fval) = ($1,$2);

      ##-- check for known fields
      if (defined($field=$FIELDS{$fkey})) {
	$field->{_parse}->($fmt,
      }
    }


      ##~~~~~~~~~~~~~~~~ OLD
    elsif ($line =~ /^\t\+\[loc\] off=(\d+) len=(\d+)$/) {
      ##-- token: location
      $w->{loc} = { off=>$1, len=>$2 };
    }
    elsif ($line =~ m/^\t\+\[xlit\] isLatin1=(\d) isLatinExt=(\d) latin1Text=(.*)$/) {
      ##-- token: xlit
      $w->{xlit} = { isLatin1=>$1, isLatinExt=>$2, latin1Text=>$3 };
    }
    elsif ($line =~ m/^\t\+\[lts\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: lts analysis
      push(@{$w->{lts}}, {(defined($1) ? (lo=>$1) : qw()),hi=>$2,w=>$3});
    }
    elsif ($line =~ m/^\t\+\[morph\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: morph analysis
      push(@{$w->{morph}}, {(defined($1) ? (lo=>$1) : qw()),hi=>$2,w=>$3});
    }
    elsif ($line =~ m/^\t\+\[morph\/lat?\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: morph analysis
      push(@{$w->{mlatin}}, {(defined($1) ? (lo=>$1) : qw()),hi=>$2,w=>$3});
    }
    elsif ($line =~ m/^\t\+\[morph\/safe] (\d)$/) {
      ##-- token: field: morph-safety check
      $w->{msafe} = $1;
    }
    elsif ($line =~ m/^\t\+\[rw\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: rewrite target
      push(@{$w->{rw}}, $rw={(defined($1) ? (lo=>$1) : qw()),hi=>$2,w=>$3});
    }
    elsif ($line =~ m/^\t+\+\[rw\/lts\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: LTS analysis of rewrite target
      $w->{rw} = [ {} ] if (!$w->{rw});
      $rw        = $w->{rw}[$#{$w->{rw}}] if (!$rw);
      push(@{$rw->{lts}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
    }
    elsif ($line =~ m/^\t+\+\[rw\/morph\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: morph analysis of rewrite target
      $w->{rw}   = [ {} ] if (!$w->{rw});
      $rw          = $w->{rw}[$#{$w->{rw}}] if (!$rw);
      push(@{$rw->{morph}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
    }
    elsif ($line =~ m/^\t\+\[eqpho\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: phonetic equivalent, full-fst version
      push(@{$w->{eqpho}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
    }
    elsif ($line =~ m/^\t\+\[eqpho\] (.*?)\s*(?:\<([\d\.\+\-eE]+)\>)?$/) {
      ##-- token: field: phonetic equivalent, optional weight
      push(@{$w->{eqpho}}, {hi=>$1,w=>$2});
    }
    elsif ($line =~ m/^\t\+\[eqrw\] (?:((?:\\.|[^:])*) : )?(.*) \<([\d\.\+\-eE]+)\>$/) {
      ##-- token: field: rewrite equivalent, full-fst version
      push(@{$w->{eqrw}}, {(defined($1) ? (lo=>$1) : qw()), hi=>$2, w=>$3});
    }
    elsif ($line =~ m/^\t\+\[eqrw\] (.*?)\s*(?:\<([\d\.\+\-eE]+)\>)?$/) {
      ##-- token: field: rewrite equivalent, optional weight
      push(@{$w->{eqrw}}, {hi=>$1,w=>$2});
    }
    elsif ($line =~ m/^\t\+\[(.*?moot)\/tag\]\s?(.*)$/) {
      ##-- token: field: ?moot/tag
      $w->{$1}{tag} = $2;
    }
    elsif ($line =~ m/^\t\+\[(.*moot)\/analysis\]\s?(\S+)\s(.*?)(?: <([\d\.\+\-eE]+)>)?$/) {
      ##-- token: field: ?moot/analysis
      push(@{$w->{$1}{analyses}}, {tag=>$2,details=>$3,cost=>$4});
    }
    elsif ($line =~ m/^\t\+\[([^\]]*)\]\s?(.*)$/) {
      ##-- token: field: unknown named field "+[$name] $val", parse into $w->{other}{$name} = \@vals
      push(@{$w->{other}{$1}}, $2);
    }
    else {
      ##-- token: field: unnamed field
      #$fmt->warn("parseTextString(): could not parse line '$line'");
      $line =~ s/^\t//;
      push(@{$w->{other}{$fmt->{defaultFieldName}||''}}, $line);
    }
  }
  push(@$body,{%sa,tokens=>$s}) if (@$s || %sa); ##-- final sentence

  ##-- construct & buffer document
  $_ = bless($_,'DTA::CAB::Sentence') foreach (@$body);
  $doc->{body} = $body;
  $fmt->{doc} = $doc;

  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##  + just returns $fmt->{doc}
##  + inherited from DTA::CAB::Format::TT


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
##  + inherited from DTA::CAB::Format::TT

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
##  + inherited from DTA::CAB::Format::TT

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
  $out .= join('', map { "\t+[eqpho] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_)."\n" } grep {defined($_)} @{$tok->{eqpho}})
    if ($tok->{eqpho});

  ##-- Rewrite Equivalents ('eqrw')
  $out .= join('', map { "\t+[eqrw] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_)."\n" } grep {defined($_)} @{$tok->{eqrw}})
    if ($tok->{eqrw});

  ##-- Morph ('morph')
  $out .= join('', map { "\t+[morph] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>\n" } @{$tok->{morph}})
    if ($tok->{morph});

  ##-- Morph::Latin ('morph/lat')
  $out .= join('', map { "\t+[morph/lat] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>\n" } @{$tok->{mlatin}})
    if ($tok->{mlatin});

  ##-- MorphSafe ('morph/safe')
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

  ##-- moot
  if ($tok->{moot}) {
    $out .= "\t+[moot/tag] $tok->{moot}{tag}\n";
    $out .= join('', map {"\t+[moot/analysis] $_->{tag} $_->{details} <".($_->{cost}||0).">\n"} @{$tok->{moot}{analyses}})
      if ($tok->{moot}{analyses});
  }

  ##-- dmoot
  if ($tok->{dmoot}) {
    $out .= "\t+[dmoot/tag] $tok->{dmoot}{tag}\n";
    $out .= join('', map {"\t+[dmoot/analysis] $_->{tag} $_->{details} <".($_->{cost}||0).">\n"} @{$tok->{dmoot}{analyses}})
      if ($tok->{dmoot}{analyses});
  }

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
##  + concatenates formatted tokens, adding sentence-id comment if available
##  + inherited from DTA::CAB::Format::TT

## $out = $fmt->formatDocument($doc)
##  + concatenates formatted sentences, adding document 'xmlbase' comment if available
##  + inherited from DTA::CAB::Format::TT

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
 ## Methods: Input
 
 $doc = $fmt->parseTextString();
 
 ##========================================================================
 ## Methods: Output
 
 $fmt = $fmt->putToken($tok);

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
L<DTA::CAB::Format|DTA::CAB::Format> via L<DTA::CAB::Format::TT|DTA::CAB::Format::TT>.

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
Inherited from L<DTA::CAB::Format::TT|DTA::CAB::Format::TT>.

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
## DESCRIPTION: DTA::CAB::Format::Text: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item parseTextString

 $fmt = $fmt->parseTextString($str);

Guts for document parsing: parse string $str into local document buffer $fmt-E<gt>{doc}.

=item parseTTString

 $fmt = $fmt->parseTTString($str);

Alias for parseTextString().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Text: Methods: Output
=pod

=head2 Methods: Output

=over 4

=item putToken

 $fmt = $fmt->putToken($tok);

Override: append formatted token $tok to output buffer.

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
