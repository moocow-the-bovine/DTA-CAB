## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Server::XmlRpc.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA::CAB XML-RPC server using RPC::XML

package DTA::CAB::Server::XmlRpc;
use DTA::CAB::Server;
use RPC::XML;
use RPC::XML::Server;
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
##     ##-- Underlying server
##     xsrv => $xsrv,      ##-- low-level server, an RPC::XML::Server object
##     xopt => \%opts,     ##-- options for RPC::XML::Server->new()
##     xrun => \%opts,     ##-- options for RPC::XML::Server->server_loop()
##     ##
##     ##-- XML-RPC procedure naming
##     procNamePrefix => $prefix, ##-- default: 'dta.cab.'
##     ##
##     ##-- hacks
##     encoding => $enc,   ##-- sets $RPC::XML::ENCODING on prepare(), used by underlying server
##     ##
##     ##-- (inherited from DTA::CAB::Server)
##     as => \%analyzers,  ##-- ($name => $cab_analyzer_obj, ...)
##    }
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- underlying server
			   xsrv => undef,
			   xopt => {
				    #path => '/',         ##-- URI path for underlying server (HTTP::Daemon)
				    #host => '0.0.0.0',   ##-- host for underlying server (HTTP::Daemon)
				    port => 8000,         ##-- port for underlying server (HTTP::Daemon)
				    queue => SOMAXCONN,   ##-- queue size for underlying server (HTTP::Daemon)
				    #timeout => 10,       ##-- connection timeout (HTTP::Daemon)
				    ##
				    #no_default => 1,     ##-- disable default methods (default=enabled)
				    #auto_methods => 1,   ##-- enable auto-method seek (default=0)
				   },
			   xrun => {
				    #signal => [qw(INT HUP TERM)],
				    signal => 0, ##-- don't catch any signals by default
				   },
			   ##
			   ##-- XML-RPC procedure naming
			   procNamePrefix => 'dta.cab.',
			   ##
			   ##-- hacks
			   encoding => 'UTF-8',
			   ##
			   ##-- user args
			   @_
			  );
}

## undef = $obj->initialize()
##  + called to initialize new objects after new()

##==============================================================================
## Methods: Encoding Hacks
##==============================================================================

## \%rpcProcHash = $srv->wrapMethodEncoding(\%rpcProcHash)
##  + wraps an RPC::XML::procedure spec into $srv->{encoding}-safe code,
##    only if $rpcProcHash{wrapEncoding} is set to a true value
sub wrapMethodEncoding {
  my $srv = shift;
  if (defined($srv->{encoding}) && $_[0]{wrapEncoding}) {
    my $code_orig = $_[0]{code_orig} = $_[0]{code};
    $_[0]{code} = sub {
      my $rv  = $code_orig->(@_);
      my $rve = DTA::CAB::Utils::deep_encode($srv->{encoding}, $rv);
      return $rve;
    };
  }
  return $_[0];
}


##==============================================================================
## Methods: Generic Server API
##==============================================================================

## $rc = $srv->prepareLocal()
##  + subclass-local initialization
sub prepareLocal {
  my $srv = shift;

  ##-- get RPC::XML object
  my $xsrv = $srv->{xsrv} = RPC::XML::Server->new(%{$srv->{xopt}});
  if (!ref($xsrv)) {
    $srv->logcroak("could not create underlying server object: $xsrv\n");
  }

  ##-- hack: set server encoding
  if (defined($srv->{encoding})) {
    $srv->info("(hack) setting RPC::XML::ENCODING = $srv->{encoding}");
    $RPC::XML::ENCODING = $srv->{encoding};
  }
  ##-- hack: set $RPC::XML::FORCE_STRING_ENCODINTG
  $srv->info("(hack) setting RPC::XML::FORCE_STRING_ENCODING = 1");
  $RPC::XML::FORCE_STRING_ENCODING = 1;

  ##-- register analysis methods
  my ($aname,$a, $xp);
  while (($aname,$a)=each(%{$srv->{as}})) {
    foreach ($a->xmlRpcMethods) {
      if (UNIVERSAL::isa($_,'HASH')) {
	##-- hack method 'name'
	$_->{name} = 'analyze' if (!defined($_->{name}));
	$_->{name} = $aname.'.'.$_->{name} if ($aname);
	$_->{name} = $srv->{procNamePrefix}.$_->{name} if ($srv->{procNamePrefix});
	$srv->wrapMethodEncoding($_); ##-- hack encoding?
      }
      $xp = $xsrv->add_proc($_);
      if (!ref($xp)) {
	$srv->error("could not register XML-RPC procedure ".(ref($_) ? "$_->{name}()" : "'$_'")." for analyzer '$aname'\n",
		    " + RPC::XML::Server error: $xp\n",
		   );
      } else {
	$srv->info("registered XML-RPC procedure $_->{name}() for analyzer '$aname'\n");
      }
    }
  }

  ##-- register 'listAnalyzers' method
  my $listproc = $srv->listAnalyzersProc;
  $xsrv->add_proc($listproc);
  $srv->info("registered XML-RPC listing procedure $listproc->{name}()\n");

  return 1;
}

## $rc = $srv->run()
##  + run the server (just a dummy method)
sub run {
  my $srv = shift;
  $srv->prepare() if (!$srv->{xsrv}); ##-- sanity check
  $srv->logcroak("run(): no underlying RPC::XML object!") if (!$srv->{xsrv});
  $srv->info("server starting on host ", $srv->{xsrv}->host, ", port ", $srv->{xsrv}->port, "\n");
  $srv->{xsrv}->server_loop(%{$srv->{runopt}});
  $srv->info("server exiting\n");

  return 1;
}

##==============================================================================
## Methods: Additional
##==============================================================================

## \%procSpec = $srv->listAnalyzersProc()
sub listAnalyzersProc {
  my $srv = shift;
  my $anames = DTA::CAB::Utils::deep_encode($srv->{encoding},
					    [ map {($srv->{procNamePrefix}||'').$_ } keys(%{$srv->{as}}) ]
					   );
  return {
	  name => ($srv->{procNamePrefix}||'').'listAnalyzers',
	  code => sub { return $anames; },
	  help => 'list registered analyzer names',
	  signature => [ 'array' ],
	 };
}


1; ##-- be happy

__END__
