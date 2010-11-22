##-*- Mode: CPerl; coding: utf-8; -*-

package DTA::CAB::Client::CGIWrapper;

use DTA::CAB::Client;
use DTA::CAB::Client::XmlRpc;
use DTA::CAB::Format;
use DTA::CAB::Format::Builtin;
use DTA::CAB::Datum ':all';

use CGI qw(); #qw(:standard :cgi-lib);
#use LWP::UserAgent;
use URI::Escape;
use Encode qw(encode decode);
use File::Basename qw(basename);
use utf8;
use Data::Dumper;
use strict;

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(DTA::CAB::Client::XmlRpc);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = $CLASS_OR_OBJECT->new(%args)
## + %args, %$obj:
##   ##
##   ##-- NEW
##   sysid   => "$id str"           ##-- default __PACKAGE__ . " v$DTA::CAB::VERSION"
##   analyzers => \@analyzers,      ##-- supported analyzers (undef to query)
##   fmts => [{class=>$class,label=>$label,level=>$level},...], ##-- supported output formats
##   autoClean => $bool,            ##-- always set 'doAnalyzeClean=1' upstream analysis option
##   ##
##   ##-- INHERITED from DTA::CAB::Client::XmlRpc
##   serverURL => $url,             ##-- default: localhost:8000
##   serverEncoding => $encoding,   ##-- default: UTF-8
##   timeout => $timeout,           ##-- timeout in seconds, default: 300 (5 minutes)
##   xcli => $xcli,                 ##-- RPC::XML::Client object
sub new {
  my $that = shift;
  my $wr = $that->SUPER::new(
			     ##-- identity
			     sysid => (__PACKAGE__ . " v$DTA::CAB::VERSION"),
			     analyzers => [qw(dta.cab.norm dta.cab.expand)],
			     autoClean => 0,

			     fmts => [
				      {key=>'csv',  class=>'DTA::CAB::Format::CSV', label=>'CSV'},
				      {key=>'json', class=>'DTA::CAB::Format::JSON', label=>'JSON', level=>1},
				      {key=>'perl', class=>'DTA::CAB::Format::Perl', label=>'Perl', level=>2},
				      {key=>'text', class=>'DTA::CAB::Format::Text', label=>'Text'},
				      {key=>'tt',   class=>'DTA::CAB::Format::TT', label=>'TT'},
				      {key=>'xml',  class=>'DTA::CAB::Format::XmlNative', label=>'XML (Native)', level=>1},
				      {key=>'xmlrpc',  class=>'DTA::CAB::Format::XmlRpc', label=>'XML-RPC', level=>1},
				      {key=>'yaml', class=>'DTA::CAB::Format::YAML', label=>'YAML', level=>0},
				     ],

			     ##-- user args
			     @_,
			    );

  ##-- update formats
  foreach (@{$wr->{fmts}}) {
    $_->{key} = $_->{class} if (!defined($_->{key}));
  }
  $wr->{fmtsh} = { map {($_->{key}=>$_)} @{$wr->{fmts}} };

  return $wr;
}

##==============================================================================
## Methods: top-level

## undef = $wr->run(\*STDIN)
## undef = $wr->run("$cgi_src_str")
## undef = $wr->run("$cgi_src_file")
## undef = $wr->run(\%cgi_param_hash)
sub run {
  my $wr   = shift;
  my $q    = $wr->{q}  = CGI->new(@_);
  $q->charset('UTF-8');
  my $qv = $wr->{qv} = $q->Vars;

  ##-- auto-decode some vars
  my @u8keys = qw(q);
  my (@u8vals,$key);
  foreach $key (grep {exists $qv->{$_}} @u8keys) {
    @u8vals = $q->param($key);
    foreach (@u8vals) {
      $_ = decode('utf8', $_);
    }
    if (@u8vals<=1) {
      $qv->{$key} = $u8vals[0];
    } else {
      $qv->{$key} = [@u8vals];
    }
  }

  ##-- html headers (debug)
  print
    ($wr->html_header,
     $wr->html_qform,
     #$wr->html_vars, ##-- debug
    );

  ##-- fetch query results
  if (defined($qv->{q}) && $qv->{q} ne '') {
    my $rdoc = $wr->fetchResults();
    #print $q->pre(Data::Dumper->Dump([$rdoc],['rdoc'])); ##-- debug

    ##-- format
    if ($rdoc) {
      my $ofkey = $qv->{of} || $wr->{fmts}[0]{key};
      my $ofdat = $wr->{fmtsh}{$ofkey};
      my $of    = $ofdat->{class}->new(level=>$ofdat->{level},encoding=>'UTF-8');
      my $os    = $of->putDocumentRaw($rdoc)->toString;
      $os = decode('utf8',$os) if (!utf8::is_utf8($os));

      print
	($q->div({id=>'section'},
		 $q->h2("Results (", $q->tt($ofdat->{class}). ")"),
		 $q->pre(htmlesc($os)),
		));

    } else {
      print $wr->html_error;
    }
  }

  ##-- footer
  print $wr->html_footer;

  ##-- cleanup & return
  delete @$wr{qw(q qv error)};
  return;
}

