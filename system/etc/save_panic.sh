#!/system/bin/sh

# Script to record emphemeral information (VC state, kernel logs),
# and write it to a file to try to ensure it is captured for futher
# use. This script is expected to finish within 10 seconds; it is
# not guarrantteed that the caller will block waiting for it to complete.

# Since this is executed when the VC has apparently crashed, use of
# system services or IPC should be limited as much as possible, to
# avoid the possibility of deadlocks with other parts of the system
# may be suceptible to hanging, in this state.

# Note: this script may be triggered from a kernel helper: make
# no assumptions about environment or path.

set +e # Keep going if there are any unexpected errors

DIR=/data/panics

REASON="$@"

PANIC="$DIR/panic_log.txt"

BOOTID="unknown"
read BOOTID < /proc/sys/kernel/random/boot_id || true
UPTIME="unknown"
read UPTIME REST < /proc/uptime || true

MKDIR=/system/bin/mkdir
DATE=/system/bin/date
CHOWN=/system/bin/chown
SYNC=/system/bin/sync
DMESG=/system/bin/dmesg
VCDBG=/system/bin/vcdbg

VCDBGARGS="dumpstate -vv"
VCDBGARGS_I2C="dump i2c_debug"

TAG="*******************************************"

# ensure any directories created are initially only
# u+rwx, g+rwx, o+rx
umask 0002

# ensure directory is created
$MKDIR -p "$DIR"

# We need to grant system access so ABS can later take
# files and push them to the dropbox
$CHOWN root.system "$DIR"

# ensure any files created are initially only
# u+rwx, g+rw, o+
umask 0017

# Only append to file: if existing report has not been collected
# just keep appending to it

echo "Beginning of panic log for reason: $REASON"	>> "$PANIC"
echo -n "Wall clock at start of panic log: " 		>> "$PANIC"
$DATE 							>> "$PANIC"
echo "Uptime at start of panic log: $UPTIME"		>> "$PANIC"
echo "Boot id for panic: $BOOTID"			>> "$PANIC"

echo "$TAG"						>> "$PANIC"
echo "Results of: dmesg" 				>> "$PANIC"
$DMESG							>> "$PANIC"
echo "$TAG"						>> "$PANIC"
echo "Results of: vcdbg $VCDBGARGS" 			>> "$PANIC"
$VCDBG $VCDBGARGS 					>> "$PANIC"
echo "Results of: vcdbg $VCDBGARGS_I2C" 		>> "$PANIC"
$VCDBG $VCDBGARGS_I2C 					>> "$PANIC"
$SYNC # Ensure critical information is synced

echo "$TAG"						>> "$PANIC"
echo -n "Wall clock at end of panic log: " 		>> "$PANIC"
$DATE 							>> "$PANIC"
echo "End of panic log for reason: $REASON"		>> "$PANIC"
$SYNC # Ensure footer is synced
