#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Server::XmlRpc;
use Encode qw(encode decode);

BEGIN {
  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
  binmode(STDIN, ':utf8');
  binmode(STDOUT,':utf8');
  binmode(STDERR,':utf8');
}

##-- load server object
our $srv = DTA::CAB::Server::XmlRpc->loadPerlFile("cab-server-xmlrpc.PL");
$srv->prepare();
$srv->run();
print "$0: all done\n";
