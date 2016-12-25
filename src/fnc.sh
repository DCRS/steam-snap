#!/bin/bash

function show_message()
{
	style=$1
	shift

	case "$style" in
	--error)
		title=$"Error"
		;;
	--warning)
		title=$"Warning"
		;;
	*)
		title=$"Note"
		;;
	esac

	# Show the message on standard output, for logging
	echo -e "$title: $*"

	if [ -z "$STEAMOS" ]; then
		if ! zenity "$style" --text="$*" 2>/dev/null; then
			# Save the prompt in a temporary file because it can have newlines in it
			tmpfile="$(mktemp || echo "/tmp/steam_message.txt")"
			echo -e "$*" >"$tmpfile"
			xterm -bg "#383635" -fg "#d1cfcd" -T "$title" -e "cat $tmpfile; echo -n 'Press enter to continue: '; read input" 2>/dev/null || \
				(echo "$title:"; cat "$tmpfile"; echo -n 'Press enter to continue: '; read input)
			rm -f "$tmpfile"
		fi
	else
		# Temporary until we have a zenity equivalent for SteamOS
		echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $title: $*" >> /tmp/steam_startup_messages_$USER.txt
	fi
}

function show_license_agreement()
{
	LICENSE="$STEAMROOT/steam_install_agreement.txt"
	if [ ! -f "$STEAMCONFIG/steam_install_agreement.txt" ]; then
		if [ ! -f "$LICENSE" ]; then
			show_message --error $"Couldn't find Steam install license agreement, aborting!"
			exit 1
		fi

		set +e
		# See if they have been grandfathered in through the beta
		SSAVersion=$(find -L "$STEAMCONFIG/`detect_package`" -name sharedconfig.vdf -exec fgrep SSAVersion {} \;)
		set -e

		if [ "$SSAVersion" != "" ]; then
			answer=accepted
		else
			answer=declined
			set +e
			output=$(zenity --width 650 --height 500 --text-info --title=$"Steam Install Agreement" --filename="$LICENSE" --checkbox=$"I have read and accept these terms." 2>&1)
			STATUS=$?
			set -e
			if echo $output | grep "status 1:" >/dev/null; then
				# Zenity couldn't launch a window
				STATUS=-1
			fi
			case $STATUS in
			0)	# The agreement was accepted
				answer=accepted
				;;
			1)	# The agreement was declined
				;;
			*)	# zenity wasn't available, try a fallback
				tmpfile="$(mktemp || echo "/tmp/steam_message.txt")"
				command="more \"$LICENSE\" || cat \"$LICENSE\"; echo -n $'Do you accept the terms of this agreement? [y/N]: '; read input; if [ x\$input = xy -o x\$input = xY ]; then echo accepted >\"$tmpfile\"; fi"
				xterm -bg "#383635" -fg "#d1cfcd" -T $"Steam Install Agreement" -e "$command" || \
					/bin/bash -c "$command"
				if [ -f "$tmpfile" ]; then
					read answer <"$tmpfile"
					rm "$tmpfile"
				fi
				;;
			esac
			if [ "$answer" != "accepted" ]; then
				exit 0
			fi
		fi

		cp "$LICENSE" "$STEAMCONFIG"/
	fi
}


function distro_description()
{
	echo "$(detect_distro) $(detect_release) $(detect_arch)"
}

function detect_distro()
{
	if [ -f /etc/lsb-release ]; then
		(. /etc/lsb-release; echo $DISTRIB_ID | tr '[A-Z]' '[a-z]')
	elif [ -f /etc/os-release ]; then
		(. /etc/os-release; echo $ID | tr '[A-Z]' '[a-z]')
	elif [ -f /etc/debian_version ]; then
		echo "debian"
	else
		# Generic fallback
		uname -s
	fi
}

function detect_release()
{
	if [ -f /etc/lsb-release ]; then
		(. /etc/lsb-release; echo $DISTRIB_RELEASE)
	elif [ -f /etc/os-release ]; then
		(. /etc/os-release; echo $VERSION_ID)
	elif [ -f /etc/debian_version ]; then
		cat /etc/debian_version
	else
		# Generic fallback
		uname -r
	fi
}

function detect_arch()
{
	case $(uname -m) in
	*64)
		echo "64-bit"
		;;
	*)
		echo "32-bit"
		;;
	esac
}

function detect_platform()
{
	# Default to unknown/unsupported distribution, pick something and hope for the best
	platform=ubuntu12_32

	# Check for specific supported distribution releases
	case "$(detect_distro)-$(detect_release)" in
	ubuntu-12.*)
		platform=ubuntu12_32
		;;
	esac
	echo $platform
}

function detect_universe()
{
	if test -f "$STEAMROOT/Steam.cfg" && \
	     egrep '^[Uu]niverse *= *[Bb]eta$' "$STEAMROOT/Steam.cfg" >/dev/null; then
		STEAMUNIVERSE="Beta"
	elif test -f "$STEAMROOT/steam.cfg" && \
	     egrep '^[Uu]niverse *= *[Bb]eta$' "$STEAMROOT/steam.cfg" >/dev/null; then
		STEAMUNIVERSE="Beta"
	else
		STEAMUNIVERSE="Public"
	fi
	echo $STEAMUNIVERSE
}

