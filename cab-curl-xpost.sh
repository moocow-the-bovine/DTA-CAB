#!/bin/bash

if test "$#" -eq 0 ; then
  cat <<EOF >&2

 Usage: $0 URL INFILE [CONTENT_TYPE=text/plain [CURL_ARGS]]

  e.g. $0 http://kaskade.dwds.de:9099/query?a=default;clean=1;fmt=json FILE.tj 'application/json; charset=utf8' -o out.json

EOF
  exit 1
fi

url="$1"; shift
infile="$1"; shift;
if [ $# -gt 0 ]; then
  ctype="$1";
  shift;
fi
test -z "$ctype" && ctype="text/plain; charset=utf8"
exec curl -X POST -sS "$url" -H "Content-Type: $ctype" --data-binary @"$infile" "$@"
