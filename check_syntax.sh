#!/usr/bin/env bash
# Basic Shell Syntax Checker
# Copyright (C) 2018-2019, VR25 @ xda-developers
# License: GPLv3+

echo
cd ${0%/*} 2>/dev/null
modId=${PWD##/}
for f in $(find . \( -path ./_builds -o -path ./_resources \) -prune \
  -o -type f -name '*.sh') .* ./$modId/$modId* ./$modId/M
do
  [ -f "$f" ] && bash -n $f
done
echo
