#!/bin/sh

echo "-------------------------------------"
echo "deploy.sh"
echo "V0.10: Try several times to mount USB sticks if mount fails"
echo "V0.09: Log installation to boot medium removed again because it caused problems"
echo "V0.08: Log installation to boot medium"
echo "V0.07: Do not install E2 if disk is not partitioned
             and parameter partition is set to 0"
echo "V0.06: Added EXT2 option for E2 and MINI partitions"
echo "V0.05: Added JFS option for RECORD partition"
echo "V0.04: Changed ini File format"
echo "V0.03: Suppress meaningless tar errors during save settings"
echo "V0.02: Format Mini partitions with Ext3 instead of Ext2"
echo "V0.01: New parameter CREATEMINI and cleanup of KEEPSETTINGS"
echo "-------------------------------------"

# default installation device
HDD=/dev/sda

# Check if the correct MTD setup has been used
if [ -z "`cat /proc/mtd | grep mtd3 | grep 'TF Kernel'`" ]
then
        echo 'ERR MTD' > /dev/fplarge
        echo 'ERR MTD'
        exit 1
fi


# Give the system a chance to recognize the USB stick
echo "Mounting USB stick"
echo '   9'     > /dev/fpsmall
echo 'USB STCK' > /dev/fplarge

sleep 5
mkdir /instsrc

i=1
while (true) do
  mount -t vfat /dev/sdb1 /instsrc
  if [ $? -ne 0 ]; then
    mount -t vfat /dev/sdb /instsrc
    if [ $? -eq 0 ]; then
      break
    fi
  else
    break
  fi

  if [ $i -gt 5 ]; then
    echo "USB" > /dev/fpsmall
    echo "FAILED" > /dev/fplarge
    exit
  fi

  echo "USB" > /dev/fpsmall
  echo "RETRY $i" > /dev/fplarge

  sleep 5
  i=`expr $i + 1`
done


# If the file topfield.tfd is located on the stick, flash it
if [ -f /instsrc/topfield.tfd ]; then

  echo
  echo Please stand by. This will take about 1.5 minutes...
  echo After the reboot of the box, it may take another 2 or
  echo 3 minutes until the picture comes back
  echo

  cat /instsrc/topfield.tfd | tfd2mtd > /dev/mtdblock5
  mv /instsrc/topfield.tfd /instsrc/topfield.tfd_
  dd if=/dev/zero of=/dev/sda bs=512 count=64
  umount /instsrc

  echo Shutting down
  reboot
  exit
fi
mkdir /instdest


export startingLine1=`grep -m 1 -n "\[settings\]" /instsrc/Enigma_Installer.ini | awk -F: '{ print $1 }' 2>/dev/null`
export startingLine2=`grep -m 1 -n "\[ownsettings\]" /instsrc/Enigma_Installer.ini | awk -F: '{ print $1 }' 2>/dev/null`

if [ -z "$startingLine1" ]; then
  echo "No specification for KEEP SETTINGS detected"
  export set startingLine1=9999
else
  echo "Specification for KEEP SETTINGS detected at line $startingLine1"
fi

if [ -z "$startingLine2" ]; then
  echo "No specification for additional KEEP SETTINGS detected"
  export set startingLine2=9999
else
  echo "Specification for additional KEEP SETTINGS detected at line "$startingLine2
fi

if [ "$startingLine1" -gt "$startingLine2" ]; then
  export set startingLine="$startingLine2"
else
  export set startingLine="$startingLine1"
fi


eval `sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
    -e 's/;.*$//' \
    -e 's/[[:space:]]*$//' \
    -e 's/^[[:space:]]*//' \
    -e "s/^\(.*\)=\([^\"']*\)$/\1=\"\2\"/" \
   < /instsrc/Enigma_Installer.ini \
    | sed -n -e "/^\[parameter\]/,/^\s*\[/{/^[^;].*\=.*/p;}"`


echo "-------------------------------------"
echo "partition:" "$partition"
echo "createmini:" "$createmini"
echo "keepsettings:" "$keepsettings"
echo "keepbootargs:" "$keepbootargs"

echo "usejfs:" "$usejfs"
echo "useext2e2:" "$useext2e2"

echo "usbhdd:" "$usbhdd"
echo "format:" "$format"
echo "update:" "$update"
echo "-------------------------------------"

# Undocumented feature for testing: abort shell script
if [ "$CONSOLE" = "666" ]; then
  echo "CONSOLE" > /dev/fplarge
  echo "Entering console mode"
  exit
fi

if [ "$usbhdd" = "1" ]; then
  HDD=/dev/sdb
fi

ROOTFS=$HDD"1"
SWAPFS=$HDD"2"
DATAFS=$HDD"3"

