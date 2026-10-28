#!/bin/zsh
# Runs the unit tests. With only the Command Line Tools installed (no Xcode), Swift Testing lives outside the default
# search paths and its Foundation overlay may be missing, so point the compiler at it and skip cross-import overlays.
set -eu
cd "${0:A:h}/.."
CLT=/Library/Developer/CommandLineTools
if [[ "$(xcode-select -p)" == "$CLT" ]]; then
  F="$CLT/Library/Developer/Frameworks"
  L="$CLT/Library/Developer/usr/lib"
  exec swift test -Xswiftc -F -Xswiftc "$F" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
fi
exec swift test "$@"
