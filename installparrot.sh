#!/bin/bash

### Configuration des partitions ###
DISK="/dev/sda"
BOOT_PART="${DISK}1"
ROOT_PART="${DISK}2"
HOME_PART="${DISK}3"
SWAP_PART="${DISK}4"

# Nettoyage de la table de partition
sgdisk --zap-all $DISK

# Création des partitions
sgdisk -n 1:0:+500M -t 1:ef00 $DISK       # /boot (EFI)
sgdisk -n 2:0:+25G  -t 2:8300 $DISK       # /
sgdisk -n 3:0:+5G   -t 3:8300 $DISK       # /home
sgdisk -n 4:0:+500M -t 4:8200 $DISK       # swap

# Formatage
mkfs.fat -F32 $BOOT_PART
mkfs.ext4 -O ^has_journal $ROOT_PART
mkfs.ext4 $HOME_PART
mkswap $SWAP_PART

# Montage
mount $ROOT_PART /mnt
mkdir -p /mnt/boot
mount $BOOT_PART /mnt/boot
mkdir -p /mnt/home
mount $HOME_PART /mnt/home
swapon $SWAP_PART

### Installation du système ###
parrot-mirror-selector default stable
debootstrap --arch=amd64 stable /mnt

### Configuration de base ###
# FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot
arch-chroot /mnt /bin/bash <<EOF
# Locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Clavier (remplacer fr par votre langue)
echo "KEYMAP=fr" > /etc/vconsole.conf

# Fuseau horaire
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# Utilisateurs et groupes
groupadd poche
groupadd miaou
groupadd wand
groupadd Hogwarts
groupadd Hog_warts

useradd -m -s /bin/bash -g poche -G Hogwarts pierre
useradd -m -s /bin/bash -g miaou -G Hog_warts dinosaur
useradd -m -s /bin/bash -g wand -G Hogwarts lee
useradd -m -s /bin/bash -g poche -G Hogwarts 'fred&george'

# Permissions sudo
echo -e "pierre\tALL=(dinosaur) NOPASSWD: ALL" >> /etc/sudoers
echo -e "dinosaur\tALL=(pierre) NOPASSWD: ALL" >> /etc/sudoers

# SSH
apt update && apt install -y openssh-server
sed -i 's/#Port 22/Port 42/' /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl enable ssh

# Clé SSH (à remplacer par la clé fournie)
mkdir -p /home/pierre/.ssh
echo "EPITECH_SSH_PUBLIC_KEY" > /home/pierre/.ssh/authorized_keys
chmod 700 /home/pierre/.ssh
chmod 600 /home/pierre/.ssh/authorized_keys
chown -R pierre:poche /home/pierre/.ssh

# Mise à jour finale
apt full-upgrade -y
EOF

### Finalisation ###
umount -R /mnt
swapoff -a
reboot