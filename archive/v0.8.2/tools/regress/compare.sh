#!/usr/bin/env bash
# compare.sh <nameA> <nameB> - pixel-compare two runs made by run.sh.
cd "$(dirname "$0")/out" && python ../compare.py "$1" "$2"
