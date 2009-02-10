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
			   xargs => {
				     compress_requests => 0,    ##-- send compressed requests?
				     compress_thresh   => 8192, ##-- byte limit for compressed requests
				     ##
				     message_file_thresh => 0,  ##-- disable file-based message spooling
				    },
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
  $cli->{xcli} = RPC::XML::Client->new($cli->{serverURL}, %{$cli->{xargs}})
    or $cli->logdie("could not create underlying RPC::XML::Client: $!");
  $cli->{xcli}->message_file_thresh(0)
    if (defined($cli->{xargs}{message_file_thresh}) && !$cli->{xargs}{message_file_thresh});
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
## $rsp_or_error = $cli->request($req, $doDeepEncoding=1)
##  + send XML-RPC request, log if error occurs
sub request {
  my ($cli,$req,$doRecode) = @_;

  ##-- cache RPC::XML encoding
  $doRecode   = 1 if (!defined($doRecode));
  my $enc_tmp = $RPC::XML::ENCODING;
  $RPC::XML::ENCODING = $cli->{serverEncoding};

  $cli->connect() if (!$cli->{xcli});
  $req = DTA::CAB::Utils::deep_encode($cli->{serverEncoding}, $req) if ($doRecode);
  my $rsp = $cli->{xcli}->send_request( $req );
  if (!ref($rsp)) {
    $cli->error("RPC::XML::Client::send_request() failed:");
    $cli->error($rsp);
  }
  elsif ($rsp->is_fault) {
    $cli->error("XML-RPC fault (".$rsp->code.") ".$rsp->string);
  }

  ##-- cleanup & return
  $RPC::XML::ENCODING = $enc_tmp;
  return $doRecode ? DTA::CAB::Utils::deep_decode($cli->{serverEncoding},$rsp) : $rsp;
}


##==============================================================================
## Methods: Generic Client API: Queries
##==============================================================================

## $req = $cli->newRequest($methodName, @args)
##  + returns new RPC::XML::request
##  + encodes all elementary data types as strings
sub newRequest {
  my ($cli,$method,@args) = @_;
  my $str_tmp = $RPC::XML::FORCE_STRING_ENCODING;
  $RPC::XML::FORCE_STRING_ENCODING = 1;
  my $req = RPC::XML::request->new($method,@args);
  $RPC::XML::FORCE_STRING_ENCODING = $str_tmp;
  return $req;
}

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my ($cli,$aname,$tok,$opts) = @_;
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeToken",
					   $tok,
					   (defined($opts) ? $opts : qw())
					  ));
  return ref($rsp) && !$rsp->is_fault ? toToken($rsp->value) : $rsp;
}

## $sent = $cli->analyzeSentence($analyzer, $sent, \%opts)
sub analyzeSentence {
  my ($cli,$aname,$sent,$opts) = @_;
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeSentence",
					   $sent,
					   (defined($opts) ? $opts : qw())
					  ));
  return ref($rsp) && !$rsp->is_fault ? toSentence($rsp->value) : $rsp;
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my ($cli,$aname,$doc,$opts) = @_;
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeDocument",
					   $doc,
					   (defined($opts) ? $opts : qw())
					  ));
  return ref($rsp) && !$rsp->is_fault ? toDocument($rsp->value) : $rsp;
}

## $data_str = $cli->analyzeRaw($analyzer, $input_str, \%opts)
sub analyzeData {
  my ($cli,$aname,$data,$opts) = @_;
  my $rsp = $cli->request($cli->newRequest("$aname.analyzeData",
					   RPC::XML::base64->new($data),
					   (defined($opts) ? $opts : qw())
					  ),
			  #0 ##-- no deep recode
			 );
  return ref($rsp) && !$rsp->is_fault ? $rsp->value : $rsp;
}


1; ##-- be happy

__END__
