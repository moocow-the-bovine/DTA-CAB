##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description:
##  + abstract handler API class for DTA::CAB::Server::HTTP
##======================================================================

package DTA::CAB::Server::HTTP::Handler;
use HTTP::Status;
use DTA::CAB::Logger;
use UNIVERSAL qw(isa);
use strict;

our @ISA = qw(DTA::CAB::Logger);

##======================================================================
## API
##======================================================================

## $handler = $class_or_obj->new(%options)
sub new {
  my $that = shift;
  return bless { @_ }, ref($that)||$that;
}

## $bool = $handler->prepare($server,$path)
sub prepare { return 1; }

## $bool = $path->run($server, $localPath, $clientSocket, $httpRequest)
##  + local processing
sub run {
  my ($handler,$srv,$path,$csock,$hreq) = @_;
  $srv->clientError($csock, RC_INTERNAL_SERVER_ERROR, (ref($handler)||$handler), "::run() method not implemented");
  return 1;
}

##======================================================================
## URI class aliases (for derived classes)
##======================================================================

## %ALIAS = ($aliasName => $className, ...)
our (%ALIAS);

## undef = DTA::CAB::Server::HTTP::Handler->registerAlias($aliasName=>$fqClassName, ...)
sub registerAlias {
  shift; ##-- ignore class argument
  my (%alias) = @_;
  @ALIAS{keys(%alias)} = values(%alias);
}

## $className_or_undef = DTA::CAB::Server::HTTP::Handler->fqClass($alias_or_class_suffix)
sub fqClass {
  my $alias = $_[1]; ##-- ignore class argument

  ##-- Case 0: $alias wasn't defined in the first place: use empty string
  $alias = '' if (!defined($alias));

  ##-- Case 1: $alias is already fully qualified
  return $alias if (isa($alias,'DTA::CAB::Server::HTTP::Handler'));

  ##-- Case 2: $alias is a registered alias: recurse
  return $_[0]->fqClass($ALIAS{$alias}) if (defined($ALIAS{$alias}) && $ALIAS{$alias} ne $alias);

  ##-- Case 2: $alias is a valid "DTA::CAB::Server::HTTP::Handler::" suffix
  return "DTA::CAB::Server::HTTP::Handler::${alias}" if (isa("DTA::CAB::Server::HTTP::Handler::${alias}", 'DTA::CAB::Server::HTTP::Handler'));

  ##-- default: return undef
  return undef;
}

##======================================================================
## Local package aliases
##======================================================================
BEGIN {
  __PACKAGE__->registerAlias(
			     'DTA::CAB::Server::HTTP::Handler::base' => __PACKAGE__,
			     'base' => __PACKAGE__,
			    );
}

1; ##-- be happy
