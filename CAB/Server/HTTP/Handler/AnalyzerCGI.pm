##-*- Mode: CPerl -*-

## File: DTA::CAB::Server::HTTP::Handler::AnalyzerCGI.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description:
##  + DTA::CAB::Server::HTTP::Handler class: analyzer CGI
##======================================================================

package DTA::CAB::Server::HTTP::Handler::AnalyzerCGI;
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

## %allowFormats
##  + default allowed formats
our (%allowFormats);
BEGIN {
  foreach (qw(CSV JSON Null Perl Storable Text TT Xml XmlNative XmlPerl XmlRpc YAML)) {
    $allowFormats{$_}=$allowFormats{lc($_)}=$allowFormats{uc($_)} = "DTA::CAB::Format::$_";
  }
}

##--------------------------------------------------------------
## Aliases
BEGIN {
  DTA::CAB::Server::HTTP::Handler->registerAlias(
						 'AnalyzerCGI' => __PACKAGE__,
						 'analyzerCGI' => __PACKAGE__,
						 'analyzercgi' => __PACKAGE__,
						);
}

##--------------------------------------------------------------
## Methods: API

## $handler = $class_or_obj->new(%options)
## + %options:
##     ##-- INHERITED from Handler::CGI
##     encoding => $defaultEncoding,  ##-- default encoding (UTF-8)
##     allowGet => $bool,             ##-- allow GET requests? (default=1)
##     allowPost => $bool,            ##-- allow POST requests? (default=1)
##     ##
##     ##-- NEW in Handler::AnalyzerCGI
##     allowAnalyzers => \%analyzers, ##-- set of allowed analyzers ($allowedAnalyzerName=>$bool, ...) -- default=undef (all allowed)
##     defaultAnalyzer => $aname,     ##-- default analyzer name (default = 'default')
##     allowFormats => \%formats,     ##-- allowed formats: ($fmtAlias => $formatClassName, ...)
##     defaultFormat => $class,       ##-- default format (default=$DTA::CAB::Format::CLASS_DEFAULT)
##     forceClean => $bool,           ##-- always appends 'doAnalyzeClean'=>1 to options if true (default=false)
##     returnRaw => $bool,            ##-- return all data as text/plain? (default=0)
##
## + runtime %$handler data:
##     ##-- INHERITED from Handler::CGI
##     cgi => $cgiobj,                ##-- CGI object (after cgiParse())
##     vars => \%vars,                ##-- CGI variables (after cgiParse())
##     cgisrc => $cgisrc,             ##-- CGI source (after cgiParse())
##
## + CGI parameters:
##     ##-- query data, in order of preference
##     d => $docData,                 ##-- document data (for analyzeDocument())
##     q => $rawQuery,                ##-- raw untokenized query string (for analyzeDocument())
##     ##
##     ##-- misc
##     a => $analyer,                 ##-- analyzer key in %{$srv->{as}}
##     fmt => $format,                ##-- I/O format
##     encoding => $enc,              ##-- I/O encoding
##     pretty => $level,              ##-- pretty-printing level
##     raw => $bool,                  ##-- if true, data will be returned as text/plain (default=$handler->{returnRaw})
sub new {
  my $that = shift;
  my $handler =  $that->SUPER::new(
				   encoding=>'UTF-8', ##-- default CGI parameter encoding
				   allowGet=>1,
				   allowPost=>1,
				   allowAnalyzers=>undef,
				   defaultAnalyzer=>'default',
				   allowFormats => {%allowFormats},
				   defaultFormat => $DTA::CAB::Format::CLASS_DEFAULT,
				   forceClean => 0,
				   returnRaw => 0,
				   @_,
				  );
  return $handler;
}

## $bool = $handler->prepare($server)
##  + sets $handler->{allowAnalyzers} if not already defined
sub prepare {
  my ($handler,$srv) = @_;
  $handler->{allowAnalyzers} = { map {($_=>1)} keys %{$srv->{as}} } if (!$handler->{allowAnalyzers});
  return 1;
}

