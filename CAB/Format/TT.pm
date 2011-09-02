## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::TT.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser: one-token-per-line text

package DTA::CAB::Format::TT;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use IO::File;
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
##     raw => $bool,                   ##-- attempt to load/save raw data
##     fh  => $fh,                     ##-- IO::Handle for read/write
##     utf8 => $bool,                  ##-- read/write utf8?
##     defaultFieldName => $name,      ##-- default name for unnamed fields; parsed into @{$tok->{other}{$name}}; default=''
##    }

sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   doc => undef,

		   ##-- common
		   utf8 => 1,
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
  return ($_[0]->SUPER::noSaveKeys, qw(doc outbuf));
}

##==============================================================================
## Methods: I/O: Generic
##==============================================================================

## $fmt = $fmt->close()
##  + inherited

##==============================================================================
## Methods: I/O: Block-wise
##==============================================================================

## \%head = blockScanHead(\$buf,\%opts)
##  + gets header offset, length from (mmaped) \$buf
##  + %opts are as for blockScan()
sub blockScanHead {
  my ($fmt,$bufr,$opts) = @_;
  return [0,$+[0]] if ($$bufr =~ m(\A\n*+(?:%% base=.*\n++)?));
  return [0,0];
}

## \%head = blockScanFoot(\$buf,\%opts)
##  + gets footer offset, length from (mmaped) \$buf
##  + %opts are as for blockScan()
##  + override returns empty
sub blockScanFoot {
  my ($fmt,$bufr,$opts) = @_;
  return [0,0];
}

## \@blocks = $fmt->blockScanBody(\$buf,\%opts)
##  + scans $filename for block boundaries according to \%opts
sub blockScanBody {
  my ($fmt,$bufr,$opts) = @_;

  ##-- scan blocks into head, body, foot
  my $bsize  = $opts->{size};
  my $fsize  = $opts->{fsize};
  my $eob    = $opts->{eob} =~ /^s/i ? 's' : 'w';
  my $blocks = [];

  my ($off0,$off1,$blk);
  for ($off0=$opts->{head}[0]+$opts->{head}[1]; $off0 < $fsize; $off0=$off1) {
    push(@$blocks, $blk={off=>$off0});
    pos($$bufr) = ($off0+$bsize < $fsize ? $off0+$bsize : $fsize);
    if ($eob eq 's' ? $$bufr=~m/\n{2,}/sg : $$bufr=~m/\n{1,}/sg) {
      $off1 = $+[0];
      $blk->{eos} = $+[0]-$-[0] > 1 ? 1 : 0;
    } else {
      $off1       = $fsize;
      $blk->{eos} = 1;
    }
    $blk->{len} = $off1-$off0;
  }

  return $blocks;
}


## $fmt_or_undef = $fmt->blockAppend($block,$filename)
##  + append a block $block to a file $filename
##  + $block is a HASH-ref as returned by blockScan()
sub blockAppend {
  my ($fmt,$block,$file) = @_;
  #$fmt->vlog('trace', "blockAppend(off=$block->{off}, len=$block->{len}, file=$file)");

  ##-- truncate extraneous newlines from data
  use bytes;
  my $bufr = $block->{data};
  if (!$block->{eos}) {
    $$bufr =~ s/\n\K(\n+)$//s;
  } else {
    $$bufr =~ s/\n\n\K(\n+)$//s;
  }

  ##-- get header for non-initial blocks
  my $head = $block->{n} > 0 ? $fmt->blockScanHead($bufr,{}) : [0,0];

  ##-- open & write
  my $outfh = IO::File->new(($block->{n}==0 ? '>' : '>>').$file)
    or $fmt->logconfess("blockAppend(): open failed for '$file': $!");
  binmode($outfh, utf8::is_utf8($$bufr) ? ':utf8' : ':raw');
  $outfh->print($head->[1] ? substr($$bufr,$head->[0]+$head->[1]) : $$bufr)
    or $fmt->logconfess("blockAppend(): print failed to '$file': $!");

  $outfh->close;
  return $fmt;
}


