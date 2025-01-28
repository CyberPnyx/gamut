#!/bin/bash

# Vérification des droits root
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root."
  exit 1
fi

# Variables
DISK="/dev/sda"
EFI_SIZE="500M"
ROOT_SIZE="25G"
HOME_SIZE="5G"
SWAP_SIZE="500M"

# Confirmation
read -p "ATTENTION : Toutes les données sur $DISK seront effacées. Continuer ? (o/N) " confirm
if [[ "$confirm" != "o" ]]; then
  echo "Opération annulée."
  exit 1
fi

# Partitionnement
echo "Création de la table de partitions GPT..."
parted --script $DISK mklabel gpt

# Partition EFI
echo "Création de la partition EFI..."
parted --script $DISK mkpart primary fat32 1MiB $EFI_SIZE
parted --script $DISK set 1 esp on

# Partition SWAP
echo "Création de la partition SWAP..."
parted --script $DISK mkpart primary linux-swap $EFI_SIZE $(($EFI_SIZE + $SWAP_SIZE))

# Partition ROOT
echo "Création de la partition ROOT..."
parted --script $DISK mkpart primary ext4 $(($EFI_SIZE + $SWAP_SIZE)) $(($EFI_SIZE + $SWAP_SIZE + $ROOT_SIZE))

# Partition HOME
echo "Création de la partition HOME..."
parted --script $DISK mkpart primary ext4 $(($EFI_SIZE + $SWAP_SIZE + $ROOT_SIZE)) 100%

# Formater les partitions
echo "Formatage des partitions..."
mkfs.fat -F32 ${DISK}1  # EFI
mkswap ${DISK}2          # SWAP
mkfs.ext4 ${DISK}3       # ROOT
mkfs.ext4 ${DISK}4       # HOME

# Activer SWAP
echo "Activation de la SWAP..."
swapon ${DISK}2

# Monter les partitions
echo "Montage des partitions..."
mount ${DISK}3 /mnt
mkdir -p /mnt/boot
mount ${DISK}1 /mnt/boot
mkdir -p /mnt/home
mount ${DISK}4 /mnt/home

# Installation de base
echo "Installation de Parrot OS..."
debootstrap --arch=amd64 parrot /mnt http://deb.parrot.sh/parrot

# Configuration du système
echo "Configuration du système..."
echo "$HOSTNAME" > /mnt/etc/hostname
cat <<EOF > /mnt/etc/fstab
UUID=$(blkid -s UUID -o value ${DISK}3) / ext4 defaults 0 1
UUID=$(blkid -s UUID -o value ${DISK}1) /boot vfat defaults 0 2
UUID=$(blkid -s UUID -o value ${DISK}4) /home ext4 defaults 0 2
UUID=$(blkid -s UUID -o value ${DISK}2) none swap sw 0 0
EOF

# Chroot pour finaliser l'installation
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt /bin/bash <<EOL
apt update && apt upgrade -y
apt install linux-image-amd64 grub-efi-amd64 -y

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ParrotOS
update-grub
exit
EOL

# Fin
echo "Installation terminée. Vous pouvez redémarrer."
