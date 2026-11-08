#!/system/bin/sh
FILE2CHECK="/data/hwval/adb_check.bin"
MD5CHECK="27ec1016c3db85fa8bb547ada6d3321e"

if [ x$(getprop ro.boot.unlocked_kernel) == 'xtrue' ]; then
	echo "Enabling ADB for unlocked devices" > /dev/kmsg
	setprop sys.usb.config adb
	exit
else
	echo "DEVICE IS LOCKED" > /dev/kmsg
fi

if [ -e ${FILE2CHECK} ] ; then
	CHECKSUM=$(md5 ${FILE2CHECK})
	CHECKSUM=${CHECKSUM%% *}
	if [ "${CHECKSUM}" == "${MD5CHECK}" ] ; then
		echo "Enabling ADB on first boot" > /dev/kmsg
		setprop sys.usb.config adb
	fi
	rm -rf ${FILE2CHECK}
	sync
fi
