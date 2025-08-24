#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C
d(){ printf "== %s ==\n" "$1"; shift; "$@"; echo; }
d "A apex"      sh -c 'dig +short iaionex.com A'
d "CNAME www"   sh -c 'dig +short www.iaionex.com CNAME'
d "HTTP -> HTTPS" sh -c 'curl -sSI http://iaionex.com  | awk "/^HTTP|^Location/"; true'
d "HTTPS + HSTS"  sh -c 'curl -sSI https://iaionex.com | awk "/^HTTP|^Strict-Transport-Security/"; true'
