#!/bin/bash

# Automatically re-run script under sudo if not root
if [ $(id -u) -ne 0 ]; then
    echo "Re-running script under sudo..."
    sudo "$0" "$@"
    exit
fi

# Checking device for fusing
if [ -z $1 ]; then
    echo "Usage: ./fushing /dev/sdx"
    exit 0
fi

case $1 in
/dev/sd[a-z] | /dev/loop[0-9])
    if [ ! -e $1 ]; then
        echo "Error: $1 does not exist."
        exit 1
    fi
    DEV_NAME=`basename $1`
    BLOCK_CNT=`cat /sys/block/${DEV_NAME}/size` ;;
/dev/sd[a-z])
    REMOVABLE=`cat /sys/block/${DEV_NAME}/removable` ;;
/dev/loop[0-9])
    REMOVABLE=1 ;;
*)
    echo "Error: Unsupported SD reader"
    exit 0
esac

if [ ${REMOVABLE} -le 0 ]; then
    echo "Error: $1 is non-removable device. Stop."
    exit 1
fi

if [ -z ${BLOCK_CNT} -o ${BLOCK_CNT} -le 0 ]; then
    echo "Error: $1 is inaccessible. Stop fusing now!"
    exit 1
fi

let DEV_SIZE=${BLOCK_CNT}/2
if [ ${DEV_SIZE} -gt 64000000 ]; then
    echo "Error: $1 size (${DEV_SIZE} KB) is too large"
    exit 1
fi

if [ ${DEV_SIZE} -le 3800000 ]; then
    echo "Error: $1 size (${DEV_SIZE} KB) is too small"
    echo "       At least 4GB SDHC card is required, please try another card."
    exit 1
fi

# Confirm fushing
echo "All data on "$1" now will be destroyed! Continue? [y/n]"
read ans
if ! [ $ans == 'y' ]
then
    exit
fi

echo "[Unmounting all existing partitions on the device]"

umount $1*

# Generate bootloader
echo "[Generate bootloader...]"
./bootgen bootloader.bin u-boot.bin

# Start partitioning
echo "[Erase partition $1...]"

DRIVE=$1
dd if=/dev/zero of=$DRIVE bs=1024 count=1024 &>/dev/null

SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`
echo [Disk size = $SIZE bytes]

# Write MBR
echo "[Write MBR...]"
dd if=bootloader.bin of=${DRIVE} bs=512 seek=1 &> /dev/null

# Start partitioning
echo "[Partitioning $1...]"
{
# Partition 1
echo -e "n"
echo -e "p"
echo -e "1"
echo -e " "
echo -e "+64M"
# Partition 1
echo -e "n"
echo -e "p"
echo -e "2"
echo -e " "
echo -e " "
echo -e "w"
} | fdisk $DRIVE &> /dev/null

echo "[Making filesystems...]"

if [[ ${DRIVE} == /dev/*mmcblk* ]]
then
	DRIVE=${DRIVE}p
fi

# Format the disk
mkfs.vfat -F 32 -n boot ${DRIVE}1 &> /dev/null
mkfs.ext4 -L rootfs ${DRIVE}2 &> /dev/null
#mkfs.ext4 -L usrdata ${DRIVE}3 &> /dev/null
#mkfs.vfat -F 32 -n data ${DRIVE}4 &> /dev/null

# Copy kenrel image
echo "[Copying uImage...]"
UIMAGE=uImage 
mount ${DRIVE}1 /mnt
cp $UIMAGE /mnt
sync
umount ${DRIVE}1

sleep 1

# Copy rootfs
echo "[Copying rootfs]"
ROOTFS=rootfs.tar.bz2
mount ${DRIVE}2 /mnt
tar jxvf $ROOTFS -C /mnt
sync
umount ${DRIVE}2

echo "[Done]"

