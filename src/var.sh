#!/bin/bash

set -o pipefail
shopt -s failglob
set -u

# Allow us to debug what's happening in the script if necessary
if [ "${STEAM_DEBUG-}" ]; then
	set -x
fi
export TEXTDOMAIN=steam
export TEXTDOMAINDIR=/usr/share/locale

ARCHIVE_EXT=tar.xz

# figure out the absolute path to the script being run a bit
# non-obvious, the $steampath is where steam lives ($HOME/.steam), cd's into the
# specified directory, then uses $PWD to figure out where that
# directory lives - and all this in a subshell, so we don't affect
# $PWD

STEAMROOT="$(cd $steambase && echo $PWD)"
if [ -z ${STEAMROOT} ]; then
	echo $"Couldn't find Steam root directory from "$0", aborting!"
	exit 1
fi
STEAMDATA="$STEAMROOT"
if [ -z ${STEAMEXE-} ]; then
  STEAMEXE=steam #usually called as steam.sh
fi
# Backward compatibility for server operators
if [ "$STEAMEXE" = "steamcmd" ]; then
	echo "***************************************************"
	echo "The recommended way to run steamcmd is: steamcmd.sh $*"
	echo "***************************************************"
	exec "$STEAMROOT/steamcmd.sh" "$@"
	echo "Couldn't find steamcmd.sh" >&1
	exit 255
fi
cd "$STEAMROOT"

# Save the system paths in case we need to restore them
export SYSTEM_PATH="$PATH"
export SYSTEM_LD_LIBRARY_PATH="${LD_LIBRARY_PATH-}"
export SYSTEM_LD_PRELOAD="$LD_PRELOAD"

##FNC.SH

#determine platform
UNAME=`uname`
if [ "$UNAME" != "Linux" ]; then
   show_message --error "Unsupported Operating System"
   exit 1
fi

# identify Linux distribution and pick an optimal bin dir
PLATFORM=`detect_platform`
PLATFORM32=`echo $PLATFORM | grep 32 || true`
PLATFORM64=`echo $PLATFORM | grep 64 || true`
if [ -z "$PLATFORM32" ]; then
	PLATFORM32=`echo $PLATFORM | sed 's/64/32/'`
fi
if [ -z "$PLATFORM64" ]; then
	PLATFORM64=`echo $PLATFORM | sed 's/32/64/'`
fi
STEAMEXEPATH=$PLATFORM/$STEAMEXE

# common variables for later

# We use ~/.steam for bootstrap symlinks so that we can easily
# tell partners where to go to find the Steam libraries and data.
# This is constant so that legacy applications can always find us in the future.
STEAMCONFIG=$steampath
PIDFILE="$STEAMCONFIG/steam.pid" # pid of running steam for this user
STEAMBIN32LINK="$STEAMCONFIG/bin32"
STEAMBIN64LINK="$STEAMCONFIG/bin64"
STEAMSDK32LINK="$STEAMCONFIG/sdk32" # 32-bit steam api library
STEAMSDK64LINK="$STEAMCONFIG/sdk64" # 64-bit steam api library
STEAMROOTLINK="$STEAMCONFIG/root" # points at the Steam install path for the currently running Steam
STEAMDATALINK="`detect_steamdatalink`" # points at the Steam content path
STEAMSTARTING="$STEAMCONFIG/starting"

# Was -steamos specified
: "${STEAMOS:=}"
if steamos_arg $@; then
	STEAMOS=1
fi

# See if this is the initial launch of Steam
if [ ! -f "$PIDFILE" ] || ! kill -0 $(cat "$PIDFILE") 2>/dev/null; then
	INITIAL_LAUNCH=true
else
	INITIAL_LAUNCH=false
fi

if [ "${1-}" = "--reset" ]; then
	reset_steam
	exit
fi

if [ "$INITIAL_LAUNCH" ]; then
	# Show the license agreement, if needed
	show_license_agreement

	if [ -z "${STEAMSCRIPT:-}" ]; then
		STEAMSCRIPT="$steambin/usr/bin/`detect_package`"
	fi

	# Install any additional dependencies - won't work anyway
