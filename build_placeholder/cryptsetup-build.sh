#!/bin/sh
#author primeroz
#Dec 22 2015

. /etc/init.d/tc-functions
useBusybox

trap 'f_cleanup ; trap 2 ; kill -2 $$' 1 2 3 13 15

if [ "$USER" = root ] ; then
   echo "Please don't run as root, exiting."
   sleep 2
   exit 1
fi

OIFS=$IFS
IFS=' '

##******************************************************************************************************************
##***************************************************Functions******************************************************

f_cleanup (){
find /tmp/cryptsetup* -type d -exec sudo chown tc:staff {} +
find /tmp/cryptsetup* -type f -exec sudo chown tc:staff {} +
clean1ist="/tmp/cryptsetup*"
for clean in ${clean1ist}; do
  rm -fr $clean
done
if [ -f ${tczStore}/test_file ]; then 
  rm -f ${tczStore}/test_file
fi
IFS=$OIFS
}

f_location (){
getMirror
echo " ${MAGENTA}Repo ${WHITE}in use: ${CYAN}$MIRROR${NORMAL} "
echo " ${MAGENTA}TCE ${WHITE}directory in use: ${CYAN}${tczStore}${NORMAL} "
}

f_connchk (){
echo " ${MAGENTA}Verifying connection to server, please wait...${NORMAL}"
wget -qs -T 20 ${address}
case $? in
	0) echo " ${GREEN}connection ok${NORMAL}";;
	1) echo " ${YELLOW}${message}${NORMAL}"; sleep 5; exit 9;;
esac
}


##******************************************************************************************************************
##*****************************************************Main*********************************************************

unset ans
unset VER
unset lib
unset VX
unset cryptdownload

crypt=cryptsetup
crypt_version=1.7.4
tce_dir=/etc/sysconfig/tcedir
op=${tce_dir}/optional
tczStore=$(readlink -f $op)
part1=${tczStore#/mnt/}
tcz_partition=${part1%%/*}
installdir=/tmp/cryptsetup_upgrade
ffBuild=cryptsetup.${RANDOM}$RANDOM
ffBuildPath=/tmp/$ffBuild
ffInstallPath=/tmp/${ffBuild}_install
ffdirpath=${ffBuildPath}/${crypt}/usr
ffdownload="https://www.kernel.org/pub/linux/utils/cryptsetup/v1.7/cryptsetup-${crypt_version}.tar.xz"
message1="check internet connection, then try again"
message2="verify connection, perhaps a typo? then try again"
xy=0

clear
f_location
f_cleanup >/dev/null 2>&1
[ -d $installdir ] && rm -fr $installdir

IFS=' '
##test for writable tce dir
if [ ! -f "${tczStore}/test_file" ]; then
  touch ${tczStore}/test_file
  if [ "x$?" != x0 ]; then
      echo "${RED} tce directory not writable${NORMAL} "
      f_cleanup >/dev/null 2>&1
      exit 3
  fi
fi

echo -e "\n ${BLUE}Fetching dependencies${NORMAL}.. "
unset address
unset message
address="http://tinycorelinux.net/index.html"
message=$message1
f_connchk

#load dependencies
if [ -f "${tczStore}/squashfs-tools-4.x.tcz" ]; then
    squashfs="squashfs-tools-4.x"
else
    squashfs="squashfs-tools"
fi

deps1="$squashfs \
compiletc \
liblvm2 \
lvm2-dev \
wget \
libgcrypt-dev \
popt-dev "

rundeps1=" libgcrypt \
liblvm2 \
libgcrypt \
popt "

for Z in $deps1
do 
	tce-load -w $Z 2>/dev/null
	tce-load -i $Z 2>/dev/null
	  if [ ! -e /usr/local/tce.installed/$Z ]; then
	      echo "${RED}  Dependency install failed${NORMAL} "
	      f_cleanup >/dev/null 2>&1
	      exit 3
	  fi
done


##******************************************************************************************************************

f_connchk

/usr/local/bin/wget -nc $ffdownload -O /tmp/${crypt}.tar.xz


##******************************************************************************************************************
#Build

if [ ! -d "$ffBuildPath" ]; then 
  mkdir -p ${ffBuildPath}
else
  rm -rf ${ffBuildPath}
  mkdir -p ${ffBuildPath}
fi

if [ ! -d "$ffInstallPath" ]; then 
  mkdir -p ${ffInstallPath}
else
  rm -rf ${ffInstallPath}
  mkdir -p ${ffInstallPath}
fi


cd /tmp
#Extracting archive
if [ -f /tmp/${crypt}.tar.xz ] ; then
	tar xvf ${crypt}.tar.xz -C $ffBuildPath
  if [ "x$?" != x0 ]; then
      echo "${RED} Corrupt archive, please re-start operation ${NORMAL} "
      f_cleanup >/dev/null 2>&1
      sleep 5
      exit 9
  fi

fi

cd ${ffBuildPath}/cryptsetup-${crypt_version}

./configure 
make
make install DESTDIR=${ffInstallPath}

echo -e "\n ${BLUE}Create extension${NORMAL}.. "
mksquashfs ${ffInstallPath}/ ${crypt}.tcz
md5sum ${crypt}.tcz > ${crypt}.tcz.md5.txt

for i in $rundeps1 
do
echo $i >> ${crypt}.tcz.dep
done

cat > ${crypt}.tcz.info << "EOF4"
Title:                  cryptsetup.tcz
Description:     Cryptsetup
Version:            ${crypt_version}
Author:              cryptsetup
Original-site:    https://gitlab.com/cryptsetup/cryptsetup
Copying-policy: GPL
Size:		   5G
Extension_by:  primeroz
Tags:                 system
Comments:	Use cryptsetup to easily encrypt partitions or disks.

                BE CAREFUL. YOU MAY LOSE DATA WHEN YOU CHOOSE A WRONG DISK!

                Example for a hard disk /dev/sdd:
                
                $ sudo su
                $ cryptsetup luksFormat /dev/sdd
                $ cryptsetup luksOpen /dev/sdd cryptedsdd
                $ mkfs.ext4 /dev/mapper/cryptedsdd
                $ mkdir /mnt/cryptedsdd
                $ mount /dev/mapper/cryptedsdd /mnt/cryptedsdd
Change-log:     ...
2017/03/19 First version ${crypt_version} (primeroz)
Current:             

EOF4

copylist="${crypt}.tcz \
${crypt}.tcz.dep \
${crypt}.tcz.md5.txt \
${crypt}.tcz.info "

mkdir -p ${installdir}

for c in $copylist
do 
  [ -f ${ffBuildPath}/cryptsetup-${crypt_version}/$c ] && cp ${ffBuildPath}/cryptsetup-${crypt_version}/$c ${installdir}/$c
done

#f_cleanup >/dev/null 2>&1
IFS=' '

echo -e "\n ${BLUE}${crypt}.tcz is being copied to ${CYAN}${installdir}${NORMAL} \n \
remember to edit the ${crypt}.tcz.info file \n as required, before running submitqc.. \n" 
read -p " OK? enter to quit "


##*******************************************************End********************************************************
##******************************************************************************************************************

IFS=$OIFS
exit 0


