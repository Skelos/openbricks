#!/bin/sh

/bin/busybox mount -t proc none /proc
/bin/busybox --install -s

if [ "$1" = geexbox ]; then
  DIALOG=/usr/bin/dialog
  CFDISK=/usr/bin/cfdisk
  SFDISK=/usr/bin/sfdisk
  MKDOSFS=/usr/bin/mkdosfs
  SYSLINUX=/usr/bin/syslinux
else
  DIALOG=""
  [ "$1" != --nodialog ] && DIALOG=`which dialog`
  CFDISK=`which cfdisk`
  SFDISK=`which sfdisk`
  MKDOSFS=`which mkdosfs`
  SYSLINUX=`which syslinux`
fi
VERSION=`cat VERSION`
BACKTITLE="GeeXboX $VERSION installator"

if [ "$UID" != "0" ]; then
  if [ -n "$DIALOG" ]; then
    $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "ERROR" --msgbox "\nYou need to be root to install GeeXboX\n" 0 0
  else
    echo ""
    echo "**** You need to be root to install GeeXboX ****"
    echo ""
  fi
  exit 1
fi

if [ -z "$SFDISK" -o -z "$SYSLINUX" ]; then
  if [ -n "$DIALOG" ]; then
    $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "ERROR" --msgbox "\nYou need to have syslinux and sfdisk installed to install GeeXboX\n" 0 0
  else
    echo ""
    echo "**** You need to have syslinux and sfdisk installed to install GeeXboX ****"
    echo ""
  fi
  exit 1
fi

if [ -n "$DIALOG" ]; then
  while true; do
    if [ -e /dev/.devfsd ]; then
      DISKS=`cat /proc/partitions | sed -n "s/\ *[0-9][0-9]*\ *[0-9][0-9]*\ *\([0-9][0-9]*\)\ \([a-z0-9/]*disc\).*$/\2 (\1_blocks)/p"`
    else
      DISKS=`cat /proc/partitions | sed -n "s/\ *[0-9][0-9]*\ *[0-9][0-9]*\ *\([0-9][0-9]*\)\ \([a-z]*\)$/\2 (\1_blocks)/p"`
    fi
    if [ -z "$DISKS" ]; then
      $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "ERROR" --yesno "\nNo disks found on this system.\nCheck again?" 0 0 || exit 1
    else
      DISKS="$DISKS refresh list"
      if [ -z "$CFDISK" ]; then
        CFDISK_MSG="As you don't have cfdisk installed, the installator won't be able to create the partition for you. You'll have to create it yourself before installing."
      else
        CFDISK_MSG="You can now edit your partition table to create a FAT16 partition (type=06). Be careful to choose the right disk! We won't take responsibility for any data loss."
      fi
      DISK=`$DIALOG --stdout --backtitle "$BACKTITLE" --title "Installation device" --menu "\nYou are going to install GeeXboX. For this you will need a PRIMARY FAT16 partition (hdX1 to hdX4) with about 8 MB of free space (max. 1 GB). It WON'T work with FAT32 or ext2 partitions.\n$CFDISK_MSG" 0 0 0 $DISKS` || exit 1
      [ $DISK != refresh ] && break
    fi
  done
  $CFDISK /dev/$DISK || exit 1
else
  echo ""
  echo "You are going to install GeeXboX. For this you will need a PRIMARY"
  echo "FAT16 partition (hdX1 to hdX4) with about 8 MB of free space (max 1 GB)"
  echo "It WON'T work with FAT32 or ext2 partitions."
  echo "This installator won't create the partition. You'll have to create it"
  echo "yourself before installing. Be careful when choosing the partition"
  echo "where to install! We won't take responsibility for any data loss."
  echo ""
fi

while [ ! -b "$DEV" ]; do
  if [ -n "$DIALOG" ]; then
    DISKS=""
    for i in `$SFDISK -l | grep FAT16 | grep ${DISK%disc} | cut -f1 -d' '`; do
      S=`$SFDISK -s "$i" | sed 's/\([0-9]*\)[0-9]\{3\}/\1/'`
      DISKS="$DISKS $i ${S}MB"
    done
    if [ -z "$DISKS" ]; then
      $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "ERROR" --msgbox "\nYou don't have any FAT16 partitions on your system. Please create a FAT16 partition first using for example cfdisk.\n" 0 0
      exit 1
    else
      DEV=`$DIALOG --stdout --aspect 15 --backtitle "$BACKTITLE" --title "Installation device" --menu "Where do you want to install GeeXboX?" 0 0 0 $DISKS` || exit 1
    fi
  else
    read -p "Where do you want to install GeeXboX? (eg: /dev/hda1) " DEV
    echo ""
  fi
  if [ ! -b "$DEV" ]; then
    if [ -n "$DIALOG" ]; then
      $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "ERROR" --msgbox "\n'$DEV' is not a valid block device.\n" 0 0
    else
      echo ""
      echo "**** '$DEV' is not a valid block device ****"
      echo ""
      exit 1
    fi
  fi
done

if [ -z "$MKDOSFS" ]; then
  if [ -n "$DIALOG" ]; then
    $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "Warning" --msgbox "\n'$DEV' needs to be a FAT16 partition. As you don't have mkdosfs installed, I won't be able to format the partition. Hopefully it is already formatted.\n" 0 0
  else
    echo "'$DEV' needs to be a FAT16 partition."
    echo "As you don't have mkdosfs installed, I won't be able to format the"
    echo "partition. Hopefully it is already formatted."
  fi
