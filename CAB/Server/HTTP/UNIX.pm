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
##     relayCmd    => \@cmd,         ##-- TCP relay command-line for exec() (default=[qw(socat ...)], see prepareRelay())
##     relayAddr   => $addr,         ##-- TCP relay address to bind (default=$daemonArgs{LocalAddr}, see prepareRelay())
##     relayPort   => $port,         ##-- TCP relay address to bind (default=$daemonArgs{LocalPort}, see prepareRelay())
##     relayPid    => $pid,          ##-- child PID for TCP relay process (sockrelay.perl / socat; see prepareRelay())
##
##     ##-- (inherited from DTA::CAB::Server:HTTP): Underlying HTTP::Daemon server
##     daemonMode => $daemonMode,    ##-- one of 'serial' or 'fork' [default='serial']
##     #daemonArgs => \%daemonArgs,   ##-- args to HTTP::Daemon->new(); default={LocalAddr=>'0.0.0.0',LocalPort=>8088}
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

  ##-- terminate tcp-relay subprocess
  kill('TERM'=>$srv->{relayPid}) if ($srv->{relayPid});

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

##--------------------------------------------------------------
## $rc = $srv->prepareLocal()
##  + subclass-local initialization
sub prepareLocal {
  my $srv = shift;

  ##-- Server::HTTP initialization
  my $rc  = $srv->SUPER::prepareLocal(@_);
  return $rc if (!$rc);

  ##-- get socket path
  my $sockpath = $srv->{_socketPath} = $srv->{daemon}->hostpath()
    or $srv->logconfess("prepareLocal(): daemon returned bad socket path");

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
      or $srv->logconfess("prepareLocal(): failed to set ownership for socket '$sockpath': $!");
  }

  ##-- setup socket permissions
  if ( ($srv->{socketPerms}//'') ne '' ) {
    my $sockperms = oct($srv->{socketPerms});
    $srv->vlog('info', sprintf("setting socket permissions (0%03o) on %s", $sockperms, $sockpath));
    chmod($sockperms, $sockpath)
      or $srv->logconfess("prepareLocal(): failed to set permissions for socket '$sockpath': $!");
  }

  ##-- setup TCP relay subprocess
  $rc &&= $srv->prepareRelay(@_);

  ##-- ok
  return $rc;
}

##--------------------------------------------------------------
## $bool = $srv->prepareRelay()
##  + sets up TCP relay subprocess
sub prepareRelay {
  my $srv = shift;
  my $addr = $srv->{relayAddr} || $srv->{daemonArgs}{LocalAddr};
  my $port = $srv->{relayPort} || $srv->{daemonArgs}{LocalPort};
  return 1 if (!$addr && !$port); ##-- no relay required

  my $sockpath = $srv->{_socketPath};
  $addr ||= '0.0.0.0';
  @$srv{qw(relayAddr relayPort)} = ($addr,$port);

  $srv->vlog('trace',"starting TCP socket relay on ${addr}:${port}");
  if ( ($srv->{relayPid}=fork()) ) {
    ##-- parent
    $srv->vlog('info', "started TCP socket relay process for ${addr}:${port} on pid=$srv->{relayPid}");
  } else {
    ##-- child (relay)

    ##-- cleanup: close file desriptors
    POSIX::close($_) foreach (3..1024);

    ##-- cleanup: environment
    #delete @ENV{grep {$_ !~ /^(?:PATH|PERL|LANG|L[CD]_)/} keys %ENV};

    ##-- get relay command
    my $cmd = ($srv->{relayCmd}
	       || [
		   #qw(env -i), ##-- be paranoid
		   #qw(sockrelay.perl -syslog), "-label=dta-cab-relay/$port",
		   qw(socat -d -ly),
		   #"-lpdta-cab-relay/$port", ##-- doesn't set environment varaibles
		   "-lpdta_cab_relay",        ##-- environment variable prefix: DTA_CAB_RELAY_PEERADDR, ...
		   "TCP-LISTEN:${port},bind=${addr},backlog=".IO::Socket->SOMAXCONN.",reuseaddr,fork",
		   qq{EXEC:socat -d -ly - 'UNIX-CLIENT:$sockpath'}, ##-- use EXEC:socat idiom to populate socat environment variables (SOCAT_PEERADDR,SOCAT_PEERPORT)
		  ]);

    $srv->vlog('trace', "RELAY: ", join(' ', @$cmd));
    exec(@$cmd)
      or $srv->logconfess("prepareLocal(): failed to start TCP socket relay: $!");
  }

  return 1; ##-- never reached
}


