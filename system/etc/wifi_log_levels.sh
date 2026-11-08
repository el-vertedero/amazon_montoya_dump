#!/system/bin/sh

LOGSRC="wifi"
LOGNAME="wifi_log_levels"
METRICSTAG="metrics.$LOGNAME"
LOGCATTAG="main.$LOGNAME"
DELAY=120
LOOPSTILMETRICS=29 # Should send to metrics buffer every hour
currentLoop=0
TMP=/tmp #tmpfs, should not be permanent storage
WL=/system/xbin/wl

if [ ! -x $WL ] ; then
	exit
fi

# Given a line containing a wl status mode line, record values we are interested in
#Mode: Managed   RSSI: -46 dBm   SNR: 0 dB       noise: -91 dBm  Flags: RSSI on-channel  Channel: 165

function wl_status_mode_tokens ()
{
	while [ $# -gt 0 ] ; do
		case "$1" in
			RSSI:)
				RSSI=$2
				CONN_STATUS="ConnStatusConnected"
				shift 2
				;;
			noise:)
				NOISE=$2
				shift 2
				;;
			Channel:)
				CHANNEL=$2
				shift 2
				;;
			"Not associated.")
				CONN_STATUS="ConnStatusDisconnected"
				shift
				;;
			*)	shift
				;;
		esac
	done
}

function log_connstatus_metrics
{
	logStr="$LOGSRC:$LOGNAME:$CONN_STATUS=1;CT;1;NR"
	log -t $METRICSTAG $logStr
}

