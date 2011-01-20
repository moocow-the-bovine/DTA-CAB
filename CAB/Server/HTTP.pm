## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Server::HTTP.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: DTA::CAB standalone HTTP server using HTTP::Daemon

package DTA::CAB::Server::HTTP;
use DTA::CAB::Server;
use DTA::CAB::Server::HTTP::Handler::Builtin;
use HTTP::Daemon;
use HTTP::Status;
use POSIX ':sys_wait_h';
use Encode qw(encode decode);
use Socket qw(SOMAXCONN);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Server);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- Underlying HTTP::Daemon server
##     daemonMode => $daemonMode,    ##-- one of 'serial', 'fork', 'xmlrpc' [default='serial']
##     daemonArgs => \%daemonArgs,   ##-- args to HTTP::Daemon->new()
##     paths      => \%path2handler, ##-- maps local URL paths to configs
##     daemon     => $daemon,        ##-- underlying HTTP::Daemon object
##     cxsrv      => $cxsrv,         ##-- associated DTA::CAB::Server::XmlRpc object for XML-RPC handlers
##     ##
##     ##-- security
##     allowUserOptions => $bool, ##-- allow user options? (default: true)
##     allow => \@allow_ip_regexes, ##-- allow queries from these clients (default=none)
##     deny  => \@deny_ip_regexes,  ##-- deny queries from these clients (default=none)
##     _allow => $allow_ip_regex,   ##-- single allow regex (compiled by 'prepare()')
##     _deny  => $deny_ip_regex,    ##-- single deny regex (compiled by 'prepare()')
##     ##
##     ##-- logging
##     logAttempt => $level,        ##-- log connection attempts at $level (default=undef: none)
##     logConnect => $level,        ##-- log successful connections (client IP and requested path) at $level (default='debug')
##     logRquestData => $level,     ##-- log full client request data at $level (default=undef: none)
##     logClientError => $level,    ##-- log errors to client at $level (default='debug')
##     logClose => $level,          ##-- log close client connections (default=undef: none)
##     ##
##     ##-- (inherited from DTA::CAB::Server)
##     as  => \%analyzers,    ##-- ($name=>$cab_analyzer_obj, ...)
##     aos => \%anlOptions,   ##-- ($name=>\%analyzeOptions, ...) : %opts passed to $anl->analyzeXYZ($xyz,%opts)
##    }
##
## + path handlers:
##   - object descended from DTA::CAB::Server::HTTP::Handler
##   - or HASH ref  { class=>$subclass, %classNewArgs }
##   - or ARRAY ref [        $subclass, @classNewArgs ]
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- underlying server
			   daemon => undef,
			   daemonArgs => {
					  LocalPort=>8088,
					  ReuseAddr=>1,
					 },
			   #cxsrv => undef,

			   ##-- path config
			   paths => {},

			   ##-- security
			   allowUserOptions => 1,
			   allow => [],
			   deny  => [],
			   _allow => undef,
			   _deny  => undef,

			   ##-- logging
			   logAttempt => undef,
			   logConnect => 'debug',
			   logRequestData => undef,
			   logClose => undef,
			   logClientError => 'trace',

			   ##-- user args
			   @_
			  );
}

## undef = $obj->initialize()
##  + called to initialize new objects after new()

##==============================================================================
## Methods: Generic Server API
##==============================================================================

## $rc = $srv->prepareLocal()
##  + subclass-local initialization
sub prepareLocal {
  my $srv = shift;

  ##-- setup HTTP::Daemon object
  if (!($srv->{daemon}=HTTP::Daemon->new(%{$srv->{daemonArgs}}))) {
    $srv->logconfess("could not create HTTP::Daemon object: $!");
  }
  my $daemon = $srv->{daemon};

  ##-- register path handlers
  my ($path,$ph);
  while (($path,$ph)=each %{$srv->{paths}}) {
    $srv->registerPathHandler($path,$ph)
      or $srv->logconfess("registerPathHandler() failed for path '$path': $!");
  }

  ##-- compile allow/deny regexes
  foreach my $policy (qw(allow deny)) {
    my $re = $srv->{$policy} && @{$srv->{$policy}} ? join('|', map {"(?:$_)"} @{$srv->{$policy}}) : '^$';
    $srv->{"_".$policy} = qr/$re/;
  }

  return 1;
}