function detect_package()
{
	case `detect_universe` in
	"Beta")
		STEAMPACKAGE="steambeta"
		;;
	*)
		STEAMPACKAGE="steam"
		;;
	esac
	echo "$STEAMPACKAGE"
}


function detect_steamdatalink()
{
	# Don't create a link in development
	if [ -f "$STEAMROOT/steam_dev.cfg" ]; then
		STEAMDATALINK=""
	else
		STEAMDATALINK="$STEAMCONFIG/`detect_package`"
	fi
	echo $STEAMDATALINK
}

function detect_bootstrap()
{
	if [ -f "$STEAMROOT/bootstrap.tar.xz" ]; then
		echo "$STEAMROOT/bootstrap.tar.xz"
	else
		# This is the default bootstrap install location for the Ubuntu package.
		# We use this as a fallback for people who have an existing installation and have never run the new install_bootstrap code in bin_steam.sh
		echo "$steambin/usr/lib/`detect_package`/bootstraplinux_`detect_platform`.tar.xz"
	fi
}

function install_bootstrap()
{
	# Don't install if disabled
	if ! [ -z "$disablebootstrapupdates" ]; then
		return 0
	fi
	# Don't install bootstrap in development
	if [ -f "$STEAMROOT/steam_dev.cfg" ]; then
		return 1
	fi

	STATUS=0

	# Save the umask and set strong permissions
	omask=`umask`
	umask 0077

	STEAMBOOTSTRAPARCHIVE=`detect_bootstrap`
	if [ -f "$STEAMBOOTSTRAPARCHIVE" ]; then
		echo "Installing bootstrap $STEAMBOOTSTRAPARCHIVE"
		tar xf "$STEAMBOOTSTRAPARCHIVE"
		STATUS=$?
	else
		show_message --error $"Couldn't start bootstrap and couldn't reinstall from $STEAMBOOTSTRAPARCHIVE.  Please contact technical support."
		STATUS=1
	fi

	# Restore the umask
	umask $omask

	return $STATUS
}

function runtime_supported()
{
	case "$(detect_distro)-$(detect_release)" in
	# Add additional supported distributions here
	ubuntu-*)
		return 0
		;;
	*)	# Let's try this out for now and see if it works...
		return 0
		;;
	esac

	# This distro doesn't support the Steam Linux Runtime (yet!)
	return 1
}

function download_archive()
{
	curl -#Of "$2" 2>&1 | tr '\r' '\n' | sed 's,[^0-9]*\([0-9]*\).*,\1,' | zenity --progress --auto-close --no-cancel --width 400 --text="$1\n$2"
	return ${PIPESTATUS[0]}
}

function extract_archive()
{
	case "$2" in
	*.gz)
		BF=$(($(gzip --list "$2" | sed -n -e "s/.*[[:space:]]\+[0-9]\+[[:space:]]\+\([0-9]\+\)[[:space:]].*$/\1/p") / $((512 * 100)) + 1))
		;;
	*.xz)
		BF=$(($(xz --robot --list "$2" | grep totals | awk '{print $5}') / $((512 * 100)) + 1))
		;;
	*)
		BF=""
		;;
	esac
	if [ "${BF}" ]; then
		tar --blocking-factor=${BF} --checkpoint=1 --checkpoint-action='exec=echo $TAR_CHECKPOINT' -xf "$2" -C "$3" | zenity --progress --auto-close --no-cancel --width 400 --text="$1"
		return ${PIPESTATUS[0]}
	else
		echo "$1"
		tar -xf "$2" -C "$3"
		return $?
	fi
}

function has_runtime_archive()
{
	# Make sure we have files to unpack
    if [ ! -f "$STEAM_RUNTIME.$ARCHIVE_EXT.part0" ]; then
		return 1
	fi

	if [ ! -f "$STEAM_RUNTIME.checksum" ]; then
		return 1
	fi

	return 0
}

