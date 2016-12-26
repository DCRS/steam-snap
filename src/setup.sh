#!/bin/bash

#Create all the symlinks & copy/update the files if needed
# $steamsource (ln -s) -> $steambase
files=$(dir -w 1 $steamsource)
mkdir -p $steambase
mkdir -p $steampath
for f in $files; do #link every file from $steamsource
  cpf=true
  for fn in SteamApps steamapps userdata ssfn; do #except these
    if [ "$f" == "$fn" ]; then
      cpf=false
      if ! [ -e "$steambase/$f" ]; then #only copy them if they don't exist
        cp -rvp $steamsource/$f $steambase/$f
      fi
    fi
  done
  if $cpf; then #if they should be linked (see above) remove the old link (if exists) and create a new one
    rm -f $steambase/$f
    ln -s $steamsource/$f $steambase/$f
  fi
done
rm -f $steampath/steam.pid #this ensures steam will update the symbolic links

#LD_LIBRARY_PATH

_chld() {
  #replace $2 with $3 on $1 and add to LD_LIBRARY_PATH if exists (fixes 32bit lib missing on 64bit os bugs)
  local n=${1//"$2"/"$3"}
  if [ -e $n ]; then
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$n"
  fi
  local n=${n/"$SNAP"/"$steamruntime32"}
  if [ -e $n ]; then
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$n"
  fi
}

for l in ${LD_LIBRARY_PATH//":"/" "}; do #for all libs
  if echo "$l" | grep "^/snap/steam/" > /dev/null; then #if inside steam snap
    if [ -e "$l" ]; then #and exists (fails for a path with spaces)
      echo "for $l"
      _chld "$l" lib lib32
      _chld "$l" x86_64 i386
    fi
  fi
done

LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$SNAP/steam/.steam/ubuntu12_32"

export STEAM_LD_PRELOAD="$LD_PRELOAD:$steamruntime32/usr/lib/i386-linux-gnu/dri/swrast_dri.so"
