#!/usr/bin/perl -w

## File: dta-cab-http-check.perl
## Author: Bryan Jurish <jurish@bbaw.de>
## Description:
##  + DTA::CAB::Server::HTTP monitoring plugin (for nagios, icinga, etc)

use File::Basename qw(basename dirname);
use Monitoring::Plugin;
use LWP::UserAgent;
use Pod::Usage;
use JSON;
use Getopt::Long qw(:config no_ignore_case);
use Time::HiRes qw(gettimeofday tv_interval);
use strict;

##======================================================================
## Version
our $VERSION = 0.01;
our $SVNID   = q(
  $HeadURL: svn+ssh://odo.dwds.de/home/svn/dev/DTA-CAB/trunk/dta-cab-check.perl $
  $Id: dta-cab-check.perl 16718 2016-11-21 08:59:33Z moocow $
);

##======================================================================
## Globals

our ($help,$version);
our $mp = 'Monitoring::Plugin';   ##-- later: object
our $prog = basename($0);

our $timeout   = 30;
our $time_warn =  5;
our $time_crit = 10;

our $vl_silent = 0;
our $vl_debug  = 1;
our $vl_trace  = 2;
our $verbose  = $vl_silent;  ##-- 0..2

##======================================================================
## Command-Line
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,

	   ##-- behavior
	   'query-timeout|qt|timeout|t=i' => \$timeout,
	   'time-warn|tw|warn|w=i' => \$time_warn,
	   'time-critical|tc|critical|c=i' => \$time_crit,

	   ##-- logging
	   'verbose|v' => sub { ++$verbose; },
	  );

if ($version) {
  print STDERR "${prog} version ${VERSION}${SVNID}";
  exit 0;
}
pod2usage({-exitval=>0, -verbose=>0}) if ($help);


##-- Monitoring::Plugin interface object
$mp = Monitoring::Plugin->new
  (
   shortname => 'CAB',
   usage => 'Usage: %s [OPTIONS] CAB_SERVER_URL(s)...',
   version => $VERSION,
   #blurb   => $blurb,
   #extra   => $extra,
   #url     => $url,
   license => "perl5",
   plugin  => 'CAB',
   timeout => $timeout,
  );

##-- signal handling
$SIG{__DIE__} = sub {
  $mp->plugin_die(UNKNOWN, join('', @_));
};

##======================================================================
## verbose messaging

## undef = vmsg($level,@msg)
sub vmsg {
  my $level = shift;
  return if (!defined($level) || ($verbose < $level));
  print STDERR "$prog: ", @_, "\n";
}


##======================================================================
## MAIN

$mp->plugin_die("no server URL specified") if (!@ARGV);
my $url    = shift(@ARGV);
my $geturl = "$url/status?f=json";

##-- sanitize thresholds
$time_crit = $timeout    if ($timeout   < $time_crit);
$time_warn = $time_crit  if ($time_crit < $time_warn);

##-- debug output
vmsg($vl_debug, "set status_url = $geturl");
vmsg($vl_debug, "set timeout = ", $timeout);
vmsg($vl_debug, "set time_warn = ", $time_warn);
vmsg($vl_debug, "set time_crit = ", $time_crit);


##-- query server
my $ua = LWP::UserAgent->new(
			     ssl_opts => {SSL_verify_mode=>'SSL_VERIFY_NONE'}, ##-- avoid "certificate verify failed" errors
			    )
  or die("$prog: failed to create user agent for URL $url: $!");

my $t0  = [gettimeofday];
my $rsp = $ua->get($geturl)
  or die("failed to retrieve URL $geturl");
my $time  = sprintf("%.3f", tv_interval($t0));

##-- parse response & add perforamance data
$mp->add_perfdata(label=>'time', value=>$time, uom=>'s');
my $status = {};
my $rc = CRITICAL;
if ($rsp->is_success) {
  $rc     = OK;
  $status = from_json($rsp->decoded_content);
}
my $memMB = sprintf("%.2f", ($status->{memSize}//0) / 1024);
$mp->add_perfdata(label=>'mem', value=>$memMB, uom=>'MB');
$mp->add_perfdata(label=>'nreq', value=>($status->{nRequests}//0), uom=>'c');
$mp->add_perfdata(label=>'nerr', value=>($status->{nErrors}//0), uom=>'c');
{
  no warnings 'numeric';
  $mp->add_perfdata(label=>'cached', value=>($status->{cacheHitRate}+0), uom=>'%');
};

##-- final exit
$mp->plugin_exit($rc, "$url - ${time}s ${memMB}MB");
