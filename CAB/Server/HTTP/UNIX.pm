## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Server::HTTP::UNIX.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: DTA::CAB standalone HTTP server using HTTP::Daemon::UNIX

package DTA::CAB::Server::HTTP::UNIX;
use DTA::CAB::Server::HTTP;
use HTTP::Daemon::UNIX;
use POSIX ':sys_wait_h';
use Socket qw(SOMAXCONN);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Server::HTTP);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- DTA::CAB::Server::HTTP::UNIX overrides
##     daemonArgs => \%daemonArgs,   ##-- overrides for HTTP::Daemon::UNIX->new(); default={LocalPath=>'/tmp/dta-cab.sock'}
##     socketPerms => $mode,         ##-- socket permissions as an octal string (default='0666')
##     socketUser  => $user,         ##-- socket user or uid (root only; default=undef: current user)
##     socketGroup => $group,        ##-- socket group or gid (default=undef: current group)
##     _socketPath => $path,         ##-- bound socket path (for unlink() on destroy)
##
##     ##-- (inherited from DTA::CAB::Server:HTTP): Underlying HTTP::Daemon server
##     daemonMode => $daemonMode,    ##-- one of 'serial' or 'fork' [default='serial']
##     daemonArgs => \%daemonArgs,   ##-- args to HTTP::Daemon->new(); default={LocalAddr=>'0.0.0.0',LocalPort=>8088}
##     paths      => \%path2handler, ##-- maps local URL paths to configs
##     daemon     => $daemon,        ##-- underlying HTTP::Daemon::UNIX object
##     cxsrv      => $cxsrv,         ##-- associated DTA::CAB::Server::XmlRpc object for XML-RPC handlers
##     xopt       => \%xmlRpcOpts,   ##-- options for RPC::XML::Server sub-object (for XML-RPC handlers; default: {no_http=>1})
##     ##
##     ##-- (inherited from DTA::CAB::Server:HTTP): caching & status
##     cacheSize  => $nelts,         ##-- maximum number of responses to cache (default=1024; undef for no cache)
##     cacheLimit => $nbytes,        ##-- max number of content bytes for cached responses (default=undef: no limit)
##     cache      => $lruCache,      ##-- response cache: (key = $url, value = $response), a DTA::CAB::Cache::LRU object
##     nRequests  => $nRequests,     ##-- number of requests (after access control)
##     nCacheHits => $nCacheHits,    ##-- number of cache hits
##     nErrors    => $nErrors,       ##-- number of client errors
##     ##
##     ##-- (inherited from DTA::CAB::Server:HTTP): security
##     allowUserOptions => $bool,   ##-- allow user options? (default: true)
##     allow => \@allow_ip_regexes, ##-- allow queries from these clients (default=none)
##     deny  => \@deny_ip_regexes,  ##-- deny queries from these clients (default=none)
##     _allow => $allow_ip_regex,   ##-- single allow regex (compiled by 'prepare()')
##     _deny  => $deny_ip_regex,    ##-- single deny regex (compiled by 'prepare()')
##     maxRequestSize => $bytes,    ##-- maximum request content-length in bytes (default: undef//-1: no max)
##     bgConnectTimeout => $secs,   ##-- timeout for detecting chrome-style "background connections": connected sockets with no data on them (0:none; default=1)
##     ##
##     ##-- (inherited from DTA::CAB::Server:HTTP): forking
##     forkOnGet => $bool,	    ##-- fork() handler for HTTP GET requests? (default=0)
##     forkOnPost => $bool,	    ##-- fork() handler for HTTP POST requests? (default=1)
##     forkMax => $n,		    ##-- maximum number of subprocess to spwan (default=4; 0~no limit)
##     children => \%pids,	    ##-- child PIDs
##     pid => $pid,		    ##-- PID of parent server process
##     ##
##     ##-- (inherited from DTA::CAB::Server:HTTP): logging
##     logRegisterPath => $level,   ##-- log registration of path handlers at $level (default='info')
##     logAttempt => $level,        ##-- log connection attempts at $level (default=undef: none)
##     logConnect => $level,        ##-- log successful connections (client IP and requested path) at $level (default='debug')
##     logRquestData => $level,     ##-- log full client request data at $level (default=undef: none)
##     logResponse => $level,       ##-- log full client response at $level (default=undef: none)
##     logCache => $level,          ##-- log cache hit data at $level (default=undef: none)
##     logClientError => $level,    ##-- log errors to client at $level (default='debug')
##     logClose => $level,          ##-- log close client connections (default=undef: none)
##     logReap => $level,           ##-- log harvesting of child pids (default=undef: none)
##     logSpawn => $level,          ##-- log spawning of child pids (default=undef: none)
##     ##
##     ##-- (inherited from DTA::CAB::Server)
##     as  => \%analyzers,    ##-- ($name=>$cab_analyzer_obj, ...)
##     aos => \%anlOptions,   ##-- ($name=>\%analyzeOptions, ...) : %opts passed to $anl->analyzeXYZ($xyz,%opts)
##    }
##
## + path handlers are as for DTA::CAB::Server::HTTP
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- underlying server
			   daemonArgs => {
					  Local => "/tmp/dta-cab.sock",
					 },
			   socketPerms => '0666',
			   socketUser  => undef,
			   socketGroup => undef,
			   _socketPath => undef,

			   ##-- user args
			   @_
			  );
}