## $rc = $srv->run()
##  + run the server
sub run {
  my $srv = shift;
  $srv->prepare() if (!$srv->{daemon}); ##-- sanity check
  $srv->logcroak("run(): no underlying HTTP::Daemon object!") if (!$srv->{daemon});

  my $daemon = $srv->{daemon};
  $srv->info("server starting on host ", $daemon->sockhost, ", port ", $daemon->sockport, "\n");

  my ($csock,$chost,$hreq,$handler,$localPath,$rsp);
  while (defined($csock=$daemon->accept)) {
    ##-- got client $csock (HTTP::Daemon::ClientConn object; see HTTP::Daemon(3pm))
    $chost = $csock->peerhost();

    ##-- access control
    $srv->vlog($srv->{logAttempt}, "attempted connect from client $chost");
    if (!$srv->clientAllowed($csock,$chost)) {
      $srv->denyClient($csock);
      next;
    }

    ##-- serve client: parse HTTP request
    $hreq = $csock->get_request();
    if (!$hreq) {
      $srv->clientError($csock, "could not parse HTTP request");
      next;
    }

    ##-- log basic request, and possibly request data
    $srv->vlog($srv->{logConnect}, "client $chost: ", $hreq->method, " ", $hreq->uri);
    $srv->vlog($srv->{logRequestData}, "client $chost: HTTP::Request={\n", $hreq->as_string, "}");

    ##-- map request to handler
    ($handler,$localPath) = $srv->getPathHandler($hreq->uri);
    if (!defined($handler)) {
      $srv->clientError($csock, RC_NOT_FOUND, "cannot resolve URI ", $hreq->uri);
      next;
    }

    ##-- pass request to handler
    eval {
      $rsp = $handler->run($srv,$localPath,$csock,$hreq);
    };
    if ($@) {
      $srv->clientError($csock,RC_INTERNAL_SERVER_ERROR,"handler ", (ref($handler)||$handler), "::run() died: $@");
      next;
    }
    elsif (!defined($rsp)) {
      $srv->clientError($csock,RC_INTERNAL_SERVER_ERROR,"handler ", (ref($handler)||$handler), "::run() failed");
      next;
    }

    ##-- ... and dump response to client
    $csock->send_response($rsp) if ($csock->opened);
  }
  continue {
    ##-- cleanup after client
    $srv->vlog($srv->{logClose}, "closing connection to client $chost");
    $csock->shutdown(2) if ($csock->opened);
    $handler->finish($srv,$csock) if (defined($handler));
    $hreq=$handler=$localPath=$rsp=undef;
  }


  $srv->info("server exiting\n");
  return $srv->finish();
}

##==============================================================================
## Methods: Local: Path Handlers