##==============================================================================
## Methods: Local: spawn and reap

## \&reaper = $srv->reaper()
##  + zombie-harvesting code; installed to local %SIG
sub reaper {
  my $srv = shift;
  return sub {
    my ($child);
    while (($child = waitpid(-1,WNOHANG)) > 0) {

      ##-- check whether required subprocess bailed on us
      if ($srv->{relayPid} && $child == $srv->{relayPid}) {
	delete $srv->{relayPid};
	$srv->logdie("TCP relay process ($child) exited with status $?");
      }

      ##-- normal case: handle client-level forks (e.g. for POST)
      $srv->vlog($srv->{logReap},"reaped subprocess pid=$child, status=$?");
      delete $srv->{children}{$child};
    }

    #$SIG{CHLD}=$srv->reaper() if ($srv->{installReaper}); ##-- re-install reaper for SysV
  };
}



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

## ($pid,$uid,$gid) = $sock->peercred()
##  + gets peer credentials; returns (-1,-1,-1) on failure
sub peercred {
  my $sock = shift;
  if ($sock->can('SO_PEERCRED')) {
    my $buf = $sock->sockopt($sock->SO_PEERCRED);
    return unpack('lll',$buf);
  }
  return (-1,-1,-1);
}

## \%env = $sock->peerenv()
## \%env = $sock->peerenv($pid)
##  + gets environment variables for peer process, if possible
##  + uses cached value in ${*sock}{peerenv} if present
##  + returns undef on failure
sub peerenv {
  my ($sock,$pid) = @_;
  return ${*$sock}{'peerenv'} if (${*$sock}{'peerenv'});
  ($pid) = $sock->peercred if (!$pid);
  my ($fh,%env);
  if (open($fh,"</proc/$pid/environ")) {
    local $/ = "\0";
    my ($key,$val);
    while (defined($_=<$fh>)) {
      chomp($_);
      ($key,$val) = split(/=/,$_,2);
      $env{$key} = $val;
    }
    close($fh);
  }

  ##-- debug
  #print STDERR "PEERENV($sock): $_=$env{$_}\n" foreach (sort keys %env);

  ${*$sock}{'peerenv'} = \%env;
}

## $str = $sock->peerstr()
## $str = $sock->peerstr($uid,$gid,$pid)
##  + returns stringified unix peer credentials: "${USER}.${GROUP}[${PID}]"
sub peerstr {
  my ($sock,$pid,$uid,$gid) = @_;
  ($pid,$uid,$gid) = $sock->peercred() if (@_ < 4);
  return (
	  (defined($uid) ? (getpwuid($uid)//'?') : '?')
	  .'.'
	  .(defined($gid) ? (getgrgid($gid)//'?') : '?')
	  .':'
	  .(defined($pid) ? (basename(pid_cmd($pid)//'?')."[$pid]") : '?[?]')
	 );
}

## $host = peerhost()
##  + for relayed connections, gets underlying TCP peer via socat environment
##  + for unix connections, returns UNIX credentials as as for peerstr()
sub peerhost {
  my $sock = shift;

  ##-- get socat environment variable if possible
  my $env = $sock->peerenv();
  return $env->{DTA_CAB_RELAY_PEERADDR} if ($env && $env->{DTA_CAB_RELAY_PEERADDR});

  ##-- return UNIX socket credentials
  return $sock->peerstr();
}

## $port = peerport()
##  + for relayed connections, gets underlying TCP port via socat environment
##  + for unix connections, returns socket path
sub peerport {
  my $sock = shift;

  ##-- get socat environment variable if possible
  my $env = $sock->peerenv();
  return $env->{DTA_CAB_RELAY_PEERPORT} if ($env && $env->{DTA_CAB_RELAY_PEERPORT});

  ##-- return UNIX socket credentials
  return $sock->peerpath();
}



1; ##-- be happy

__END__
