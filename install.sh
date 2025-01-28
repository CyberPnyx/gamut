#!/bin/bash

echo -e "\e[34;1mStarting Archlinux installation...\e[0m"

# Partitionnement
echo -e "\e[33;1mPlease partition your disk: \"n\", \"p\", enter, enter, \"+21G\", and \"w\"\e[0m"
fdisk /dev/sda

# Configuration de l'heure
timedatectl set-ntp true

# Configuration LVM
pvcreate /dev/sda1
vgcreate vg_arch /dev/sda1
lvcreate -L 400M -n boot vg_arch
lvcreate -L 15G -n root vg_arch
lvcreate -L 5G -n home vg_arch
lvcreate -L 500M -n swap vg_arch

# Formatage des partitions
mkfs.fat -F 32 /dev/vg_arch/boot
mkfs.ext4 /dev/vg_arch/root
mkfs.ext4 /dev/vg_arch/home
mkswap /dev/vg_arch/swap
swapon /dev/vg_arch/swap

# Montage des partitions
mount /dev/vg_arch/root /mnt
mkdir /mnt/home
mkdir /mnt/boot
mount /dev/vg_arch/home /mnt/home
mount /dev/vg_arch/boot /mnt/boot

# Mise à jour des miroirs
reflector --country France --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Installation de base
pacstrap /mnt base linux linux-firmware networkmanager nano vim lvm2 openssh

# Génération du fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Fin de l'installation
echo -e "\e[34;1mInstallation finished\e[0m"
echo -e "\e[34;1mPlease execute the following commands:\e[0m"
echo -e "\e[33;1march-chroot /mnt /bin/bash\e[0m"
echo -e "\e[33;1m./settings.sh\e[0m"

echo -e "\e[34;1mPlease reboot your system after running the settings script.\e[0m"
