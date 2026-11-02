#!/system/bin/sh
# Entra no rootfs Debian via proot (usado no adb shell)
B=/data/local/tmp/tibia
export LD_LIBRARY_PATH=$B/bin
export PROOT_LOADER=$B/bin/loader
export PROOT_TMP_DIR=$B/tmp
exec $B/bin/proot -0 --link2symlink --kill-on-exit \
  -r $B/rootfs -b /dev -b /proc -b /sys -b /data/local/tmp/tibia/share:/share \
  -w /root /usr/bin/env -i HOME=/root TERM=xterm LANG=C.UTF-8 \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$@"
