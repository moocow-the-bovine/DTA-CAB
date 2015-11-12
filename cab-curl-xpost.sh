#!/bin/bash

## url_base : base url to use for query-string arguments
url_base="http://www.deutschestextarchiv.de/cab/query";

if test "$#" -eq 0 ; then
  cat <<EOF >&2

 Usage: $0 URL_OR_QUERY_STRING INFILE [CONTENT_TYPE=text/plain [CURL_ARGS]]

 Examples:
   $0 "${url_base}?a=default&fmt=json" FILE.json "application/json; charset=utf8" -o out.json
   $0 "?a=default&fmt=json" FILE.json > out.json

EOF
  exit 1
fi

url="$1"; shift
infile="$1"; shift;
if test $# -gt 0 ; then
  ctype="$1";
  shift;
fi

case "$url" in
    "?"*)
	url="${url_base}${url}"
	;;
    *)
	;;
esac
test -z "$ctype" && ctype="text/plain; charset=utf8"

exec curl -X POST -sSL --post301 --post302 --post303 -H "Content-Type: $ctype" --data-binary @"$infile" "$@" "$url"