# If the keyword 'keepsettings' has been specified, save some config files to the disk
if [ "$keepsettings" = "1" ]; then
  echo Saving settings
  echo "SAVE" > /dev/fpsmall
  echo "SETTINGS" > /dev/fplarge
  if [ ! -d /instsrc/e2settings ] || [ ! -f /instsrc/e2settings/backup.tar.gz ]; then
    export set savFile="backup.tar.gz"
  else
    export set savFile="backup-new.tar.gz"
    echo "Settings are already on the stick. Saving current settings to backup-new.tar.gz but will use backup.tar.gz to restore."
  fi

  if [ ! -d /instsrc/e2settings ]; then
    mkdir /instsrc/e2settings
  fi
  mount $ROOTFS /instdest
  cd /instdest

  echo "Using settings in file /instsrc/Enigma_Installer.ini, starting at line "$startingLine
  tar cvzf "/instsrc/e2settings/$savFile" `tail /instsrc/Enigma_Installer.ini -n +$startingLine | grep -v "^#"` 2>/dev/null

  cd /
  sync
  sleep 3
  umount /instdest
fi

if [ "$usbhdd" = "1" ]; then
  # the following is only executed when usbhdd is selected
  echo "Preparing installation to USB HDD"
  mkdir /instsrc1
  if [ -d /initsrc/settings ]; then
    cp -r /instsrc/settings /instsrc1
  fi
  cp /instsrc/rootfs.tar.gz /instsrc1
  if [ $? != 0 ]; then
    echo "error copying files to RAM disk"
    echo 'FAIL'     > /dev/fpsmall
    echo 'RAMDISK'  > /dev/fplarge
    exit
  fi

  # remount the RAM disk
  umount /instsrc
  mv /instsrc /instsrc_
  mv /instsrc1 /instsrc

  echo "waiting for USB stick to be detached"
  echo 'STCK'     > /dev/fpsmall
  echo ' DETACH'  > /dev/fplarge

  while (true) do
    if [ "`grep sdb /proc/diskstats`" == "" ]; then
      break
    fi
    sleep 1
  done

  echo "USB detached"
  echo ' HDD'     > /dev/fpsmall
  echo ' ATTACH'  > /dev/fplarge

  while (true) do
    if [ "`grep sdb /proc/diskstats`" != "" ]; then
      break
    fi
    sleep 1
  done

  echo "USB attached"
fi

# Skip formatting if the keyword 'format' is not specified in the control file
if [ $format != "1" ]; then
  echo Checking hdd
  echo '   8'     > /dev/fpsmall
  echo 'HDD CHK'  > /dev/fplarge

  fsck.ext3 -y $ROOTFS
  if [ "$usejfs" = "1" ]; then
    fsck.jfs -p $DATAFS
  else
    fsck.ext2 -y $DATAFS
  fi
else
  if [ "$partition" = "1" ]; then
    echo "Partitioning HDD"
    echo '   8'     > /dev/fpsmall
    echo 'HDD PART' > /dev/fplarge
    dd if=/dev/zero of=$HDD bs=512 count=64
    sfdisk --re-read $HDD
    if [ "$createmini" != "1" ]; then
      # Erase the disk and create 3 partitions
      #  1:   2GB Linux
      #  2: 512MB Swap
      #  3: remaining space LINUX
      sfdisk $HDD -uM << EOF
,2048,L
,256,S
,,L
;
EOF
    else
      export set recsize=$((`sfdisk -s $HDD`/1024-2048-256-1024-1024-1024-1024))
      # Erase the disk and create 8 partitions
      #  1:   2GB Linux
      #  2: 512MB Swap
      #  3: remaining space LINUX
      #  4: Extended Partition
      #  5: 1GB  LINUX
      #  6: 1GB  LINUX
      #  7: 1GB  LINUX
      #  8: 1GB  LINUX
      sfdisk $HDD -uM << EOF
