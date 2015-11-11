#!/bin/bash

pod2html --css="../../dtacab.css" --backlink --podroot=blib --podpath=lib:script --noheader --infile=CAB/WebServiceHowto.pod | perl -p    -e'sub hackhref { if (($href=shift)=~s{^[\/\.]*/(?:script|lib)/}{}) { $href=~s{/}{.}g; } $href=~s{^http://\./}{}; $href; }' -e 's/<a href="([^"]*)/'\''<a href="'\''.hackhref($1)/eg;'  > blib/html/DTA.CAB.WebServiceHowto.html
