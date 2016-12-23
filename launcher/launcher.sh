#!/bin/sh

export HOME="$SNAP_USER_DATA"
steambin="$SNAP/deb"
steampath="$HOME/.steam"

. $SNAP/sh/fnc.sh
. $SNAP/sh/var.sh
. $SNAP/sh/core.sh
