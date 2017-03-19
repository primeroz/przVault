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

VERSION=1.2.1
SRCNAM=gocryptfs_v${VERSION}_debian8_amd64.tar.gz
WRKDIR=gocryptfs-${VERSION}
EXTNAM=gocryptfs
TMPDIR=/tmp/gocryptfs
URL="https://github.com/rfjakob/gocryptfs/releases/download/v${VERSION}/${SRCMAM}"

######################################################
# Prepare extension creation                         #
######################################################

deps="wget"

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

# Crete temporary directory

mkdir -p $TMPDIR

######################################################
# Compile extension                                  #
######################################################

# Export variables needed for compilation

if [ ! -f $SRCNAM ];then
	wget $URL -O$SRCNAM
fi

tar -xf $SRCNAM

# Configure it

cd $WRKDIR
# Install in base temp dir
mkdir -p $TMPDIR/usr/local/bin
cp gocryptfs $TMPDIR/usr/local/bin
chmod 755 $TMPDIR/usr/local/bin/gocryptfs

# Strip executables

find $TMPDIR | xargs file | grep ELF | cut -f 1 -d : | xargs strip --strip-unneeded

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

