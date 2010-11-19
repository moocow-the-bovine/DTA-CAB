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
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:t|tt|ttt|cab\-t|cab\-tt|cab\-ttt)$/);
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
##     defaultFieldName => $name,      ##-- default name for unnamed fields; parsed into @{$tok->{other}{$name}}; default=''
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

  my ($tok,$rw,$line);
  my ($text,@fields,$fieldi,$field, $fkey,$fval,$fobj);
  my $sents  = [];
  my $s      = [];
  my %sa     = qw(); ##-- sentence attributes
  my %doca   = qw(); ##-- document attributes

  my %f2key =
    ('morph/lat'=>'mlatin',
     'morph/la'=>'mlatin',
    );

  while ($src =~ m/^(.*)$/mg) {
    $line = $1;
    if ($line =~ /^\%\% xml\:base=(.*)$/) {
      ##-- special comment: document attribute: xml:base
      $doca{xmlbase} = $1;
    }
    elsif ($line =~ /^\%\% Sentence (.*)$/) {
      ##-- special comment: sentence attribute: xml:id
      $sa{xmlid} = $1;
    }
    elsif ($line =~ /^\%\%(.*)$/) {
      ##-- generic line: add to _cmts
      push(@{$sa{_cmts}},$1); ##-- generic doc- or sentence-level comment
      next;
    }
    elsif ($line eq '') {
      ##-- blank line: eos
      push(@$sents, { %sa, tokens=>$s }) if (@$s || %sa);
      $s   = [];
      %sa = qw();
    }
    else {
      ##-- token
      ($text,@fields) = split(/\t/,$line);
      push(@$s, $tok=bless({text=>$text},'DTA::CAB::Token'));
      foreach $fieldi (0..$#fields) {
	$field = $fields[$fieldi];
	if (($fieldi == 0 && $field =~ m/^(\d+) (\d+)$/) || ($field =~ m/^\[loc\] (?:off=)?(\d+) (?:len=)?(\d+)$/)) {
	  ##-- token: field: loc
	  $tok->{loc} = { off=>$1,len=>$2 };
	}
#	elsif ($field =~ m/^\[(xmlid|chars)\] (.*)$/) {
#	  ##-- token: field: DTA::TokWrap special field
#	  $tok->{$1} = $2;
#	}
	elsif ($field =~ m/^\[xlit\] (?:isLatin1|l1)=(\d) (?:isLatinExt|lx)=(\d) (?:latin1Text|l1s)=(.*)$/) {
	  ##-- token: field: xlit
	  $tok->{xlit} = { isLatin1=>$1, isLatinExt=>$2, latin1Text=>$3 };
	}
	elsif ($field =~ m/^\[(lts|eqpho|eqphox|morph|mlatin|morph\/lat?|rw|rw\/lts|rw\/morph|eqrw|moot\/morph|dmoot\/morph)\] (.*)$/) {
	  ##-- token fields: fst analysis: (lts|eqpho|eqphox|morph|mlatin|rw|rw/lts|rw/morph|eqrw|moot/morph|dmoot/morph)
	  ($fkey,$fval) = ($1,$2);
	  if ($fkey =~ s/^rw\///) {
	    $tok->{rw} = [ {} ] if (!$tok->{rw});
	    $fobj      = $tok->{rw}[$#{$tok->{rw}}];
	  }
	  elsif ($fkey =~ s/^dmoot\///) {
	    $tok->{dmoot} = {} if (!$tok->{dmoot});
	    $fobj         = $tok->{dmoot};
	  }
	  elsif ($fkey =~ s/^moot\///) {
	    $tok->{moot}  = {} if (!$tok->{moot});
	    $fobj         = $tok->{moot};
	  }
	  else {
	    $fobj = $tok;
	  }
	  $fkey = $f2key{$fkey} if (defined($f2key{$fkey}));
	  if ($fval =~ /^(?:(.*?) \: )?(?:(.*?) \@ )?(.*?)(?: \<([\d\.\+\-eE]+)\>)?$/) {
	    push(@{$fobj->{$fkey}}, {(defined($1) ? (lo=>$1) : qw()), (defined($2) ? (lemma=>$2) : qw()), hi=>$3, w=>($4||0)});
	  } else {
	    $fmt->warn("parseTTString(): could not parse FST analysis field '$fkey' for token '$text': $field");
	  }
	}
	elsif ($field =~ m/^\[morph\/safe\] (\d)$/) {
	  ##-- token: field: morph-safety check (morph/safe)
	  $tok->{msafe} = $1;
	}
	elsif ($field =~ m/^\[(.*?moot)\/(tag|word|lemma)\]\s?(.*)$/) {
	  ##-- token: field: (moot|dmoot)/(tag|word|lemma)
	  $tok->{$1}{$2} = $3;
	}
	elsif ($field =~ m/^\[(.*?moot)\/analysis\]\s?(\S+)\s(?:\~\s)?(.*?)(?: <([\d\.\+\-eE]+)>)?$/) {
	  ##-- token: field: moot/analysis|dmoot/analysis
	  push(@{$tok->{$1}{analyses}}, {tag=>$2,details=>$3,cost=>$4});
	}
	elsif ($field =~ m/^\[(toka|tokpp)\]\s?(.*)$/) {
	  ##-- token: field: other known list field: (toka|tokp�p)
	  push(@{$tok->{$1}}, $2);
	}
	elsif ($field =~ m/^\[([^\]]*)\]\s?(.*)$/) {
	  ##-- token: field: unknown named field "[$name] $val", parse into $tok->{other}{$name} = \@vals
	  push(@{$tok->{other}{$1}}, $2);
	}
	else {
	  ##-- token: field: unnamed field
	  #$fmt->warn("parseTTString(): could not parse token field '$field' for token '$text'");
	  push(@{$tok->{other}{$fmt->{defaultFieldName}||''}}, $field);
	}
      }
    }
  }
  push(@$sents,{%sa,tokens=>$s}) if (@$s || %sa); ##-- final sentence

  ##-- construct & buffer document
  $_ = bless($_,'DTA::CAB::Sentence') foreach (@$sents);
  $fmt->{doc} = bless({%doca,body=>$sents}, 'DTA::CAB::Document');
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
  my $out = '';

  ##-- pre-token comments
  $out .= join('', map {"%%$_\n"} map {split(/\n/,$_)} @{$tok->{_cmts}}) if ($tok->{_cmts});

  ##-- text
  $out .= $tok->{text};

  ##-- Location ('loc'), moot compatibile
  $out .= "\t$tok->{loc}{off} $tok->{loc}{len}" if (defined($tok->{loc}));

  ##-- xml-id
  #$out .= "\t[xmlid] $tok->{xmlid}" if (defined($tok->{xmlid}));

  ##-- character list
  #$out .= "\t[chars] $tok->{chars}" if (defined($tok->{chars}));

  ##-- cab token-preprocessor analyses
  $out .= join('', map {"\t[tokpp] $_"} grep {defined($_)} @{$tok->{tokpp}}) if ($tok->{tokpp});

  ##-- tokenizer-supplied analyses
  $out .= join('', map {"\t[toka] $_"} grep {defined($_)} @{$tok->{toka}}) if ($tok->{toka});

  ##-- Transliterator ('xlit')
  $out .= "\t[xlit] l1=$tok->{xlit}{isLatin1} lx=$tok->{xlit}{isLatinExt} l1s=$tok->{xlit}{latin1Text}"
    if (defined($tok->{xlit}));

  ##-- LTS ('lts')
  $out .= join('', map { "\t[lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{lts}})
    if ($tok->{lts});

  ##-- phonetic digests ('soundex', 'koeln', 'metaphone')
  $out .= "\t[soundex] $tok->{soundex}"     if (defined($tok->{soundex}));
  $out .= "\t[koeln] $tok->{koeln}"         if (defined($tok->{koeln}));
  $out .= "\t[metaphone] $tok->{metaphone}" if (defined($tok->{metaphone}));

  ##-- Phonetic Equivalents ('eqpho')
  $out .= join('', map { "\t[eqpho] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_) } grep {defined($_)} @{$tok->{eqpho}})
    if ($tok->{eqpho});

  ##-- Known Phonetic Equivalents ('eqphox')
  $out .= join('', map { "\t[eqphox] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_) } grep {defined($_)} @{$tok->{eqphox}})
    if ($tok->{eqphox});

  ##-- Morph ('morph')
  if ($tok->{morph}) {
    $out .= join('',
		 map {("\t[morph] "
		       .(defined($_->{lo}) ? "$_->{lo} : " : '')
		       .(defined($_->{lemma}) ? "$_->{lemma} @ " : '')
		       ."$_->{hi} <$_->{w}>")
		    } @{$tok->{morph}});
  }

  ##-- Morph::Latin ('morph/lat')
  $out .= join('', map { "\t[morph/lat] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{mlatin}})
    if ($tok->{mlatin});

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
		   ? map {("\t[rw/morph] "
			   .(defined($_->{lo}) ? "$_->{lo} : " : '')
			   .(defined($_->{lemma}) ? "$_->{lemma} @ " : '')
			   ."$_->{hi} <$_->{w}>"
			  )} @{$_->{morph}}
		   : qw()),
		 )
	       } @{$tok->{rw}})
    if ($tok->{rw});

  ##-- Rewrite Equivalents ('eqrw')
  $out .= join('', map { "\t[eqrw] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_) } grep {defined($_)} @{$tok->{eqrw}})
    if ($tok->{eqrw});

  ##-- dmoot
  if ($tok->{dmoot}) {
    ##-- dmoot/tag
    $out .= "\t[dmoot/tag] $tok->{dmoot}{tag}";

    ##-- dmoot/morph
    $out .= join('', map {("\t[dmoot/morph] "
			   .(defined($_->{lo}) ? "$_->{lo} : " : '')
			   .(defined($_->{lemma}) ? "$_->{lemma} @ " : '')
			   ."$_->{hi} <$_->{w}>"
			  )} @{$tok->{dmoot}{morph}})
      if ($tok->{dmoot}{morph});

    ##-- dmoot/analyses
    $out .= join('', map {"\t[dmoot/analysis] $_->{tag} ~ $_->{details} <".($_->{cost}||0).">"} @{$tok->{dmoot}{analyses}})
      if ($tok->{dmoot}{analyses});
  }

  ##-- moot
  if ($tok->{moot}) {
    ##-- moot/word
    $out .= "\t[moot/word] $tok->{moot}{word}" if (defined($tok->{moot}{word}));

    ##-- moot/tag
    $out .= "\t[moot/tag] $tok->{moot}{tag}";

    ##-- moot/lemma
    $out .= "\t[moot/lemma] $tok->{moot}{lemma}" if (defined($tok->{moot}{lemma}));

    ##-- moot/morph (UNUSED)
    $out .= join('', map {("\t[moot/morph] "
			   .(defined($_->{lo}) ? "$_->{lo} : " : '')
			   .(defined($_->{lemma}) ? "$_->{lemma} @ " : '')
			   ."$_->{hi} <$_->{w}>"
			  )} @{$tok->{moot}{morph}})
      if ($tok->{moot}{morph});

    ##-- moot/analyses
    $out .= join('', map {("\t[moot/analysis] $_->{tag}"
			   .(defined($_->{lemma}) ? " \@ $_->{lemma}" : '')
			   ." ~ $_->{details} <".($_->{cost}||0).">"
			  )} @{$tok->{moot}{analyses}})
      if ($tok->{moot}{analyses});
  }

  ##-- lemma equivalents
  $out .= join('', map {("\t[eqlemma] "
			 .(defined($_->{lo}) ? "$_->{lo} : " : '')
			 .$_->{hi}
			 .(defined($_->{w}) ? " <$_->{w}>" : '')
			)} grep {defined($_)} @{$tok->{eqlemma}})
    if ($tok->{eqlemma});


  ##-- unparsed fields (pass-through)
  if ($tok->{other}) {
    my ($name);
    $out .= ("\t"
	     .join("\t",
		   (map { $name=$_; map { "[$name] $_" } @{$tok->{other}{$name}} }
		    sort grep {$_ ne $fmt->{defaultFieldName}} keys %{$tok->{other}}
		   ),
		   ($tok->{other}{$fmt->{defaultFieldName}}
		    ? @{$tok->{other}{$fmt->{defaultFieldName}}}
		    : qw()
		   ))
	    );
  }

  ##-- ... ???
  $fmt->{outbuf} .= $out."\n";
  return $fmt;
}

## $fmt = $fmt->putSentence($sent)
##  + concatenates formatted tokens, adding sentence-id comment if available
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->{outbuf} .= join('', map {"%%$_\n"} map {split(/\n/,$_)} @{$sent->{_cmts}}) if ($sent->{_cmts});
  $fmt->{outbuf} .= "%% Sentence $sent->{xmlid}\n" if (defined($sent->{xmlid}));
  $fmt->putToken($_) foreach (@{toSentence($sent)->{tokens}});
  $fmt->{outbuf} .= "\n";
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
##  + concatenates formatted sentences, adding document 'xmlbase' comment if available
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->{outbuf} .= join('', map {"%%$_\n"} map {split(/\n/,$_)} @{$doc->{_cmts}}) if ($doc->{_cmts});
  $fmt->{outbuf} .= "%% xml:base=$doc->{xmlbase}\n\n" if (defined($doc->{xmlbase}));
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

Guts for fromString(): parse string $str into local document buffer
$fmt-E<gt>{doc}.

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

##========================================================================
## EXAMPLE
##========================================================================
=pod

=head1 EXAMPLE

An example file in the format accepted/generated by this module (with very long lines) is:

 wie	[xlit] l1=1 lx=1 l1s=wie	[lts] vi <0>	[eqpho] Wie	[eqpho] wie	[morph] wie[_ADV] <0>	[morph] wie[_KON] <0>	[morph] wie[_KOKOM] <0>	[morph] wie[_KOUS] <0>	[morph/safe] 1
 oede	[xlit] l1=1 lx=1 l1s=oede	[lts] ?2de <0>	[eqpho] Oede	[eqpho] Öde	[eqpho] öde	[morph/safe] 0	[rw] öde <1>	[rw/lts] ?2de <0>	[rw/morph] öde[_ADJD] <0>	[rw/morph] öde[_ADJA][pos][sg][nom]*[weak] <0>	[rw/morph] öde[_ADJA][pos][sg][nom][fem][strong_mixed] <0>	[rw/morph] öde[_ADJA][pos][sg][acc][fem]* <0>	[rw/morph] öde[_ADJA][pos][sg][acc][neut][weak] <0>	[rw/morph] öde[_ADJA][pos][pl][nom_acc]*[strong] <0>	[rw/morph] öd~en[_VVFIN][first][sg][pres][ind] <0>	[rw/morph] öd~en[_VVFIN][first][sg][pres][subjI] <0>	[rw/morph] öd~en[_VVFIN][third][sg][pres][subjI] <0>	[rw/morph] öd~en[_VVIMP][sg] <0>
 !	[xlit] l1=1 lx=1 l1s=!	[lts]  <0>	[morph/safe] 1
 

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


=cut
