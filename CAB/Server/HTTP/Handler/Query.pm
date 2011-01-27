##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::Query.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + CAB HTTP Server: request handler: analyzer queries by CGI form
##======================================================================

package DTA::CAB::Server::HTTP::Handler::Query;
use DTA::CAB::Server::HTTP::Handler::CGI;
use HTTP::Status;
use URI::Escape qw(uri_escape uri_escape_utf8);
use Encode qw(encode decode);
use CGI ':standard';
use Carp;
use strict;

##--------------------------------------------------------------
## Globals

our @ISA = qw(DTA::CAB::Server::HTTP::Handler::CGI);

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'Query' => __PACKAGE__,
						 'analyzerCGI' => __PACKAGE__,
						 'analyzercgi' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## Methods: API

## $h = $class_or_obj->new(%options)
## %$h, %options:
##  (
##   ##-- INHERITED from Handler::CGI
##   encoding => $defaultEncoding,  ##-- default encoding (UTF-8)
##   allowGet => $bool,             ##-- allow GET requests? (default=1)
##   allowPost => $bool,            ##-- allow POST requests? (default=1)
##   allowList => $bool,            ##-- if true, allowed analyzers will be listed for 'PATHROOT/.../list' paths
##   pushMode => $mode,             ##-- push mode for addVars (default='keep')
##   ##
##   ##-- NEW in Handler::Query
##   prefix => $prefix,             ##-- analyzer name prefix (automatically trimmed; default='dta.cab.')
##   allowAnalyzers => \%analyzers, ##-- set of allowed analyzers ($allowedAnalyzerName=>$bool, ...) -- default=undef (all allowed)
##   defaultAnalyzer => $aname,     ##-- default analyzer name (default = 'default')
##   formats => $registry,          ##-- registry of allowed formats; default=$DTA::CAB::Format::REG
##   defaultFormat => $class,       ##-- default format (default=$DTA::CAB::Format::CLASS_DEFAULT)
##   allowUserOptions => $bool,     ##-- allow user options to analyzeDocument()? (default=1)
##   forceClean => $bool,           ##-- always appends 'doAnalyzeClean'=>1 to options if true (default=false)
##   returnRaw => $bool,            ##-- return all data as text/plain? (default=0)
##   logVars => $level,             ##-- log-level for variable expansion (default=undef: none)
##  )
sub new {
  my $that = shift;
  my $h =  $that->SUPER::new(
			     encoding=>'UTF-8', ##-- default CGI parameter encoding
			     allowGet=>1,
			     allowPost=>1,
			     allowList=>1,
			     logVars => undef,
			     pushMode => 'keep',
			     allowAnalyzers=>undef,
			     prefix => 'dta.cab.',
			     defaultAnalyzer=>'default',
			     formats => $DTA::CAB::Format::REG,
			     defaultFormat => $DTA::CAB::Format::CLASS_DEFAULT,
			     allowUserOptions => 1,
			     forceClean => 0,
			     returnRaw => 0,
			     @_,
			    );
  return $h;
}

## $bool = $h->prepare($server)
##  + sets $h->{allowAnalyzers} if not already defined
sub prepare {
  my ($h,$srv) = @_;
  $h->{allowAnalyzers} = { map {($_=>1)} keys %{$srv->{as}} } if (!$h->{allowAnalyzers});
  return 1;
}

