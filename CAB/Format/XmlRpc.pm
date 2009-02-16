## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlRpc.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: XML-RPC using RPC::XML

package DTA::CAB::Format::XmlRpc;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Datum ':all';
use RPC::XML;
use RPC::XML::Parser;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlCommon);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- input
##     rxprs  => $rpc_parser,      ##-- RPC::XML::Parser object
##     rxdata => $rpc_data,        ##-- structured data as decoded by RPC::XML::Parser
##
##     ##-- output
##     docbuf => $doc,             ##-- DTA::CAB::Document output buffer
##     xprs   => $xml_parser,      ##-- XML::LibXML parser object
##     level  => $formatLevel,     ##-- format level
##     encoding => $encoding,      ##-- output encoding
##
##     ##-- common
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input
		   rxprs => RPC::XML::Parser->new(),
		   #rxdata => undef,

		   ##-- output
		   docbuf   => DTA::CAB::Document->new(),
		   encoding => 'UTF-8',
		   level    => 0,
		   #xprs => XML::LibXML->new, (inherited from XmlCommon)
		   #xdoc => undef, (inherited from XmlCommon)

		   ##-- common
		   #(none)

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
  return qw(rxprs rxdata docbuf xprs);
}


##==============================================================================
## Methods: Parsing
##==============================================================================

##--------------------------------------------------------------
## Methods: Parsing: Input selection

## $fmt = $fmt->close()
##  + close current input source, if any
sub close {
  delete($_[0]{rxdata});
  return $_[0];
}

## $fmt = $fmt->fromString($string)
sub fromString {
  my $fmt = shift;
  $fmt->close;
  $fmt->{rxdata} = $fmt->{rxprs}->parse($_[0]);
  return $fmt->checkData();
}

## $fmt = $fmt->fromFile($filename_or_handle)
sub fromFile { return $_[0]->DTA::CAB::Format::fromFile(@_[1..$#_]); }

## $fmt = $fmt->fromFh($handle)
sub fromFh {
  my ($fmt,$fh) = @_;
  $fmt->close;
  $fmt->{rxdata} = $fmt->{rxprs}->parse($fh);
  return $fmt->checkData();
}

## $fmt_or_undef = $fmt->checkData()
##  + check for valid parse
sub checkData {
  my $fmt = shift;
  if (!defined($fmt->{rxdata})) {
    $fmt->logwarn("checkData(): no parse data {rxdata} defined");
    return undef;
  }
  elsif (!ref($fmt->{rxdata})) {
    $fmt->logwarn("checkData(): parse error: $fmt->{rxdata}");
    return undef;
  }
  elsif ($fmt->{rxdata}->is_fault) {
    $fmt->logwarn("checkData(): fault: (".$fmt->{rxdata}->code.") ".$fmt->{rxdata}->string);
    return undef;
  }
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Parsing: Generic API

sub parseDocument {
  my $fmt = shift;
  if (!defined($fmt->{rxdata})) {
    $fmt->logconfess("parseDocument(): no source data {rxdata} defined!");
    return undef;
  }
  my $doc = $fmt->forceDocument($fmt->{rxdata}->value);

  ##-- force doc refs, deep
  if (UNIVERSAL::isa($doc,'DTA::CAB::Document')) {
    @{$doc->{body}} = map { toSentence($_) } @{$doc->{body}};
    foreach (@{$doc->{body}}) {
      @{$_->{tokens}} = map { toToken($_) } @{$_->{tokens}};
    }
  }

  return $doc;
}

##==============================================================================
## Methods: Formatting
##==============================================================================


##--------------------------------------------------------------
## Methods: Formatting: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  $_[0]{docbuf} = DTA::CAB::Document->new();
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output in $fmt->{docbuf} to byte-string (using Storable::freeze())
sub toString {
  my ($fmt,$level) = @_;
  my $rpcobj = RPC::XML::smart_encode( $fmt->{docbuf} );
  $level     = $fmt->{level} if (!defined($level));
  return (defined($level) && $level>0
	  ? $fmt->rpcXmlDocument($rpcobj)->toString($level)
	  : encode($fmt->{encoding}, $rpcobj->as_string));
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
sub toFh {
  my ($fmt,$fh,$level) = @_;
  my $rpcobj = RPC::XML::smart_encode( $fmt->{docbuf} );
  $level     = $fmt->{level} if (!defined($level));
  $fmt->rpcXmlDocument($rpcobj)->toFH($fh,$level);
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Formatting: Local

## $parser = $fmt->xmlParser()
sub xmlParser {
  return $_[0]{xprs} if ($_[0]{xprs});
  return $_[0]{xprs} = XML::LibXML->new();
}

## $xmldoc = $fmt->rpcXmlDocument($rpcobj_or_string)
sub rpcXmlDocument {
  return $_[0]->xmlParser->parse_string( ref($_[1]) ? $_[1]->as_string : $_[1] );
}

##--------------------------------------------------------------
## Methods: Formatting: Recommended API

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
## Methods: Formatting: Required API

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


1; ##-- be happy

__END__
