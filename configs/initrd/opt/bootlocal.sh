#!/bin/sh
# put other system startup commands here

# Start haveged
if [ -x /usr/local/sbin/haveged ];then
	/usr/local/sbin/haveged 
fi