#	if [ -z "$STEAMOS" ]; then
#		STEAMDEPS="`dirname $STEAMSCRIPT`/`detect_package`deps"
#		if [ -f "$STEAMDEPS" -a -f "$STEAMROOT/steamdeps.txt" ]; then
#			"$STEAMDEPS" $STEAMROOT/steamdeps.txt
#		fi
#	fi

	# Create symbolic links for the Steam API
	if [ ! -e "$STEAMCONFIG" ]; then
		mkdir "$STEAMCONFIG"
	fi
	if [ "$STEAMROOT" != "$STEAMROOTLINK" -a "$STEAMROOT" != "$STEAMDATALINK" ]; then
		rm -f "$STEAMBIN32LINK" && ln -s "$STEAMROOT/$PLATFORM32" "$STEAMBIN32LINK"
		rm -f "$STEAMBIN64LINK" && ln -s "$STEAMROOT/$PLATFORM64" "$STEAMBIN64LINK"
		rm -f "$STEAMSDK32LINK" && ln -s "$STEAMROOT/linux32" "$STEAMSDK32LINK"
		rm -f "$STEAMSDK64LINK" && ln -s "$STEAMROOT/linux64" "$STEAMSDK64LINK"
		rm -f "$STEAMROOTLINK" && ln -s "$STEAMROOT" "$STEAMROOTLINK"
		if [ "$STEAMDATALINK" ]; then
			rm -f "$STEAMDATALINK" && ln -s "$STEAMDATA" "$STEAMDATALINK"
		fi
	fi

	# Temporary bandaid until everyone has the new libsteam_api.so
	rm -f ~/.steampath && ln -s "$STEAMCONFIG/bin32/steam" ~/.steampath
	rm -f ~/.steampid && ln -s "$PIDFILE" ~/.steampid
	rm -f ~/.steam/bin && ln -s "$STEAMBIN32LINK" ~/.steam/bin
	# Uncomment this line when you want to remove the bandaid
	#rm -f ~/.steampath ~/.steampid ~/.steam/bin
fi

# Show what we detect for distribution and release
echo "Running Steam on $(distro_description)"

# The Steam runtime is a complete set of libraries for running
# Steam games, and is intended to continue to work going forward.
#
# The runtime is open source and the scripts used to build it are
# available on GitHub:
#	https://github.com/ValveSoftware/steam-runtime
#
# We would like this runtime to work on as many Linux distributions
# as possible, so feel free to tinker with it and submit patches and
# bug reports.
#
: "${STEAM_RUNTIME:=}"
if [ "$STEAM_RUNTIME" = "debug" ]; then
	# Use the debug runtime if it's available, and the default if not.
	export STEAM_RUNTIME="$STEAMROOT/$PLATFORM/steam-runtime"

	if unpack_runtime; then
		if [ -z "${STEAM_RUNTIME_DEBUG-}" ]; then
			STEAM_RUNTIME_DEBUG="$(cat "$STEAM_RUNTIME/version.txt" | sed 's,-release,-debug,')"
		fi
		if [ -z "{$STEAM_RUNTIME_DEBUG_DIR-}" ]; then
			STEAM_RUNTIME_DEBUG_DIR="$STEAMROOT/$PLATFORM"
		fi
		if [ ! -d "$STEAM_RUNTIME_DEBUG_DIR/$STEAM_RUNTIME_DEBUG" ]; then
			# Try to download the debug runtime
			STEAM_RUNTIME_DEBUG_URL=$(grep "$STEAM_RUNTIME_DEBUG" "$STEAM_RUNTIME/README.txt")
			mkdir -p "$STEAM_RUNTIME_DEBUG_DIR"

			STEAM_RUNTIME_DEBUG_ARCHIVE="$STEAM_RUNTIME_DEBUG_DIR/$(basename "$STEAM_RUNTIME_DEBUG_URL")"
			if [ ! -f "$STEAM_RUNTIME_DEBUG_ARCHIVE" ]; then
				echo $"Downloading debug runtime: $STEAM_RUNTIME_DEBUG_URL"
				(cd "$STEAM_RUNTIME_DEBUG_DIR" && \
					download_archive $"Downloading debug runtime..." "$STEAM_RUNTIME_DEBUG_URL")
			fi
			if ! extract_archive $"Unpacking debug runtime..." "$STEAM_RUNTIME_DEBUG_ARCHIVE" "$STEAM_RUNTIME_DEBUG_DIR"; then
				rm -rf "$STEAM_RUNTIME_DEBUG" "$STEAM_RUNTIME_DEBUG_ARCHIVE"
			fi
		fi
		if [ -d "$STEAM_RUNTIME_DEBUG_DIR/$STEAM_RUNTIME_DEBUG" ]; then
			echo "STEAM_RUNTIME debug enabled, using $STEAM_RUNTIME_DEBUG"
			export STEAM_RUNTIME="$STEAM_RUNTIME_DEBUG_DIR/$STEAM_RUNTIME_DEBUG"

			# Set up the link to the source code
			ln -sf "$STEAM_RUNTIME/source" /tmp/source
		else
			echo $"STEAM_RUNTIME couldn't download and unpack $STEAM_RUNTIME_DEBUG_URL, falling back to $STEAM_RUNTIME"
		fi
	fi
