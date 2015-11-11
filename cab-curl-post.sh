#!/bin/bash

if test "$#" -eq 0 ; then
  cat <<EOF >&2

 Usage: $0 URL INFILE [CURL_ARGS]

  e.g. $0 "http://www.deutschestextarchiv.de/demo/cab/query?a=default&clean=1&fmt=tei" FILE.xml -o out.xml

EOF
  exit 1
fi

url="$1"; shift
infile="$1"; shift;
exec curl -X POST -sS "$url" -F qd="@$infile" "$@"
