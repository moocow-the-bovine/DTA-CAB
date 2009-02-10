#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Utils ':all';
use Encode qw(encode decode);
use File::Basename qw(basename);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = 0.01;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

#BEGIN {
#  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
#  binmode(STDIN, ':utf8');
#  binmode(STDOUT,':utf8');
#  binmode(STDERR,':utf8');
#}

##-- I/O
our $rcFile          = undef;
our $inputEncoding   = 'UTF-8';
our $outputEncoding  = 'UTF-8';

our $morphDictFile = undef;
our $rwDictFile = undef;

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|M'     => \$man,
	   'version|V' => \$version,

	   ##-- I/O
	   'configuration|c=s'    => \$rcFile,
	   'input-encoding|ie=s'  => \$inputEncoding,
	   'output-encoding|oe=s' => \$outputEncoding,
	   'morph-cache|morph-dict|md|mc|m=s'    => \$morphDictFile,
	   'rw-cache|rw-dict|rc|rd|r=s'           => \$rwDictFile,
	  );

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({-exitval=>0, -verbose=>0, -message=>'No config file specified!'}) if (!defined($rcFile));

if ($version) {
  print STDERR
    ("${prog} v$VERSION by Bryan Jurish <moocow\@bbaw.de>\n",
     "  + using DTA::CAB v$DTA::CAB::VERSION\n"
    );
  exit(0);
}

##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
DTA::CAB::Logger->ensureLog();

##-- analyzer
our $cab = DTA::CAB->loadPerlFile($rcFile)
  or die("$0: load failed for analyzer from '$rcFile': $!");
our $a_tok = $cab->analyzeTokenSub();

##===================
## Read input (1 word per line)
$cab->trace("parsing input");
our @toks = qw();
push(@ARGV,'-') if (!@ARGV);
while (defined($line=<>)) {
  chomp($line);
  next if ($line =~ /^\s*$/ || $line =~ /^\%\%/);
  $line = decode($inputEncoding,$line);
  ($text,$rest) = split(/\t/,$line);
  $tok = bless({text=>$text,(defined($rest) ? (rest=>$rest) : qw())},'DTA::CAB::Token');
  push(@toks, $a_tok->($tok)); ##-- analyze
}

##===================
## Generate dictionary files

if (defined($morphDictFile)) {
  $cab->trace("generating morph cache '$morphDictFile'");
  open(DICT,">$morphDictFile") or die("$0: open failed for morph cache '$morphDictFile': $!");
  foreach $tok (grep {defined($_->{morph})} @toks) {
    print DICT encode($outputEncoding, join("\t", $tok->{text}, map {"$_->[0] <$_->[1]>"} @{$tok->{morph}})."\n");
  }
  close(DICT);
}

if (defined($rwDictFile)) {
  $cab->trace("generating rewrite cache '$rwDictFile'");
  open(DICT,">$rwDictFile") or die("$0: open failed for rewrite cache '$rwDictFile': $!");
  foreach $tok (grep {defined($_->{rw})} @toks) {
    print DICT encode($outputEncoding, join("\t", $tok->{text}, map {"$_->[0] <$_->[1]>"} @{$tok->{rw}})."\n");
  }
  close(DICT);
}


__END__
=pod

=head1 NAME

dta-cab-cachegen.perl - Cache generator for DTA::CAB server

=head1 SYNOPSIS

 dta-cab-cachegen.perl [OPTIONS...] TYPE_LIST_FILE(s)...

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit

 I/O Options
  -config RCFILE                  ##-- load analyzer config file RCFILE
  -input-encoding ENCODING        ##-- override input encoding (default: UTF-8)
  -output-encoding ENCODING       ##-- override output encoding (default: UTF-8)
  -morph-dict CACHEFILE           ##-- generate morph cache CACHEFILE
  -rw-dict    CACHEFILE           ##-- generate rewrite cahce CACHEFILE

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

Not yet written.

=cut

##==============================================================================
## Options and Arguments
##==============================================================================
=pod

=head1 OPTIONS AND ARGUMENTS

=cut

##==============================================================================
## Options: General Options
=pod

=head2 General Options

=over 4

=item -help

Display a short help message and exit.

=item -man

Display a longer help message and exit.

=item -version

Display program and module version information and exit.

=back

=cut

##==============================================================================
## Options: Other Options
=pod

=head2 Other Options

Not yet written.

=cut

##======================================================================
## Footer
##======================================================================

=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

RPC::XML by Randy J. Ray.

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

perl(1),
DTA::CAB(3pm),
RPC::XML(3pm).

=cut
