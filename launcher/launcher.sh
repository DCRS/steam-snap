#!/bin/bash

set -x

export HOME="$SNAP_USER_DATA"
steambin="$SNAP/deb"
steambase="$SNAP/steam/.steam"
steampath="$HOME/.steam"

. $SNAP/sh/fnc.sh

echo "Setup steam..."
. $SNAP/sh/setup.sh

echo "Launch steam..."
. $SNAP/sh/var.sh
. $SNAP/sh/core.sh
