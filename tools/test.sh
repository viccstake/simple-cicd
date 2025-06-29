#!/usr/bin/env bash
set -euo pipefail

mode=
depth=

success=true
case "$mode" in
    'backend'); 
        echo "Testing backend.."
        python './util/test_latency.py' "$depth"
        python './util/test_roa.py'
        [[ $depth -lt 1 ]] && exit 0
        exit 0
    ;;
    'ios_frontend');
        echo "Testing iOS frontend.."
        exit 0
    *) usage >&2; exit 1;;
esac