## $bool = $path->run($server, $localPath, $clientSocket, $httpRequest)
##  + local processing
sub run {
  my ($handler,$srv,$path,$csock,$hreq) = @_;

  ##-- parse query parameters
  my $cgi  = $handler->cgiParse($srv,$path,$csock,$hreq) or return undef;
  my $vars = $handler->{vars};
  my $enc  = $vars->{encoding} || $handler->{encoding};

  ##-- get analyzer $a
  my $akey = $vars->{'a'} || $handler->{defaultAnalyzer};
  if ($handler->{allowAnalyzers} && !$handler->{allowAnalyzers}{$akey}) {
    return $srv->clientError($csock, RC_FORBIDDEN, "access denied for analyzer '$akey'");
  }
  elsif (!defined($a=$srv->{as}{$akey})) {
    return $srv->clientError($csock, RC_NOT_FOUND, "unknown analyzer '$akey'");
  }
  my $ao = $srv->{aos}{$akey} || {};

  ##-- decode query parameters
  #$handler->decodeVars($vars,[qw(d s w q a fmt)], $enc);
  $handler->decodeVars($vars,[qw(d q a fmt)], $enc);

  ##-- local vars
  my ($fclass,$fmt, $qdoc,$ostr);
  eval {
    #local $SIG{__DIE__} = sub { goto cgirun_end; };

    ##-- get formatter
    if (defined($vars->{fmt}) && !defined($fclass=$handler->{allowFormats}{$vars->{fmt}})) {
      return $srv->clientError($csock, RC_NOT_FOUND, "unknown format '$vars->{fmt}'");
    }
    $fclass = $handler->{defaultFormat} if (!defined($fclass));
    $fmt = $fclass->new(level=>$vars->{pretty}, encoding=>$enc);
    return $srv->clientError($csock,RC_INTERNAL_SERVER_ERROR,"could not parse input query: $@") if (!$fmt);

    ##-- parse input query
    if (defined($vars->{d})) {
      $qdoc = $fmt->parseString($vars->{d}) or $fmt->logwarn("parseString() failed for document query parameter 'd'");
    }
#    elsif (defined($vars->{s})) {
#      $qdoc = $fmt->parseString($vars->{s}) or $fmt->logconfess("parseString() failed for sentence query parameter 's'");
#      $qdoc = $qdoc->{body}[0] || DTA::CAB::Sentence->new();
#      $qsub = $a->can('analyzeSentence');
#    }
#    elsif (defined($vars->{w})) {
#      $qdoc = $fmt->parseString($vars->{w}) or $fmt->logconfess("parseString() failed for token query parameter 'w'");
#      $qdoc = $qdoc->{body}[0]{tokens}[0] || DTA::CAB::Token->new();
#      $qsub = $a->can('analyzeToken');
#    }
    else { #if (defined($vars->{q}))
      my $qsrc = defined($vars->{q}) ? $vars->{q} : '';
      $qsrc    = join("\n", @$qsrc) if (ref($qsrc));
      my $ifmt = DTA::CAB::Format::Raw->new;
      $qdoc = $ifmt->parseString($qsrc) or $ifmt->logwarn("parseString() failed for raw query parameter 'q'");
    }
    return $srv->clientError($csock,RC_INTERNAL_SERVER_ERROR,"could not parse input query: $@") if (!$qdoc);

    ##-- analyze
    $qdoc = $a->analyzeDocument($qdoc, {%$ao, ($handler->{forceClean} ? (doAnalyzeClean=>1) : qw())})
      or return $srv->clientError($csock,RC_INTERNAL_SERVER_ERROR,"could not analyze query document");

    ##-- format
    $ostr = $fmt->flush->putDocument($qdoc)->toString;
    $fmt->flush;
    $ostr = encode($enc,$ostr) if (utf8::is_utf8($ostr));
    return $srv->clientError($csock,RC_INTERNAL_SERVER_ERROR,"could format output document: $@") if (!defined($ostr));
  cgirun_end:
  };
  return $srv->clientError($csock,RC_INTERNAL_SERVER_ERROR,"could not process query: $@") if ($@ || !defined($ostr));

  ##-- dump to client
  my $contentType = $fmt->mimeType || 'text/plain';
  my $returnRaw   = defined($vars->{raw}) ? $vars->{raw} : $handler->{returnRaw};
  $csock->print(
		header('-nph' => 1,
		       '-status' => '200 OK',
		       '-charset' => $enc,
		       '-content-encoding' => $enc,
		       '-content-length'   => length($ostr),
		       ($returnRaw
			? ('-type' => 'text/plain')
			: ('-type' => $contentType, '-attachment' => ("cab".$fmt->defaultExtension))
		       )
		      ),
		$ostr,
	       );
  return 1;
}


##--------------------------------------------------------------
## Methods: Local

1; ##-- be happy