## $handler = $srv->registerPathHandler($pathStr, \%handlerSpec)
## $handler = $srv->registerPathHandler($pathStr, \@handlerSpec)
## $handler = $srv->registerPathHandler($pathStr, $handlerObject)
##  + registers a path handler for path $pathStr
##  + sets $srv->{paths}{$pathStr} = $handler
sub registerPathHandler {
  my ($srv,$path,$ph) = @_;

  if (ref($ph) && ref($ph) eq 'HASH') {
    ##-- HASH ref: implicitly parse
    my $class = DTA::CAB::Server::HTTP::Handler->fqClass($ph->{class});
    $srv->logconfess("unknown class '", ($ph->{class}||'??'), "' for path '$path'")
      if (!UNIVERSAL::isa($class,'DTA::CAB::Server::HTTP::Handler'));
    $ph = $class->new(%$ph);
  }
  elsif (ref($ph) && ref($ph) eq 'ARRAY') {
    ##-- ARRAY ref: implicitly parse
    my $class = DTA::CAB::Server::HTTP::Handler->fqClass($ph->[0]);
    $srv->logconfess("unknown class '", ($ph->[0]||'??'), "' for path '$path'")
      if (!UNIVERSAL::isa($class,'DTA::CAB::Server::HTTP::Handler'));
    $ph = $class->new(@$ph[1..$#$ph]);
  }

  ##-- prepare URI
  $ph->prepare($srv,$path)
    or $srv->logconfess("Path::prepare() failed for path string '$path'");

  return $srv->{paths}{$path} = $ph;
}


## ($handler,$localPath) = $srv->getPathHandler($hreq_uri)
sub getPathHandler {
  my ($srv,$uri) = @_;

  my @segs = $uri->canonical->path_segments;
  my ($i,$path,$handler);
  for ($i=$#segs; $i >= 0; $i--) {
    $path = join('/',@segs[0..$i]);
    return ($handler,$path) if (defined($handler=$srv->{paths}{$path}));
  }
  return ($handler,$path);
}



##==============================================================================
## Methods: Local: Access Control

## $bool = $srv->clientAllowed($clientSock)
##  + returns true iff $cli may access the server
sub clientAllowed {
  my ($srv,$csock,$chost) = @_;
  $chost = $csock->peerhost() if (!$chost);
  return ($chost =~ $srv->{_allow} || $chost !~ $srv->{_deny});
}

## undef = $srv->denyClient($clientSock)
## undef = $srv->denyClient($clientSock, $denyMessage)
##  + denies access to $client
##  + shuts down client socket
sub denyClient {
  my ($srv,$csock,@msg) = @_;
  my $chost = $csock->peerhost();
  @msg = "Access denied from client $chost" if (!@msg);
  $srv->clientError($csock, RC_FORBIDDEN, @msg);
}

##======================================================================
## Methods: Local: error handling

## undef = $srv->clientError($clientSock,$status,@message)
##  + send an error message to the client
##  + $status defaults to RC_INTERNAL_SERVER_ERROR
##  + shuts down the client socket
sub clientError {
  my ($srv,$csock,$status,@msg) = @_;
  if ($csock->opened) {
    my $chost = $csock->peerhost();
    my $msg   = join('',@msg);
    $status   = RC_INTERNAL_SERVER_ERROR if (!defined($status));
    $srv->vlog($srv->{logClientError}, "clientError($chost): $msg");
    {
      my $_warn=$^W;
      $^W=0;
      $csock->send_error($status, $msg);
      $^W=$_warn;
    }
    $csock->shutdown(2);
  }
  $csock->close() if (UNIVERSAL::can($csock,'close'));
  $@ = undef;     ##-- unset eval error
  return undef;
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Server::HTTP - DTA::CAB standalone HTTP server using HTTP::Daemon

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Server::HTTP;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 
 ##========================================================================
 ## Methods: Generic Server API
 
 $rc = $srv->prepareLocal();
 $rc = $srv->run();
 
 ##========================================================================
 ## Methods: Local: Path Handlers
 
 $handler = $srv->registerPathHandler($pathStr, \%handlerSpec);
 ($handler,$localPath) = $srv->getPathHandler($hreq_uri);
 
 ##========================================================================
 ## Methods: Local: Access Control
 
 $bool = $srv->clientAllowed($clientSock);
 undef = $srv->denyClient($clientSock);
 
 ##========================================================================
 ## Methods: Local: error handling
 
 undef = $srv->clientError($clientSock,$status,@message);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

L<DTA::CAB::Server::HTTP|DTA::CAB::Server::HTTP>
inherits from
L<DTA::CAB::Server|DTA::CAB::Server>,
and supports the L<DTA::CAB::Server|DTA::CAB::Server> API.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $srv = CLASS_OR_OBJ->new(%args);

=over 4

=item Arguments and Object Structure:

 (
  ##-- Underlying HTTP::Daemon server
  daemonMode => $daemonMode,    ##-- one of 'serial', 'fork', 'xmlrpc' [default='serial']
  daemonArgs => \%daemonArgs,   ##-- args to HTTP::Daemon->new()
  paths      => \%path2handler, ##-- maps local URL paths to handlers
  daemon     => $daemon,        ##-- underlying HTTP::Daemon object
  cxsrv      => $cxsrv,         ##-- associated DTA::CAB::Server::XmlRpc object (for XML-RPC handlers)
  ##
  ##-- security
  #allowUserOptions => $bool,   ##-- allow client-specified analysis options? (default: true)
  allow => \@allow_ip_regexes, ##-- allow queries from these clients (default=none)
  deny  => \@deny_ip_regexes,  ##-- deny queries from these clients (default=none)
  _allow => $allow_ip_regex,   ##-- single allow regex (compiled by 'prepare()')
  _deny  => $deny_ip_regex,    ##-- single deny regex (compiled by 'prepare()')
  ##
  ##-- logging
  logAttempt => $level,        ##-- log connection attempts at $level (default=undef: none)
  logConnect => $level,        ##-- log successful connections (client IP and requested path) at $level (default='debug')
  logRquestData => $level,     ##-- log full client request data at $level (default=undef: none)
  logClientError => $level,    ##-- log errors to client at $level (default='debug')
  logClose => $level,          ##-- log close client connections (default=undef: none)
  ##
  ##-- (inherited from DTA::CAB::Server)
  as  => \%analyzers,    ##-- ($name=>$cab_analyzer_obj, ...)
  aos => \%anlOptions,   ##-- ($name=>\%analyzeOptions, ...) : %opts passed to $anl->analyzeXYZ($xyz,%opts)
 )

=item path handlers:

Each path handler specified in $opts{paths} should be one of the following:

=over 4

=item *

An object descended from L<DTA::CAB::Server::HTTP::Handler|DTA::CAB::Server::HTTP::Handler>.

=item *

A HASH ref of the form

 { class=>$subclass, %newArgs }

The handler will be instantiated by $subclass-E<gt>new(%newArgs).
$subclass may be specified as a suffix of C<DTA::CAB::Server::HTTP::Handler>,
e.g. $subclass="Query" will instantiate a handler of class C<DTA::CAB::Server::HTTP::Handler::Query>.

=item *

An ARRAY ref of the form

 [$subclass, @newArgs ]

The handler will be instantiated by $subclass-E<gt>new(@newArgs).
$subclass may be specified as a suffix of C<DTA::CAB::Server::HTTP::Handler>,
e.g. $subclass="Query" will instantiate a handler of class C<DTA::CAB::Server::HTTP::Handler::Query>.

=back

=back

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP: Methods: Generic Server API
=pod

=head2 Methods: Generic Server API

=over 4

=item prepareLocal

 $rc = $srv->prepareLocal();

Subclass-local initialization.
This override initializes the underlying HTTP::Daemon object,
sets up the path handlers, and compiles the server's _allow and _deny
regexes.

=item run

 $rc = $srv->run();

Run the server on the specified port until further notice.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP: Methods: Local: Path Handlers
=pod

=head2 Methods: Local: Path Handlers

=over 4

=item registerPathHandler

 $handler = $srv->registerPathHandler($pathStr, \%handlerSpec);
 $handler = $srv->registerPathHandler($pathStr, \@handlerSpec)
 $handler = $srv->registerPathHandler($pathStr, $handlerObject)

Registers a path handler for path $pathStr (and all sub-paths).
See L</new>() for a description of the allowed forms for handler specifications.

Sets $srv-E<gt>{paths}{$pathStr} = $handler

=item getPathHandler

 ($handler,$localPath) = $srv->getPathHandler($hreq_uri);

Gets the most specific path handler (and its local path) for the URI object $hreq_uri.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP: Methods: Local: Access Control
=pod

=head2 Methods: Local: Access Control

=over 4

=item clientAllowed

 $bool = $srv->clientAllowed($clientSock);

Returns true iff $clientSock may access the server.

=item denyClient

 undef = $srv->denyClient($clientSock);
 undef = $srv->denyClient($clientSock, $denyMessage)

Denies access to $clientSock
and shuts down client socket.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP: Methods: Local: error handling
=pod

=head2 Methods: Local: error handling

=over 4

=item clientError

 undef = $srv->clientError($clientSock,$status,@message);

Sends an error message to the client and
shuts down the client socket.
$status defaults to RC_INTERNAL_SERVER_ERROR (see HTTP::Status).

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<DTA::CAB::Server(3pm)|DTA::CAB::Server>,
L<DTA::CAB::Server::HTTP::Handler(3pm)|DTA::CAB::Server::HTTP::Handler>,
L<DTA::CAB::Client::HTTP(3pm)|DTA::CAB::Client::HTTP>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
