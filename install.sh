#!/bin/bash

# --------------------------------------------------
# Script d'installation de Arch Linux + KDE Plasma
# À exécuter depuis l'ISO Arch en mode UEFI
# --------------------------------------------------

# Désactiver le mode lecture seule
mount -o remount,rw /mnt

# ---------------------------------------------------------------------
# Configuration manuelle (À MODIFIER AVANT EXÉCUTION !)
# ---------------------------------------------------------------------
DISK="/dev/sda"               # Disque à formater
USERNAME="archuser"           # Nom d'utilisateur
HOSTNAME="archplasma"         # Nom de la machine
TIMEZONE="Europe/Paris"       # Fuseau horaire
LANG="fr_FR.UTF-8"            # Langue système
KEYMAP="fr-latin9"            # Clavier
ROOT_PASSWORD="root"          # Mot de passe root
USER_PASSWORD="user"          # Mot de passe utilisateur
# ---------------------------------------------------------------------

# Partitions (UEFI)
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

# Vérification de la connexion Internet
ping -c 3 archlinux.org || { echo "Pas de connexion Internet!"; exit 1; }

# Synchronisation de l'horloge
timedatectl set-ntp true

# Nettoyage du disque
echo "Effacement du disque..."
sgdisk --zap-all $DISK
partprobe $DISK

# Partitionnement (GPT/UEFI)
echo "Création des partitions..."
parted $DISK mklabel gpt
parted $DISK mkpart "EFI" fat32 1MiB 513MiB
parted $DISK set 1 esp on
parted $DISK mkpart "ROOT" ext4 513MiB 100%

# Formatage
echo "Formatage des partitions..."
mkfs.fat -F32 $EFI_PART
mkfs.ext4 $ROOT_PART

# Montage
mount $ROOT_PART /mnt
mkdir /mnt/boot
mount $EFI_PART /mnt/boot

# Installation des paquets de base
echo "Installation des paquets de base..."
pacstrap /mnt base base-devel linux linux-firmware nano reflector

# Génération du fstab
genfstab -U /mnt >> /mnt/mnt/fstab

# Configuration système
arch-chroot /mnt /bin/bash <<EOF
    # Configuration de base
    echo "$HOSTNAME" > /etc/hostname
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc

    # Localisation
    sed -i "s/#$LANG/$LANG/" /etc/locale.gen
    echo "LANG=$LANG" > /etc/locale.conf
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
    locale-gen

    # Mise à jour miroirs
    reflector --country France --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

    # Initialisation
    mkinitcpio -P

    # Mot de passe root
    echo "root:$ROOT_PASSWORD" | chpasswd

    # Installation KDE Plasma
    pacman -Syu --noconfirm xorg sddm plasma kde-applications dolphin firefox plasma-wayland-session

    # Activer services
    systemctl enable sddm
    systemctl enable NetworkManager

    # Création utilisateur
    useradd -m -G wheel -s /bin/bash $USERNAME
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    # Pilotes graphiques (Décommenter selon besoin)
    # pacman -S --noconfirm nvidia nvidia-utils    # NVIDIA
    # pacman -S --noconfirm mesa vulkan-intel      # Intel
    # pacman -S --noconfirm mesa vulkan-radeon     # AMD
EOF

# Nettoyage final
umount -R /mnt
systemctl reboot