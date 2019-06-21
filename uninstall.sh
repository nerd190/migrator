#!/system/bin/sh
# remove leftovers

(until [ -d /data/media/0/migrator ]; do sleep 20; done
rm -rf /data/media/0/migrator
exit 0 &) &
exit 0
