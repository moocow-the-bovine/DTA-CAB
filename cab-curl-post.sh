#!/bin/bash

## url_base : base url to use for query-string arguments
url_base="http://www.deutschestextarchiv.de/cab/query";

if test "$#" -eq 0 ; then
  cat <<EOF >&2

 Usage: $0 URL_OR_QUERY_STRING INFILE [CURL_ARGS]

 Examples:
   $0 "${url_base}?a=default&clean=1&fmt=tei" FILE.xml -o out.xml
   $0 "?a=default&fmt=tei" FILE.xml > out.xml

EOF
  exit 1
fi

url="$1"; shift
infile="$1"; shift;

case "$url" in
    "?"*)
	url="${url_base}${url}"
	;;
    *)
	;;
esac
echo curl -X POST "$url" -sSL --post301 --post302 --post303 -F qd="@$infile" "$@"
