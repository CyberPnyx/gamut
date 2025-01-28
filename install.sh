#!/bin/bash
set -e

# Variables
DISK="/dev/sda"
HOSTNAME="client_s${USER}"
LVM_VG="arch_vg"
CRYPTNAME="cryptlvm"

# Partitionnement avec UEFI
parted --script "${DISK}" \
    mklabel gpt \
    mkpart "EFI" fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart "LVM" 513MiB 100% 

# Cryptsetup pour partition LVM
echo "password" | cryptsetup luksFormat "${DISK}2"
echo "password" | cryptsetup open "${DISK}2" "${CRYPTNAME}"

# Configuration LVM
pvcreate "/dev/mapper/${CRYPTNAME}"
vgcreate "${LVM_VG}" "/dev/mapper/${CRYPTNAME}"
lvcreate -L 15G -n root "${LVM_VG}"
lvcreate -L 5G -n home "${LVM_VG}"
lvcreate -L 400M -n boot "${LVM_VG}"
lvcreate -L 500M -n swap "${LVM_VG}"

# Formatage
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -O "^has_journal" "/dev/${LVM_VG}/boot"
mkfs.ext4 "/dev/${LVM_VG}/root"
mkfs.ext4 "/dev/${LVM_VG}/home"
mkswap "/dev/${LVM_VG}/swap"

# Montage
mount "/dev/${LVM_VG}/root" /mnt
mkdir -p /mnt/{boot,home}
mount "/dev/${LVM_VG}/boot" /mnt/boot
mount "/dev/${LVM_VG}/home" /mnt/home
swapon "/dev/${LVM_VG}/swap"

# Installation paquets de base
pacstrap /mnt base base-devel linux linux-firmware lvm2 neovim

# Génération fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configuration système
arch-chroot /mnt /bin/bash <<EOF
set -e

# Locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen

# Clavier (remplacer fr par votre layout)
echo "KEYMAP=fr" > /etc/vconsole.conf

# Fuseau horaire (remplacer Europe/Paris par votre zone)
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# Hostname
echo "${HOSTNAME}" > /etc/hostname

# Initramfs
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Bootloader
bootctl install
cat <<EOL > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=UUID=$(blkid -s UUID -o value "${DISK}2"):${CRYPTNAME} root=/dev/${LVM_VG}/root quiet rw
EOL

# Utilisateurs et groupes
groupadd asso
groupadd managers
groupadd Hogwarts
useradd -m -G asso,Hogwarts turban
useradd -m -G managers,Hogwarts dumbledore

# Plasma KDE
pacman -Syu --noconfirm xorg plasma kde-applications sddm
systemctl enable sddm

# Configuration SSH
pacman -S --noconfirm openssh
sed -i 's/#Port 22/Port 42/' /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl enable sshd

# Montage automatique Parrot OS (à adapter avec UUID réel)
echo "UUID=PARROT_HOME_UUID /home/parrot ext4 defaults,nofail 0 0" >> /etc/fstab

# Configuration finale
passwd -d root
exit
EOF

umount -R /mnt
swapoff -a