function log_metrics_wifi_status
{
	if [ $CONN_STATUS != "ConnStatusConnected" ] ; then
		return
	fi
	status=`$WL status`

	# Chanspec is present in 11n/ac capabilities.
	bandwidth=`echo "$status" | grep Chanspec | grep -o -e [248]0MHz`
	if [ "$bandwidth" ] ; then
		logBwStr="$LOGSRC:$LOGNAME:ChannelBandwidth$bandwidth=1;CT;1:NR"
	else
		# Device is 11a/b/g which only has 20 MHz bandwidth
		logBwStr="$LOGSRC:$LOGNAME:ChannelBandwidth20MHz=1;CT;1:NR"
	fi
	log -t $METRICSTAG $logBwStr

	channel=${CHANNEL%/*}

	# wl status should have "802.11N Capable:" for 11n
	ht=`echo "$status" | grep "802.11N Capable"`
	if [ "$ht" ] ; then
		logStr="$LOGSRC:$LOGNAME:WifiMode11n=1;CT;1:NR"
		log -t $METRICSTAG $logStr
		return
	fi

	# If all the supported rates have (b), assume 11b.
	rates=`echo "$status" | grep "Supported Rates"`
	if [ "${rates#*[0-9] }" == "$rates" ] ; then
		logStr="$LOGSRC:$LOGNAME:WifiMode11b=1;CT;1:NR"
		log -t $METRICSTAG $logStr
		return
	fi

	# If the above are not true, then it is g/a depending on channel
	if [ $channel -lt 36 ] ; then
		logStr="$LOGSRC:$LOGNAME:WifiMode11g=1;CT;1:NR"
		log -t $METRICSTAG $logStr
	else
		logStr="$LOGSRC:$LOGNAME:WifiMode11a=1;CT;1:NR"
		log -t $METRICSTAG $logStr
	fi
}

function log_metrics_rssi
{
	if [ "$RSSI" -eq 0 ]; then
		return 0
	fi
	logStr="$LOGSRC:$LOGNAME:RssiLevel$RSSI=1;CT;1:NR"
	log -t $METRICSTAG $logStr
}

function log_metrics_snr
{
	if [ "$RSSI" -eq 0 -o "$NOISE" -eq 0 ]; then
		return 0
	fi
	SNR=$(($RSSI - $NOISE))
	logStr="$LOGSRC:$LOGNAME:SnrLevel$SNR=1;CT;1:NR"
	log -t $METRICSTAG $logStr
}

function log_metrics_noise
{
	if [ "$NOISE" -eq 0 ]; then
		return 0
	fi
	logStr="$LOGSRC:$LOGNAME:NoiseLevel$NOISE=1;CT;1:NR"
	log -t $METRICSTAG $logStr
}

function log_metrics_p2p_rssi
{
	if [ "$P2P_RSSI" -eq 0 ]; then
		return 0
	fi
	logStr="$LOGSRC:$LOGNAME:P2PRssiLevel$P2P_RSSI=1;CT;1:NR"
	log -t $METRICSTAG $logStr
}

function log_metrics_p2p_snr
{
	if [ "$P2P_RSSI" -eq 0 -o "$NOISE" -eq 0 ]; then
		return 0
	fi
	P2P_SNR=$(($P2P_RSSI - $NOISE))
	logStr="$LOGSRC:$LOGNAME:P2PSnrLevel$P2P_SNR=1;CT;1:NR"
	log -t $METRICSTAG $logStr
}

function log_metrics_p2p_noise
{
	if [ "$P2P_RSSI" -eq 0 -o "$NOISE" -eq 0 ]; then
		return 0
	fi
	logStr="$LOGSRC:$LOGNAME:P2PNoiseLevel$NOISE=1;CT;1:NR"
	log -t $METRICSTAG $logStr
}

function log_metrics_reset_counter
{
		RESET_COUNT="0"
		if [ -e /proc/wifi_reset_counter ] ; then
			read RESET_COUNT < /proc/wifi_reset_counter
		fi
		log -t $METRICSTAG "$LOGSRC:$LOGNAME:wifi_reset_counter=$RESET_COUNT;CT;1:NR"
}

function log_wifi_metrics
{
	log_metrics_rssi
	log_metrics_snr
	log_metrics_noise
	log_metrics_reset_counter

	P2P_RSSI=$(getprop debug.p2p.rssi_level)
	log_metrics_p2p_rssi
	log_metrics_p2p_snr
	log_metrics_p2p_noise

	log_connstatus_metrics
	log_metrics_wifi_status
}

function clear_stale_stats
{
	NOISE=0
	RSSI=0
	CHANNEL=0
	CONN_STATUS="ConnStatusOther"
	$WL reset_cnts
}

function log_logcat
{
	PHY_RSSI=`$WL phy_rssi_ant`
	TEMP=`$WL phy_tempsense`
	BTC27=`$WL btc_params 27`

	STATUS_TMP="/tmp/$LOGNAME.status.$$"
	$WL status > $STATUS_TMP
	while read A REST ; do
		case "$A" in
			*) wl_status_mode_tokens $A $REST ;;
		esac
	done < $STATUS_TMP
	rm -f $STATUS_TMP

	logStr="$LOGNAME:noise=$NOISE;rssi=$RSSI;channel=$CHANNEL;phy_tempsense=$TEMP;phy_rssi_ant=$PHY_RSSI;btcparam27=$BTC27;"

	COUNTERS=($($WL counters))
	i=0
	while [[ $i -lt $((${#COUNTERS[*]} - 1)) ]] ; do
		case ${COUNTERS[$i]} in txframe|txbyte|txretrans|txerror|rxframe|rxbyte|rxerror|txburst|txphyerror|rxbadplcp|rxcrsglitch|rxstrt|rxdfrmucastmbss|rxbadfcs)
			logStr=$logStr"${COUNTERS[$i]}=${COUNTERS[$i+1]};"
			;;
		esac
		((i++))
	done

	log -t $LOGCATTAG $logStr

	log_maxmin_signals
}

# Log the maximum and minimum values regarding signal quality
function log_maxmin_signals
{
	if [[ ! "$PREVIOUS_CHANNEL" ]] ; then
		PREVIOUS_CHANNEL=$CHANNEL
	elif [[ $PREVIOUS_CHANNEL != $CHANNEL ]] ; then
		PREVIOUS_CHANNEL=$CHANNEL
		MAX_RSSI=''
		MIN_RSSI=''
		MAX_NOISE=''
		MIN_NOISE=''
		MAX_P2P_RSSI=''
		MIN_P2P_RSSI=''
		MAX_P2P_NOISE=''
		MIN_P2P_NOISE=''
	fi

	if [[ ! "$MAX_RSSI" && ! "$MIN_RSSI" && ! "$RSSI" -eq 0 ]] ; then
		MAX_RSSI=$RSSI
		MIN_RSSI=$RSSI
	fi

	if [[ ! "$MAX_NOISE" && ! "$MIN_NOISE" && ! "$NOISE" -eq 0 ]] ; then
		MAX_NOISE=$NOISE
		MIN_NOISE=$NOISE
	fi

	P2P_RSSI=$(getprop debug.p2p.rssi_level)
	if [[ ! "$MAX_P2P_RSSI" && ! "$MIN_P2P_RSSI" && ! "$P2P_RSSI" -eq 0 ]] ; then
		MAX_P2P_RSSI=$P2P_RSSI
		MIN_P2P_RSSI=$P2P_RSSI
	fi

	if [ ! $RSSI -eq 0 ] ; then
		if [ $RSSI -gt $MAX_RSSI ] ; then
			MAX_RSSI=$RSSI
		fi

		if [ $RSSI -lt $MIN_RSSI ] ; then
			MIN_RSSI=$RSSI
		fi
	fi

	if [ ! $NOISE -eq 0 ] ; then
		if [ $NOISE -gt $MAX_NOISE ] ; then
			MAX_NOISE=$NOISE
		fi

		if [ $NOISE -lt $MIN_NOISE ] ; then
			MIN_NOISE=$NOISE
		fi
	fi

	if [ ! $P2P_RSSI -eq 0 ] ; then
		if [ $P2P_RSSI -gt $MAX_P2P_RSSI ] ; then
			MAX_P2P_RSSI=$P2P_RSSI
		fi

		if [ $P2P_RSSI -lt $MIN_P2P_RSSI ] ; then
			MIN_P2P_RSSI=$P2P_RSSI
		fi
	fi

	logStr="$LOGNAME:max_rssi=$MAX_RSSI;min_rssi=$MIN_RSSI;max_noise=$MAX_NOISE;min_noise=$MIN_NOISE;"
	logStr=$logStr"max_p2prssi=$MAX_P2P_RSSI;min_p2prssi=$MIN_P2P_RSSI;"
	log -t $LOGCATTAG $logStr
}

function run ()
{
	log_logcat

	if [[ $currentLoop -eq $LOOPSTILMETRICS ]] ; then
		log_wifi_metrics
		currentLoop=0
	else
		((currentLoop++))
	fi

	clear_stale_stats
}

# Run the collection repeatedly, pushing all output through to the metrics log.
while true ; do
	run
	sleep $DELAY
done
