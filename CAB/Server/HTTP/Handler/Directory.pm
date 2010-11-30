##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::dummy.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
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

## $handler = $class_or_obj->new(%options)
##  + options:
##     dir => $baseDirectory,  ##-- default='.'
##     logLevel => $level,     ##-- debug log level (defaul=undef (none))
sub new {
  my $that = shift;
  my $handler =  bless { dir=>'.', @_ }, ref($that)||$that;
  $handler->{dir} =~ s|/$||g;
  return $handler;
}

## $bool = $handler->prepare($server)
sub prepare { return (-d $_[0]{dir} && -r $_[0]{dir}); }

## $rc = $handler->run($server, $localPath, $clientSocket, $httpRequest)
sub run {
  my ($handler,$srv,$path,$csock,$hreq) = @_;
  my $path_matched = $path;
  my $path_full    = $hreq->uri->path();
  my $file         = $path_full;
  $file            =~ s/^\Q$path_matched\E\/?//;
  $file            = $handler->{dir}.'/'.$file;
  $handler->vlog($handler->{logLevel}, "run(", $csock->peerhost, "): file=$file");
  if (!-r $file) {
    $srv->clientError($csock,RC_NOT_FOUND);
    return 1;
  }
  $csock->send_file_response($file);
  return 1;
}

1; ##-- be happy
