#!/bin/bash

export LD_PRELOAD="$LD_PRELOAD"

set -x
set -e

if echo "$SNAP_REVISION" | fold -w 1 | head -n 1 | grep "x" > /dev/null; then
  if [ "$1" == "shell_pre" ]; then
    bash
  fi
fi

export HOME="$SNAP_USER_DATA"
steambin="$SNAP/deb"
steamsource="$SNAP/steam/.steam"
steampath="$HOME/.steam"
steambase="$HOME/.steam"
steamruntime32="$steamsource/ubuntu12_32/steam-runtime/i386/"
steamruntime64="$steamsource/ubuntu12_32/steam-runtime/amd64/"
disablebootstrapupdates=true #really long and anjoying string, isn't it?

env

. $SNAP/sh/fnc.sh

echo "Setup steam..."
. $SNAP/sh/setup.sh

export LIBGL_DEBUG=verbose

echo "Launch steam..."
. $SNAP/sh/var.sh
set +e
. $SNAP/sh/core.sh

env
ldd $SNAP/steam/.steam/ubuntu12_32/steamui.so

# If steam requested to restart, then restart
if [ $STATUS -eq $MAGIC_RESTART_EXITCODE ] ; then
 echo "Restarting Steam by request..."
	exec "$0" "$@"
fi

if echo "$SNAP_REVISION" | fold -w 1 | head -n 1 | grep "x" > /dev/null; then
  if [ "$1" == "shell_after" ]; then
    bash
  fi
fi

if [ $STATUS -eq 127 ] ; then #command/library not found
  exit 127
fi
