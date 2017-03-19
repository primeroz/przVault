#!/bin/sh
#
######################################################
# Build script for TinyCore 3.x                      #
#                                                    #
# See .info for details                              #
#                                                    #
# May 14, 2010                                       #
######################################################

######################################################
# Configure extension creation parameters            #
######################################################

VERSION=1.0.0
SRCNAM=pinentry-${VERSION}.tar.bz2
WRKDIR=pinentry-${VERSION}
EXTNAM=pinentry
TMPDIR=/tmp/pinentry
URL="https://www.gnupg.org/ftp/gcrypt/pinentry/${SRCNAM}.tar.bz2"

######################################################
# Prepare extension creation                         #
######################################################

deps="util-linux_base-dev.tcz libpwquality-dev openssl-dev gtk2-dev libassuan-dev libsecret-dev squashfs-tools compiletc"

for Z in $deps                                                                                                     
do                                                                                                                   
  tce-load -w $Z 2>/dev/null                                                                                         
  tce-load -i $Z 2>/dev/null                                                                                         
    if [ ! -e /usr/local/tce.installed/$Z ]; then                                                                    
        echo "${RED}  Dependency install failed${NORMAL} "                                                           
        f_cleanup >/dev/null 2>&1                                                                                    
        exit 3                                                                                                       
    fi                                                                                                               
done  

# Remove dirs and files left from previous creation

rm -r -f $WRKDIR

rm -r -f $TMPDIR
rm -r -f $TMPDIR-doc

# Crete temporary directory

mkdir -p $TMPDIR

######################################################
# Compile extension                                  #
######################################################

# Export variables needed for compilation

export CFLAGS="-Os -pipe"
export CXXFLAGS="-Os -pipe -fno-exceptions -fno-rtti"

# Unpack source in current directory

if [ ! -f $SRCNAM ];then
	wget $URL -O$SRCNAM
fi

tar -xf $SRCNAM

# Configure it

cd $WRKDIR
./configure --prefix=/usr/local

# Compile

make

# Install in base temp dir

make install DESTDIR=$TMPDIR

# Delete compilation work directory

cd ..
rm -r -f $WRKDIR

# Remove unneded dirs and files

# Adjust directory access rigths

find $TMPDIR/ -type d | xargs chmod -v 755;

# Strip executables

find $TMPDIR | xargs file | grep ELF | cut -f 1 -d : | xargs strip --strip-unneeded

# Move files to doc extension

mkdir -p $TMPDIR-doc/usr/local/share
mv $TMPDIR/usr/local/share/info $TMPDIR-doc/usr/local/info

###################################################
# Create base extension in temp dir               #
###################################################

cd $TMPDIR
cd ..
mksquashfs $TMPDIR $EXTNAM.tcz
cd $TMPDIR
find usr -not -type d > $EXTNAM.tcz.list
mv ../$EXTNAM.tcz .

# Create md5 file

md5sum $EXTNAM.tcz > $EXTNAM.tcz.md5.txt

# Cleanup temp directory

rm -r -f usr  

###################################################
# Create doc extension in temp dir                #
###################################################

cd $TMPDIR-doc
cd ..
mksquashfs $TMPDIR-doc $EXTNAM-doc.tcz
cd $TMPDIR-doc
find usr -not -type d > $EXTNAM-doc.tcz.list
mv ../$EXTNAM-doc.tcz .

# Create md5 file

md5sum $EXTNAM-doc.tcz > $EXTNAM-doc.tcz.md5.txt

# Cleanup temp directory

rm -r -f usr  

