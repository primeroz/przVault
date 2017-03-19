#!/bin/sh
#firefox-ESR create tcz script for
#tinycore-5/6/7.x, x86, core64 (x86_64) and corepure64 (x86_64) versions
#author coreplayer2
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
find /tmp/firefox* -type d -exec sudo chown tc:staff {} +
find /tmp/firefox* -type f -exec sudo chown tc:staff {} +
clean1ist="/tmp/firefox* /tmp/ffversion"
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
unset ffdownload

ff=firefox-ESR
tce_dir=/etc/sysconfig/tcedir
op=${tce_dir}/optional
tczStore=$(readlink -f $op)
part1=${tczStore#/mnt/}
tcz_partition=${part1%%/*}
installdir=/tmp/ff_upgrade
ffBuild=firefox.${RANDOM}$RANDOM
ffBuildPath=/tmp/$ffBuild
ffdirpath=${ffBuildPath}/${ff}/usr/local
latestVER="https://download.mozilla.org/?product=firefox-esr-latest&os=win&lang=en-US"
ffdownload="http://download-origin.cdn.mozilla.net/pub/firefox/releases/38.0.0esr/linux-i686/en-US/firefox-38.0.0esr.tar.bz2"
message1="check internet connection, then try again"
message2="verify connection, perhaps a typo? then try again"
xy=0

clear
f_location
f_cleanup >/dev/null 2>&1
[ -d /tmp/ff_upgrade ] && rm -fr /tmp/ff_upgrade

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
curl \
wget \
openssl \
bzip2 \
file \
gtk2 \
libasound \
dbus-glib \
hicolor-icon-theme \
cairo \
gamin "

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


##discover firefox arch
lib=$(echo $MIRROR | grep -o 'x86_64')
case $lib in
	x86_64)
	ffdownload=${ffdownload/linux-i686/linux-x86_64}
	;;
esac

##******************************************************************************************************************
##discover version 

echo -e "\n ${BLUE}Acquiring latest version${NORMAL}.. "
cd /tmp

curl -s $latestVER 2>/dev/null | grep -o '[[:digit:]]*\.[[:digit:]]' 2>/dev/null | sort -u | tail -1 >/tmp/ffversion
curl -s $latestVER 2>/dev/null | grep -o '[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]' 2>/dev/null | sort -u | tail -1 >>/tmp/ffversion
VER=$(cat /tmp/ffversion | sort -u | tail -1)



if [ -n "$VER" ]; then
  echo -e "${WHITE} Latest ESR version is: ${CYAN}${VER}${NORMAL} \n\n "
else
  echo -e "\n ${YELLOW}Error acquiring latest version${NORMAL},\n "
fi

echo -e "\n Select ${WHITE}(${MAGENTA}Y${NORMAL}/${MAGENTA}y${WHITE})${NORMAL} to get version ${CYAN}${VER}esr${NORMAL} or \n \
Select ${WHITE}(${MAGENTA}N${NORMAL}/${MAGENTA}n${WHITE})${NORMAL} To specify alternative version ${NORMAL}..? \n\n \
Enter ${WHITE}(${MAGENTA}Y${NORMAL}/${MAGENTA}n${WHITE})${NORMAL} "
unset ans
	while [ "$ans" != [Yy] ] || [ "$ans" != [Nn] ] || [ -z "$ans" ]
	do
	read -n1 ans
	case $ans in
	  [Yy])
	    	break
	  ;;

	  [Nn])
				#specify version
		echo -e " Enter exact version requested.  For example to download \
version 38.3.0esr simply type \n\n  ${WHITE}38.3.0${NORMAL} \n 
at the prompt: then select enter \n " 
		read -p VER
		break
	  ;;

	  *) 
		echo -e "\n ${YELLOW}Invalid selection${NORMAL},\n "
	  ;;

	esac
	done


f_connchk

/usr/local/bin/wget -nc ${ffdownload//38.0.0/$VER} -O /tmp/${ff}.tar.bz2


#End of Version selection
##******************************************************************************************************************
#Creat new extension

if [ ! -d "$ffBuildPath" ]; then 
dirlist="tce.installed \
share/applications \
share/doc/${ff} \
share/pixmaps "

for d in $dirlist
do 
  [ ! -f ${ffdirpath}/$d ] && mkdir -p ${ffdirpath}/$d
done
fi

##Make support files
echo "gtk2.tcz
libasound.tcz
dbus-glib.tcz
hicolor-icon-theme.tcz
cairo.tcz
openssl.tcz
gtk3.tcz
gamin.tcz
" > "${ffBuildPath}/${ff}.tcz.dep"


desktopfile="${ffdirpath}/share/applications/${ff}.desktop"
while [ ! -f "$desktopfile" ]; do
cat > $desktopfile << "EOF1"
[Desktop Entry]
Name=firefox-ESR
Exec=/usr/local/firefox-ESR/firefox
Terminal=False
Comment=firefox-ESR Web Browser
StartupNotify=True
Type=Application
Categories=Application;Network;
Icon=firefox.png
X-FullPathIcon=/usr/local/share/pixmaps/firefox.png

EOF1
done


tceinstalled="${ffdirpath}/tce.installed/${ff}"
while [ ! -f "$tceinstalled" ]; do

if [ x"$lib" != xx86_64 ]; then
cat > ${tceinstalled} << "EOF2"
#!/bin/sh
[ -d /var/lib/dbus ] || mkdir -p /var/lib/dbus
[ -f /var/lib/dbus/machine-id ] || dbus-uuidgen --ensure=/var/lib/dbus/machine-id

if [ -f /usr/local/bin/firefox ] ; then  
	rm -rf /usr/local/bin/firefox
	ln -s /usr/local/firefox-ESR/firefox /usr/local/bin/firefox
else 
ln -s /usr/local/firefox-ESR/firefox /usr/local/bin/firefox
fi

EOF2

elif [ x"$lib" == xx86_64 ]; then
cat > ${tceinstalled} << "EOF3"
#!/bin/sh 

# ln to binary on PATH
if [ ! -h /usr/local/bin/firefox ]; then
	ln -s /usr/local/firefox-ESR/firefox /usr/local/bin/firefox
fi

# ln lib64 to lib
if [ ! -e /lib64 ]; then
	ln -s /lib /lib64
fi

EOF3
fi
done


licensefile="${ffdirpath}/share/doc/${ff}/COPYING"
while [ ! -f "$licensefile" ]; do
cat > $licensefile << "EOF5"
License information may be obtained from
about:license

EOF5
done


cd /tmp
#Extracting archive
if [ -f /tmp/${ff}.tar.bz2 ] ; then
	tar jxvf ${ff}.tar.bz2 -C $ffdirpath
  if [ "x$?" != x0 ]; then
      echo "${RED} Corrupt archive, please re-start operation ${NORMAL} "
      f_cleanup >/dev/null 2>&1
      sleep 5
      exit 9
  fi
mv ${ffBuildPath}/${ff}/usr/local/firefox ${ffdirpath}/${ff}
fi

if [ ! -f ${ffdirpath}/share/pixmaps/firefox.png ]; then
cp ${ffdirpath}/${ff}/browser/chrome/icons/default/default48.png ${ffdirpath}/share/pixmaps/firefox.png
fi

#set extension permissions
set -x
[ x$PWD = x$ffBuildPath/${ff} ] || cd $ffBuildPath/${ff}
[ x$PWD = x$ffBuildPath/${ff} ] || exit
set +x
find . -type d -exec sudo chown root:root {} +
find . -type d -exec sudo chmod 755 {} +
find . -type f -exec sudo chown root:root {} +
cd ..
find $ffdirpath -iname tce.installed -exec sudo chown root:staff {} +
find $ffdirpath -iname tce.installed -exec sudo chmod 775 {} +
find ${ffdirpath}/tce.installed -type f -exec sudo chown tc:staff {} +
find ${ffdirpath}/tce.installed -type f -exec sudo chmod 755 {} +


echo -e "\n ${BLUE}Create extension${NORMAL}.. "
mksquashfs ${ff}/ ${ff}.tcz
md5sum ${ff}.tcz > ${ff}.tcz.md5.txt


if [ x"$lib" != xx86_64 ]; then
cat > firefox-ESR.tcz.info << "EOF4"
Title:                  firefox-ESR.tcz
Description:     Firefox-ESR web browser
Version:            38.3.0
Author:              The Mozilla Community
Original-site:    http://download.cdn.mozilla.net/pub/mozilla.org/firefox/releases
Copying-policy: MPL
Size:		   51M
Extension_by:  coreplayer2
Tags:                 web browser mozilla firefox ESR    
Comments:	   This extension is the current "Firefox-ESR" 
                           (Extended Service Release), containing the 
                           latest significant security updates.
                           
                           This extension is maintained in each repository 
                           to provide basic Firefox availability.  For the
                           latest Firefox build for personal use, run the 
                           "firefox-getlatest.tcz" extension.  
Change-log:     ...
                           2015/10/1 First version 38.3.0esr (coreplayer2)
Current:             

EOF4

elif [ x"$lib" == xx86_64 ]; then
cat > firefox-ESR.tcz.info << "EOF6"
Title:                  firefox-ESR.tcz
Description:     Firefox-ESR web browser
Version:            38.3.0
Author:              The Mozilla Community
Original-site:    http://download.cdn.mozilla.net/pub/mozilla.org/firefox/releases
Copying-policy: MPL
Size:		   51M
Extension_by:  coreplayer2
Tags:                 web browser mozilla firefox ESR    
Comments:	   This extension is the current "Firefox-ESR" 
                           (Extended Service Release), containing the 
                           latest significant security updates.
                           
                           This extension is maintained in each repository 
                           to provide basic Firefox availability.  For the
                           latest Firefox build for personal use, run the 
                           "firefox-getlatest.tcz" extension.  
Change-log:     ...
                           2015/10/1 First version 38.3.0esr for corepure64 (coreplayer2)
Current:             

EOF6

fi

[ -f ${installdir} ] || mkdir -p ${installdir}

copylist="${ff}.tcz \
${ff}.tcz.dep \
${ff}.tcz.md5.txt \
${ff}.tcz.info "

for c in $copylist
do 
  [ -f ${ffBuildPath}/$c ] && cp ${ffBuildPath}/$c ${installdir}/$c
done

f_cleanup >/dev/null 2>&1
IFS=' '

echo -e "\n ${BLUE}${ff}.tcz is being copied to ${CYAN}${installdir}${NORMAL} \n \
remember to edit the ${ff}.tcz.info file \n as required, before running submitqc.. \n" 
read -p " OK? enter to quit "


##*******************************************************End********************************************************
##******************************************************************************************************************

IFS=$OIFS
exit 0


