#!/usr/bin/env bash
#-------------------------------
# Arch Linux installation script
#-------------------------------

echo "--------------------------"
echo "Setting up some initial settings."
echo "--------------------------"

# Set up time synchronization
timedatectl set-ntp true

pacman-key --init
pacman-key --populate
pacman -Syyy
pacman -S pacman-contrib --noconfirm

echo "--------------------------"
echo "Setting up mirrors for optimal download speeds"
echo "--------------------------"
# backup old mirrors
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
# todo install rank mirrors if not already in iso image (check that it is)
curl -s "https://archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

echo -e "\nInstalling prerequisites...\n"
pacman -S noconfirm gptfdisk

echo "---------------------------------"
echo "-----Select a Disk to format-----"
echo "---------------------------------"
lsblk
echo "Please Enter a disk: (Example /dev/sda)"
read DISK


echo "--------------------------"
echo "-----Formatting Disk------"
echo "--------------------------"

# disk Prep
sgdisk -Z ${DISK} # erases disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# Create partitions
sgdisk -n 1:0:+1000M ${DISK} # partition 1 (UEFI SYS), default start block, 512MB
sgdisk -n 2:0:0 ${DISK} # Partition 2 (Root), default start, remaining

# set Partition Types
sgdisk -t 1:ef00 ${DISK}
sgdisk -t 2:8300 ${DISK}

# Label Partitions
sgdisk -c 1:"UEFISYS" ${DISK}
sgdisk -c 2:"ROOT" ${DISK}

# Make File systems
echo -e "\nCreating Filesystems...\n"

mkfs.vfat -F32 -n "UEFISYS" "${DISK}p1" # Formats Boot partition to Fat32 on partition 1
mkfs.xfs -L "ROOT" "${DISK}p2"

# Mount target
mkdir /mnt
mount -t xfs "${DISK}p2" /mnt
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat "${DISK}p1" /mnt/boot/



echo "-----------------------------"
echo "Arch installing on Main Drive"
echo "-----------------------------"

pacstrap /mnt base base-devel --noconfirm --needed

# Zen Kernel
pacstrap /mnt linux-zen linux-zen-firmware --noconfirm needed


echo "--------------------------"
echo "Setup Dependencies"
echo "--------------------------"

pacstrap /mnt networkmanager --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab


echo "--------------------------"
echo "Bootloader Systemd Installation"
echo "--------------------------"

bootctl install --esp-path /mnt/boot
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=${DISK}p2 rw
EOF

arch-chroot /mnt

echo "----------------------------"
echo "Getting Post install scripts"
echo "----------------------------"

pacman -S --noconfirm pacman-contrib curl git
mkdir temp
cd temp
git clone https://github.com/john_ripper/ArchInstaller
cd ArchInstaller


echo "---------------------------"
echo "System ready for First Boot"
echo "---------------------------"