## $bool = $path->run($server, $localPath, $clientSocket, $httpRequest)
## + process $httpRequest as CGI form-encoded query
##
## + analyzer list
##   if $localPath ends in '/list', a list of analyzers will be returned,
##   encoded accroding to the 'format' form variable.
##
## + form parameters:
##   (
##    q    => $queryString,          ##-- raw, untokenized query string (preferred over 'qd')
##    qd   => $queryData,            ##-- query data (formatted document)
##    a    => $analyzerName,         ##-- analyzer key in %{$h->{allowAnalyzers}}, %{$srv->{as}}
##    fmt  => $queryFormat,          ##-- query/response format (default=$h->{defaultFormat})
##    enc  => $queryEncoding,        ##-- query encoding (default='UTF-8')
##    raw  => $bool,                 ##-- if true, data will be returned as text/plain (default=$h->{returnRaw})
##    pretty => $level,              ##-- response format level
##    ##
##    $opt => $value,                ##-- other options are passed to analyzeDocument() (if $h->{allowUserOptions} is true)
##   )
our %localParams = map {($_=>undef)} qw(q qd a fmt enc raw pretty);
sub run {
  my ($h,$srv,$path,$c,$hreq) = @_;

  ##-- check for HEAD
  return $h->headResponse() if ($hreq->method eq 'HEAD');

  ##-- check for LIST
  my @upath = $hreq->uri->path_segments;
  return $h->runList($srv,$path,$c,$hreq) if ($upath[$#upath] eq 'list');

  ##-- parse query parameters
  my $vars = $h->cgiParams($c,$hreq,defaultName=>'qd') or return undef;
  return $h->cerror($c, undef, "no query parameters specified!") if (!$vars || !%$vars);
  $h->vlog($h->{logVars}, "got query params:\n", Data::Dumper->Dump([$vars],['vars'])) if ($h->{logVars});

  ##-- get parameters: encodings
  my $enc = $h->getEncoding(@$vars{qw(encoding enc)},$hreq,$h->{encoding});
  return $h->cerror($c, undef, "unknown encoding '$enc'") if (!defined(Encode::find_encoding($enc)));

  ##-- pre-process query parameters
  $h->decodeVars($vars, vars=>[qw(q a format fmt)], allowHtmlEscapes=>0);
  $h->trimVars($vars,  vars=>[qw(q a format fmt)]);

  ##-- get analyzer $a
  my $akey = $vars->{'a'} || $h->{defaultAnalyzer};
  $akey =~ s/^\Q$h->{prefix}\E// if (defined($h->{prefix})); ##-- trim leading prefix
  if ($h->{allowAnalyzers} && !$h->{allowAnalyzers}{$akey}) {
    return $h->cerror($c, RC_FORBIDDEN, "access denied for analyzer '$akey'");
  }
  elsif (!defined($a=$srv->{as}{$akey})) {
    return $h->cerror($c, RC_NOT_FOUND, "unknown analyzer '$akey'");
  }

  ##-- get analyzer options
  my %ao = $srv->{aos}{$akey} ? %{$srv->{aos}{$akey}} : qw();
  if ($h->{allowUserOptions}) {
    foreach (grep {!exists $localParams{$_}} keys %$vars) {
      $ao{$_} = $vars->{$_};
    }
  }
  $ao{doAnalyzeClean}=1 if ($h->{forceClean});

  ##-- get format class
  my $fc  = $vars->{format} || $vars->{fmt} || $h->{defaultFormat};
  my $fmt = $h->{formats}->newFormat($fc, encoding=>$enc, level=>$vars->{pretty})
    or return $h->cerror($c, undef, "unknown format '$fc'");

  ##-- parse input query
  my ($qdoc);
  if (defined($vars->{q})) {
    my $qsrc = defined($vars->{q}) ? $vars->{q} : '';
    $qsrc    = join("\n", @$qsrc) if (ref($qsrc));
    my $qfmt = $h->{formats}->newFormat('raw', encoding=>$enc)
      or return $h->cerror($c, undef, "cannot create 'raw' format for query parameter 'q'");
    $qdoc = $qfmt->parseString($vars->{q})
      or $qfmt->logwarn("parseString() failed for raw query parameter 'q'");
  }
  elsif (defined($vars->{qd})) {
    $qdoc = $fmt->parseString($vars->{qd})
      or $fmt->logwarn("parseString() failed for query parameter 'qd' via format '$fc'");
  }
  else {
    return $h->cerror($c, undef, "no query specified: use either the 'q' or 'qd' parameter!");
  }
  return $h->cerror($c, undef, "could not parse input query: $@") if (!$qdoc);

  ##-- analyze
  $qdoc = $a->analyzeDocument($qdoc, \%ao)
    or return $h->cerror($c, undef, "analyzeDocument() failed");

  ##-- format
  my $rstr = $fmt->flush->putDocument($qdoc)->toString;
  $rstr    = encode($enc,$rstr) if (utf8::is_utf8($rstr));
  return $h->cerror($c, undef, "could format output document using format '$fc': $@") if (!defined($rstr));

  ##-- dump to client
  my $filename = defined($vars->{q}) ? $vars->{q} : 'data';
  $filename =~ s/\W.*$/_/;
  $filename .= $fmt->defaultExtension;
  return $h->dumpResponse(\$rstr,
			  raw=>$vars->{raw},
			  type=>$fmt->mimeType,
			  charset=>$enc,
			  filename=>$filename);
}

## $response = $h->runList($h,$srv,$path,$c,$hreq)
##  + guts for analyzer list
##  + accepted form parameters:
##     a => $regex       ##-- regex of analyzers match
##     enc => $encoding, ##-- query/return encoding
##     fmt => $format,   ##-- format to return list in
sub runList {
  my ($h,$srv,$path,$c,$hreq) = @_;

  ##-- check for LIST
  return $h->cerror($c,RC_NOT_FOUND,"/list path disabled") if (!$h->{allowList});

  ##-- parse list query parameters
  my $vars = $h->cgiParams($c,$hreq) or return undef;
  $h->vlog('debug', "got query params:\n", Data::Dumper->Dump([$vars],['vars']));

  my $enc = $h->getEncoding(@$vars{qw(enc encoding)},$hreq,$h->{encoding});
  return $h->cerror($c, undef, "unknown encoding '$enc'") if (!defined(Encode::find_encoding($enc)));

  $h->decodeVars($vars, vars=>[qw(a fmt format)], encoding=>$enc, allowHtmlEscapes=>0);
  $h->trimVars($vars,  vars=>[qw(a fmt format)]);

  ##-- get matching analyzers
  my $qre = defined($vars->{a}) ? qr/$vars->{a}/ : qr//;
  my @as  = (grep {$_ =~ $qre}
	     grep {!defined($h->{allowAnalyzers}) || $h->{allowAnalyzers}{$_}}
	     sort
	     #map  {($_,defined($h->{prefix}) ? "$h->{prefix}$_" : qw())}
	     keys %{$srv->{as}});

  ##-- get format
  my $fc  = $vars->{format} || $vars->{fmt} || $h->{defaultFormat};
  my $fmt = $h->{formats}->newFormat($fc,encoding=>$enc,level=>$vars->{pretty})
    or return $h->cerror($c, undef, "unknown format '$fc': $@");

  ##-- dump analyzers
  $fmt->{raw} = 1; ##-- hack to allow format dump of raw (non-document) data
  my ($ostr);
  if ($fmt->isa('DTA::CAB::Format::TT')) {
    $ostr = join("\n", @as,'');
  }
  elsif ($fmt->isa('DTA::CAB::Format::XmlNative')) {
    $fmt->{arrayEltKeys}{tokens} = 'a';
    $fmt->{key2xml}{text} = 'name';
    $fmt->putDocument({tokens=>[map {{text=>$_}} @as]});
    my $odoc = $fmt->xmlDocument;
    $odoc->documentElement->setNodeName('analyzers');
    ##
    $ostr = $fmt->toString;
  }
  else {
    $ostr = $fmt->putData(\@as)->toString;
  }
  $ostr = encode($enc,$ostr) if (utf8::is_utf8($ostr));

  ##-- dump response
  return $h->dumpResponse(\$ostr,
			  raw=>$vars->{raw},
			  type=>$fmt->mimeType,
			  charset=>$enc,
			  filename=>("analyzers".$fmt->defaultExtension),
			 );
}

## $rsp = $h->dumpResponse(\$contentRef, %opts)
##  + Create and return a new data-dump response.
##    Known %opts:
##    (
##     raw => $bool,      ##-- return raw data (text/plain) ; defualt=$h->{returnRaw}
##     type => $mimetype, ##-- mime type if not raw mode
##     charset => $enc,   ##-- character set, if not raw mode
##     filename => $file, ##-- attachment name, if not raw mode
##    )
sub dumpResponse {
  my ($h,$dataref,%vars) = @_;
  my $returnRaw   = defined($vars{raw}) ? $vars{raw} : $h->{returnRaw};
  my $contentType = ($returnRaw || !$vars{type} ? 'text/plain' : $vars{type});
  $contentType   .= "; charset=$vars{charset}" if ($vars{charset} && $contentType !~ m|application/octet-stream|);
  ##
  my $rsp = $h->response(RC_OK);
  $rsp->content_type($contentType);
  $rsp->content_ref($dataref) if (defined($dataref));
  $rsp->header('Content-Disposition' => "attachment; filename=\"$vars{filename}\"") if ($vars{filename} && !$returnRaw);
  return $rsp;
}

##--------------------------------------------------------------
## Methods: Local

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Server::HTTP::Handler::Query - CAB HTTP Server: request handler: analyzer queries by CGI form

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Server::HTTP::Handler::Query;
 
 ##========================================================================
 ## Methods: API
 
 $h = $class_or_obj->new(%options);
 $bool = $h->prepare($server);
 $bool = $path->run($server, $localPath, $clientSocket, $httpRequest);
 $response = $h->runList($h,$srv,$path,$c,$hreq);
 $rsp = $h->dumpResponse(\$contentRef, %opts);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Server::HTTP::Handler::Query
is a request handler class for use with a
L<DTA::CAB::Server::HTTP|DTA::CAB::Server::HTTP> server
which handles queries to selected server-supported analyzers
submitted as CGI-style forms.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP::Handler::Query: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Server::HTTP::Handler::Query inherits from
L<DTA::CAB::Server::HTTP::Handler::CGI> and implements the
L<DTA::CAB::Server::HTTP::Handler> API.

=item Variable: (%allowFormats);

Default allowed formats.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server::HTTP::Handler::Query: Methods: API
=pod

=head2 Methods: API

=over 4

=item new

 $h = $class_or_obj->new(%options);

%$h, %options:

  (
   ##-- INHERITED from Handler::CGI
   encoding => $defaultEncoding,  ##-- default encoding (UTF-8)
   allowGet => $bool,             ##-- allow GET requests? (default=1)
   allowPost => $bool,            ##-- allow POST requests? (default=1)
   allowList => $bool,            ##-- if true, allowed analyzers will be listed for 'PATHROOT/.../list' paths
   pushMode => $mode,             ##-- push mode for addVars (default='keep')
   ##
   ##-- NEW in Handler::Query
   allowAnalyzers => \%analyzers, ##-- set of allowed analyzers ($allowedAnalyzerName=>$bool, ...) -- default=undef (all allowed)
   defaultAnalyzer => $aname,     ##-- default analyzer name (default = 'default')
   allowFormats => \%formats,     ##-- allowed formats: ($fmtAlias => $formatClassName, ...)
   defaultFormat => $class,       ##-- default format (default=$DTA::CAB::Format::CLASS_DEFAULT)
   forceClean => $bool,           ##-- always appends 'doAnalyzeClean'=>1 to options if true (default=false)
   returnRaw => $bool,            ##-- return all data as text/plain? (default=0)
   logVars => $level,             ##-- log-level for variable expansion (default=undef: none)
  )

=item prepare

 $bool = $h->prepare($server);

Sets $h-E<gt>{allowAnalyzers} if not already defined.

=item run

 $bool = $path->run($server, $localPath, $clientSocket, $httpRequest);

Process $httpRequest matching $localPath as CGI form-encoded query.

If $localPath ends in '/list', a list of analyzers will be returned,
encoded accroding to the 'format' form variable (see L</runList>).

Otherwise, the following CGI form parameters are supported:

 (
  ##-- query data, in order of preference
  data => $docData,              ##-- document data (for analyzeDocument())
  q    => $rawQuery,             ##-- raw untokenized query string (for analyzeDocument())
  ##
  ##-- misc
  a => $analyer,                 ##-- analyzer key in %{$srv->{as}}
  format => $format,             ##-- I/O format
  encoding => $enc,              ##-- I/O encoding
  pretty => $level,              ##-- pretty-printing level
  raw => $bool,                  ##-- if true, data will be returned as text/plain (default=$h->{returnRaw})
 )

=item runList

 $response = $h->runList($h,$srv,$path,$c,$hreq);

Guts for '/list' requests.

=item dumpResponse

 $rsp = $h->dumpResponse(\$contentRef, %opts);

Create and return a new data-dump response.
Known %opts:

 (
  raw => $bool,      ##-- return raw data (text/plain) ; defualt=$h->{returnRaw}
  type => $mimetype, ##-- mime type if not raw mode
  charset => $enc,   ##-- character set, if not raw mode
  filename => $file, ##-- attachment name, if not raw mode
 )

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<DTA::CAB::Server::HTTP::Handler::CGI(3pm)|DTA::CAB::Server::HTTP::Handler::CGI>,
L<DTA::CAB::Server::HTTP::Handler(3pm)|DTA::CAB::Server::HTTP::Handler>,
L<DTA::CAB::Server::HTTP(3pm)|DTA::CAB::Server::HTTP>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...

=cut
