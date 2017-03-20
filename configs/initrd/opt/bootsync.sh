#!/bin/sh
# put other system startup commands here, the boot process will wait until they complete.
# Use bootlocal.sh for system startup commands that can run in the background 
# and therefore not slow down the boot process.
/usr/bin/sethostname box
/opt/bootlocal.sh &

# ln lib to lib64 for binary support
/bin/ln -s /lib /lib64

