#!/bin/bash

set -x
set -e

export HOME="$SNAP_USER_DATA"
steambin="$SNAP/deb"
steamsource="$SNAP/steam/.steam"
steampath="$HOME/.steam"
steambase="$HOME/steam"
disablebootstrapupdates=true #really long and anjoying string, isn't it?

env

. $SNAP/sh/fnc.sh

echo "Setup steam..."
. $SNAP/sh/setup.sh

_chld() {
  #replace $2 with $3 on $1 and add to LD_LIBRARY_PATH if exists (fixes 32bit lib missing on 64bit os bugs)
  local n=${1//"$2"/"$3"}
  if [ -e $n ]; then
    LD="$LD_LIBRARY_PATH:$n"
  fi
}
for l in ${LD//":"/" "}; do #for all libs
  if echo "$l" | grep "^/snap/steam/" > /dev/null; then #if inside steam snap
    if [ -e "$l" ]; then #and exists (fails for a path with spaces)
      echo "for $l"
      _chld "$l" lib lib32
      _chld "$l" x86_64 i386
    fi
  fi
done


echo "Launch steam..."
. $SNAP/sh/var.sh
set +e
. $SNAP/sh/core.sh

env

# If steam requested to restart, then restart
if [ $STATUS -eq $MAGIC_RESTART_EXITCODE ] ; then
 echo "Restarting Steam by request..."
	exec "$0" "$@"
fi

if [ $STATUS -eq 127 ] ; then #command/library not found
  exit 127
fi