##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->fromFh($filename_or_handle)
##  + override calls fromFh_str()
sub fromFh {
  return $_[0]->fromFh_str(@_[1..$#_]);
}

## $fmt = $fmt->fromString(\$string)
##  + select input from string $string
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parseTTString(ref($_[0]) ? $_[0] : \$_[0]);
}

##--------------------------------------------------------------
## Methods: Input: Local

## $fmt = $fmt->parseTTString(\$str)
##  + guts for fromString(): parse string $str into local document buffer.
sub parseTTString {
  my ($fmt,$src) = @_;
  utf8::decode($$src) if ($fmt->{utf8} && !utf8::is_utf8($$src));

  my %f2key =
    ('morph/lat'=>'mlatin',
     'morph/la'=>'mlatin',
    );

  ##-- split by sentence
  my ($toks,$tok,$rw,$text,@fields,$fieldi,$field, $fkey,$fval,$fobj);
  my (%sa,%doca);
  my $sents =
    [
     map {
       %sa=qw();
       $toks=
	 [
	  map {
	    if ($_ =~ /^\%\% (?:xml\:)?base=(.*)$/) {
	      ##-- special comment: document attribute: xml:base
	      $doca{'base'} = $1;
	      qw()
	    } elsif ($_ =~ /^\%\% Sentence (.*)$/) {
	      ##-- special comment: sentence attribute: xml:id
	      $sa{'id'} = $1;
	      qw()
	    } elsif ($_ =~ /^\%\%(.*)$/) {
	      ##-- generic line: add to _cmts
	      push(@{$sa{_cmts}},$1); ##-- generic doc- or sentence-level comment
	      qw()
	    } elsif ($_ =~ /^$/) {
	      ##-- blank line: ignore
	      qw()
	    } else {
	      ##-- token
	      ($text,@fields) = split(/\t/,$_);
	      $tok={text=>$text};
	      foreach $fieldi (0..$#fields) {
		$field = $fields[$fieldi];
		if (($fieldi == 0 && $field =~ m/^(\d+) (\d+)$/) || ($field =~ m/^\[loc\] (?:off=)?(\d+) (?:len=)?(\d+)$/)) {
		  ##-- token: field: loc
		  $tok->{loc} = { off=>$1,len=>$2 };
		} elsif ($field =~ m/^\[(?:xml\:?)?(id|chars)\] (.*)$/) {
		  ##-- token: field: DTA::TokWrap special fields: (id|chars|xml:id|xml:chars)
		  $tok->{$1} = $2;
		} elsif ($field =~ m/^\[(exlex|pnd|mapclass|errid|xc|xr|xp|pb|lb|bb|c|b|coff|clen|boff|blen)\] (.*)$/) {
		  ##-- token: field: other literal field (exlex, pnd, mapclass, errid, ...)
		  $tok->{$1} = $2;
		} elsif ($field =~ m/^\[xlit\] /) {
		  ##-- token: field: xlit
		  if ($field =~ m/^\[xlit\] (?:isLatin1|l1)=(\d) (?:isLatinExt|lx)=(\d) (?:latin1Text|l1s)=(.*)$/) {
		    $tok->{xlit} = { isLatin1=>($1||0), isLatinExt=>($2||0), latin1Text=>$3 };
		  } else {
		    $tok->{xlit} = { isLatin1=>'', isLatinExt=>'', latin1Text=>substr($field,7) };
		  }
		} elsif ($field =~ m/^\[(lts|eqpho|eqphox|morph|mlatin|morph\/lat?|rw|rw\/lts|rw\/morph|eqrw|moot\/morph|dmoot\/morph)\] (.*)$/) {
		  ##-- token fields: fst analysis: (lts|eqpho|eqphox|morph|mlatin|rw|rw/lts|rw/morph|eqrw|moot/morph|dmoot/morph)
		  ($fkey,$fval) = ($1,$2);
		  if ($fkey =~ s/^rw\///) {
		    $tok->{rw} = [ {} ] if (!$tok->{rw});
		    $fobj      = $tok->{rw}[$#{$tok->{rw}}];
		  } elsif ($fkey =~ s/^dmoot\///) {
		    $tok->{dmoot} = {} if (!$tok->{dmoot});
		    $fobj         = $tok->{dmoot};
		  } elsif ($fkey =~ s/^moot\///) {
		    $tok->{moot}  = {} if (!$tok->{moot});
		    $fobj         = $tok->{moot};
		  } else {
		    $fobj = $tok;
		  }
		  $fkey = $f2key{$fkey} if (defined($f2key{$fkey}));
		  if ($fval =~ /^(?:(.*?) \: )?(?:(.*?) \@ )?(.*?)(?: \<([\d\.\+\-eE]+)\>)?$/) {
		    push(@{$fobj->{$fkey}}, {(defined($1) ? (lo=>$1) : qw()), (defined($2) ? (lemma=>$2) : qw()), hi=>$3, w=>($4||0)});
		  } else {
		    $fmt->warn("parseTTString(): could not parse FST analysis field '$fkey' for token '$text': $field");
		  }
		} elsif ($field =~ m/^\[m(?:orph\/)?safe\] (\d)$/) {
		  ##-- token: field: morph-safety check (msafe|morph/safe)
		  $tok->{msafe} = $1;
		} elsif ($field =~ m/^\[(.*?moot)\/(tag|word|lemma)\]\s?(.*)$/) {
		  ##-- token: field: (moot|dmoot)/(tag|word|lemma)
		  $tok->{$1}{$2} = $3;
		} elsif ($field =~ m/^\[(.*?moot)\/analysis\]\s?(\S+)\s(?:\~\s)?(.*?)(?: <([\d\.\+\-eE]+)>)?$/) {
		  ##-- token: field: moot/analysis|dmoot/analysis
		  push(@{$tok->{$1}{analyses}}, {tag=>$2,details=>$3,cost=>$4});
		} elsif ($field =~ m/^\[(toka|tokpp)\]\s?(.*)$/) {
		  ##-- token: field: other known list field: (toka|tokpp)
		  push(@{$tok->{$1}}, $2);
		} elsif ($field =~ m/^\[([^\]]*)\]\s?(.*)$/) {
		  ##-- token: field: unknown named field "[$name] $val", parse into $tok->{other}{$name} = \@vals
		  push(@{$tok->{other}{$1}}, $2);
		} else {
		  ##-- token: field: unnamed field
		  #$fmt->warn("parseTTString(): could not parse token field '$field' for token '$text'");
		  push(@{$tok->{other}{$fmt->{defaultFieldName}||''}}, $field);
		}
	      }
	      $tok
	    }
	  }
	  split(/\n/, $_)
	 ];
       (%sa || @$toks ? {%sa,tokens=>$toks} : qw())
     } split(/\n\n+/, $$src)
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
## Methods: Output: Generic

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.tt'; }

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)
sub toFh {
  $_[0]->DTA::CAB::Format::toFh(@_[1..$#_]);
  $_[0]->setLayers();
  return $_[0];
}

##--------------------------------------------------------------
## Methods: Output: Generic API

## \$buf = $fmt->token2buf($tok,\$buf)
##  + buffer output for a single token
##  + called by putToken()
sub token2buf {
  my ($fmt,$tok,$bufr) = @_;
  $bufr  = \(my $buf='') if (!defined($bufr));
  $$bufr = '';

  ##-- pre-token comments
  $$bufr .= join('', map {"%%$_\n"} map {split(/\n/,$_)} @{$tok->{_cmts}}) if ($tok->{_cmts});

  ##-- text
  $$bufr .= $tok->{text};

  ##-- Location ('loc'), moot compatibile
  $$bufr .= "\t$tok->{loc}{off} $tok->{loc}{len}" if (defined($tok->{loc}));

  ##-- character list
  #$$bufr .= "\t[chars] $tok->{chars}" if (defined($tok->{chars}));

  ##-- literal fields
  foreach (grep {defined($tok->{$_})} qw(id exlex pnd mapclass errid xc xr xp pb lb bb c coff clen b boff blen)) {
    $$bufr .= "\t[$_] $tok->{$_}"
  }

  ##-- cab token-preprocessor analyses
  $$bufr .= join('', map {"\t[tokpp] $_"} grep {defined($_)} @{$tok->{tokpp}}) if ($tok->{tokpp});

  ##-- tokenizer-supplied analyses
  $$bufr .= join('', map {"\t[toka] $_"} grep {defined($_)} @{$tok->{toka}}) if ($tok->{toka});

  ##-- Transliterator ('xlit')
  $$bufr .= "\t[xlit] l1=$tok->{xlit}{isLatin1} lx=$tok->{xlit}{isLatinExt} l1s=$tok->{xlit}{latin1Text}"
    if (defined($tok->{xlit}));

  ##-- LTS ('lts')
  $$bufr .= join('', map { "\t[lts] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{lts}})
    if ($tok->{lts});

  ##-- phonetic digests ('soundex', 'koeln', 'metaphone')
  $$bufr .= "\t[soundex] $tok->{soundex}"     if (defined($tok->{soundex}));
  $$bufr .= "\t[koeln] $tok->{koeln}"         if (defined($tok->{koeln}));
  $$bufr .= "\t[metaphone] $tok->{metaphone}" if (defined($tok->{metaphone}));

  ##-- Phonetic Equivalents ('eqpho')
  $$bufr .= join('', map { "\t[eqpho] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_) } grep {defined($_)} @{$tok->{eqpho}})
    if ($tok->{eqpho});

  ##-- Known Phonetic Equivalents ('eqphox')
  $$bufr .= join('', map { "\t[eqphox] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_) } grep {defined($_)} @{$tok->{eqphox}})
    if ($tok->{eqphox});

  ##-- Morph ('morph')
  if ($tok->{morph}) {
    $$bufr .= join('',
		 map {("\t[morph] "
		       .(defined($_->{lo}) ? "$_->{lo} : " : '')
		       .(defined($_->{lemma}) ? "$_->{lemma} @ " : '')
		       ."$_->{hi} <$_->{w}>")
		    } @{$tok->{morph}});
  }

  ##-- Morph::Latin ('morph/lat')
  $$bufr .= join('', map { "\t[morph/lat] ".(defined($_->{lo}) ? "$_->{lo} : " : '')."$_->{hi} <$_->{w}>" } @{$tok->{mlatin}})
    if ($tok->{mlatin});

  ##-- MorphSafe ('morph/safe')
  $$bufr .= "\t[morph/safe] ".($tok->{msafe} ? 1 : 0) if (exists($tok->{msafe}));

  ##-- Rewrites + analyses
  $$bufr .= join('',
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
  $$bufr .= join('', map { "\t[eqrw] ".(ref($_) ? "$_->{hi} <$_->{w}>" : $_) } grep {defined($_)} @{$tok->{eqrw}})
    if ($tok->{eqrw});

  ##-- dmoot
  if ($tok->{dmoot}) {
    ##-- dmoot/tag
    $$bufr .= "\t[dmoot/tag] $tok->{dmoot}{tag}";

    ##-- dmoot/morph
    $$bufr .= join('', map {("\t[dmoot/morph] "
			   .(defined($_->{lo}) ? "$_->{lo} : " : '')
			   .(defined($_->{lemma}) ? "$_->{lemma} @ " : '')
			   ."$_->{hi} <$_->{w}>"
			  )} @{$tok->{dmoot}{morph}})
      if ($tok->{dmoot}{morph});

    ##-- dmoot/analyses
    $$bufr .= join('', map {"\t[dmoot/analysis] $_->{tag} ~ $_->{details} <".($_->{prob}||$_->{cost}||0).">"} @{$tok->{dmoot}{analyses}})
      if ($tok->{dmoot}{analyses});
  }

  ##-- moot
  if ($tok->{moot}) {
    ##-- moot/word
    $$bufr .= "\t[moot/word] $tok->{moot}{word}" if (defined($tok->{moot}{word}));

    ##-- moot/tag
    $$bufr .= "\t[moot/tag] $tok->{moot}{tag}";

    ##-- moot/lemma
    $$bufr .= "\t[moot/lemma] $tok->{moot}{lemma}" if (defined($tok->{moot}{lemma}));

    ##-- moot/morph (UNUSED)
    $$bufr .= join('', map {("\t[moot/morph] "
			   .(defined($_->{lo}) ? "$_->{lo} : " : '')
			   .(defined($_->{lemma}) ? "$_->{lemma} @ " : '')
			   ."$_->{hi} <$_->{w}>"
			  )} @{$tok->{moot}{morph}})
      if ($tok->{moot}{morph});

    ##-- moot/analyses
    $$bufr .= join('', map {("\t[moot/analysis] $_->{tag}"
			   .(defined($_->{lemma}) ? " \@ $_->{lemma}" : '')
			   ." ~ $_->{details} <".($_->{prob}||$_->{cost}||0).">"
			  )} @{$tok->{moot}{analyses}})
      if ($tok->{moot}{analyses});
  }

  ##-- lemma equivalents
  $$bufr .= join('', map {("\t[eqlemma] "
			 .(defined($_->{lo}) ? "$_->{lo} : " : '')
			 .$_->{hi}
			 .(defined($_->{w}) ? " <$_->{w}>" : '')
			)} grep {defined($_)} @{$tok->{eqlemma}})
    if ($tok->{eqlemma});


  ##-- unparsed fields (pass-through)
  if ($tok->{other}) {
    my ($name);
    $$bufr .= ("\t"
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

  ##-- return
  $$bufr .= "\n";
  return $bufr;
}

## $fmt = $fmt->putToken($tok)
## $fmt = $fmt->putToken($tok,\$buf)
sub putToken {
  $_[0]{fh}->print(${$_[0]->token2buf(@_[1..$#_])});
  return $_[0];
}

## $fmt = $fmt->putSentence($sent)
## $fmt = $fmt->putSentence($sent,\$buf)
##  + concatenates formatted tokens, adding sentence-id comment if available
sub putSentence {
  my ($fmt,$sent,$bufr) = @_;
  $bufr = \(my $buf='') if (!defined($bufr));
  $fmt->{fh}->print(join('', map {"%%$_\n"} map {split(/\n/,$_)} @{$sent->{_cmts}})) if ($sent->{_cmts});
  $fmt->{fh}->print("%% Sentence $sent->{id}\n") if (defined($sent->{id}));
  $fmt->putToken($_,$bufr) foreach (@{toSentence($sent)->{tokens}});
  $fmt->{fh}->print("\n");
  return $fmt;
}

## $fmt = $fmt->putDocument($doc)
## $fmt = $fmt->putDocument($doc,\$buf)
##  + concatenates formatted sentences, adding document 'xmlbase' comment if available
sub putDocument {
  my ($fmt,$doc,$bufr) = @_;
  $bufr = \(my $buf='') if (!defined($bufr));
  $fmt->{fh}->print(join('', map {"%%$_\n"} map {split(/\n/,$_)} @{$doc->{_cmts}})) if ($doc->{_cmts});
  $fmt->{fh}->print("%% base=$doc->{base}\n\n") if (defined($doc->{base}));
  $fmt->putSentence($_,$bufr) foreach (@{toDocument($doc)->{body}});
  return $fmt;
}

## $fmt = $fmt->putData($data)
##  + puts raw data (uses forceDocument())
sub putData {
  $_[0]->putDocument($_[0]->forceDocument($_[1]));
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
