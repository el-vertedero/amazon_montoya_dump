#!/system/bin/sh
grep -e 'Tag="[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:' -e 'Tag="Hid' -e 'Tag="LinkKeyType"' /data/misc/bluedroid/bt_config.xml
