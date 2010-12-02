##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::File.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP::Handler class: static files
##======================================================================

package DTA::CAB::Server::HTTP::Handler::File;
use DTA::CAB::Server::HTTP::Handler;
use HTTP::Status;
use Carp;
use strict;

our @ISA = qw(DTA::CAB::Server::HTTP::Handler);

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'DTA::CAB::Server::Server::HTTP::Handler::file' => __PACKAGE__,
						 'file' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## $h = $class_or_obj->new(%options)
##  + options:
##     contentType => $mimeType,    ##-- default: text/plain
##     file => $filename,           ##-- filename to return
sub new {
  my $that = shift;
  return bless { file=>'', contentType=>'text/plain', @_ }, ref($that)||$that;
}

## $bool = $obj->prepare($srv)
sub prepare { return (-r $_[0]{file}); }

## $rsp = $h->run($server, $localPath, $clientConn, $httpRequest)
sub run {
  my ($h,$srv,$path,$csock,$hreq) = @_;
  return $h->error($csock,(-e $h->{file} ? RC_FORBIDDEN : RC_NOT_FOUND)) if (!-r $h->{file});

  $csock->send_file_response($h->{file});
  $csock->shutdown(2);
  return undef;
}


1; ##-- be happy
