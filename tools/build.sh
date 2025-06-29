#!/usr/bin/env bash

$mode=

case "$mode" in
    'backend'); 
        echo "Building backend.."
        exit 0
    ;;
    'ios_frontend');
        echo "Building iOS frontend.."
        exit 0
    *) usage >&2; exit 1;;
esac