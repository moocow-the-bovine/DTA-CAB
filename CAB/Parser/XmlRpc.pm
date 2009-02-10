## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser::XmlRpc.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: XML-RPC using RPC::XML

package DTA::CAB::Parser::XmlRpc;
use DTA::CAB::Parser;
use DTA::CAB::Parser::XmlCommon;
use DTA::CAB::Datum ':all';
use RPC::XML;
use RPC::XML::Parser;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Parser);

##==============================================================================
## Constructors etc.
##==============================================================================

## $prs = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
sub new {
  my $that = shift;
  my $prs = bless({
		   ##-- encoding (should be handled by RPC::XML::Parser stuff?)

		   ##-- RPC::XML parse
		   xprs => RPC::XML::Parser->new(),

		   ##-- parsed data
		   #xdata => undef,

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $prs;
}

##==============================================================================
## Methods: Persistence
##  + see Parser
##==============================================================================

##=============================================================================
## Methods: Parsing: Input selection
##  + see Parser
##==============================================================================

## $prs = $prs->close()
##  + close current input source, if any
sub close {
  delete($_[0]{xdata});
  return $_[0];
}

## $prs = $prs->fromString($string)
sub fromString {
  my $prs = shift;
  $prs->close;
  $prs->{xdata} = $prs->{xprs}->parse(shift);
  return $prs->checkData();
}

## $prs = $prs->fromFile($filename_or_handle)
##  + default calls $prs->fromFh()

## $prs = $prs->fromFh($handle)
sub fromFh {
  my ($prs,$fh) = @_;
  $prs->close;
  $prs->{xdata} = $prs->{xprs}->parse($fh);
  return $prs->checkData();
}

## $prs_or_undef = $prs->checkData()
##  + check for valid parse
sub checkData {
  my $prs = shift;
  if (!defined($prs->{xdata})) {
    $prs->logwarn("checkData(): no parse data {xdata} defined");
    return undef;
  }
  elsif (!ref($prs->{xdata})) {
    $prs->logwarn("checkData(): parse error: $prs->{xdata}");
    return undef;
  }
  elsif ($prs->{xdata}->is_fault) {
    $prs->logwarn("checkData(): fault: (".$prs->{xdata}->code.") ".$prs->{xdata}->string);
    return undef;
  }
  return $prs;
}

##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

sub parseDocument {
  my $prs = shift;
  if (!defined($prs->{xdata})) {
    $prs->logconfess("parseDocument(): no source data {xdata} defined!");
    return undef;
  }
  my $doc = $prs->forceDocument($prs->{xdata}->value);

  ##-- force doc refs, deep
  if (UNIVERSAL::isa($doc,'DTA::CAB::Document')) {
    @{$doc->{body}} = map { toSentence($_) } @{$doc->{body}};
    foreach (@{$doc->{body}}) {
      @{$_->{tokens}} = map { toToken($_) } @{$_->{tokens}};
    }
  }
  return $doc;
}

1; ##-- be happy

__END__
