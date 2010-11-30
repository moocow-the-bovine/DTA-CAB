##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::Builtin.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP::Handler: built-in classes
##======================================================================

package DTA::CAB::Server::HTTP::Handler::Builtin;
use strict;

use DTA::CAB::Server::HTTP::Handler;
use DTA::CAB::Server::HTTP::Handler::File;
use DTA::CAB::Server::HTTP::Handler::Directory;
use DTA::CAB::Server::HTTP::Handler::Response;
use DTA::CAB::Server::HTTP::Handler::CGI;

1; ##-- be happy