function unpack_runtime()
{
	if ! has_runtime_archive; then
		if [ -d "$STEAM_RUNTIME" ]; then
			# The runtime is unpacked, let's use it!
			return 0
		fi
		return 1
	fi

	# Make sure we haven't already unpacked them
	if [ -f "$STEAM_RUNTIME/checksum" ] && cmp "$STEAM_RUNTIME.checksum" "$STEAM_RUNTIME/checksum" >/dev/null; then
		return 0
	fi

	# Unpack the runtime
	EXTRACT_TMP="$STEAM_RUNTIME.tmp"
	rm -rf "$EXTRACT_TMP"
	mkdir "$EXTRACT_TMP"
	cat "$STEAM_RUNTIME.$ARCHIVE_EXT".part* >"$STEAM_RUNTIME.$ARCHIVE_EXT"
	EXISTING_CHECKSUM="$(cd "$(dirname "$STEAM_RUNTIME")"; md5sum "$(basename "$STEAM_RUNTIME.$ARCHIVE_EXT")")"
	EXPECTED_CHECKSUM="$(cat "$STEAM_RUNTIME.checksum")"
	if [ "$EXISTING_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
		echo $"Runtime checksum: $EXISTING_CHECKSUM, expected $EXPECTED_CHECKSUM" >&2
		return 2
	fi
	if ! extract_archive $"Unpacking Steam Runtime" "$STEAM_RUNTIME.$ARCHIVE_EXT" "$EXTRACT_TMP"; then
		return 3
	fi

	# Move it into place!
	if [ -d "$STEAM_RUNTIME" ]; then
		rm -rf "$STEAM_RUNTIME.old"
		if ! mv "$STEAM_RUNTIME" "$STEAM_RUNTIME.old"; then
			return 4
		fi
	fi
	if ! mv "$EXTRACT_TMP"/* "$EXTRACT_TMP"/..; then
		return 5
	fi
	rm -rf "$EXTRACT_TMP"
	if ! cp "$STEAM_RUNTIME.checksum" "$STEAM_RUNTIME/checksum"; then
		return 6
	fi
	return 0
}

function get_missing_libraries()
{
	# Make sure to turn off injected dependencies (LD_PRELOAD) when running ldd
	if ! LD_PRELOAD= ldd "$1" >>/dev/null 2>&1; then
		# We couldn't run the link loader for this architecture
		echo "libc.so.6"
	else
		LD_PRELOAD= ldd "$1" | grep "=>" | grep -v linux-gate | grep -v / | awk '{print $1}' || true
	fi
}

function check_shared_libraries()
{
	if [ -f "$STEAMROOT/$PLATFORM/steamui.so" ]; then
		MISSING_LIBRARIES=$(get_missing_libraries "$STEAMROOT/$PLATFORM/steamui.so")
	else
		MISSING_LIBRARIES=$(get_missing_libraries "$STEAMROOT/$PLATFORM/$STEAMEXE")
	fi
	if [ "$MISSING_LIBRARIES" != "" ]; then
		show_message --error $"You are missing the following 32-bit libraries, and Steam may not run:\n$MISSING_LIBRARIES"
	fi
}

function ignore_signal()
{
	:
}

function reset_steam()
{
	# Ensure STEAMROOT is defined to something reasonable so we don't wipe the wrong thing
	if [ -z "${STEAMROOT}" ]; then
		show_message --error $"Couldn't find Steam directory, it's not safe to reset Steam. Please contact technical support."
		return 1
	fi

	# Don't wipe development files
	if [ -f "$STEAMROOT/steam_dev.cfg" ]; then
		echo "Can't reset development directory"
		return 1
	fi

	if [ -z "$INITIAL_LAUNCH" ]; then
		show_message --error $"Please exit Steam before resetting it."
		return 1
	fi

	if [ ! -f "$(detect_bootstrap)" ]; then
		show_message --error $"Couldn't find bootstrap, it's not safe to reset Steam. Please contact technical support."
		return 1
	fi

	if [ "$STEAMROOT" = "" ]; then
		show_message --error $"Couldn't find Steam, it's not safe to reset Steam. Please contact technical support."
		return 1
	fi

	STEAM_SAVE="$STEAMROOT/.save"

	# Don't let the user interrupt us, or they may corrupt the install
	trap ignore_signal INT

	# /usr/bin/steam uses the existence of the data link to know whether to bootstrap. Remove it before
	# continuing, so that if the machine is turned off while this is occuring, a new bootstrap will be
	# put in place next time steam is run.
	rm -f "$STEAMDATALINK"

	# Back up games and critical files
	# Backup package dir so that we're not hitting CDNs if there is no manifest change
	mkdir -p "$STEAM_SAVE"
	for i in bootstrap.tar.xz ssfn* SteamApps steamapps userdata package; do
		if [ -e "$i" ]; then
			mv -f "$i" "$STEAM_SAVE/"
		fi
	done
	for i in "$STEAMCONFIG/registry.vdf"; do
		mv -f "$i" "$i.bak"
	done

	# Check before removing
	if [ "$STEAMROOT" != "" ]; then
		rm -rf "$STEAMROOT/"*
	fi

	# Move things back into place
	mv -f "$STEAM_SAVE/"* "$STEAMROOT/"
	rmdir "$STEAM_SAVE"

	# Reinstall the bootstrap and we're done.
	if install_bootstrap; then
		STATUS=0

		# Restore the steam data link
		ln -s "$STEAMDATA" "$STEAMDATALINK"
		echo $"Reset complete!"
	else
		STATUS=1
		echo $"Reset failed!"
	fi

	# Okay, at this point we can recover, so re-enable interrupts
	trap '' INT

	return $STATUS
}

function steamos_arg()
{
    for option in "$@"
    do
		if [ "$option" = "-steamos" ]; then
			return 0; # 0 == true in bash
        fi
    done

	return 1; # 1 == false in bash speak
}
