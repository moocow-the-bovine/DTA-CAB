y#!/usr/bin/perl -w

use RPC::XML;
use RPC::XML::Client;
use RPC::XML::Parser;
use Encode qw(encode decode);
use Getopt::Long qw(:config no_ignore_case);
use File::Basename qw(basename);
use Data::Dumper;
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

##-- Server Options
our $do_eval = 0;
our $do_array = 0;
our $server = 'http://localhost:8088';

##-- I/O
our $fromfile = undef;
our $outfile  = '-';

##-- defaults
our $local_encoding = undef;
our $server_encoding = undef;
our $force_strings = 0;

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|m'     => \$man,
	   'version|V' => \$version,

	   ##-- XML-RPC Options
	   'server|s=s'    => \$server,
	   'from|file|f=s' => \$fromfile,    ##-- read literal query from file
	   'eval|e!' => \$do_eval,
	   'array|a!' => \$do_array,
	   'local-encoding|le=s' => \$local_encoding,   ##-- decode() + encode()
	   'server-encoding|se=s' => \$server_encoding, ##-- encode() + decode()
	   'strings-only|S' => \$force_strings,         ##-- force strings?
	   'dump|d!' => \$dump,
	   'outfile|o=s' => \$outfile,
	  );

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({-exitval=>1, -verbose=>0, -message=>'No method or source file specified!'}) if (!@ARGV && !$fromfile);

if ($version) {
  print STDERR
    ("${prog} v$VERSION by Bryan Jurish <moocow\@bbaw.de>\n");
  exit(0);
}

##==============================================================================
## MAIN

$server  = 'http://'.$server if ($server !~ m|//|);
$server  =~ s{^([^/]*//[^/:]*)/}{$1:8088/};

##-- setup RPC::XML hacks
$RPC::XML::ENCODING = $server_encoding if (defined($server_encoding));
$RPC::XML::FORCE_STRING_ENCODING = $force_strings if (defined($force_strings));

##-- setup request
my ($req);
if ($fromfile) {
  ##-- read requesst from file
  open(FROM,"<$fromfile") or die("$prog: open failed for source file '$fromfile': $!");
  $req = RPC::XML::Parser->new()->parse(\*FROM)
    or die("$prog: could not parse XML-RPC request from file '$fromfile': $!");
  close(FROM);
} else {
  my $method = shift(@ARGV);
  my @args   = map {$do_eval ? eval($_) : $_} @ARGV;
  @args = ( [@args] ) if ($do_array);
  $req = RPC::XML::request->new($method,@args)  ##-- implicitly calls RPC::XML::smart_encode()
  or die("$prog: could not create XML-RPC request from command-line: $!");
}

##-- encoding black magic (ugly ugly ugly)
$req->{name} = decode($local_encoding,$req->{name})  if (defined($local_encoding)  && !utf8::is_utf8($req->{name}));
$req->{name} = encode($server_encoding,$req->{name}) if (defined($server_encoding) &&  utf8::is_utf8($req->{name}));
my @queue = ($req->{args});
while (defined($ar=shift(@queue))) {
  if (UNIVERSAL::isa($ar,'ARRAY')) {
    push(@queue, @$ar);
  }
  elsif (UNIVERSAL::isa($ar,'HASH')) {
    push(@queue, values(%$ar));
  }
  elsif (UNIVERSAL::isa($ar,'SCALAR')) {
    $$ar = decode($local_encoding,$$ar) if (defined($local_encoding) && !utf8::is_utf8($$ar));
    $$ar = encode($server_encoding,$$ar) if (defined($server_encoding) && utf8::is_utf8($$ar));
  }
}

##-- setup client & send off request
my $cli = RPC::XML::Client->new($server)
  or die("$prog: could not create client for server '$server': $!");

my $rsp = $cli->send_request($req)
  or die("$prog: send_request() failed: $!");
if (!ref($rsp)) {
  print STDERR "XML-RPC Error: $rsp\n";
  exit 1;
}

open(OUT,">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");

if ($dump) {
  ##-- dump value
  my $val = $rsp->value;
  print OUT Data::Dumper->new([$val],['response'])->Sortkeys(1)->Indent(1)->Dump, "\n";
} else {
  ##-- output XML-RPC string
  my $rspstr = $rsp->as_string;
  $rspstr = decode($server_encoding, $rspstr) if (defined($server_encoding) && !utf8::is_utf8($rspstr));
  $rspstr = encode($server_encoding, $rspstr) if (defined($server_encoding) &&  utf8::is_utf8($rspstr));
  #$rspstr = encode($local_encoding,$rspstr)   if (defined($local_encoding));

  print OUT
    ('<?xml version="1.0"', (defined($server_encoding) ? " encoding=\"$server_encoding\"" : qw()), "?>\n",
     $rspstr,
     "\n",
    );
}

__END__
=pod

=head1 NAME

xmlrpc-call.perl - XML RPC command-line tool

=head1 SYNOPSIS

 xmlrpc-call.perl [OPTIONS] METHOD [ARG(s)...]

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit

 Encoding Options:
  -local-encoding ENCODING        ##-- decode query from ENCODING
  -server-encoding ENCODING       ##-- encode query to ENCODING

 XML-RPC Options:
  -eval , -noeval                 ##-- do/don't eval command-line args as perl code (default=don't)
  -array , -noarray               ##-- do/don't implicitly create an array of arguments (default=don't)
  -server  URL                    ##-- set server URL (default: http://localhost:8088)
  -from    INPUT_FILE             ##-- read literal query from INPUT_FILE (default=command line)
  -output  OUTPUT_FILE            ##-- XML output (default=-)
  -dump                           ##-- if true, just dump value with Data::Dumper

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
## Options: XML-RPC Options
=pod

=head2 XML-RPC Options

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

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2019 by Bryan Jurish. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

perl(1),
RPC::XML(3perl).

=cut


