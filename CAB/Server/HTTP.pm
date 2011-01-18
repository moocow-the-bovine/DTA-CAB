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
