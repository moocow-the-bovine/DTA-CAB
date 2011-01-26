#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Client::HTTP;
use DTA::CAB::Utils ':all';
use DTA::CAB::Datum ':all';
use Encode qw(encode decode);
use File::Basename qw(basename);
use Getopt::Long qw(:config no_ignore_case);
use Time::HiRes qw(gettimeofday tv_interval);
use IO::File;
use Pod::Usage;

##==============================================================================
## DEBUG
##==============================================================================
#do "storable-debug.pl" if (-f "storable-debug.pl");

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = $DTA::CAB::VERSION;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

##-- Log options
our %logOpts = (rootLevel=>'WARN', level=>'INFO'); ##-- options for DTA::CAB::Logger::ensureLog()

##-- Client Options
our $defaultPort = 9099;
our $defaultPath = '/cgi';
our $serverURL   = "http://localhost:${defaultPort}${defaultPath}";
our %clientOpts = (
		   timeout=>65535, ##-- wait for a *long* time (65535 = 2**16-1 ~ 18.2 hours)
		   testConnect=>1,
		   mode => 'xpost',
		   post => 'urlencoded',
		  );

##-- Analysis & Action Options
our $analyzer = 'default';
our $action = 'document';
our %analyzeOpts = qw(); #(pretty=>0);
our $doProfile = undef;

##-- I/O Options
our $inputClass  = undef;  ##-- default parser class
our $outputClass = undef;  ##-- default format class
our $outfile     = '-';
our %formatOpts  = qw();
our $encoding = 'UTF-8';
our ($ifmt,$ofmt);

our $bench_iters = 1; ##-- number of benchmark iterations for -bench mode
our $trace_request_file = undef; ##-- trace request to file?

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man'       => \$man,
	   'version|V' => \$version,

	   ##-- Client Options
	   'server-url|serverURL|server|url|s|u=s' => \$serverURL,
	   'timeout|T=i' => \$clientOpts{timeout},
	   'test-connect|tc!' => \$clientOpts{testConnect},
	   'get' => sub { $clientOpts{mode}='get'; },
	   'post' => sub { $clientOpts{mode}='post'; },
	   'multipart|multi!' => sub { $clientOpts{post}=$_[1] ? 'multipart' : 'urlencoded'; },
	   'xpost' => sub { $clientOpts{mode}='xpost'; },
	   'xmlrpc' => sub { $clientOpts{mode}='xmlrpc'; },

	   ##-- Analysis Options
	   'analyzer|a=s' => \$analyzer,
	   'analysis-option|analyze-option|ao|O=s' => \%analyzeOpts,
	   'profile|p!' => \$doProfile,
	   'list|l'   => sub { $action='list'; },
	   'token|t|word|w' => sub { $action='token'; },
	   'sentence|S' => sub { $action='sentence'; },
	   'document|d' => sub { $action='document'; },
	   'data|D' => sub { $action='data'; }, ##-- server-side parsing
	   'raw|R' => sub { $action='raw'; }, ##-- server-side tokenization & parsing
	   'bench|b:i' => sub { $action='bench'; $bench_iters=$_[1]; },

	   ##-- I/O: common
	   'format-class|fc=s'   => \$formatClass,
	   'format-option|fo=s'  => \%formatOpts,	
	   'format-level|fl|output-level|ol|pretty=s' => \$analyzeOpts{pretty},
	   'format-encoding|encoding|e=s' => \$encoding,

	   ##-- I/O: output
	   'format-file|ff|output-file|output|o=s' => \$outfile,

	   ##-- debugging
	   'trace-request|trace|request|tr=s' => \$trace_request_file, ##-- not implemented here

	   ##-- Log4perl
	   DTA::CAB::Logger->cabLogOptions('verbose'=>1),
	  );

if ($version) {
  print STDERR
    ("${prog} (DTA::CAB version $DTA::CAB::VERSION) by Bryan Jurish <jurish\@bbaw.de>\n",
     '  $HeadURL: svn+ssh://odo.dwds.de/home/svn/dev/DTA-CAB/trunk/dta-cab-xmlrpc-client.perl $', "\n",
     '  $Id: dta-cab-xmlrpc-client.perl 4476 2010-11-30 14:19:08Z moocow $', "\n",
    );
  exit(0);
}

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);


##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
DTA::CAB::Logger->logInit();

