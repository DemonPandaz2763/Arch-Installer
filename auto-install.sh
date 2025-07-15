#!/bin/bash

set -e

echo "=== Arch Linux Automated Install ==="
echo
echo "Listing available drives..."
fdisk -l

# Input for drive
read -rp "Enter the target device (e.g., /dev/sda): " DRIVE

# Input for confirmation
echo "WARNING: ALL data on target \"$DRIVE\" will be wiped"
read -rp "Type 'YES' to continue: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
	echo "Aborted."
	exit 1
fi

# Wipe drive to unallocated
echo "Wiping target $DRIVE"

wipefs --all "$DRIVE"

printf "(echo n; echo; echo; echo; echo +1G; echo t; echo ef; echo n; echo; echo; echo; echo +4G; echo t; echo; echo 82; echo n; echo; echo; echo; echo; echo t; echo; echo 83; echo w;)" | fdisk "$DRIVE"

# Create partitions
echo "Creating partitions on $DRIVE"
mkfs.ext4 $PART3
mkswap $PART2
mmkfs.fat -F 32 $PART1

read -rp "Partitions created. Type 'YES' if it looks right: " CONTINUE

if [[ $CONTINUE != "YES" ]]; then
	echo "Aborted."
	exit 1
fi

# Mount target
mount $PART3 /mnt
mount --mkdir $PART1 /mnt/boot
swapon $PART1

# Install packages
echo
echo "=== Package Installation==="
echo "1. Minimal Env (base, linux, linux-firmware, vim, sudo, networkmanager)"
echo "2. Gnome Env (minimal + gnome)"
echo "3. XFCE Env (minimal + xfce4, xfce4-goodies, lightdm, lightdm-gtk-greeter)"
echo "4. LXDE Env (minimal + lxde + lxdm)"
echo
read -rp "Select an env to install" ENV

case "ENV" in
	1)
		PKGS="base linux linux-firmware vim sudo networkmanager grub efibootmgr"
		;;
	2)
		PKGS="base linux linux-firmware vim sudo networkmanager gnome grub efibootmgr"
		;;
	3)
		PKGS="base linux linux-firmware vim sudo networkmanager xfce4 xfce4-goodies lightdm lightdm-gtk-greeter grub efibootmgr"
		;;
	4)
		PKGS="base linux linux-firmware vim sudo networkmanager lxde lxdm grub efibootmgr"
		;;
	*)
		echo "Invalid choice. Aborting."
		exit 1
		;;
esac

echo "Installing packages..."
pacstrap -K /mnt $PKGS

genfstab -U /mnt >> /mnt/etc/fstab

echo
echo "Filesystem fully setup. Now Configuring."

echo
echo "Adding timezone..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

echo "Configuring locale gen..."
arch-chroot /mnt echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
arch-chroot /mnt locale-gen

echo "Configuring language..."
arch-chroot /mnt echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Configuring hostname..."
echo
read -rp "Choose hostname to add: " HOSTNAME
arch-chroot /mnt echo "$HOSTNAME" > /etc/hostname

echo "Building initramfs..."
arch-chroot /mnt mkinitcpio -P

echo "Configuring users with user:user and root:root"
arch-chroot /mnt printf "root\nroot\n" | passwd root

arch-chroot /mnt useradd -m -g users -G wheel,storage,power -s /bin/bash user
arch-chroot /mnt printf "user\nuser\n" | passwd user

echo "Configuring bootloader..."
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo "Enabling services..."
arch-chroot /mnt systemctl enable fstrim.timer
arch-chroot /mnt systemctl enable NetworkManager

case "ENV" in
	1)
		echo "No display manager needed for minimanl install."
		;;
	2)
		arch-chroot /mnt systemctl enable gdm
		;;
	3)
		arch-chroot /mnt systemctl enable lightdm
		;;
	4)
		arch-chroot /mnt systemctl enable lxdm
		;;
	*)
		echo "Invalid choice. Aborting."
		exit 1
		;;
esac
