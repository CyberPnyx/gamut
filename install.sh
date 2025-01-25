#!/bin/bash

echo -e "\e[34;1mStarting Archlinux installation...\e[0m"
echo -e "\e[33;1mPlease enter: \"n\", \"p\", enter, enter, \"+21G\" and \"w\"\e[0m"
fdisk /dev/sda
timedatectl
pvcreate /dev/sda1
vgcreate vg_arch /dev/sda1
lvcreate -L 400M -n boot vg_arch
lvcreate -L 15G -n root vg_arch
lvcreate -L 5G -n home vg_arch
lvcreate -L 500M -n swap vg_arch
mkfs.ext2 /dev/vg_arch/boot
mkfs.ext4 /dev/vg_arch/root
mkfs.ext4 /dev/vg_arch/home
mkswap /dev/vg_arch/swap
swapon /dev/vg_arch/swap
mount /dev/vg_arch/root /mnt
mkdir /mnt/home
mkdir /mnt/boot
mount /dev/vg_arch/home /mnt/home
mount /dev/vg_arch/boot /mnt/boot
reflector --country France --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacstrap -K /mnt base linux linux-firmware networkmanager nano vim lvm2 grub plasma-meta sddm xorg xorg-server konsole dolphin openssh
genfstab -U /mnt >> /mnt/etc/fstab
curl -o /mnt/settings.sh https://your-server/path/to/settings.sh
chmod +x /mnt/settings.sh
echo -e "\e[34;1mInstallation finished\e[0m"
echo -e "\e[34;1mPlease execute \"arch-chroot /mnt /bin/bash\" and then \"./settings.sh\"\e[0m"
