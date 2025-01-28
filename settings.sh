#!/bin/bash

#installer le grpahique
pacman -S xorg-server xorg-xinit plasma-desktop sddm konsole dolphin firefox emacs grub

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc --utc
echo -e "\e[33;1mRemove the \"#\" of the \"en_US.UTF-8\" line\e[0m"
sleep 10
emacs /etc/locale.gen
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