,2048,L
,256,S
,$recsize,L
,,E
,1024,L
,1024,L
,1024,L
,,L
EOF
    fi
  else
    echo Skipping partitioning of the disk
    # Check if the RECORD Partition is there already. If not cancel the installation
    fpart=`fdisk -l "$HDD" | grep -c "$HDD"3`
    if [ $fpart = 0 ]; then
      echo ' ERR' > /dev/fpsmall
      echo 'REC PART'  > /dev/fplarge
      echo Error. Disk not partitioned yet. Installation canceled.
      halt
    else
      echo OK, Disk already partitioned.
    fi
  fi

  # Format both Linux partitions
  echo "Formatting HDD"
  echo '   7'     > /dev/fpsmall
  echo 'HDD FMT'  > /dev/fplarge
  ln -s /proc/mounts /etc/mtab

  fs="ext3"
  if [ "$useext2e2" = "1" ]; then
    fs="ext2"
  fi

  mkfs.$fs -L MINI9 $ROOTFS

  if [ "$partition" = "1" ]; then
    if [ "$createmini" = "1" ]; then
      echo 'MINI'     > /dev/fpsmall
      mknod $HDD"5" b 8 5
      mknod $HDD"6" b 8 6
      mknod $HDD"7" b 8 7
      mknod $HDD"8" b 8 8
      mkfs.$fs -L MINI1 $HDD"5"
      mkfs.$fs -L MINI2 $HDD"6"
      mkfs.$fs -L MINI3 $HDD"7"
      mkfs.$fs -L MINI4 $HDD"8"
    fi
    echo '   6'     > /dev/fpsmall
    if [ "$usejfs" = "1" ]; then
      echo 'HDD FMT JFS'  > /dev/fplarge
      mkfs.jfs -q -L RECORD $DATAFS
    else
      mkfs.ext2 -L RECORD $DATAFS
    fi
  fi

  # Initialise the swap partition
  echo '   5'     > /dev/fpsmall
  echo 'HDD SWAP' > /dev/fplarge
  mkswap $SWAPFS
  echo "SWAPPART" > /deploy/swaplabel
  dd if=/deploy/swaplabel of="$SWAPFS" seek=1052 bs=1 count=8
fi


# Skip rootfs installation if the keyword 'update' is not specified in the control file
if [ "$update" = "1" ]; then
  echo "Installing root file system"
  echo '   4'     > /dev/fpsmall
  echo 'ROOT FS'  > /dev/fplarge
  mount $ROOTFS /instdest
  cd /instdest
  gunzip -c /instsrc/rootfs.tar.gz | tar -x
  if [ "$usbhdd" = "1" ]; then
    sed -e "s#sda#sdb#g" etc/fstab > fstab1
    mv fstab1 etc/fstab
    sed -e "s#sda#sdb#g" etc/init.d/rcS > rcS1
    mv rcS1 etc/init.d/rcS
    chmod 744 etc/init.d/rcS
  fi
  cd ..
  sync
  umount /instdest
else
  echo Skipping root file system
fi


# Restore the settings
if [ "$keepsettings" = "1" ]; then
  echo Restoring settings
  echo "RSTR" > /dev/fpsmall
  echo "SETTINGS" > /dev/fplarge
  mount $ROOTFS /instdest
  cd /instdest
  tar xzf "/instsrc/e2settings/backup.tar.gz"
  cd /
  sync
  sleep 3
  umount /instdest
fi

# Make sure that the data partition contains subdirectories
mkdir -p /mnt
mount $DATAFS /mnt
mkdir -p /mnt/movie
mkdir -p /mnt/music
mkdir -p /mnt/picture
sync
umount /mnt

# Write U-Boot settings into the flash
echo "Flashing U-Boot settings"
echo '   3'     > /dev/fpsmall
echo 'LOADER'   > /dev/fplarge
dd if=/deploy/u-boot.mtd1 of=/dev/mtdblock1
if [ $? -ne 0 ]; then
  echo "FAIL" > /dev/fpsmall
  exit
fi

# Skip Flash MTD2 if keyword 'nomtd2' is specified in the control file
if [ "$keepbootargs" != "1" ]; then
	if [ "$usbhdd" = "1" ]; then
		dd if=/deploy/U-Boot_Settings_usb.mtd2 of=/dev/mtdblock2
	else
		dd if=/deploy/U-Boot_Settings_hdd.mtd2 of=/dev/mtdblock2
	fi
	if [ $? -ne 0 ]; then
		echo "FAIL" > /dev/fpsmall
		exit
	fi
else
  echo "Skipped flashing mtdblock2 on user request."
fi

# write the kernel to flash
echo "Flashing kernel"
echo '   2'     > /dev/fpsmall
echo 'KERNEL'   > /dev/fplarge
mount $ROOTFS /instdest
dd if=/instdest/boot/uImage of=/dev/mtdblock3
if [ $? -ne 0 ]; then
  echo "FAIL" > /dev/fpsmall
  exit
fi


# unmount and check the file system
echo '   1'     > /dev/fpsmall
echo 'FSCK'     > /dev/fplarge
umount /instdest
rmdir /instdest
fsck.ext3 -f -y $ROOTFS


# rename uImage to avoid infinite installation loop
if [ "$usbhdd" != "1" ]; then
  mv -f /instsrc/uImage /instsrc/uImage_
  umount /instsrc
fi


# Reboot
echo '   0'     > /dev/fpsmall
echo 'REBOOT'   > /dev/fplarge
sleep 2
reboot
