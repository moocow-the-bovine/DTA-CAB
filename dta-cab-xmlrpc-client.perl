#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Client::XmlRpc;
use DTA::CAB::Utils ':all';
use Encode qw(encode decode);
use File::Basename qw(basename);
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

##-- Client
our $serverURL  = 'http://localhost:8000';
our $serverEncoding = 'UTF-8';
our $localEncoding  = 'UTF-8';
our $analyzer = 'dta.cab.default';

##-- actions
our $action = 'list';
our %analyzeOpts = qw();   ##-- currently unused
our $formatClass = 'Text'; ##-- default format class
our $parserClass = 'TT';   ##-- default parser class

our $rawClass = 'Freeze'; ##-- I/O class for raw comms

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|m'     => \$man,
	   'version|V' => \$version,

	   ##-- Server
	   'server-url|server|url|s|u=s' => \$serverURL,
	   'local-encoding|le=s'  => \$localEncoding,
	   'server-encoding|se=s' => \$serverEncoding,
	   'analyzer|a=s' => \$analyzer,
	   'format-class|fc=s' => \$formatClass,
	   'parser-class|pc=s' => \$parserClass,
	   'raw-class|rc=s' => \$rawClass,

	   ##-- Action
	   'list|l'   => sub { $action='list'; },
	   'token|t' => sub { $action='token'; },
	   'sentence|S' => sub { $action='sentence'; },
	   'document|d' => sub { $action='document'; },
	   'raw|r' => sub { $action='raw'; }, ##-- server-side parsing
	  );

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);

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

##-- create client object
our $cli = DTA::CAB::Client::XmlRpc->new(
					 serverURL=>$serverURL,
					 serverEncoding=>$serverEncoding,
					);
$cli->connect() or die("$0: connect() failed: $!");

##-- format class
$formatClass = 'DTA::CAB::Formatter::'.$formatClass if (!UNIVERSAL::isa($formatClass,'DTA::CAB::Formatter'));
our $fmt = $formatClass->new()
  or die("$0: could not create formatter of class $formatClass: $!");

##-- parser class
$parserClass = 'DTA::CAB::Parser::'.$parserClass if (!UNIVERSAL::isa($parserClass,'DTA::CAB::Parser'));
our $prs = $parserClass->new()
  or die("$0: could not create parser of class $parserClass: $!");

##===================
## Actions

if ($action eq 'list') {
  ##-- action: list
  my @anames = $cli->analyzers;
  print map { "$_\n" } @anames;
}
elsif ($action eq 'token') {
  ##-- action: 'tokens'
  foreach $tokin (map {DTA::CAB::Utils::deep_decode($localEncoding,$_)} @ARGV) {
    $tokout = $cli->analyzeToken($analyzer, $tokin, \%analyzeOpts);
    print $fmt->formatString( $fmt->formatToken($tokout) );
  }
}
elsif ($action eq 'sentence') {
  ##-- action: 'sentence'
  our $s_in  = DTA::CAB::Utils::deep_decode($localEncoding,[@ARGV]);
  our $s_out = $cli->analyzeSentence($analyzer, $s_in, \%analyzeOpts);
  print $fmt->formatString( $fmt->formatSentence($s_out) );
}
elsif ($action eq 'document') {
  ##-- action: 'document': interpret args as filenames & parse 'em!
  our ($d_in,$d_out);
  foreach $doc_filename (@ARGV) {
    $d_in = DTA::CAB::Utils::deep_decode($localEncoding, $prs->parseFile($doc_filename))
      or die("$0: parse failed for input file '$doc_filename': $!");
    $d_out = $cli->analyzeDocument($analyzer, $d_in, \%analyzeOpts);
    print $fmt->formatString( $fmt->formatDocument($d_out) );
  }
}
elsif ($action eq 'raw') {
  ##-- action: 'generic': do server-side parsing
  our ($d_in,$raw_in,$raw_out,$d_out);

  ##-- raw data formatter
  our $raw_fmt = "DTA::CAB::Formatter::${rawClass}"->new()
    or die("$0: could not create raw formatter of class '$rawClass': $!");

  ##-- raw data parser
  our $raw_prs = "DTA::CAB::Parser::${rawClass}"->new()
    or die("$0: could not create raw parser of class '$rawClass': $!");

  foreach $doc_filename (@ARGV) {
    $d_in = DTA::CAB::Utils::deep_decode($localEncoding, $prs->parseFile($doc_filename))
      or die("$0: parse failed for input file '$doc_filename': $!");
    $raw_in  = $raw_fmt->formatString( $raw_fmt->formatDocument($d_in) );
    $raw_out = $cli->analyzeData( $analyzer, $raw_in, {%analyzeOpts, parserClass=>$rawClass, formatClass=>$rawClass} );
    $d_out   = $raw_prs->parseString( $raw_out );
    print $fmt->formatString( $fmt->formatDocument($d_out) );
  }
}
else {
  die("$0: unknown action '$action'");
}

$cli->disconnect();


__END__
=pod

=head1 NAME

dta-cab-xmlrpc-client.perl - XML-RPC client for DTA::CAB server queries

=head1 SYNOPSIS

 dta-cab-xmlrpc-client.perl [OPTIONS...] ARGUMENTS

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit

 Server Selection
  -serverURL URL                  ##-- set server URL (default: localhost:8000)
  -analyzer NAME                  ##-- set analyzer name (default: 'dta.cab.default')
  -server-encoding ENCODING       ##-- override server encoding (default: UTF-8)
  -local-encoding ENCODING        ##-- override local encoding (default: UTF-8)

 Analysis Selection:
  -list                           ##-- query registered analyzers from server
  -token                          ##-- ARGUMENTS are token text
  -sentence                       ##-- ARGUMENTS are analyzed as a sentence
  -document                       ##-- ARGUMENTS are filenames, analyzed as documents (TODO!)

 I/O
  -format-class CLASS             ##-- select output formatter class (default: Text)

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
