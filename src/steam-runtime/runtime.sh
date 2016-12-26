#!/bin/sh

pwd=$PWD

#set -x

packages=$(cat packages.txt | sed '/^#/ d' | sed '/^\s*$/d')

source_pkgs=()
binary_pkgs=()

debpath="$PWD/deb"
aptroot="$PWD/aptroot"
if [ -z "$RUNTIME" ]; then
  runtime="$PWD/runtime"
else
  runtime="$RUNTIME"
fi
rm -rf $debpath $runtime $aptroot
mkdir -p $debpath $runtime $aptroot

export APT_CONFIG=$aptroot/apt.conf

arch="$1"
if [ -z "$arch" ]; then
  arch="amd64"
fi

rel="xenial"

aptopt="-c=$aptroot/apt.conf"
aptoopt="-o='Dir::Etc::main=\"$aptroot/apt.conf\";'"

apt="/usr/bin/apt-get $aptopt $aptoopt"
aptcache="/usr/bin/apt-cache $aptopt $aptoopt"

echo "APT::Architecture \"$arch\";
APT::Architectures \"$arch\";
APT::Default-Release \"$rel\";
" > $aptroot/apt.conf

echo "Loading packages.txt..."

#with open("packages.txt") as f:
#	for line in f:
#		if line[0] != '#':
#			toks = line.split()
#			if len(toks) > 1:
#				source_pkgs.add(toks[0])
#				binary_pkgs.update(toks[1:])

pkgline() {
  read line
  if ! [ -z "$line" ]; then
    IFS=' ' read -ra cell <<< $(echo "$line" | xargs)
    source_pkgs+=("${cell[0]}")
    binary_pkgs+=("${cell[@]:1}")
    pkgline
  else
    #echo "b: ${binary_pkgs[@]}"
    #echo "s: ${source_pkgs[@]}"
    mainscript
  fi
}

#apt-get --print-uris --yes install <my_package_name> | grep ^\' | cut -d\' -f2 >downloads.list

#if not args.debug:
#	binary_pkgs -= {x for x in binary_pkgs if re.search('-dbg$|-dev$|-multidev$',x)}

filter_pkgs() {
  echo "Filter the packages..."
  :
}

find_pkgs() {
  echo "Load apt cache..."
  echo -n > $aptroot/not_found
  pkgs=()
  pshow=""
  for p in "${binary_pkgs[@]}"; do
    pshow="$pshow $p:$arch"
  done
  pkginfo=$($aptcache show $pshow 2> /dev/null | grep "^Package: ")
  echo "Find the packages..."
  for p in "${binary_pkgs[@]}"; do
    echo "$pkginfo" | grep -o "^Package: $p$" > /dev/null
    ex=$?
    if [ $ex -ne 0 ]; then
      echo "[p] $p NOT FOUND!" 1>&2
      echo "$p" >> $aptroot/not_found
    else
      pkgs+=("$p:$arch")
    fi
  done
  nf=$(cat $aptroot/not_found)
  if [ -z "$nf" ]; then
    echo "All packages were found and are available"
  else
    echo "The following packages were not found and will be ignored:"
    echo "$nf"
    echo "Please fix that"
    exit 2
  fi
}

wait_pids() {
  alldown=true
  echo "wait_pids...."
  for p in $@; do
    if ps -p $PID > /dev/null
    then
       echo "$PID is still running"
       alldown=false
    fi
  done
  if ! $alldown; then
    sleep 1s
    wait_pids $@
  fi
}

dl_canidate() {
  echo "[d] apt download"
  $apt download $pkglist
  ex=$?
  if [ $ex -ne 0 ]; then
    echo "[d] apt download exited with $ex! Removing canidates..."
    skip=$($apt download $pkglist 2>&1 | grep "»[a-z:.0-9-]*«" -o | grep "[a-z:.0-9-]*" -o)
    for p in $skip; do
      echo "[r] Remove canidate... $p"
      echo "$p" >> $aptroot/canidates
      pkglist=${pkglist/" $p:$arch "/" "}
    done
    dl_canidate
  fi
}

dl_pkgs() {
  echo "Download the packages..."
  cd $debpath
  pkglist=" ${pkgs[@]} "
  pkglist=$(apt-rdepends $aptoopt $pkglist | grep -v "^ ")
  pkglist2=" $(echo $pkglist) "
  pkglist=""
  for p in $pkglist2; do
    echo "$p" | grep ":$arch$" > /dev/null
    if [ $? -ne 0 ]; then
      echo "$p" | grep ":any$" > /dev/null
      if [ $? -ne 0 ]; then
        pkglist="$pkglist $p:$arch"
      else
        echo "[p] Force suffix $arch (instead of any) on $p..."
        pkglist="$pkglist ${p/":any"/":$arch"}"
      fi
    else
      pkglist="$pkglist $p"
    fi
  done
  pkglist=" $(echo $pkglist) "
  echo -n > $aptroot/canidates
  dl_canidate
}

extract_pkgs() {
  let pkgcount=0
  for d in *.deb; do
    let pkgcount=$pkgcount+1
    echo "[d] unpack $d"
    dpkg -x $d $runtime
  done
}

show_result() {
  . $runtime/etc/lsb-release
  echo
  echo
  echo
  echo "Successfully installed \"$DISTRIB_DESCRIPTION $arch Steam Runtime\" with $pkgcount packages into $runtime"
  echo
  echo "The following packages were ignored because they are canidates: $(echo $(cat $aptroot/canidates))"
  echo
  echo
  echo
}

mainscript() {
  case "$o2" in
    check)
      filter_pkgs
      find_pkgs
      ;;
    dl)
      filter_pkgs
      find_pkgs
      dl_pkgs
      ;;
    *)
      filter_pkgs
      find_pkgs
      dl_pkgs
      extract_pkgs
      show_result
  esac
}

o2="$2"

echo "$packages" | pkgline #everything must be called in "pkgline" now
