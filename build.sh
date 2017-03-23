#!/usr/bin/env bash
#

if (netstat -nl| grep 8123) ; then
	export http_proxy="http://localhost:8123"
	export https_proxy="http://localhost:8123"
fi

#
#Set Colors https://natelandau.com/bash-scripting-utilities/
#

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

purple=$(tput setaf 171)
red=$(tput setaf 1)
green=$(tput setaf 76)
tan=$(tput setaf 3)
blue=$(tput setaf 38)

#
# Headers and  Logging
#

e_header() { printf "\n${bold}${purple}==========  %s  ==========${reset}\n" "$@" 
}
e_arrow() { printf "➜ $@\n"
}
e_success() { printf "${green}✔ %s${reset}\n" "$@"
}
e_error() { printf "${red}✖ %s${reset}\n" "$@"
}
e_warning() { printf "${tan}➜ %s${reset}\n" "$@"
}
e_underline() { printf "${underline}${bold}%s${reset}\n" "$@"
}
e_bold() { printf "${bold}%s${reset}\n" "$@"
}
e_note() { printf "${underline}${bold}${blue}Note:${reset}  ${blue}%s${reset}\n" "$@"
}

# Make push and popd silent
pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

# define a function we can use to print out the usage for this script

usage()
{
cat << EOF

Usage: $0 OPTIONS

This script builds a gzipped tarfile containing all of the files necessary to

OPTIONS:
   -h, --help                 print usage for this command

Note; currently, the default is to build a development ISO (which includes the
EOF
}

# Define a function to read configuration-values in from a file
read_config_file()
{
  while read LINE; do
    VAR=`printf '%s' "$LINE" | sed 's|\(.*\)=.*|\1|'`

    VAL=`printf '%s' "$LINE" | sed 's|.*=\(.*\)|\1|'`
    eval "$VAR=\"$VAL\""
  done < $1
}

# Define a function to verify md5 of file
verify_md5_file()
{
	FILE=$1
	MD5=$FILE.md5.txt

	md5sum -c $MD5 $FILE

}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(getopt -o hb:m:pdt:c:v -l help,builtin-list:,mirror-list:,build-prod-image,build-debug-image,tc-passwd:,config:,verbose,dpkg-list: -- "$@")
then
    usage
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
set -- $options

# Some internal defaults - be quiet by default.
WGET_V='-nv'
TAR_V=''

# Explicitly create DEB_PACKAGE_LIST_URL as an array
DEB_PACKAGE_LIST_URL=()

# loop through the command line arguments, parsing them as we go along
# (and shifting them off of the list of command line arguments as they,
# and their arguments if they have any, are parsed).  Note the use of
# the 'tr' and 'sed' commands when parsing the command arguments. The
# 'tr' command is used to remove the leading and trailing quotes from
# the arguments while the 'sed' command is used to remove the leading
# equals sign from the argument (if it exists).
#BUNDLE_TYPE_SELECTED=0
#while [ $# -gt 0 ]
#do
#  case $1 in
#  -b|--builtin-list) BUILTIN_LIST=`echo $2 | tr -d "'" | sed 's:^[=]\?\(.*\)$:\1:'`; shift;;
#  -m|--mirror-list) MIRROR_LIST=`echo $2 | tr -d "'" | sed 's:^[=]\?\(.*\)$:\1:'`; shift;;
#  -p|--build-prod-image) 
#    if [ $BUNDLE_TYPE_SELECTED -eq 0 ]; then 
#      BUNDLE_TYPE='prod'; 
#      BUNDLE_TYPE_SELECTED=1
#    else 
#      printf '%s: ERROR, cannot specify both -d and -p\n' "$0"
#      printf '    (bundle must be either prod or debug, not both)\n'
#      usage
#      exit 1
#    fi
#    ;;
#  -d|--build-debug-image)
#    if [ $BUNDLE_TYPE_SELECTED -eq 0 ]; then 
#      BUNDLE_TYPE='debug'; 
#      BUNDLE_TYPE_SELECTED=1
#    else 
#      printf '%s: ERROR, cannot specify both -d and -p\n' "$0"
#      printf '    (bundle must be either prod or debug, not both)\n'
#      usage
#      exit 1
#    fi
#    ;;
#  -t|--tc-passwd)
#    TC_PASSWD=`echo $2 | tr -d "'"`
#    test1=`echo $TC_PASSWD | grep '^c-passwd='`
#    if [[ ! -z $test1 ]]; then
#      test=`echo $test1 | sed 's:^c-passwd=\(.*\)$:\1:'`
#      printf '%s: WARNING, found value that looks like it includes part' "$0"
#      printf ' of the long argument name (%s); should the password value be' "$TC_PASSWD"
#      printf ' "%s" instead?\n' "$test"
#    fi;
#    test2=`echo $TC_PASSWD | grep '^='`
#    if [[ ! -z $test2 ]]; then
#      printf "%s: WARNING, password value with a leading '=' found" "$0"
#      printf " (%s), did you use an '=' between the short argument (-t)" "$test2"
#      printf " and its value? If so, you might not get the password you expect...\n"
#    fi;
#    shift;;
#  --dpkg-list)
#    DEB_PACKAGE_LIST_URL+=(`echo $2 | tr -d "'"`)
#    shift;;
#  -c|--config) CONFIG_FILE=`printf '%s' "$2" | tr -d "'" | sed 's:^[=]\?\(.*\)$:\1:'`; shift;;
#  -h|--help) usage; exit 0;;
#  -v|--verbose)
#          TAR_V='v'
#          WGET_V='-v'
#          ;;
#  (--) shift; break;;
#  (-*) echo "$0: error - unrecognized option $1" 1>&2; usage; exit 1;;
#  esac
#  shift
#done

# if there are still arguments left, the syntax of the command is wrong
# (there were extra arguments given that don't belong)
#if [ ! $# -eq 0 ]; then
#  echo "$0: error - extra fields included in commmand; remaining args=$@" 1>&2; usage; exit 1
#fi

# If a config-file was specified on the command-line, read it into the
# environment (obliterating any values already in the environment)
if [ -n "$CONFIG_FILE" ]; then
  read_config_file $CONFIG_FILE
fi
# Use any config-values which were provided in the config file or environment 
## variables, but not over-ridden on the command-line
#[ -z "$BUILTIN_LIST" -a -n "$MK_BUNDLE_BUILTIN_LIST" ] && 
#  BUILTIN_LIST="$MK_BUNDLE_BUILTIN_LIST"
#[ -z "$MIRROR_LIST" -a -n "$MK_BUNDLE_MIRROR_LIST" ] && 
#  MIRROR_LIST="$MK_BUNDLE_MIRROR_LIST"
#[ -z "$TC_PASSWD" -a -n "$MK_BUNDLE_TC_PASSWD" ] && 
#  TC_PASSWD="$MK_BUNDLE_TC_PASSWD"
#[ -z "$BUNDLE_TYPE" -a -n "$MK_BUNDLE_TYPE" ] && 
#  BUNDLE_TYPE="$MK_BUNDLE_TYPE"
#[ -z "$TCL_MIRROR_URI" -a -n "$MK_BUNDLE_TCL_MIRROR_URI" ] && 
#  TCL_MIRROR_URI="$MK_BUNDLE_TCL_MIRROR_URI"
#[ -z "$TCL_ISO_URL" -a -n "$MK_BUNDLE_TCL_ISO_URL" ] && 
#  TCL_ISO_URL="$MK_BUNDLE_TCL_ISO_URL"
#
# Set to default anything still not specified, for which there is a reasonable
# default-value
[ -z "$BUNDLE_TYPE" ] && BUNDLE_TYPE='dev'
[ -z "$TCL_MIRROR_URI" ] && TCL_MIRROR_URI='http://distro.ibiblio.org/tinycorelinux/7.x/x86_64/tcz'
[ -z "$TCL_ISO_URL" ] && TCL_ISO_URL='http://distro.ibiblio.org/tinycorelinux/7.x/x86_64/release/distribution_files'
[ -z "${DEB_PACKAGE_LIST_URL[*]}" ] && DEB_PACKAGE_LIST_URL[0]='http://distro.ibiblio.org/tinycorelinux/5.x/x86/debian_wheezy_main_i386_Packages.gz'
[ -z "$DEB_MIRROR_URL" ] && DEB_MIRROR_URL='ftp://ftp.us.debian.org/debian'

# Save our top level directory; watch out for spaces!
TOP_DIR="${PWD}"
#
## otherwise, sanity check the arguments that were parsed to ensure that
## the required arguments are present and the optional ones make sense
## (in terms of which optional arguments were given, and in what combination)
#if [[ -z $BUILTIN_LIST ]] || [[ -z $MIRROR_LIST ]]; then
#  printf "\nError (Missing Argument); the 'builtin-list' and 'mirror-list' must both be specified\n"
#  usage
#  exit 1
#elif [ ! -r $BUILTIN_LIST ] || [ ! -r $MIRROR_LIST ]; then
#  printf "\nError; the 'builtin-list' and 'mirror-list' values must both be readable files;"
#  printf ' values parsed are as follows:\n'
#  printf '\tbuiltin-list\t=> "%s"\n' "$BUILTIN_LIST"
#  printf '\tmirror-list\t=> "%s"\n' "$MIRROR_LIST"
#  usage
#  exit 1
#elif [ "$BUNDLE_TYPE" != 'prod' ] && [ "$BUNDLE_TYPE" != 'debug' ] && [ "$BUNDLE_TYPE" != 'dev' ]; then
#  printf "\nBundle type must be one of 'prod', 'dev', or 'debug'\n"
#  usage
#  exit 1
#fi

# Make sure we're starting with a clean (i.e. empty) build directory to hold
# the gzipped tarfile that will contain all of dependencies
e_header "Starting Build"
echo ""
e_bold "Create Environment"
rm -rf tmp-build-dir && \
mkdir -p tmp-build-dir/build_dir/boot && \
mkdir -p tmp-build-dir/build_dir/cde/optional && \
cp -r configs/isolinux tmp-build-dir/build_dir/boot && \
chmod -R u+w tmp-build-dir/build_dir/boot/isolinux

if [ $? -eq 0 ]; then
	e_success "Environment Created"
else
	e_error "failed to create environment in tmp-build-dir"
	exit 1
fi

echo ""
e_bold "Build Custom initramfs image"
mkdir tmp-build-dir/myimg.gz/
cp -a configs/initrd/* tmp-build-dir/myimg.gz/
pushd tmp-build-dir/myimg.gz/
	find | sudo cpio -o -H newc | gzip -2 >  ../build_dir/boot/myimg.gz && \
	advdef -z4 ../build_dir/boot/myimg.gz
popd

## TESTING START HERE!!!!!

echo ""
e_bold "Fetch Upstream Packages"
wget $WGET_V -P tmp-build-dir/build_dir/boot $TCL_ISO_URL/vmlinuz64 && \
wget $WGET_V -P tmp-build-dir/build_dir/boot $TCL_ISO_URL/corepure64.gz

if [ $? -eq 0 ]; then
	e_success "Upstream Kernel and INITRAMFS Fetched"
else
	e_error "failed to Fetch kernel and Initramfs"
	exit 1
fi

echo ""
e_bold "Populating CDE from configs/tc/extensions.lst"
for file in `cat configs/tc/extensions.lst`
do
	if echo $file | egrep -q "^#"; then continue; fi
	echo ""
	e_note "$file"
	wget $WGET_V -P tmp-build-dir/build_dir/cde/optional $TCL_MIRROR_URI/$file && \
	wget $WGET_V -P tmp-build-dir/build_dir/cde/optional $TCL_MIRROR_URI/$file.md5.txt && \
	echo $file >> tmp-build-dir/build_dir/cde/onboot.lst

	if [ $? -ne 0 ]; then
		e_error "Failed to download $file"
		exit 1	
	fi

	wget $WGET_V -P tmp-build-dir/build_dir/cde/optional $TCL_MIRROR_URI/$file.dep
done

echo ""
e_bold "Checking dependencies"
pushd tmp-build-dir/build_dir/cde/optional
	ls -1 *.dep | while read depfile
	do
		cat $depfile | while read dep
		do
			if [ ! -f $dep ]; then
				e_warning "$dep missing - consider adding it to extensions.lst"
			fi
		done
	done
popd
sleep 2

if [ -d extras_bin ];then
echo ""
e_bold "Copying Extras BIN"
	for file in `cat configs/tc/extras.lst`
	do
		if [ -f extras_bin/$file ]; then
		e_note "$file"
		cp extras_bin/$file tmp-build-dir/build_dir/cde/optional
		echo $file >> tmp-build-dir/build_dir/cde/onboot.lst
		fi
	done
fi


echo ""
e_bold "Building Iso"
# since this is multi-line, easier to build it here
preparer="primeroznl <primeroznl@gmail.com>
https://github.com/primeroz/przVault
Built on [$(uname -a)]
Built at [$(date +'%Y-%m-%d %H:%M:%S')]
Built by [$(whoami)@$(hostname -f)]"

pushd tmp-build-dir
	mkisofs -quiet -l -J -R																				\
    -no-emul-boot -boot-load-size 4 -boot-info-table            \
    -b boot/isolinux/isolinux.bin                               \
    -c boot/isolinux/boot.cat                                   \
    -A 'przVault 0.1' -sysid 'LINUX'                     				\
    -p "${preparer:0:128}"                                      \
    -V "przVault 0.1"                        										\
    -copyright 'LICENSE'                                        \
    -o "remastered.iso" build_dir  && \
	isohybrid remastered.iso

	if [ $? -eq 0 ]; then
		e_success "ISO Successfuly built"
		e_arrow "Run it with ./runtc"
	else
		e_error "failed to Build ISO"
		popd
		exit 1
	fi
popd

