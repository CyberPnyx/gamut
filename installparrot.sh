#!/bin/bash

set -e  # Arrêt du script en cas d'erreur

### VARIABLES ###
DISK="/dev/sda"
PART_ROOT="25G"
PART_HOME="5G"
PART_BOOT="500M"
PART_SWAP="500M"

echo "Début de l'installation automatique de Parrot OS..."

### INSTALLATION DES DEPENDANCES ###
echo "Installation des paquets nécessaires..."
apt update && apt install -y parted debootstrap sudo openssh-server vim bash-completion locales

### VERIFICATION DES DROITS ROOT ###
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root ! Utilisez sudo."
  exit 1
fi

### PARTITIONNEMENT ###
echo "Partitionnement du disque..."
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary ext4 1MiB $PART_BOOT
parted -s $DISK mkpart primary linux-swap $PART_BOOT $(($PART_BOOT + $PART_SWAP))
parted -s $DISK mkpart primary ext4 $(($PART_BOOT + $PART_SWAP)) $(($PART_BOOT + $PART_SWAP + $PART_ROOT))
parted -s $DISK mkpart primary ext4 $(($PART_BOOT + $PART_SWAP + $PART_ROOT)) 100%

mkfs.ext4 ${DISK}3  # Root
mkfs.ext4 ${DISK}4  # Home
mkfs.vfat -F32 ${DISK}1  # Boot
mkswap ${DISK}2  # Swap
swapon ${DISK}2

### MONTAGE DES PARTITIONS ###
echo "Montage des partitions..."
mount ${DISK}3 /mnt || { echo "Erreur de montage de /mnt"; exit 1; }
mkdir -p /mnt/{boot,home}
mount ${DISK}1 /mnt/boot || { echo "Erreur de montage de /mnt/boot"; exit 1; }
mount ${DISK}4 /mnt/home || { echo "Erreur de montage de /mnt/home"; exit 1; }

### INSTALLATION DU SYSTEME ###
echo "Installation du système..."
debootstrap stable /mnt https://deb.parrot.sh/parrot/ || { echo "Erreur lors de debootstrap"; exit 1; }

### CONFIGURATION DU SYSTEME ###
echo "Configuration du système..."
echo "parrot" > /mnt/etc/hostname
echo "127.0.1.1 parrot" >> /mnt/etc/hosts

cat <<EOF > /mnt/etc/fstab
UUID=$(blkid -s UUID -o value ${DISK}3) / ext4 defaults 0 1
UUID=$(blkid -s UUID -o value ${DISK}4) /home ext4 defaults 0 2
UUID=$(blkid -s UUID -o value ${DISK}1) /boot vfat defaults 0 2
UUID=$(blkid -s UUID -o value ${DISK}2) none swap sw 0 0
EOF

### CHROOT DANS LE NOUVEAU SYSTEME ###
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc
chroot /mnt /bin/bash <<EOF

# Mise à jour et installation de paquets
apt update && apt upgrade -y

# Configuration locale
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Création des utilisateurs et groupes
useradd -m -G poche,Hogwarts -s /bin/bash pierre
useradd -m -G miaou,Hogwarts -s /bin/bash dinosaur
useradd -m -G wand,Hogwarts -s /bin/bash lee
useradd -m -G poche,Hogwarts -s /bin/bash "fred&george"

# Autorisations sudo
echo 'pierre ALL=(dinosaur) ALL' >> /etc/sudoers
echo 'dinosaur ALL=(pierre) ALL' >> /etc/sudoers

# Configuration SSH
echo "Port 42" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl enable ssh

EOF

### FINALISATION ###
echo "Installation terminée ! Vous pouvez redémarrer la machine."
umount -R /mnt || echo "Échec du démontage de /mnt"
reboot