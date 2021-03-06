#!/bin/bash

## url_base : base url to use for query-string arguments
url_base="http://www.deutschestextarchiv.de/demo/cab/query";

if test "$#" -eq 0 -o "$1" = "-h" -o "$1" = "--help" ; then
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

##-- prepend base URL if required
case "$url" in
    "?"*)
	url="${url_base}${url}"
	;;
    *)
	;;
esac

exec curl -X POST -sSF qd="@$infile" -L --post301 --post302 --post303 "$@" "$url"
