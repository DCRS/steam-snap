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
