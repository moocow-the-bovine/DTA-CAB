## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TJ.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: one-token-per-line text

package DTA::CAB::Format::TJ;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode encode_utf8 decode_utf8);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::TT);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:tj|tjson|cab\-tj|cab\-tjson)$/);
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
##     outbuf  => $stringBuffer,     ##-- buffered output
##     level   => $formatLevel,      ##-- <0:no 'text' attribute; >=0: all attributes
##
##     ##-- Common
##     raw => $bool,                   ##-- attempt to load/save raw data
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
		   level => 0,

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
  return qw(doc outbuf jxs);
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
  return $fmt->parseTJString($_[0]);
}

##--------------------------------------------------------------
## Methods: utilities

## $jxs = $fmt->jsonxs()
sub jsonxs {
  require JSON::XS;
  return $_[0]{jxs} if (defined($_[0]{jxs}));
  return $_[0]{jxs} = JSON::XS->new->utf8(0)->relaxed(1)->canonical(0)->allow_blessed(1)->convert_blessed(1);
}


##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseTJString($str)
##  + guts for fromString(): parse string $str into local document buffer.
sub parseTJString {
  my $fmt = shift;

  my $srcr = \$_[0];
  if (!utf8::is_utf8($$srcr)) {
    ##-- JSON::XS likes byte-string input
    my $src = decode_utf8($$srcr);
    $srcr   = \$src;
  }

  my $jxs = $fmt->jsonxs();

  ##-- split by sentence
  my ($toks,$tok,$text,$json, $fkey,$fval,$fobj);
  my (%sa,%doca);
  my $sents =
    [
     map {
       %sa=qw();
       $toks=
	 [
	  map {
	    if ($_ =~ /^\%\%\$TJ\:DOC=(.+)$/) {
	      ##-- tj comment: document
	      $json = defined($1) && $1 ? $jxs->decode($1) : {};
	      @doca{keys %$json} = values %$json;
	      qw()
	    } elsif ($_ =~ /^\%\%\$TJ\:SENT=(.+)$/) {
	      $json = defined($1) && $1 ? $jxs->decode($1) : {};
	      @sa{keys %$json} = values %$json;
	      qw()
	    } elsif ($_ =~ /^\%\% (?:xml\:)?base=(.*)$/) {
	      ##-- (tt-compat) special comment: document attribute: xml:base
	      $doca{'base'} = $1;
	      qw()
	    } elsif ($_ =~ /^\%\% Sentence (.*)$/) {
	      ##-- (tt-compat) special comment: sentence attribute: xml:id
	      $sa{'id'} = $1;
	      qw()
	    } elsif ($_ =~ /^\%\%(.*)$/) {
	      ##-- (tt-compat) generic line: add to _cmts
	      push(@{$sa{_cmts}},$1); ##-- generic doc- or sentence-level comment
	      qw()
	    } else {
	      ##-- vanilla token
	      ($text,$json) = split(/\t/,$_,2);
	      $tok = (defined($json) && $json ne '' ? $jxs->decode($json) : {});
	      $tok->{text}=$text if (!defined($tok->{text}));
	      $tok
	    }
	  }
	  split(/\n/, $_)
	 ];
       (%sa || @$toks ? {%sa,tokens=>$toks} : qw())
     } split(/\n\n+/, $$srcr)
    ];

  ##-- construct & buffer document
  #$_ = bless($_,'DTA::CAB::Sentence') foreach (@$sents);
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
## Methods: Output: MIME

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.tj'; }

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
##  + default implementation just returns $fmt->{outbuf}
sub toString {
  $_[0]{outbuf}  = '' if (!defined($_[0]{outbuf}));
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
  #my ($fmt,$tok) = @_;

  $_[0]{outbuf} .=
    (
     ($_[1]{_cmts} ? join('', map {"%%$_\n"} map {split(/\n/,$_)} @{$_[1]{_cmts}}) : '')
     .$_[1]{text}
     ."\t"
     .$_[0]->jsonxs->encode(($_[0]{level}||0) >= 0
			    ? $_[1]
			    : {(map {$_ eq 'text' ? qw() : ($_=>$_[1]{$_})} keys %{$_[1]})}
			   )
     ."\n"
    );

  return $_[0];
}

## $fmt = $fmt->putSentence($sent)
##  + concatenates formatted tokens, adding sentence-id comment if available
sub putSentence {
  #my ($fmt,$sent) = @_;
  my $sh = {(map {$_ eq 'tokens' ? qw() : ($_=>$_[1]{$_})} keys %{$_[1]})};
  $_[0]{outbuf} .=  '%%$TJ:SENT='.$_[0]->jsonxs->encode($sh) if (%$sh);
  $_[0]->putToken($_) foreach (@{toSentence($_[1])->{tokens}});
  $_[0]->{outbuf} .= "\n";
  return $_[0];
}

## $fmt = $fmt->putDocument($doc)
##  + concatenates formatted sentences, adding document 'xmlbase' comment if available
sub putDocument {
  #my ($fmt,$doc) = @_;
  my $dh = {(map {$_ eq 'body' ? qw() : ($_=>$_[1]{$_})} keys %{$_[1]})};
  $_[0]{outbuf} .= '%%$TJ:DOC='.$_[0]->jsonxs->encode($dh)."\n" if (%$dh);
  $_[0]->putSentence($_) foreach (@{toDocument($_[1])->{body}});
  $_[0]->{outbuf} .= "\n";
  return $_[0];
}


## $fmt = $fmt->putData($data)
##  + puts raw data (json)
sub putData {
  $_[0]{outbuf} .= $_[0]->jsonxs->encode($_[1]);
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::TJ - Datum parser: one-token-per-line text; token data as JSON

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::TJ;
 
 ##========================================================================
 ## Constructors etc.
 
 $fmt = DTA::CAB::Format::TJ->new(%args);
 
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
## DESCRIPTION: DTA::CAB::Format::TJ: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Format::TJ
inherits from
L<DTA::CAB::Format::TT|DTA::CAB::Format::TT>.

=item Filenames

DTA::CAB::Format::TJ registers the filename regex:

 /\.(?i:tj|cab-tj)$/

with L<DTA::CAB::Format|DTA::CAB::Format>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::TJ: Constructors etc.
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
## DESCRIPTION: DTA::CAB::Format::TJ: Methods: Persistence
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
## DESCRIPTION: DTA::CAB::Format::TJ: Methods: Input
=pod

=head2 Methods: Input

=over 4

=item close

 $fmt = $fmt->close();

Override: close current input source, if any.

=item fromString

 $fmt = $fmt->fromString($string);

Override: select input from string $string.

=item parseTJString

 $fmt = $fmt->parseTJString($str)

Guts for fromString(): parse string $str into local document buffer
$fmt-E<gt>{doc}.

=item parseDocument

 $doc = $fmt->parseDocument();

Override: just returns local document buffer $fmt-E<gt>{doc}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::TJ: Methods: Output
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