##-- sanity checks
$serverURL = "http://$serverURL" if ($serverURL !~ m|[^:]+://|);
if ($serverURL =~ m|([^:]+://[^/:]*)(/[^:]*)$|) {
  $serverURL = "$1:${defaultPort}$2";
}

##-- trace request file?
our $tracefh = undef;
if (defined($trace_request_file)) {
  $tracefh = IO::File->new(">$trace_request_file")
    or die("$0: open failed for trace file '$trace_request_file': $!");
}

##-- create client object
our $cli = DTA::CAB::Client::HTTP->new(%clientOpts,
				       serverURL => $serverURL,
				       encoding => $encoding,
				       tracefh=>$tracefh,
				      );
$cli->connect() or die("$0: connect() failed: $!");

##======================================================
## Input & Output Formats

our $isFileAction = ($action =~ m(data|doc|raw|bench));
$formatOpts{encoding} = $encoding;

##-- sanity check
die("$prog: unknown format class '$formatClass'")
  if (defined($formatClass) && !DTA::CAB::Format->newFormat($formatClass));

$ifmt = DTA::CAB::Format->newReader(class=>$formatClass, ($isFileAction ? (file=>$ARGV[0]) : qw()),%formatOpts)
  or die("$0: could not create input parser of class $formatClass: $!");

if (defined($formatClass) || $outfile ne '-') {
  $ofmt = DTA::CAB::Format->newWriter(class=>$formatClass, file=>$outfile, %formatOpts);
} else {
  $ofmt = $ifmt;
}
die("$0: could not create output formatter of class $formatClass: $!") if (!$ofmt);

DTA::CAB->debug("using input format class ", ref($ifmt));
DTA::CAB->debug("using output format class ", ref($ofmt));

##-- analysis options
$analyzeOpts{fmt}         = $ifmt->shortName;
$analyzeOpts{contentType} = $ifmt->mimeType;

##-- input file
push(@ARGV,'-') if (!@ARGV && $isFileAction);

##-- output file
our $outfh = IO::File->new(">$outfile")
  or die("$0: open failed for output file '$outfile': $!");

##======================================================
## Profiling

our $ntoks = 0;
our $nchrs = 0;
our $cunit = 'chr';

our @tv_values = qw();
sub profile_start {
  return if (scalar(@tv_values) % 2 != 0); ##-- timer already running
  push(@tv_values,[gettimeofday]);
}
sub profile_stop {
  return if (scalar(@tv_values) % 2 == 0); ##-- timer already stopped
  push(@tv_values,[gettimeofday]);
}
sub profile_elapsed {
  my ($started,$stopped);
  my @values = @tv_values;
  my $elapsed = 0;
  while (@values) {
    ($started,$stopped) = splice(@values,0,2);
    $stopped  = [gettimeofday] if (!defined($stopped));
    $elapsed += tv_interval($started,$stopped);
  }
  return $elapsed;
}

profile_start() if ($doProfile);

##======================================================
## Actions

if ($action eq 'list') {
  ##-- action: list
  my @anames = $cli->analyzers;
  $outfh->print("$0: analyzer list for $serverURL\n", map { "$_\n" } @anames);
}
elsif ($action eq 'token') {
  ##-- action: 'tokens'
  $doProfile = 0;
  foreach $tokin (map {DTA::CAB::Utils::deep_decode($encoding,$_)} @ARGV) {
    $tokout = $cli->analyzeToken($analyzer, $tokin, \%analyzeOpts);
    $ofmt->putTokenRaw($tokout);
  }
  $ofmt->toFh($outfh);
}
elsif ($action eq 'sentence') {
  ##-- action: 'sentence'
  $doProfile = 0;
  our $s_in  = DTA::CAB::Utils::deep_decode($encoding, toSentence([map {toToken($_)} @ARGV]));
  our $s_out = $cli->analyzeSentence($analyzer, $s_in, \%analyzeOpts);
  $ofmt->putSentenceRaw($s_out);
  $ofmt->toFh($outfh);
}
elsif ($action eq 'data' || $action eq 'document' || $action eq 'raw') {
  $cunit = 'bytes';
  $analyzeOpts{qraw} = 1 if ($action eq 'raw');

  ##-- action: 'data': do server-side parsing
  our ($s_in,$s_out);
  push(@ARGV,'-') if (!@ARGV);
  foreach $doc_filename (@ARGV) {
    open(DOC,"<$doc_filename") or die("$0: open failed for input file '$doc_filename': $!");
    {
      local $/=undef;
      $s_in = <DOC>;
      close(DOC);
    }
    $s_out = $cli->analyzeData($analyzer, $s_in, {%analyzeOpts});
    $outfh->print( $s_out );
    if ($doProfile) {
      $nchrs += length($s_in);
      ##-- count tokens, pausing profile timer
      profile_stop();
      $ntoks += $ofmt->parseString($s_out)->nTokens;
      profile_start();
    }
  }
}
elsif ($action eq 'bench') {
  $doProfile=1;
  our ($bench_i);
  our ($d_in,$w_in,$w_out);
  $bench_iters = 1 if (!$bench_iters);
  foreach $doc_filename (@ARGV) {
    $d_in = $ifmt->parseFile($doc_filename)
      or die("$0: parse failed for input file '$doc_filename': $!");
    foreach $bench_i (1..$bench_iters) {
      profile_start();
      foreach $w_in (map {@{$_->{tokens}}} @{$d_in->{body}}) {
	$w_out = $cli->analyzeToken($analyzer, $w_in, \%analyzeOpts);
      }
      profile_stop();
    }
    #$ofmt->putDocumentRaw($d_out);
    if ($doProfile) {
      $ntoks += $bench_iters * $d_in->nTokens();
      $nchrs += $bench_iters * $d_in->nChars();
    }
  }
}
else {
  die("$0: unknown action '$action'");
}
$cli->disconnect();

##-- profiling
DTA::CAB::Logger->logProfile('info', profile_elapsed, $ntoks, $nchrs) if ($doProfile);
DTA::CAB::Logger->trace("client exiting normally.");

__END__
=pod

=head1 NAME

dta-cab-http-client.perl - Generic HTTP client for DTA::CAB::Server::HTTP queries

=head1 SYNOPSIS

 dta-cab-http-client.perl [OPTIONS...] ARGUMENTS

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit
  -verbose LEVEL                  ##-- set default log level

 Client Options:
  -server URL                     ##-- set server URL (default: http://localhost:9099)
  -timeout SECONDS                ##-- set server timeout in seconds (default: lots)
  -test-connect , -notest-connect ##-- do/don't send a test request to the server (default: do)
  -trace FILE                     ##-- trace request(s) sent to the server to FILE
  -get                            ##-- query server using URL-only GET requests
  -post                           ##-- query server using use content-only POST requests
  -multipart    , -nomultipart    ##-- for POST requests, do/don't use 'multipart/form-data' encoding (default=don't)
  -xpost                          ##-- query server using URL+content POST requests (default)
  -xmlrpc                         ##-- query server using XML-RPC requests

 Analysis Options:
  -list                           ##-- just list registered analyzers
  -analyzer NAME                  ##-- set analyzer name (default: 'default')
  -analyze-option OPT=VALUE       ##-- set analysis option (default: none)
  -profile , -noprofile           ##-- do/don't report profiling information (default: do)
  -token                          ##-- ARGUMENTS are token text
  -sentence                       ##-- ARGUMENTS are analyzed as a sentence
  -document                       ##-- ARGUMENTS are filenames, analyzed as documents (default)
  -data                           ##-- ARGUMENTS are filenames, analyzed as documents (same as '-document')
  -raw                            ##-- ARGUMENTS are filenames, analyzed as raw text

 I/O Options:
  -format-class CLASS             ##-- select I/O format class (default: TT)
  -format-option OPT=VALUE        ##-- set I/O format option
  -format-encoding ENCODING       ##-- override I/O encoding (default: 'UTF-8')
  -format-level LEVEL             ##-- override output formatter level (default: 1)
  -output-file FILE               ##-- set output file (default: STDOUT)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

dta-cab-http-client.perl is a command-line client for L<DTA::CAB|DTA::CAB>
analysis of token(s), sentence(s), and/or document(s) by
querying a running L<DTA::CAB::Server::HTTP|DTA::CAB::Server::HTTP> server
with the L<DTA::CAB::Client::HTTP|DTA::CAB::Client::HTTP> module.

See L<dta-cab-http-server.perl(1)|dta-cab-http-server.perl> for a
corresponding server.

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

=item -verbose

Set default log level (trace|debug|info|warn|error|fatal).

=back

=cut

##==============================================================================
## Options: Client Options
=pod

=head2 Client Options

=over 4

=item -server URL

Set server URL (default: localhost:8000).

=item -timeout SECONDS

Set server timeout in seconds (default: lots).

=item -test-connect , -notest-connect

Do/don't send a test HEAD request to the server (default: do).

=item -trace FILE

If specified, all client requests will be logged to FILE.

=back

=cut


##==============================================================================
## Options: Analysis Options
=pod

=head2 Analysis Options

=over 4

=item -list

Don't actually perform any analysis;
rather,
just print a list of analyzers registered with the server.

=item -analyzer NAME

Request analysis by the analyzer registered under name NAME (default: 'default').

=item -analyze-option OPT=VALUE

Set an arbitrary analysis option C<OPT> to C<VALUE>.
May be multiply specified.

Available options depend on the analyzer class to be called.

=item -profile , -noprofile

Do/don't report profiling information (default: do).

=item -token

Interpret ARGUMENTS as token text.

=item -sentence

Interpret ARGUMENTS as a sentence (list of tokens).

=item -document

Interpret ARGUMENTS as filenames, to be analyzed as documents.
This is the default action.

=item -data

Currently just an alias for -document.

=back

=cut

##==============================================================================
## Options: I/O Options
=pod

=head2 I/O Options

=over 4

=item -format-class CLASS

Select I/O format class B<CLASS>.  Default is TT.
B<CLASS> may be any alias supported by
L<DTA::CAB::Format::newFormat|DTA::CAB::Format/newFormat>.

=item -format-option OPT=VALUE

Set an arbitrary I/O format option.
May be multiply specified.

=item -format-encoding ENCODING

Set I/O encoding; default=UTF-8.

=item -format-level LEVEL

Override output format level (default: 1).

=item -output-file FILE

Set output file (default: STDOUT).

=back

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

Copyright (C) 2010 by Bryan Jurish

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<dta-cab-cachegen.perl(1)|dta-cab-cachegen.perl>,
L<dta-cab-http-server.perl(1)|dta-cab-http-server.perl>,
L<dta-cab-http-client.perl(1)|dta-cab-http-client.perl>,
L<dta-cab-xmlrpc-server.perl(1)|dta-cab-xmlrpc-server.perl>,
L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<RPC::XML(3pm)|RPC::XML>,
L<perl(1)|perl>,
...

=cut