## undef = $obj->initialize()
##  + called to initialize new objects after new()

## undef = $obj->DESTROY()
##  + override unlinks any bound UNIX socket
sub DESTROY {
  my $srv = shift;

  ##-- destroy daemon (force-close socket)
  delete($srv->{daemon}) if ($srv->{daemon});

  ##-- unlink socket if we got it
  if ($srv->{_socketPath} && -e $srv->{_socketPath}) {
    unlink($srv->{_socketPath})
      or warn("failed to unlink server socket $srv->{_socketPath}: $!");
    delete $srv->{_socketPath};
  }

  ##-- superclass destruction if available
  $srv->SUPER::DESTROY() if ($srv->can('SUPER::DESTROY'));
}

##==============================================================================
## Methods: HTTP server API (abstractions for HTTP::UNIX)

## $str = $srv->socketLabel()
##  + returns symbolic label for bound socket address
sub socketLabel {
  my $srv = shift;
  return "$srv->{daemonArgs}{Local}";
}

## $str = $srv->daemonLabel()
##  + returns symbolic label for running daemon
sub daemonLabel {
  my $srv = shift;
  return $srv->{daemon}->hostpath;
}

## $bool = $srv->canBindSocket()
##  + returns true iff socket can be bound; should set $! on error
sub canBindSocket {
  my $srv   = shift;
  my $dargs = $srv->{daemonArgs} || {};
  my $sock  = IO::Socket::UNIX->new(%$dargs, Listen=>SOMAXCONN) or return 0;
  unlink($dargs->{Local}) if ($dargs->{Local});
  undef $sock;
  return 1;
}

## $class = $srv->daemonClass()
##  + get HTTP::Daemon class
sub daemonClass {
  return 'HTTP::Daemon::UNIX';
}

## $class_or_undef = $srv->clientClass()
##  + get class for client connections
sub clientClass {
  return 'DTA::CAB::Server::HTTP::UNIX::ClientConn';
}

##==============================================================================
## Methods: Generic Server API: mostly inherited
##==============================================================================

## $rc = $srv->prepareLocal()
##  + subclass-local initialization
sub prepareLocal {
  my $srv = shift;

  ##-- Server::HTTP initialization
  my $rc  = $srv->SUPER::prepareLocal(@_);
  return $rc if (!$rc);

  ##-- get socket path
  my $sockpath = $srv->{_socketPath} = $srv->{daemon}->hostpath()
    or $srv->logdie("prepareLocal(): daemon returned bad socket path");

  ##-- setup socket ownership
  my $sockuid = (($srv->{socketUser}//'') =~ /^[0-9]+$/
		 ? $srv->{socketUser}
		 : getpwnam($srv->{socketUser}//''));
  my $sockgid = (($srv->{socketGroup}//'') =~ /^[0-9]+$/
		 ? $srv->{socketGroup}
		 : getgrnam($srv->{socketGroup}//''));
  if (defined($sockuid) || defined($sockgid)) {
    $sockuid //= $>;
    $sockgid //= $);
    $srv->vlog('info', "setting socket ownership (".scalar(getpwuid $sockuid).".".scalar(getgrgid $sockgid).") on $sockpath");
    chown($sockuid, $sockgid, $sockpath)
      or $srv->logdie("prepareLocal(): failed to set ownership for socket '$sockpath': $!");
  }

  ##-- setup socket permissions
  if ( ($srv->{socketPerms}//'') ne '' ) {
    my $sockperms = oct($srv->{socketPerms});
    $srv->vlog('info', sprintf("setting socket permissions (0%03o) on %s", $sockperms, $sockpath));
    chmod($sockperms, $sockpath)
      or $srv->logdie("prepareLocal(): failed to set permissions for socket '$sockpath': $!");
  }

  ##-- ok
  return $rc;
}

##==============================================================================
## Methods: Local: spawn and reap: inherited


##==============================================================================
## Methods: Local: Path Handlers: inherited

##==============================================================================
## Methods: Local: Access Control: inherited

##======================================================================
## Methods: Local: error handling: inherited

##==============================================================================
## PACKAGE: DTA::CAB::Server::HTTP::UNIX::ClientConn
package DTA::CAB::Server::HTTP::UNIX::ClientConn;
use File::Basename qw(basename);
use DTA::CAB::Utils qw(:proc);
our @ISA = qw(HTTP::Daemon::ClientConn);

## $host = peerhost()
##  + actually gets UNIX credentials on linux, as USER.GROUP[PID]
sub peerhost {
  my $sock = shift;
  my ($pid,$uid,$gid);
  if ($sock->can('SO_PEERCRED')) {
    my $buf = $sock->sockopt($sock->SO_PEERCRED);
    ($pid,$uid,$gid) = unpack('lll',$buf);
  }
  return (
	  (defined($uid) ? (getpwuid($uid)//'?') : '?')
	  .'.'
	  .(defined($gid) ? (getgrgid($gid)//'?') : '?')
	  .':'
	  .(defined($pid) ? (basename(pid_cmd($pid)//'?')."[$pid]") : '?[?]')
	 );
  return '???';

}
sub peerport { return ''; }



1; ##-- be happy

__END__
