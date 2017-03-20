#!/bin/bash

# XXX HARDCODED for now
DEV="/dev/sdd"


sudo mount -o loop tmp-build-dir/remastered.iso /tmp/iso
sudo mkfs.vfat /dev/sdd1 
sudo mount /dev/sdd1 /tmp/flash
sudo cp -a /tmp/iso/* /tmp/flash/ 2>&1 | egrep -v "Operation not permitted"
sudo mv /tmp/flash/boot/isolinux/* /tmp/flash
sudo mv /tmp/flash/isolinux.cfg /tmp/flash/syslinux.cfg
sudo sed -i 's/APPEND \(.*\)/APPEND \1 cde=sda1\/cde/' /tmp/flash/syslinux.cfg
sudo cp -a configs/syslinux/*.c32 /tmp/flash/
sudo umount /tmp/flash
sudo umount /tmp/sdd1
sudo ms-sys -s /dev/sdd
sudo syslinux /dev/sdd1
