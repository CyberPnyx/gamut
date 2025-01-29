#!/bin/bash

# Partie 1 - Installation de base
if [ ! -f /mnt/etc/fstab ]; then
    # Partitionnement du disque
    parted /dev/sda --script mklabel gpt
    parted /dev/sda --script mkpart ESP fat32 1MiB 401MiB
    parted /dev/sda --script set 1 esp on
    parted /dev/sda --script mkpart primary 401MiB 22.4GiB

    # Configuration LVM
    pvcreate /dev/sda2
    vgcreate arch_vg /dev/sda2
    lvcreate -L 15G -n root arch_vg
    lvcreate -L 5G -n home arch_vg
    lvcreate -L 400M -n boot arch_vg
    lvcreate -L 500M -n swap arch_vg

    # Formatage des partitions
    mkfs.fat -F32 /dev/sda1
    mkfs.ext4 /dev/arch_vg/root
    mkfs.ext4 /dev/arch_vg/home
    mkfs.ext2 /dev/arch_vg/boot
    mkswap /dev/arch_vg/swap
    swapon /dev/arch_vg/swap

    # Montage des partitions
    mount /dev/arch_vg/root /mnt
    mkdir -p /mnt/{home,boot,efi}
    mount /dev/arch_vg/home /mnt/home
    mount /dev/arch_vg/boot /mnt/boot
    mount /dev/sda1 /mnt/boot/efi

    # Installation du système de base
    pacstrap /mnt base linux linux-firmware lvm2
    genfstab -U /mnt >> /mnt/etc/fstab

    # Configuration dans l'environnement chroot
    arch-chroot /mnt /bin/bash <<EOF
    # Configuration de base
    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "KEYMAP=fr" > /etc/vconsole.conf
    echo "archlinux" > /etc/hostname

    # Configuration de GRUB
    pacman -S grub efibootmgr dosfstools os-prober nano --noconfirm
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux
    sed -i '/^HOOKS=/ s/block/& lvm2/' /etc/mkinitcpio.conf
    mkinitcpio -P
    grub-mkconfig -o /boot/grub/grub.cfg

    # Mot de passe root
    echo "root:1234" | chpasswd
EOF

    # Nettoyage final
    umount -R /mnt
    echo "Installation terminée ! Redémarrez et exécutez le script à nouveau pour la configuration finale."
    exit
fi

# Partie 2 - Post-installation (à exécuter après le premier redémarrage)
if [ $(whoami) != "root" ]; then
    echo "Veuillez exécuter ce script en tant que root"
    exit 1
fi

# Création des groupes
groupadd asso
groupadd Hogwarts
groupadd managers

# Création des utilisateurs
useradd -m -g asso -G Hogwarts turban
useradd -m -g managers -G Hogwarts dumbledore

# Définition des mots de passe
echo "Définissez le mot de passe pour turban:"
passwd turban
echo "Définissez le mot de passe pour dumbledore:"
passwd dumbledore

# Configuration réseau
cat > /etc/systemd/network/20-wired.network <<EOF
[Match]
Name=enp0s3

[Network]
DHCP=yes
EOF

systemctl restart systemd-networkd
systemctl enable systemd-resolved
systemctl start systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "Configuration finale terminée !"