#!/bin/bash

pod2html --css="../../dtacab.css" --backlink --podroot=blib --podpath=lib:script --noheader --infile=CAB/WebServiceHowto.pod | ./pod2htmlhack.perl  > blib/html/DTA.CAB.WebServiceHowto.html