##==============================================================================
## Methods: Generic

## $rdoc_or_undef = $wr->fetchResults()
## $rdoc_or_undef = $wr->fetchResults($analyzer,$qdoc,\%qopts)
##  + calls Client::XmlRpc::analyzeDocument($analyzer,$qdoc,\%qopts)
sub fetchResults {
  my ($wr,$qa,$qdoc,$qopts) = @_;
  $qa    = $wr->parseQueryAnalyzer() if (!$qa);
  $qdoc  = $wr->parseQueryDoc() if (!$qdoc);
  $qopts = $wr->parseQueryOpts() if (!$qopts);

  $wr->connect()
    or return $wr->set_error("connect() failed: $!");
  my $rdoc = $wr->analyzeDocument($qa,$qdoc,$qopts)
    or return $wr->set_error("analyzeDocument() failed: $!");

  $wr->disconnect();
  return $rdoc;
}

## $qopts = $wr->parseQueryOpts()
##  + currently just returns 'dta.cab.all'
sub parseQueryAnalyzer {
  return $_[0]{qv}{analyzer} if ($_[0]{qv} && $_[0]{qv}{analyzer});
  return 'dta.cab.default';
}

## $qopts = $wr->parseQueryOpts(\%qvars)
## $qopts = $wr->parseQueryOpts()
##  + currently just returns {}
sub parseQueryOpts {
  my ($wr,$qv) = @_;
  $qv = $wr->{qv} if (!$qv);
  return {
	  ##-- autoClean
	  ($wr->{autoclean} || $qv->{clean} ? (doAnalyzeClean=>1) : qw()),

	  ##-- format
	 }
}


## $qdoc_or_undef = $wr->parseQueryDoc(\%qvars)
## $qdoc_or_undef = $wr->parseQueryDoc()
##  + on error sets $wr->{error}
sub parseQueryDoc {
  my ($wr,$qv) = @_;
  $qv = $wr->{qv} if (!$qv);

  ##-- parse query string to document
  my $qs  = $qv->{q};
  my ($qdoc);

  ##-- parse: as sentence
  $qdoc = toDocument([toSentence([map {toToken($_)}
				  grep {defined($_)}
				  map {split(/\s+/,$_)}
				  (ref($qs) ? @$qs : ($qs))
				 ])
		     ]);

  ##-- return
  return $wr->set_error('could not parse query string "$qs"') if (!$qdoc);
  return $qdoc;
}

## undef = $wr->set_error(@err)
##  + also logs error
sub set_error {
  my ($wr,@err) = @_;
  $wr->error(@err);
  $wr->{error} = join('', @err);
  return undef;
}

##==============================================================================
## Methods: HTML

## @html = $wr->html_error()
##  + returns error string for $wr->{error}
sub html_error {
  my $wr = shift;
  my $q  = $wr->{q};
  return ($q->h2('Error'),
	  $q->tt(htmlesc($wr->{error} || '???')),
	  $q->br,
	 );
}