elif [ "$STEAM_RUNTIME" = "1" ]; then
	echo "STEAM_RUNTIME is enabled by the user"
	export STEAM_RUNTIME="$STEAMROOT/$PLATFORM/steam-runtime"
elif [ "$STEAM_RUNTIME" = "0" ]; then
	echo "STEAM_RUNTIME is disabled by the user"
elif [ -z "$STEAM_RUNTIME" ]; then
	if runtime_supported; then
		echo "STEAM_RUNTIME is enabled automatically"
		export STEAM_RUNTIME="$STEAMROOT/$PLATFORM/steam-runtime"
	else
		echo "STEAM_RUNTIME is disabled automatically"
	fi
else
	echo "STEAM_RUNTIME has been set by the user to: $STEAM_RUNTIME"
fi
if [ "$STEAM_RUNTIME" -a "$STEAM_RUNTIME" != "0" ]; then
	# Unpack the runtime if necessary
	if unpack_runtime; then
		case $(uname -m) in
			*64)
				export PATH="$STEAM_RUNTIME/amd64/bin:$STEAM_RUNTIME/amd64/usr/bin:$PATH"
				;;
			*)
				export PATH="$STEAM_RUNTIME/i386/bin:$STEAM_RUNTIME/i386/usr/bin:$PATH"
				;;
		esac

		export LD_LIBRARY_PATH="$STEAM_RUNTIME/i386/lib/i386-linux-gnu:$STEAM_RUNTIME/i386/lib:$STEAM_RUNTIME/i386/usr/lib/i386-linux-gnu:$STEAM_RUNTIME/i386/usr/lib:$STEAM_RUNTIME/amd64/lib/x86_64-linux-gnu:$STEAM_RUNTIME/amd64/lib:$STEAM_RUNTIME/amd64/usr/lib/x86_64-linux-gnu:$STEAM_RUNTIME/amd64/usr/lib:${LD_LIBRARY_PATH-}"
	else
		echo "Unpack runtime failed, error code $?"
		show_message --error $"Couldn't set up the Steam Runtime. Are you running low on disk space?\nContinuing..."
	fi
fi

# prepend our lib path to LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$STEAMROOT/$PLATFORM:$STEAMROOT/$PLATFORM/panorama:${LD_LIBRARY_PATH-}"

# Check to make sure the user will be able to run steam...
if [ -z "$STEAMOS" ]; then
	check_shared_libraries
fi

# disable SDL1.2 DGA mouse because we can't easily support it in the overlay
export SDL_VIDEO_X11_DGAMOUSE=0
