#!/system/bin/sh

set +e # keep going even with unexpected errors

DIR=/data/panics


# Check to see if a new panic was recorded
if [ -f "$DIR/panic_log.txt" ] ; then

	# If so, first, link it to a name that it will be added to
	# the dropbox by a later stage.

	ln "$DIR/panic_log.txt" "$DIR/panic_log_dropbox.txt" || true

	# and then rotate logs to ensure we keep a history of panics

	# drop panic_log_09.txt if it exists
	mv "$DIR/panic_log_08.txt" "$DIR/panic_log_09.txt" || true
	mv "$DIR/panic_log_07.txt" "$DIR/panic_log_08.txt" || true
	mv "$DIR/panic_log_06.txt" "$DIR/panic_log_07.txt" || true
	mv "$DIR/panic_log_05.txt" "$DIR/panic_log_06.txt" || true
	mv "$DIR/panic_log_04.txt" "$DIR/panic_log_05.txt" || true
	mv "$DIR/panic_log_03.txt" "$DIR/panic_log_04.txt" || true
	mv "$DIR/panic_log_02.txt" "$DIR/panic_log_03.txt" || true
	mv "$DIR/panic_log_01.txt" "$DIR/panic_log_02.txt" || true
	mv "$DIR/panic_log.txt"    "$DIR/panic_log_01.txt" || true

	# Migrate permissions so system service can read: only modify
	# permissions of files we know we created, in a directory that
	# has only ever had root write permissions.
	chown system.system $DIR/panic_log*.txt || true

	# ensure rotated log entries are committed to disk
	sync
fi
