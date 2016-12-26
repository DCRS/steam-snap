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
STEAM_LD_PRELOAD=""

srcpath=$(readlink -f "../../..") #parts/steam/build

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
      sleep .1s
    else
      sleep .5s
    fi
    waitloop
  fi
}

if [ -e $srcpath/.cache_steam ]; then
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
fi

dpkg -x steam.valve.deb deb
dpkg -x steam.ubuntu_xenial.deb deb

if ! [ -e .steam ]; then
  bash deb/usr/games/steam&steampid=$!
  set +x
  waitloop
  set -x

  rm -f $steampath/steam.sh $steampath/steam.pipe $steampath/.applied
  mv $steampath/steam.orig.sh $steampath/steam.sh

  if [ -e $srcpath/.cache_steam ]; then
    cp -rp $steampath $srcpath/.steam
  fi
else
  rm -f $steampath/steam.sh $steampath/steam.pipe $steampath/.applied
  mv $steampath/steam.orig.sh $steampath/steam.sh
fi

depspath=$(readlink -f ../install)
#export LD_PRELOAD="$depspath/usr/lib/x86_64-linux-gnu/libstdc++.so.6"
LD_PRELOAD=''
STEAM_LD_PRELOAD='/usr/$LIB/libstdc++.so.6 /usr/$LIB/libgcc_s.so.1 /usr/$LIB/libxcb.so.1 /usr/$LIB/libgpg-error.so'
maindir=$PWD

runtime_overwrite() {
  #this will create a ubuntu 16.04 steam runtime and override files (keep the old libs in place)
  for a in i386 amd64; do
    rt=$steampath/ubuntu12_32/steam-runtime/$a
    rtbase=$maindir/runtime_$a
    if [ -e $srcpath/.cache_runtime ]; then
      if [ -e $srcpath/.runtime_$a ]; then
        cp -rp $srcpath/.runtime_$a $rtbase
      fi
    fi
    if ! [ -e $rtbase ]; then
      make -C $maindir/steam-runtime runtime-$a to=$rtbase
    fi
    if [ -e $srcpath/.cache_runtime ]; then
      if ! [ -e $srcpath/.runtime_$a ]; then
        cp -rp $rtbase $srcpath/.runtime_$a
      fi
    fi
    cp -rp $rtbase/* $rt
    for f in usr/share/doc usr/doc usr/share/man usr/share/man-db; do
      rm -rf $rt/$f
    done
  done
}

fix_steam() {
  #find -type f -iname "lib*.so.*" -print
  #replace old libs with new ones and hope thinks won't break
  cp $(readlink -f $depspath/usr/lib32/libstdc++.so.6) $steampath/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu/libstdc++.so.6
  cp $(readlink -f $depspath/usr/lib/x86_64-linux-gnu/libstdc++.so.6) $steampath/ubuntu12_32/steam-runtime/amd64/usr/lib/x86_64-linux-gnu/libstdc++.so.6
  #and update/replace those
  #rm -fv $steampath/ubuntu12_32/steam-runtime/i386/lib/i386-linux-gnu/libgcc_s.so.1
  #rm -fv $steampath/ubuntu12_32/steam-runtime/amd64/lib/x86_64-linux-gnu/libgcc_s.so.1
  #rm -fv $steampath/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu/libxcb.so.1
}

cd $steampath
export USE_XVFB=true
. $steampathreturn/fnc.sh
. $steampathreturn/var.sh

touch starting

fix_steam

. $steampathreturn/core.sh

fix_steam

runtime_overwrite

#. $steampathreturn/var.sh

#set +e
#. $steampathreturn/core.sh
#set -e

#fix_steam

for f in steam.pid bin32 bin64 root sdk32 sdk64 steam.pipe; do
  rm -v $f
done
rm -vf starting
rm -v $maindir/steam/.steampid
rm -v $maindir/steam/.steampath
touch ssfn #fixes some errors