## @html = $wr->html_header()
sub html_header {
  my $wr = shift;
  my $q = $wr->{q};
  return
    ($q->header,
     $q->start_html(-title=>'DTA::CAB Client Wrapper',
		    -style=>{'src'=>'taxi.css'},
		   ),
     openTag('div',{id=>'outer'}),
     $q->div({id=>'headers'},
	     $q->h1("DTA::CAB Client Wrapper"),
	    ),
     openTag('div',{id=>'content'}),
    );
}

## @html = $wr->html_footer()
sub html_footer {
  my $wr = shift;
  my $q = $wr->{q};
  return
    (
     closeTag('div',{id=>'content'}),
     '<div id="footers">',
     "<tt>$wr->{sysid}</tt>", $q->br,
     '<address><a href="mailto:jurish@bbaw.de">jurish@bbaw.de</a></address>',
     '</div>',
     closeTag('div',{id=>'outer'}),
     $q->end_html,
    );
}

## @html = $wr->html_vars()
sub html_vars {
  my $wr = shift;
  local $Data::Dumper::Indent = 2;
  return $wr->{q}->pre(Data::Dumper->Dump([$wr->{qv}],['vars']));
}

## @html = $wr->html_qform()
sub html_qform {
  my $wr = shift;
  my $q = $wr->{q};

  ##-- get analyzer list
  if (!defined($wr->{analyzers})) {
    my @a = $wr->analyzers();
    return $wr->set_error("could get analyzer list: ".$a[0]->value) if (!@a || ref($a[0]));
    $wr->{analyzers} = \@a;
  }

  return
    (
     $q->div({id=>'section'},
	     #$q->h2('Query'),
	     $q->start_form(-method=>'GET', -id=>'queryForm'),
	     $q->table({class=>'sep'},
		       $q->tbody(
				 $q->Tr($q->td({id=>'searchLabel'}, "Query:"),
					$q->td({colspan=>3}, $q->textfield(-name=>'q',-size=>64,-id=>'searchText')),
				       ),
				 ##
				 $q->Tr($q->td({id=>'searchLabel'}, "Analyzer:"),
					$q->td($q->popup_menu({-name=>'analyzer',
							       -values=>[ @{$wr->{analyzers}} ],
							       -default=>($wr->{analyzers}[0] || 'dta.cab.default')
							      }))),
				 ##
				 $q->Tr(
					$q->td({id=>'searchLabelE'}, "Format:"),
					$q->td($q->popup_menu({-name=>'of',
							       -values=>[ map {$_->{key}} @{$wr->{fmts}} ],
							       -default=>'DTA::CAB::Format::TT',
							       -labels => { map {($_->{key}=>$_->{label})} @{$wr->{fmts}} },
							      }))),
				 ##
				 $q->Tr(
					$q->td({id=>'searchLabelE'}, "Auto-clean:"),
					$q->td($q->checkbox(-name=>'clean', checked=>($wr->{autoClean} ? 1 : 0), value=>1, label=>'',
							    ($wr->{autoClean} ? (-disabled=>1) : qw()))),
				       ),
				 ##
				 $q->Tr($q->td(),
					$q->td($q->submit(-name=>'submit',-value=>'submit')),
				       ),
				)),
	     $q->end_form,
	    ),
    );
}

##==============================================================================
## Functions: utils

sub htmlesc {
  my $str = shift;
  $str =~ s/\&/&amp;/g;
  $str =~ s/\</&lt;/g;
  $str =~ s/\>/&gt;/g;
  $str =~ s/\"/&quot;/g;
  $str =~ s/\'/&apos;/g;
  return $str;
}
sub openTag {
  my ($name,$attrs) = @_;
  return "<$name".join('', map {" $_=\"".htmlesc($attrs->{$_})."\""} sort keys %$attrs).">";
}
sub closeTag {
  my $name = shift;
  return "</$name>";
}
sub elt {
  my ($name,$attrs,@content) = @_;
  return (openTag($name,$attrs), @content, closeTag($name));
}
sub mydiv { return elt('div',@_); }
sub mytable { return elt('table',@_); }
sub mytbody { return elt('tbody',@_); }
sub mytr { return elt('tr',@_); }
sub mytd { return elt('td',@_); }
sub myth { return elt('th',@_); }
sub myspan { return elt('span',@_); }
sub mya { return elt('a',@_); }

1; ##-- be happy
