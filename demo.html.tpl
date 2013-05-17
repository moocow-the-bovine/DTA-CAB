<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" >
[%#=====================================================================
  # CAB demo page
  #
  # variables:
  #   $isUpload  : is this a file-upload demo?
%]
[% DEFAULT
  title = "DTA::CAB Demo"
%]
[% IF !isUpload ; SET queryOnChange = "onchange=\"cabQuery();\"" ; END  %]
[% IF isUpload ; SET uploadChecked = "checked" ; ELSE ; SET noUploadChecked = "checked" ; END %]
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
  <head>
    <title>[% title %]</title>
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
    <script type="text/javascript">
uploadMode = Boolean("[% isUpload %]");
    </script>
  </head>
  <body onload="cabDemoInit();">
    <div id="outer">
      <div id="headers">
	<h1>[% title %] v[% PERL %] print "$DTA::CAB::VERSION";[% END %]</h1>
      <!--</div>
      <div class="content">-->
	<div class="subsection">
	  <table><tbody>
	    <tr>
	      <form id="queryForm" action="/query" method="GET" onsubmit="return cabQuery();">
		[% IF isUpload %]
  		  [%#-- file-upload query %]
		  <td class="searchLabel">File:</td>
		  <td colspan="5">
		    <input type="file" name="q" id="i_qf" size="64" title="Document file to upload &amp; analyze"/>
		    <input type="submit" name="_s" value="submit" />
		  </td>
		[% ELSE %]
  		  [%#-- text-entry query %]
		 <td class="searchLabel">Query:</td>
		 <td colspan="4"><input type="text" name="q" size="64" class="cabQuery" title="Query word, phrase, sentence, or document." /></td>
		 <td style="text-align:right;"><input type="submit" name="_s" value="submit" /></td>
		[% END %]
	      </form>
	      </tr><!--/tr:query+submit-->
	      <tr>
		<td class="searchLabel">Analyzer:</td>
		<td colspan="4">
		  <select name="a" class="cabSelect" title="CAB analyzer" [% queryOnChange %]>
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
		  <select name="fmt" class="cabSelect"  [% queryOnChange %] title="Analysis I/O format">
		    [% PERL %]
		    return; ##-- don't use auto-generated format list (it's ugly)
		    my $h   = $stash->get('h');
		    my $reg = $h->{qh}{formats}{reg};
		    my $f0  = $h->{qh}{defaultFormat};
		    ($_->{base} = $_->{name}) =~ s/^DTA::?CAB::?Format::?// foreach (@$reg);
		    my $prev = '';
		    foreach my $f (sort {$a->{base} cmp $b->{base}} @$reg) {
		      next if ($f->{base} eq $prev);
		      print "<option ".($f->{short} eq $f0 || $f->{name} eq $f0 ? 'selected="1" ' : '')."value=\"$f->{short} : $f->{name}\">$f->{base}</option>\n";
		      $prev = $f->{base};
		    }
		    [% END %]
		    [% IF isUpload %]
		     <option selected="true" value="auto">(guess from filename)</option>
		    [% END %]
		    <option value="csv">CSV</option>
		    <option value="json">JSON</option>
		    <option value="perl">Perl</option>
		    [% IF isUpload %]
		     <option value="tei">TEI XML</option>
		     <option value="teiws">TEI XML (pre-tokenized into &lt;w&gt;, &lt;s&gt;)</option>
		    [% END %]
		    <option [% IF !isUpload %]selected="true"[% END %] value="text">Text</option>
		    <option value="tt">TT ('vertical')</option>
		    <option value="tj">TJ ('vertical' + json)</option>
		    <option value="xlist">XList (DDC term expander)</option>
		    <option value="xml">XML (Native)</option>
		    <option value="twxml">XML (TokWrap)</option>
		    <!--<option value="xmlperl">XML (Perl)</option>-->
		    <option value="xmlrpc">XML-RPC</option>
		    <option value="yaml">YAML</option>
		  </select>
		</td>
		<td/>
	      </tr><!--/tr:select:format-->
	      <tr>
		<td class="searchLabel">Flags:</td>
		<td style="text-align:left;" title="pretty: pretty-print output?">
		  <label class="cabFlagLabel"><input type="checkbox" name="pretty" value="1" [% queryOnChange %] checked />pretty</label>
		</td>
		<td style="text-align:center;" title="clean: scrub extraneous data from output?">
		  <label class="cabFlagLabel"><input type="checkbox" name="clean" value="1" [% queryOnChange %] checked />clean</label>
		</td>
		<td style="text-align:center;" title="exlex: enable cached analyses and exception lexicon?">
		  <label class="cabFlagLabel"><input type="checkbox" name="exlex_enabled" value="1" [% queryOnChange %] checked />exlex</label>
		</td>
		<td style="text-align:right;" title="tokenize: tokenize input file?">
		  <label class="cabFlagLabel"><input type="checkbox" name="tokenize" value="1" [% queryOnChange %] checked />tokenize</label>
		</td>
		<td/>
	      </tr><!--/tr:flags-->
	      <tr>
		<td class="searchLabel">Options:</td>
		<td colspan="4"><input type="text" name="qo" size="64" class="cabOptions" title="Additional options (JSON format)" value="{}"/></td>
	      </tr><!--/tr:opts-->
	    </tbody></table>
          [%#</form><!-- /queryForm -->%]
        </div><!--/div.section-->
      </div><!--/div.headers-->
      <div class="content" [% IF isUpload %]style="display:none;"[% END %]>
	<a id="btn_trf_cabq" class="trafficBtn" title="CAB+TAGH status: unknown"> </a>
	<b>URL: </b><a id="cabLink" href="/query" title="URL of raw response data">/query</a><br/>
	<pre id="cabData"></pre>
      </div><!--/div.content-->
       [% IF isUpload %]
	<a class="linkButton" style="margin-left:0px;" href="/">Live Demo</a>
       [% ELSE %]
	<a class="linkButton" style="margin-left:0px;" href="/upload">File Upload</a>
       [% END %]
	| <a class="linkButton" href="analyzers?raw=1&amp;pretty=1&amp;fmt=tt">Analyzers</a>
	| <a class="linkButton" href="formats?raw=1&amp;pretty=1&amp;fmt=tt">Formats</a>
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
