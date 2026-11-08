#!/system/bin/sh

# Remove any video symlinks in /data/ to non-existent files
# in /system.
# Actually, for now, only unlink ATVPDKIKX0DER_welcome_video.mp4

VDIR=/data/securedStorageLocation/com.amazon.tv.oobe/videos
VFILE=ATVPDKIKX0DER_welcome_video.mp4

if [ -d $VDIR ]; then
  cd $VDIR
  if [ -h $VFILE ]; then
    /system/bin/rm $VFILE
  fi
fi
