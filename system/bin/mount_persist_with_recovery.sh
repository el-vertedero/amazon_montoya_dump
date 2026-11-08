#!/system/bin/sh

# This script checks for two things: 1. consistency of persist partition and 2. contents of persist partition.
# If either of them is incorrect, it attempts to recover by mounting a known good copy in goldpersist and
# copying it to persist.

PERSIST=/dev/block/platform/sdhci.1/by-name/persist
GOLDPERSIST=/dev/block/platform/sdhci.1/by-name/goldpersist
MOUNT_ARGS_RO="-oro,context=u:object_r:persist_file:s0,nosuid,nodev,data=ordered -text4"
MOUNT_ARGS_RW="-orw,context=u:object_r:persist_file:s0,nosuid,nodev,data=ordered -text4"

# E2FSCK return codes
# ret val of 4 or 8 forces recovery, ret val of 2 forces reboot, everything else system continues to boot
E2FSCK_RET_NO_ERR=0
E2FSCK_RET_FS_ERR_CORRECTED=1
E2FSCK_RET_SYS_REBOOT=2
E2FSCK_RET_FS_ERR_UNCORRECTED=4
E2FSCK_RET_OP_ERR=8
E2FSCK_RET_USAGE_ERR=16
E2FSCK_RET_USR_CANCEL=32
E2FSCK_RET_SHARED_LIB_ERR=64

# function dump()
# dumps the argument to dmesg
dump ()
{
	echo $1 > /dev/kmsg
}

# function wait_for_file()
# wait for the device to be available for mounting
# default wait time is 5 secs similar to do_wait() in /system/core/init/builtins.c
wait_for_file ()
{
	dump "executing wait_for_file on $1"
	x=0
	while [ "$x" -lt 5  -a ! -e $1]; do
		x=$(($x+1))
		/system/bin/sleep 1
	done
}

# function recover_persist()
# 1. unmount persist
# 2. create a new ext4 partition
# 3. mount persist as rw
# 4. mount goldpersist as read-only
# 5. copy goldpersist to persist
# 6. change ownership of /persist to system and mode of access of persist/data/SFS/* keys to 444
# 7. unmount persist and mount it back as read-only
# 8. unmount goldpersist
# 9. delete cached keys in /data/DxDrm/ and /data/sfs
recover_persist ()
{
	dump "recovering persist partition"

	dump "unmounting persist"
	/system/bin/umount /persist

	dump "creating new ext4 partition"
	/system/bin/make_ext4fs -l 8388608 $PERSIST

	dump "mounting persist as rw"
	/system/bin/mount $MOUNT_ARGS_RW $PERSIST /persist

	wait_for_file $GOLDPERSIST

	dump "mounting goldpersist as read only"
	/system/bin/mount -oro,context=u:object_r:persist_file:s0 -text4 $GOLDPERSIST /mnt/asec

	dump "copying goldpersist to persist"
	/system/bin/cp -r /mnt/asec/* /persist/
	/system/bin/sync

	dump "persist partition: changing permissions to rw and ownership to system"
	chmod 0555 /persist
	chown system:system /persist
	chown system:system /persist/*
	chown system:system /persist/data/*
	chown system:system /persist/data/SFS/*
	chmod 0444 /persist/data/SFS/*

	dump "unmounting persist"
	/system/bin/umount /persist

	dump "mounting persist as ro"
	/system/bin/mount $MOUNT_ARGS_RO $PERSIST /persist

	dump "unmounting goldpersist"
	/system/bin/umount /mnt/asec
	ret_mount=$?
	dump "umount goldpersist returned $ret_mount"

	dump "delete cached keys"
	/system/bin/rm /data/DxDrm/DxKeyFile.dat
	/system/bin/rm /data/DxDrm/DxPlayReadyDB.hds
	/system/bin/rm -rf /data/sfs

	exit 0
}

wait_for_file $PERSIST

dump "executing e2fsck"
/system/bin/e2fsck -y $PERSIST
ret_fsck=$?
dump "fsck returned $ret_fsck"

if [ $(( $ret_fsck & $E2FSCK_RET_FS_ERR_UNCORRECTED )) -eq $E2FSCK_RET_FS_ERR_UNCORRECTED -o $(( $ret_fsck & $E2FSCK_RET_OP_ERR )) -eq $E2FSCK_RET_OP_ERR ] ; then
	recover_persist
fi

dump "executing mount"
/system/bin/mount $MOUNT_ARGS_RO $PERSIST /persist
ret_mount=$?
dump "mount returned $ret_mount"
if [ "$ret_mount" != "0" ] ; then
	recover_persist
fi

dump "checking persist contents"
/system/bin/sh /system/bin/persist_check.sh
ret=$?
dump "persist_check returned $ret"
if [ "$ret" != "0" ] ; then
	recover_persist
fi

exit 0
