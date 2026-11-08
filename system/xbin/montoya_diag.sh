#!/system/bin/sh

WORKING_DIR=/data/diag
LOGGING_DIR=/sdcard/
RUNNING_LOG=$LOGGING_DIR/log_file.txt
TVSERVICE=/system/xbin/tvservice
EDID_HEX_FILE_PATH=$WORKING_DIR/edid.hex
EDID_PARSER=/system/xbin/edid_parser
EDID_TXT_FILE_PATH=$WORKING_DIR/edid.txt
EDID_PARSED_DIR=$LOGGING_DIR/edid.txt
VER="1.0"
i2c_speed_edid=0
i2c_speed_hdcp=0
GENCMD_PATH=/system/bin
#I2C_SPEED_REC_FILE_PATH=$WORKING_DIR/i2c_speed

function arg_parser
{
  OPT_HELP=0;
  OPT_HDCP_CHECK=0;
  OPT_GET_EDID=0;
  OPT_RESET=0;
  OPT_SET_I2C_SPEED=0;
  OPT_HDCP_ON=0;
  OPT_HDCP_OFF=0;
  while true; do
    if [ "$1" == "" ]; then break; fi;
    case "$1" in
    -h|--help) OPT_HELP=1;;
    -p|--hdcp) OPT_HDCP_CHECK=1;;
    -d|--edid) OPT_GET_EDID=1;;
    -r|--reset) OPT_RESET=1;;
    -n|--on) OPT_HDCP_ON=1;;
    -f|--off) OPT_HDCP_OFF=1;;
    -c|--i2c) OPT_SET_I2C_SPEED=1; shift; i2c_speed_edid=$1; shift; i2c_speed_hdcp=$1;;
    -*);;
    esac;
    shift;
  done;
}

function set_i2c_speed
{
    echo "setting i2c speed, edid=$i2c_speed_edid hdcp=$i2c_speed_hdcp" >> $RUNNING_LOG
    # setting the i2c speed
    if [ -f $GENCMD_PATH/gencmd ]
    then
        $GENCMD_PATH/gencmd hdmi_tmds edidspeed=$i2c_speed_edid hdcpspeed=$i2c_speed_hdcp
    else
        echo "Error, $GENCMD_PATH/gencmd comand is not found." >> $RUNNING_LOG
    fi
    exit 0;
}

function do_reset
{
   if [ -f $RUNNING_LOG ]
   then
	rm -f $RUNNING_LOG
   fi

   if [ -f $EDID_PARSED_DIR ]
   then
	rm -f $EDID_PARSED_DIR
   fi

   exit 0;
}

function do_hdcp_check
{
    if [ -f $TVSERVICE ]
    then
        echo "reading hdcp status..." >> $RUNNING_LOG
        hdcp_status=`$TVSERVICE -s | grep HDCP`
        echo "hdcp status = $hdcp_status" >> $RUNNING_LOG
        if [ "$hdcp_status" = "" ] 
        then
            echo "Failed"
        else
            echo "OK"
       fi
   fi
   exit 0;
}
function hdcp_on
{
    if [ -f $TVSERVICE ]
    then
        echo "turning HDCP ON" >> $RUNNING_LOG
        status=`$TVSERVICE -t 1`
        echo "status $status"
        if [ "$status" = "HDCP enabled successful !" ]
        then
            echo "HDCP turned on"
        else
            echo "failed HDCP turn on"
        fi
    fi
    exit 0;
}

function hdcp_off
{
    if [ -f $TVSERVICE ]
    then
        echo "turning HDCP OFF" >> $RUNNING_LOG
        status=`$TVSERVICE -t 0`
        if [ "$status" = "HDCP disabled successful !" ]
        then
            echo "HDCP turned off"
        else
            echo "failed HDCP turn off"
        fi
    fi
    exit 0;
}

function get_edid
{
    if [ -f $TVSERVICE ]
    then
        echo "reading the edid..." >> $RUNNING_LOG
        if [ -f $EDID_HEX_FILE_PATH ]
        then
            rm -rf $EDID_HEX_FILE_PATH
        fi
        $TVSERVICE -d $EDID_HEX_FILE_PATH
        echo "Done" >> $RUNNING_LOG
    else
        echo "$TVSERVICE is not found" >> $RUNNING_LOG
    fi

    echo "parse the edid hex file..." >> $RUNNING_LOG
    if [ -f $EDID_HEX_FILE_PATH ]
    then
        if [ -f $EDID_PARSER ]
        then
            if [ -f $EDID_TXT_FILE_PATH ]
            then 
                rm -rf $EDID_TXT_FILE_PATH
            fi
            $EDID_PARSER $EDID_HEX_FILE_PATH > $EDID_TXT_FILE_PATH
            echo "Parse complete and copy to sdcard" >> $RUNNING_LOG
            #$EDID_PARSER $EDID_HEX_FILE_PATH > /sdcard/edid.txt
            cp $EDID_TXT_FILE_PATH /sdcard/
        else
            echo "Failed, $EDID_PARSER is not found" >> $RUNNING_LOG
        fi
    else
        echo "Failed, edid hex file $EDID_HEX_FILE_PATH is not found" >> $RUNNING_LOG
    fi
    exit 0;
}

function show_help
{
    echo "Usage: montoya_diag.sh [OPTIONS]"
    echo "Version: $VER"
    echo "Options:"
    echo " -h, --help                        - Show this help"
    echo " -p, --hdcp                        - Check HDCP status"
    echo " -d, --edid                        - Read the EDID Info"
    echo " -r, --reset                       - Reset all the diag info"
    echo " -c, --i2c edid_speed hdcp_speed   - set i2c speed"
    echo ""
    exit 0;
}


arg_parser "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10"

#if [ -f $RUNNING_LOG ]
#then
#    rm -f $RUNNING_LOG
#fi

if [ $# -eq 0 ]
then
    show_help
fi

if [ $OPT_HELP -eq 1 ]
then
    show_help
fi

if [ $OPT_RESET -eq 1 ]
then
   do_reset
fi


NOW=$(date +%d:%m:%y-%H:%M:%S)
if [ -f $RUNNING_LOG ]
then
   echo "=== $NOW" >> $RUNNING_LOG
else
   echo "=== $NOW" > $RUNNING_LOG
fi

if [ ! -d $WORKING_DIR ]
then
    echo "Error, $WORKING_DIR is not found!" >> $RUNNING_LOG
fi

if [ $OPT_GET_EDID -eq 1 ]
then 
    get_edid
fi

if [ $OPT_HDCP_CHECK -eq 1 ]
then
    do_hdcp_check
fi

if [ $OPT_SET_I2C_SPEED -eq 1 ]
then
    set_i2c_speed
fi

if [ $OPT_HDCP_ON -eq 1 ]
then 
    hdcp_on
fi

if [ $OPT_HDCP_OFF -eq 1 ]
then 
    hdcp_off
fi