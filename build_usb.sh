#!/usr/bin/env bash

DEV=$1

if [ -z $DEV ]; then
	echo "please specify usb device"
	exit 1
fi


sudo mount -o loop tmp-build-dir/remastered.iso /tmp/iso
sudo mkfs.vfat ${DEV}1
sudo mount ${DEV}1 /tmp/flash
sudo cp -a /tmp/iso/* /tmp/flash/ 2>&1 | egrep -v "Operation not permitted"
sudo mv /tmp/flash/boot/isolinux/* /tmp/flash
sudo mv /tmp/flash/isolinux.cfg /tmp/flash/syslinux.cfg
sudo sed -i 's/APPEND \(.*\)/APPEND \1 cde=sda1\/cde/' /tmp/flash/syslinux.cfg
sudo cp -a configs/syslinux/*.c32 /tmp/flash/
sudo umount /tmp/flash
sudo umount /tmp/iso
sudo ms-sys -s ${DEV}
sudo syslinux ${DEV}1
