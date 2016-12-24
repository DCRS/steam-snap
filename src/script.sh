#!/bin/bash

set -x
export STEAM_DEBUG=1
set -e

export HOME=$PWD/steam
mkdir -p deb
mkdir -p steam

steampath="$HOME/.steam"
steambase=$steampath
steambin="$PWD/deb"
steampathreturn="../.."

srcpath="../../.." #parts/steam/build

waitloop() { #replace the steam.sh script with "exit 0" to prevent steam from launching
  if ps -p $steampid > /dev/null
  then
    if ! [ -e $steampath/.applied ]; then
      if [ -e $steampath/steam.sh ]; then
        echo "[override] Successfully replaced steam.sh"
        mv $steampath/steam.sh $steampath/steam.orig.sh
        echo "exit 0" > $steampath/steam.sh
        touch $steampath/.applied
      fi
    fi
    sleep .1s
    waitloop
  fi
}

if [ -e $srcpath/.steam ]; then
  #after steam is once installed this script will copy it back everytime (this makes developing MUCH faster)
  cp -rp $srcpath/.steam steam
  touch .steam
  if ! [ -e $steampath/.applied ]; then
    if [ -e $steampath/steam.sh ]; then
      echo "[override] Successfully replaced steam.sh"
      mv $steampath/steam.sh $steampath/steam.orig.sh
      echo "exit 0" > $steampath/steam.sh
      touch $steampath/.applied
    fi
  fi
fi

dpkg -x steam.2.deb deb
dpkg -x steam.deb deb

if ! [ -e .steam ]; then
  bash deb/usr/games/steam&steampid=$!
  set +x
  waitloop
  set -x

  rm -f $steampath/steam.sh $steampath/steam.pipe $steampath/.applied
  mv $steampath/steam.orig.sh $steampath/steam.sh

  rm -rf $srcpath/.steam
  cp -rvp $steampath $srcpath/.steam
else
  rm -f $steampath/steam.sh $steampath/steam.pipe $steampath/.applied
  mv $steampath/steam.orig.sh $steampath/steam.sh
fi

fix_steam() {
  #fix everything
  #find -type f -iname "libstdc++.so.*" -delete -print #delete old libstd
  rm -fv $steampath/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu/libstdc++.so.6
  rm -fv $steampath/ubuntu12_32/steam-runtime/amd64/usr/lib/x86_64-linux-gnu/libstdc++.so.6
  rm -fv $steampath/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu/libstdc++.so.6
  rm -fv $steampath/ubuntu12_32/steam-runtime/i386/lib/i386-linux-gnu/libgcc_s.so.1
  rm -fv $steampath/ubuntu12_32/steam-runtime/amd64/lib/x86_64-linux-gnu/libgcc_s.so.1
  rm -fv $steampath/ubuntu12_32/steam-runtime/amd64/usr/lib/x86_64-linux-gnu/libstdc++.so.6
  rm -fv $steampath/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu/libxcb.so.1
  #find -type f -iname "libstdc++.so.*" -print -delete
}

cd $steampath
export USE_XVFB=true
. $steampathreturn/fnc.sh
. $steampathreturn/var.sh

fix_steam

set +e
. $steampathreturn/core.sh
set -e

fix_steam

#. $steampathreturn/var.sh

#set +e
#. $steampathreturn/core.sh
#set -e

#fix_steam
