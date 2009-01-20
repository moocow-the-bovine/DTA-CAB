#!/usr/bin/perl -w

use File::Basename qw(basename);
use Sys::Syslog (':DEFAULT',':standard',':macros');
use Log::Log4perl;

##----------------------------------------------------------------------
## Test: Sys::Syslog

BEGIN {
  our $logname     = basename($0);
  our $logfacility = 'user';
  our $logopts     = 'ndelay,nofatal,perror,pid';
  our @levels      = (LOG_EMERG,LOG_ALERT,LOG_CRIT,LOG_ERR,LOG_WARNING,LOG_NOTICE,LOG_INFO,LOG_DEBUG); 
  our $logmask    = (0
		     #| LOG_UPTO(LOG_WARNING) ##-- log all messages up to warning
		     #| LOG_UPTO(LOG_NOTICE)  ##-- log all messages up to notice
		     | LOG_UPTO(LOG_INFO)    ##-- log all messages up to info
		     #| LOG_UPTO(LOG_DEBUG)   ##-- log all messages up to debug
		    );
}

sub syslog_open {
  openlog($logname,$logopts,$logfacility);
  setlogmask($logmask);
}
sub syslog_close { closelog(); }

sub syslog_msg {
  my ($prio,$fmt,@args) = @_;
  syslog_open();
  syslog($prio, $fmt, @args);
  syslog_close();
}

sub test_syslog {
  my ($prio,@msg) = @ARGV;
  test_syslog_msg($prio, "%s", join('',@msg));
}

##----------------------------------------------------------------------
## Test: Log::Log4perl

use Log::Log4perl::Level;

sub init_log4p {
  Log::Log4perl::init('log4perl.conf');
}

sub test_log4p {
  my ($cat, $prio, @msg) = @_;
  init_log4p() if (!Log::Log4perl->initialized);
  my $logger = Log::Log4perl::get_logger($cat);
  my $sub    = $logger->can($prio);
  die("$0: no logging method for priority '$prio'") if (!defined($sub));
  $sub->($logger,@msg);
}
test_log4p(@ARGV);
#test_log4p('Foo','info',"test info", 123);
