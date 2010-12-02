##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::Directory.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP::Handler class: Directory
##======================================================================

package DTA::CAB::Server::HTTP::Handler::Directory;
use DTA::CAB::Server::HTTP::Handler;
use HTTP::Status;
use Carp;
use strict;

our @ISA = qw(DTA::CAB::Server::HTTP::Handler);

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'DTA::CAB::Server::HTTP::Handler::directory'=>__PACKAGE__,
						 'DTA::CAB::Server::HTTP::Handler::dir'=>__PACKAGE__,
						 'DTA::CAB::Server::HTTP::Handler::Dir'=>__PACKAGE__,
						 'directory' => __PACKAGE__,
						 'dir' => __PACKAGE__,
						 'Dir' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## Methods

## $h = $class_or_obj->new(%options)
##  + options:
##     dir => $baseDirectory,  ##-- default='.'
##     logLevel => $level,     ##-- debug log level (defaul=undef (none))
sub new {
  my $that = shift;
  my $h =  bless { dir=>'.', @_ }, ref($that)||$that;
  $h->{dir} =~ s|/$||g;
  return $h;
}

## $bool = $h->prepare($server)
sub prepare { return (-d $_[0]{dir} && -r $_[0]{dir}); }

## $rsp = $h->run($server, $localPath, $clientConn, $httpRequest)
sub run {
  my ($h,$srv,$path,$csock,$hreq) = @_;
  my $path_matched = $path;
  my $path_full    = $hreq->uri->path();
  my $file         = $path_full;
  $file            =~ s/^\Q$path_matched\E\/?//;
  $file            = $h->{dir}.'/'.$file;
  $h->vlog($h->{logLevel}, "run(", $csock->peerhost, "): file=$file");
  return $h->error($csock,(-e $file ? RC_FORBIDDEN : RC_NOT_FOUND)) if (!-r $file);
  $csock->send_file_response($file);
  $csock->shutdown(2);
  return undef;
}

1; ##-- be happy
