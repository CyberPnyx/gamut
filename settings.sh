#!/bin/bash

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc --utc
echo -e "\e[33;1mRemove the \"#\" of the \"en_US.UTF-8\" line\e[0m"
sleep 10
vim /etc/locale.gen
locale-gen
echo "KEYMAP=fr" > /etc/vconsole.conf
export KEYMAP=fr
echo "Archlinux" > /etc/hostname
mkinitcpio -P
echo -e "\e[33;1mSet the root password\e[0m"
passwd
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Groups and Users
groupadd asso
groupadd managers
groupadd Hogwarts
useradd -m -G asso,Hogwarts -s /bin/bash turban
useradd -m -G managers,Hogwarts -s /bin/bash dumbledore
echo -e "\e[33;1mSet the password for \"turban\"\e[0m"
passwd turban
echo -e "\e[33;1mSet the password for \"dumbledore\"\e[0m"
passwd dumbledore
echo -e "\e[33;1mGrant sudo access to \"dumbledore\"\e[0m"
echo "dumbledore ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# Mount Parrot OS Home Partition
echo -e "\e[33;1mAdd Parrot OS home partition to fstab\e[0m"
echo "UUID=parrot_home_partition_UUID /mnt/parrot_home ext4 defaults 0 2" >> /etc/fstab
mkdir /mnt/parrot_home
mount -a

# SSH Server
echo -e "\e[33;1mConfiguring SSH server\e[0m"
sed -i 's/#Port 22/Port 42/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
echo "AllowUsers turban dumbledore" >> /etc/ssh/sshd_config
systemctl enable sshd
systemctl start sshd

# Enable necessary services
systemctl enable NetworkManager
systemctl enable sddm

echo -e "\e[34;1mSettings finished\e[0m"
echo -e "\e[34;1mPlease execute \"exit\", then \"umount -R /mnt\" and \"shutdown now\"\e[0m"
