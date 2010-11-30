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
## $uri = $class_or_obj->new(%options)
##  + options:
##     contentType => $mimeType,    ##-- default: text/plain
##     file => $filename,           ##-- filename to return
sub new {
  my $that = shift;
  return bless { file=>'', contentType=>'text/plain', @_ }, ref($that)||$that;
}

## $bool = $obj->prepare($srv)
sub prepare { return (-r $_[0]{file}); }

## $rc = $uri->run($server, $localPath, $clientSocket)
sub run {
  my ($uri,$srv,$path,$csock) = @_;
  if (!-r $uri->{file}) {
    $srv->clientError($csock,RC_NOT_FOUND);
    return 1;
  }
  my $ioh  = IO::File->new("<$uri->{file}");
  my ($data);
  {
    local $/ = undef;
    $data = <$ioh>;
  }
  $ioh->close;
  $csock->send_response(RC_OK,
			undef,
			HTTP::Headers->new(
					   'Content-Type'=>$uri->{contentType},
					  ),
			$data
		       );
  return 0;
}


1; ##-- be happy
