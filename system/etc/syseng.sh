#!/system/bin/sh

#Error fatal
set -e

LOGNAME="syseng_board_status"
DELAY=593
TMP=/data/syseng
RUN_COUNT=1

# not a hard limit, but a suggestion to some of the collectors
MAXLINELENGTH=300
if type vcdbg >> /dev/null; then
	VC=vcdbg
else
	VC=""
fi

function clear ()
{
	ACCUM=""
}

function output ()
{
	if [ -n "$ACCUM" ] ; then
		echo "$LOGNAME:$1:$ACCUM:NR"
		ACCUM=""
	fi
}

function add_ct ()
{
	ACCUM="${ACCUM}${ACCUM:+,}$1=$2;CT;1"
}
function add_dv ()
{
	name="$1"
	shift
	ACCUM="${ACCUM}${ACCUM:+,}${name}=$@;DV;1"
}


THERMAL_BOOT_DELAY=""
if [ -e /sys/bcm/thermal_delay ] ; then
	read THERMAL_BOOT_DELAY < /sys/bcm/thermal_delay || true
fi

LCR=""
if [ -e /proc/life_cycle_reason ] ; then
	read LCR < /proc/life_cycle_reason || true
fi


boot_only=1
function run ()
{
	WIFI_REMOTE_STATUS=`getprop persist.sys.wifi.device.paired || true`
	REMOTE_TYPE=""
	if [ "$WIFI_REMOTE_STATUS" = "true" ] ; then
		REMOTE_TYPE="wifi"
	else
		REMOTE_TYPE="bluetooth"
	fi

	if [ "$VC" != "" ] ; then

		if [ $boot_only -eq 1 ] ; then
			clear

			if [ "$LCR" = "SOC Overheated Thermal Shutdown" ] ; then
				add_ct tbd_thermal_${REMOTE_TYPE} $THERMAL_BOOT_DELAY
			elif [ "$LCR" = "PCB Overheated Thermal Shutdown" ] ; then
				add_ct tbd_thermal_${REMOTE_TYPE} $THERMAL_BOOT_DELAY
			else
				add_ct tbd_other_${REMOTE_TYPE} $THERMAL_BOOT_DELAY
			fi

			output boot_only
			boot_only=0
		fi

		clear
		#[  0]   111  28049776 (/system/bin/surfaceflinger)
		$VC hostmemuse > $TMP/syseng-vchostmemuse
		while read LINE ; do
			# Trim number
			LINE=${LINE#*] }
			# remove left paren
			LINE=${LINE/\(/}
			# remove right paren
			LINE=${LINE/\)/}
			ary=($LINE)
			len=${#ary[*]}
			if [ $len -eq 3 ] ; then
				usage=${ary[1]}
				cmd=${ary[2]/://}
				# emit ary data, 1==usage, 2==cmd
				add_ct "$cmd" "$usage"
			fi
		done < $TMP/syseng-vchostmemuse
		rm -f $TMP/syseng-vchostmemuse
		output vchostmemuse
	fi


	SOCTEMP_PATH=""
	BOARDTEMP_PATH=""
	TEMP_MAX=""

	clear
	for hwmon in /sys/class/hwmon/hwmon*/device ; do
		if [ -e "$hwmon/name" ] ; then
			read NAME < "$hwmon/name"
			if [ "$NAME" = "tmp103_sensor" ] ; then
				BOARDTEMP_PATH="$hwmon"
				BOARDTEMP_NAME="$NAME"
			elif [ "$NAME" = "soctemp" ] ; then
				SOCTEMP_PATH="$hwmon"
				SOCTEMP_NAME="$NAME"
				for level in 0 1 2 3 ; do
					ENABLED="0"
					read ENABLED < "$hwmon/temp1_enable$level" || true
					if [ "$ENABLED" = "1" ] ; then
						MAX="0"
						read MAX < "$hwmon/temp1_max$level" || true
						add_ct soc_ts${level}_max $MAX
					fi
				done
				MAX=0
				read MAX < "$hwmon/temp1_crit" || true
				add_ct soc_crit_max $MAX
			fi
		fi
	done
	TEMP_MAX="$ACCUM"

	clear
	ACCUM="$TEMP_MAX"
	if [ -n "$BOARDTEMP_PATH" ] ; then
		read VALUE < "$BOARDTEMP_PATH/temp1_input" && add_ct $BOARDTEMP_NAME $VALUE
	fi

	if [ -n "$SOCTEMP_PATH" ] ; then
		read VALUE < "$SOCTEMP_PATH/temp1_input"
		add_ct $SOCTEMP_NAME $VALUE
		if [ -e "$SOCTEMP_PATH/thermal_state" ] ; then
			read VALUE < "$SOCTEMP_PATH/thermal_state"
			add_ct soc_tstate $VALUE
		fi
		if [ -e "$SOCTEMP_PATH/temp_avg" ] ; then
			read VALUE < "$SOCTEMP_PATH/temp_avg"
			add_ct soc_avg $VALUE
		fi
		if [ -e "$SOCTEMP_PATH/max_temp" ] ; then
			read VALUE < "$SOCTEMP_PATH/max_temp"
			add_ct soc_max $VALUE
		fi
		if [ -e "$SOCTEMP_PATH/stats/time_in_state" ] ; then
			while read STATE TIME; do
				add_ct soc_ts${STATE}_time $TIME
			done < "$SOCTEMP_PATH/stats/time_in_state"
		fi
		if [ -e "$SOCTEMP_PATH/stats/transitions_to_state" ] ; then
			while read STATE COUNT ; do
				add_ct soc_ts${STATE}_trans $COUNT
			done < "$SOCTEMP_PATH/stats/transitions_to_state"
		fi
	fi
	output tempstat

	# add emmc metrics. Most montoya devices use Toshiba mmc. Samsung is also an
	# approved vendor, but they did not provide an api for obtaining mmc metrics.
	# Montoya devices with Samsung mmc will return Unknown for mmcinfo and null
	# for mmc_max and mmc_avg.
	clear
	EMMC_INFO=""
	if [ -e /proc/emmcinfo ] ; then
		read EMMC_INFO < /proc/emmcinfo || true
	fi
	EMMC_AVG=""
	if [ -e /proc/emmcmlc_avg ] ; then
		read EMMC_AVG < /proc/emmcmlc_avg || true
	fi
	EMMC_MAX=""
	if [ -e /proc/emmcmlc_max ] ; then
		read EMMC_MAX < /proc/emmcmlc_max || true
	fi
	EMMC_LIFETIME_A=""
	if [ -e /proc/emmc_lifetime_a ] ; then
		read EMMC_LIFETIME_A < /proc/emmc_lifetime_a || true
	fi
	EMMC_LIFETIME_B=""
	if [ -e /proc/emmc_lifetime_b ] ; then
		read EMMC_LIFETIME_B < /proc/emmc_lifetime_b || true
	fi

	add_dv emmcinfo $EMMC_INFO
	add_ct emmcmlc_avg $EMMC_AVG
	add_ct emmcmlc_max $EMMC_MAX
	add_ct emmc_lifetime_a $EMMC_LIFETIME_A
	add_ct emmc_lifetime_b $EMMC_LIFETIME_B

	output emmcstats

	let RUN_COUNT=RUN_COUNT+1 1
}

# Run the collection repeatedly, pushing all output through to the metrics log.
# Sleep first so that we don't try to collect metrics immediately after boot-up,
# when everything is starting up.
while true ; do
	sleep $DELAY
	run > $TMP/syseng-run
	while read LINE ; do
		log -t "metrics.$LOGNAME" $LINE
	done < $TMP/syseng-run
	rm -f $TMP/syseng-run
done
