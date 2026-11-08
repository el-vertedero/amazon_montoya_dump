#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/platform/sdhci.1/by-name/recovery:5304576:12c506386812bb032b2e5c709506348c031b5db4; then
  applypatch -b /system/etc/recovery-resource.dat EMMC:/dev/block/platform/sdhci.1/by-name/boot:4665600:3969949b80eaa6954ec716c1a09c5e5f87d67a57 EMMC:/dev/block/platform/sdhci.1/by-name/recovery 12c506386812bb032b2e5c709506348c031b5db4 5304576 3969949b80eaa6954ec716c1a09c5e5f87d67a57:/system/recovery-from-boot.p && echo "
Installing new recovery image: succeeded
" >> /cache/recovery/log || echo "
Installing new recovery image: failed
" >> /cache/recovery/log
else
  log -t recovery "Recovery image already installed"
fi
