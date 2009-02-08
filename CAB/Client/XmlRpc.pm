## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Client::XmlRpc.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA::CAB XML-RPC server clients

package DTA::CAB::Client::XmlRpc;
use DTA::CAB;
use DTA::CAB::Client;
use RPC::XML;
use RPC::XML::Client;
use DTA::CAB::Datum ':all';
use DTA::CAB::Utils ':all';
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Client);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- server
##     serverURL => $url,             ##-- default: localhost:8000
##     serverEncoding => $encoding,   ##-- default: UTF-8
##
##     ##-- underlying RPC::XML client
##     xcli => $xcli,                 ##-- RPC::XML::Client object
##    }
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- server
			   serverURL      => 'http://localhost:8000',
			   serverEncoding => 'UTF-8', ##-- default server encoding
			   ##
			   ##-- RPC::XML stuff
			   xcli => undef,
			   ##
			   ##-- user args
			   @_,
			  );
}

##==============================================================================
## Methods: Generic Client API: Connections
##==============================================================================

## $bool = $cli->connected()
sub connected { return $_[0]{xcli} ? 1 : 0; }

## $bool = $cli->connect()
##  + establish connection
sub connect {
  my $cli = shift;
  $cli->{xcli} = RPC::XML::Client->new($cli->{serverURL})
    or $cli->logdie("could not create underlying RPC::XML::Client: $!");
  return 1;
}

## $bool = $cli->disconnect()
sub disconnect {
  my $cli = shift;
  delete($cli->{xcli});
  return 1;
}

## @analyzers = $cli->analyzers()
sub analyzers {
  my $rsp = $_[0]->request( RPC::XML::request->new('dta.cab.listAnalyzers') );
  return ref($rsp) && !$rsp->is_fault ? @{ $rsp->value } : $rsp;
}

##==============================================================================
## Methods: Utils
##==============================================================================

## $rsp_or_error = $cli->request($req)
##  + send XML-RPC request, log if error occurs
sub request {
  my ($cli,$req) = @_;
  $cli->connect() if (!$cli->{xcli});
  my $tmp = $RPC::XML::ENCODING;
  $RPC::XML::ENCODING = $cli->{serverEncoding};
  my $rsp = $cli->{xcli}->send_request( DTA::CAB::Utils::deep_encode($cli->{serverEncoding}, $req) );
  if (!ref($rsp)) {
    $cli->error("RPC::XML::Client::send_request() failed: $rsp");
  }
  elsif ($rsp->is_fault) {
    $cli->error("XML-RPC fault (".$rsp->code.") ".$rsp->string);
  }
  $RPC::XML::ENCODING = $tmp;
  return DTA::CAB::Utils::deep_decode($cli->{serverEncoding},$rsp);
}

##==============================================================================
## Methods: Generic Client API: Queries
##==============================================================================

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my ($cli,$aname,$tok,$opts) = @_;
  my $rsp = $cli->request(RPC::XML::request->new("$aname.analyzeToken",
						 $tok,
						 #$opts,
						));
  return ref($rsp) && !$rsp->is_fault ? toToken($rsp->value) : $rsp;
}

## $sent = $cli->analyzeSentence($analyzer, $sent, \%opts)
sub analyzeSentence {
  my ($cli,$aname,$sent,$opts) = @_;
  my $rsp = $cli->request(RPC::XML::request->new("$aname.analyzeSentence",
						 $sent,
						 #$opts,
						));
  return ref($rsp) && !$rsp->is_fault ? toSentence($rsp->value) : $rsp;
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my ($cli,$aname,$doc,$opts) = @_;
  my $rsp = $cli->request(RPC::XML::request->new("$aname.analyzeDocument",
						 $doc,
						 #$opts,
						));
  return ref($rsp) && $rsp->is_fault ? toDocument($rsp->value) : $rsp;
}


1; ##-- be happy

__END__
