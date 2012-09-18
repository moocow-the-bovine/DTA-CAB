<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" >
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
  <head>
    <title>DTA::CAB Demo</title>
    <link rel="stylesheet" type="text/css"  href="taxi.css" />
    <link rel="icon"       type="image/png" href="favicon.png"/>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <style type="text/css">
table, th, td, label, input { vertical-align: middle; }
.cabQuery, .cabOptions  { min-width: 32em; }
.cabSelect { width: 16em; }
.cabFlag { text-align: right; }
.cabFlagLabel { text-align: right; }
.cabFlagLabel:hover {
  background-color: #ffbb75; /*light orange*/
  color: #000099;
}
#cabData {
  border: 1px solid grey;
  background: none;
  margin: 5px;
  margin-left: 0px;
  margin-right: 0px;
  padding: 5px;
}
#cabLink { font-family:monospace; }
b { font-weight: bold; color: #000099; }
.trafficBtn { 
  display: inline;
  background-color: #ffffff;
  border: 1px solid gray;
  margin-left: 0px;
  margin-right: 5px;
  padding-left: .5em;
  padding-right: .5em;
  cursor: arrow;
}
</style>
    <script type="text/javascript" src="demo.js" ></script>
  </head>
  <body onload="cabDemoInit();">
    <div id="outer">
      <div id="headers">
	<h1>DTA::CAB Demo v[% PERL %] print "$DTA::CAB::VERSION";[% END %]</h1>
      <!--</div>
      <div class="content">-->
	<div class="subsection">
	  <form method="get" action="/query" id="queryForm" onsubmit="return cabQuery();">
	    <table><tbody>
	      <tr>
		<td class="searchLabel">Query:</td>
		<td colspan="4"><input type="text" name="q" size="64" class="cabQuery" title="Query word, phrase, sentence, or document." /></td>
		<td style="text-align:right;"><input type="submit" name="_s" value="submit" /></td>
	      </tr><!--/tr:query+submit-->
	      <tr>
		<td class="searchLabel">Analyzer:</td>
		<td colspan="4">
		  <select name="a" class="cabSelect" onchange="cabQuery();">
		    [% PERL %]
		    my $h   = $stash->get('h');
		    my $srv = $stash->get('srv');
		    my $qh  = $h->{qh};
		    foreach my $a (grep {!defined($qh->{allowAnalyzers}) || $qh->{allowAnalyzers}{$_}} sort keys %{$srv->{as}}) {
		      print "<option ".($a eq $qh->{defaultAnalyzer} ? 'selected="1" ' : '')."value=\"$a\">$a</option>\n";
		    }
		    [% END %]
		  </select>
		</td>
		<td/>
	      </tr><!--/tr:select:analyzer-->
	      <tr>
		<td class="searchLabelE">Format:</td>
		<td colspan="4">
		  <select name="fmt" class="cabSelect" onchange="cabQuery();">
		    [% PERL %]
		    return; ##-- don't use auto-generated format list (it's ugly)
		    my $h   = $stash->get('h');
		    my $reg = $h->{qh}{formats}{reg};
		    my $f0  = $h->{qh}{defaultFormat};
		    foreach my $f (sort {$a->{short} cmp $b->{short}} @$reg) {
		      print "<option ".($f->{short} eq $f0 || $f->{base} eq $f0 ? 'selected="1" ' : '')."value=\"$f->{short}\">$f->{short}</option>\n";
		    }
		    [% END %]
		    <option value="csv">CSV</option>
		    <option value="json">JSON</option>
		    <option value="perl">Perl</option>
		    <option selected="selected" value="text">Text</option>
		    <option value="tt">TT ('vertical')</option>
		    <option value="tj">TJ ('vertical' + json)</option>
		    <option value="xml">XML (Native)</option>
		    <option value="xmlperl">XML (Perl)</option>
		    <option value="xmlrpc">XML-RPC</option>
		    <option value="yaml">YAML</option>
		  </select>
		</td>
		<td/>
	      </tr><!--/tr:select:format-->
	      <tr>
		<td class="searchLabel">Flags:</td>
		<td style="text-align:left;"><label class="cabFlagLabel"><input type="checkbox" name="pretty" value="1" onchange="cabQuery();" checked />pretty</label></td>
		<td style="text-align:center;"><label class="cabFlagLabel"><input type="checkbox" name="clean" value="1" onchange="cabQuery();" checked />clean</label></td>
		<td style="text-align:center;"><label class="cabFlagLabel"><input type="checkbox" name="exlex_enabled" value="1" onchange="cabQuery();" checked />exlex</label></td>
		<td style="text-align:right;"><label class="cabFlagLabel"><input type="checkbox" name="tokenize" value="1" onchange="cabQuery();" checked />tokenize</label></td>
		<td/>
	      </tr><!--/tr:flags-->
	      <tr>
		<td class="searchLabel">Options:</td>
		<td colspan="4"><input type="text" name="qo" size="64" class="cabOptions" title="Additional options (JSON format)" value="{}"/></td>
	      </tr><!--/tr:opts-->
	    </tbody></table>
          </form>
        </div><!--/div.section-->
      </div><!--/div.headers-->
      <div class="content">
	<a id="btn_trf_cabq" class="trafficBtn" title="CAB+TAGH status: unknown"> </a>
	<b>URL: </b><a id="cabLink" href="/query" title="URL of raw response data">/query</a><br/>
	<pre id="cabData"></pre>
      </div><!--/div.content-->
	<a class="linkButton" style="margin-left:0px;" href="analyzers?raw=1&pretty=1&fmt=tt">Analyzers</a>
	| <a class="linkButton" href="formats?raw=1&pretty=1&fmt=tt">Formats</a>
	| <a class="linkButton" href="http://odo.dwds.de/~moocow/software/DTA-CAB">Documentation</a>
	<br/>
      <div id="footers" style="margin-top:.5em;">
        <tt>DTA::CAB::Server::HTTP</tt><br/>
	<tt>DTA::CAB</tt> v$VERSION (<tt>$SVNVERSION</tt>)
        <address>
          <a href="mailto:jurish@bbaw.de">jurish@bbaw.de</a>
        </address>
      </div>
    </div>
  </body>
</html>
