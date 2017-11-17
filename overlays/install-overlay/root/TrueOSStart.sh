#!/bin/sh
# Copyright 2017 iXsystems (Kris Moore)
# License: 2 Clause BSD
# http://www.trueos.org
# Author: Kris Moore
###########################################################################
MM_CHARSET="UTF-8" ; export MM_CHARSET
LANG="en_US.UTF-8" ; export LANG
LC_CTYPE="en_US.UTF-8" ; export LC_CTYPE
LC_COLLATE="POSIX" ; export LC_COLLATE

# Make sure this is only executed on the first login, in order for other ctrl-fX screens to work
if [ -f "/tmp/1stRun" ]
then
  exit
fi

touch /tmp/1stRun

# Make /var/tmp link
mkdir -p /var/tmp
mv /var/tmp /tmp/vartmp
ln -s /tmp/vartmp /var/tmp

sleep 1

# Check ZFS tmpdir
if [ ! -d "/tmp/zfs" ] ; then
  mkdir -p /tmp/zfs
  if [ ! -d "/tmp/zfs" ] ; then
     echo "Error creating /tmp/zfs, ZFS installs will not work!"
     echo "Press ENTER to continue"
     read tmp
  fi
fi

# Check if we have FreeBSD dist files on this media
if [ ! -d "/dist-fbsd" ] ; then
   touch /tmp/no-fbsd-release
fi

# Enable the debug version of pc-sysinstall
/root/debugpcsysinstall.sh

# Check if we need to prep a network install
if [ -e "/trueos-media-network" ] ; then
  cp -r /root/pkg-template /root/pkg
  . /root/config.sh
  ARCH=`uname -m`
  FBSDVER=`uname -r | cut -d '-' -f 1-2`
  MAJORVER="`uname -r | cut -d '-' -f 1 |  cut -d '.' -f 1`.0-RELEASE"
  # Make sure we are on a -RELEASE, otherwise use the proper uname
  echo $FBSDVER | grep -q -e 'RELEASE' -e 'STABLE'
  if [ $? -ne 0 ] ; then MAJORVER="$FBSDVER"; fi

  cp /root/pkg/repos/trueos.conf.dist /root/pkg/repos/trueos.conf
  if [ "$INSTALLPACKAGESET" = "EDGE" ] ; then
     sed -i '' "s|VERSION|${MAJORVER}/edge|g" /root/pkg/repos/trueos.conf
  else
     sed -i '' "s|VERSION|${MAJORVER}|g" /root/pkg/repos/trueos.conf
  fi
  sed -i '' "s|ARCH|${ARCH}|g" /root/pkg/repos/trueos.conf
fi

# Source our functions
. /root/functions.sh

# Set all NICS to DHCP mode (This enables networking for post install)
enable_dhcp_all

# Enable dhcp for install
dhcpcd

# Doing Server Install?
if [ -e "/trueos-server" ] ; then
  /root/TrueOSText.sh
  if [ "$?" = "0" ] ; then
    reboot -q
  else
    echo "Installation failed! Press any key to drop to shell or type 'reboot' to restart the system"
    read tmp
    if [ "$tmp" = "reboot" ] ; then
      reboot -q
    else
      /bin/sh
    fi
  fi
fi

# Check if we have an auto-install directive
if [ -e "/tmp/pc-autoinstall.conf" ]
then
  # Start the parser on this directive and begin the install
  /root/pc-sysinstall/pc-sysinstall start-autoinstall /tmp/pc-autoinstall.conf
fi

# Run the intial sorting of directories
mv /root/.fluxbox /memfs/
ln -s /memfs/.fluxbox /root/.fluxbox

# Create the .qt directory
mkdir /tmp/.qt
mkdir /tmp/xkb

# Run the installer
echo "Starting graphical Installer (AutoDetect).. Please wait.."
start_xorg

# Check if we had a successful SysInstaller exit
if [ -e "/root/.exitStatus" ] ; then
  STATUS="`cat /root/.exitStatus`"
  if [ "$STATUS" = "0" ] ; then
    reboot -q
  else
    echo "Installation failed! Press any key to drop to shell or type 'reboot' to restart the system"
    read tmp
    if [ "$tmp" = "reboot" ] ; then
      reboot -q
    else
      /bin/sh
    fi
  fi
fi

reboot -q
