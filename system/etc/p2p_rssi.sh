#!/system/bin/sh

LOGNAME="p2p_client_rssi"
LOGCATTAG="main.$LOGNAME"
LOGSRC="wifi"
WL=/system/xbin/wl

if [ ! -x $WL ] ; then
	exit
fi

GROUP_INTERFACE=$(getprop wlan.interface.p2p.group)

if [ ! "$GROUP_INTERFACE" ] ; then
	exit
fi

P2P_CLIENT_LIST=$($WL -i $GROUP_INTERFACE assoclist)

if [ "$P2P_CLIENT_LIST" ] ; then
	REST_OF_LIST=${P2P_CLIENT_LIST#*assoclist?}

	while [ "$REST_OF_LIST" ] ; do
		P2P_MAC_ADDR=${REST_OF_LIST%%?assoclist*}
		P2P_RSSI=$($WL -i $GROUP_INTERFACE rssi $P2P_MAC_ADDR)

		if [ $P2P_RSSI -ne 0 ] ; then
			setprop debug.p2p.rssi_level $P2P_RSSI
			log -t $LOGCATTAG $LOGNAME": p2p_dev_address="$P2P_MAC_ADDR" p2p_rssi="$P2P_RSSI
		fi

		REST_OF_LIST=${REST_OF_LIST#*$P2P_MAC_ADDR}
		REST_OF_LIST=${REST_OF_LIST#*assoclist?}
	done
fi
