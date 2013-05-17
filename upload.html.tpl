[% PERL %]$stash->set(srcdir=>File::Basename::dirname($stash->get('src')));[% END %]
[% SET
  guts = srcdir _ "/demo.html.tpl"
  isUpload = 1
  title = "DTA::CAB Upload Demo"
%]
[% PROCESS $guts %]
