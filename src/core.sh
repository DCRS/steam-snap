#!/bin/bash

# Touch our startup file so we can detect bootstrap launch failure
if [ "$UNAME" = "Linux" ]; then
	: >"$STEAMSTARTING"
fi

MAGIC_RESTART_EXITCODE=42
SEGV_EXITCODE=139

echo "try $STEAMROOT"
echo "try_ $STEAMEXEPATH"

# and launch steam
STEAM_DEBUGGER=${DEBUGGER-}
unset DEBUGGER # Don't use debugger if Steam launches itself recursively
set +e #if steam exits with code 42 or similar
if [ "$STEAM_DEBUGGER" == "gdb" ] || [ "$STEAM_DEBUGGER" == "cgdb" ]; then
	ARGSFILE=$(mktemp $USER.steam.gdb.XXXX)

	# Set the LD_PRELOAD varname in the debugger, and unset the global version.
	: "${LD_PRELOAD=}"
	if [ "$LD_PRELOAD" ]; then
		echo set env LD_PRELOAD=$LD_PRELOAD >> "$ARGSFILE"
		echo show env LD_PRELOAD >> "$ARGSFILE"
		unset LD_PRELOAD
	fi

	$STEAM_DEBUGGER -x "$ARGSFILE" --args "$STEAMROOT/$STEAMEXEPATH" "$@"
	rm "$ARGSFILE"
elif [ "$STEAM_DEBUGGER" == "valgrind" ]; then
    : "${STEAM_VALGRIND:=}"
	DONT_BREAK_ON_ASSERT=1 G_SLICE=always-malloc G_DEBUG=gc-friendly valgrind --error-limit=no --undef-value-errors=no --suppressions=$PLATFORM/steam.supp $STEAM_VALGRIND "$STEAMROOT/$STEAMEXEPATH" "$@" 2>&1 | tee steam_valgrind.txt
elif [ "$STEAM_DEBUGGER" == "callgrind" ]; then
    valgrind --tool=callgrind --instr-atstart=no "$STEAMROOT/$STEAMEXEPATH" "$@"
elif [ "$STEAM_DEBUGGER" == "strace" ]; then
    strace -osteam.strace "$STEAMROOT/$STEAMEXEPATH" "$@"
else
	$STEAM_DEBUGGER "$STEAMROOT/$STEAMEXEPATH" "$@"
fi
STATUS=$?

# Restore paths before unpacking the bootstrap if we need to.
export PATH="$SYSTEM_PATH"
export LD_LIBRARY_PATH="$SYSTEM_LD_LIBRARY_PATH"

if [ "$UNAME" = "Linux" ]; then
	if [ "$INITIAL_LAUNCH" -a \
	     $STATUS -ne $MAGIC_RESTART_EXITCODE -a \
	     -f "$STEAMSTARTING" -a \
	     -z "${STEAM_INSTALLED_BOOTSTRAP-}" ]; then
		# Launching the bootstrap failed, try reinstalling
		if reset_steam; then
			# We were able to reinstall the bootstrap, try again
			export STEAM_INSTALLED_BOOTSTRAP=1
			STATUS=$MAGIC_RESTART_EXITCODE
		fi
	fi
fi

# If steam requested to restart, then restart - implented in the launcher.sh script