else
  if [ -n "$DIALOG" ]; then
    $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "Formatting" --defaultno --yesno "\nDo you want to format '$DEV' in FAT16?\n" 0 0 && FORMAT=yes
  else
    read -p "Do you want to format '$DEV' in FAT16? (yes/no) " FORMAT
  fi
fi
echo ""

[ "$FORMAT" = yes ] && $MKDOSFS -n GEEXBOX "$DEV"
mkdir di
mount -t vfat "$DEV" di
if [ -d disk ]; then
  cp -a disk/* di 2>/dev/null
else
  if [ -n "$NFS" ]; then
    GEEXBOX="$NFS"
  else
    GEEXBOX="$CDROM/GEEXBOX"
  fi
  cp -a "$GEEXBOX" di/GEEXBOX 2>/dev/null
  mv di/GEEXBOX/boot/* di
  rm di/isolinux.bin
fi
sed "s/boot=cdrom/boot=${DEV#/dev/}/" di/isolinux.cfg > di/syslinux.cfg
rm di/isolinux.cfg
umount di
$SYSLINUX "$DEV"

mount -t vfat "$DEV" di
dd if="$DEV" of=di/geexbox.lnx count=1 bs=512
umount di
rmdir di

if [ -n "$DIALOG" ]; then
  `$DIALOG --backtitle "$BACKTITLE" --title "Bootloader" --defaultno --yesno "\n'$DEV' is now a bootable partition. To boot from it, you will need to install a bootloader. If you don't have any other operating systems on this hard disk, I can install a bootloader for you. Else, you will need to configure yourself a boot loader, such as LILO or GRUB.\n\nDo you want to install a single system bootloader?\n" 0 0` && MBR=yes
else
  echo ""
  echo "'$DEV' is now a bootable partition. To boot from it, you will need to"
  echo "install a bootloader. If you don't have any other operating systems on"
  echo "this hard disk, I can install a bootloader for you. Else, you will"
  echo "need to configure yourself a boot loader, such as LILO or GRUB."
  echo ""
  read -p "Do you want to install a single system bootloader? (yes/no) " MBR
fi

PART="${DEV#${DEV%%[0-9]*}}"
if [ "$MBR" = yes ]; then
  if [ -f mbr.bin ]; then
    dd if=mbr.bin of="/dev/$DISK"
  elif [ -f /usr/share/syslinux/mbr.bin ]; then
    dd if=/usr/share/syslinux/mbr.bin of="/dev/$DISK"
  fi
  echo ",,,*" | $SFDISK "/dev/$DISK" -N$PART
else
  GRUBDISK=`echo $DISK | sed 's/.*\(.\)$/\1/ ; y/abcdefghij/0123456789/'`
  GRUBPART=`echo $PART | sed 'y/12345678/01234567/'`
  GRUBDEV="(hd$GRUBDISK,$GRUBPART)"
  if [ -n "$DIALOG" ]; then
    $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "Bootloader" --msgbox "\nYou can configure LILO to boot GeeXboX simply by adding these lines at the end of your /etc/lilo.conf :\n    other=$DEV\n          label=GeeXboX\nDon't forget to execute lilo after doing this modification.\n\nOr if you use GRUB, add something along these lines to your /boot/grub/menu.lst:\n    title GeeXboX\n        rootnoverify $GRUBDEV\n        chainloader /geexbox.lnx\n\nWindows users must copy geexbox.lnx to their C:\ drive and add the\nfollowing line to the boot.ini file to use with the NT Loader.\n    c:\geexbox.lnx=\"GeeXboX\"\n\nOr you can have a look at a separate boot loader such as XOSL (http://www.ranish.com/part/xosl.htm)." 0 0
  else
    echo ""
    echo "You can configure LILO to boot GeeXboX simply by adding these"
    echo "lines at the end of your /etc/lilo.conf:"
    echo ""
    echo "    other=$DEV"
    echo "          label=GeeXboX"
    echo ""
    echo "Don't forget to execute lilo after doing this modification."
    echo ""
    echo "Or if you use GRUB, add something along these lines to your"
    echo "/boot/grub/menu.lst:"
    echo ""
    echo "    title GeeXboX"
    echo "          rootnoverify $GRUBDEV"
    echo "          chainloader /geexbox.lnx"
    echo ""
    echo "Windows users must copy geexbox.lnx to their C:\ drive and add the "
    echo "following line to the boot.ini file to use with the NT Loader."
    echo ""
    echo "    c:\geexbox.lnx=\"GeeXboX\""
    echo ""
    echo "Or you can have a look at a separate boot loader such as XOSL"
    echo "(http://www.ranish.com/part/xosl.htm)."
  fi
fi

[ -n "$CDROM" ] && eject &

if [ -n "$DIALOG" ]; then
  $DIALOG --aspect 15 --backtitle "$BACKTITLE" --title "Have Fun!" --msgbox "\nGeeXboX is now installed on '$DEV'\n" 0 0
else
  echo ""
  echo "**** GeeXboX is now installed on '$DEV'. Have fun! ****"
  echo ""
fi
