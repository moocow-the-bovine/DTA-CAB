<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html
	  PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
  <head>
    <title>DTA::CAB Demo</title>
    <link rel="stylesheet" type="text/css"  href="/taxi.css" />
    <link rel="icon"       type="image/png" href="/favicon.png"/>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<script type="text/javascript" language="javascript">
exlexClick() {
  if (document.getElementById("exlexCheckBox").checked()) {
    document.getElementById("exlexHidden").value = "1";
  } else {
    document.getElementById("exlexHidden").value = "0";
  }
}
</script>
  </head>
  <body>
    <div id="outer">
      <div id="headers">
	<h1>DTA::CAB Demo [%PERL%]print "v$DTA::CAB::VERSION";[%END%]</h1>
      </div>
      <div id="content">
        <div id="section">
          <!--<form method="post" action="/query" enctype="multipart/form-data" id="queryForm">-->
	  <form method="get" action="/query" id="queryForm">
            <table class="sep">
              <tbody>
                <tr>
                  <td id="searchLabel">Query:</td>
                  <td colspan="3"><input type="text" name="q" size="64" id="searchText" /></td>
                </tr>
                <tr>
                  <td id="searchLabel">Analyzer:</td>
                  <td>
                    <select name="a">
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
                </tr>
                <tr>
                  <td id="searchLabelE">Format:</td>
                  <td>
                    <select name="fmt">
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
                </tr>
                <tr>
                  <td id="searchLabelE">Pretty:</td>
                  <td>
                    <label><input type="checkbox" name="pretty" value="1" checked /></label>
                  </td>
                </tr>
                <tr>
                  <td id="searchLabelE">Clean:</td>
                  <td>
                    <label><input type="checkbox" name="clean" value="1" checked /></label>
                  </td>
                </tr>
                <tr>
                  <td id="searchLabelE">ExLex:</td>
                  <td>
                    <label><input id="exlexInput" type="checkbox" onclick="exlexClick();" checked /></label>
                  </td>
                </tr>
                <tr>
                  <td/>
                  <td><input type="submit" name="submit" value="submit" /></td>
                </tr>
              </tbody>
            </table>
	   <input type="hidden" id="rawHidden" name="raw" value="1"/>
	   <input type="hidden" id="exlexHidden" name="exlex_enabled" value="1"/>
          </form>
        </div>
      </div>
      <p/>
      <a class="linkButton" href="analyzers?raw=1&pretty=1&fmt=tt">Analyzers</a>
      | <a class="linkButton" href="formats?raw=1&pretty=1&fmt=tt">Formats</a>
      | <a class="linkButton" href="http://odo.dwds.de/~moocow/software/DTA-CAB">Documentation</a>
      <p/>
      <div id="footers">
        <tt>DTA::CAB::Server::HTTP</tt><br/>
	<tt>DTA::CAB</tt> v$VERSION (<tt>$SVNVERSION</tt>)<br/>
        <address>
          <a href="mailto:jurish@bbaw.de">jurish@bbaw.de</a>
        </address>
      </div>
    </div>
  </body>
</html>
