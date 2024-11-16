#!/bin/bash

# ตรวจสอบว่าเป็น root หรือไม่
if [ "$(id -u)" -ne 0 ]; then
  echo "กรุณารันสคริปต์นี้ด้วยสิทธิ์ root"
  exit 1
fi

# รับชื่อผู้ใช้จากผู้ใช้
read -p "Enter your desired username: " username

# เปิด cfdisk เพื่อให้ผู้ใช้แบ่งพาร์ติชันเอง
echo "Launching cfdisk... Please create the following partitions manually:"
echo "- Boot partition (e.g., 1 GB, primary, type Linux, marked as bootable)"
echo "- Swap partition (e.g., 2 GB, primary, type Linux swap)"
echo "- Root partition (remaining space, primary, type Linux)"
cfdisk /dev/sda

# ฟอร์แมตพาร์ติชัน
echo "Formatting partitions..."
mkfs.ext4 /dev/sda1         # ฟอร์แมต boot เป็น ext4
mkswap /dev/sda2            # ฟอร์แมต swap
swapon /dev/sda2            # เปิดใช้งาน swap
mkfs.ext4 /dev/sda3         # ฟอร์แมต root เป็น ext4

# เมาท์พาร์ติชัน
mount /dev/sda3 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

# ติดตั้งระบบหลัก
echo "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware

# สร้าง fstab
genfstab -U /mnt >> /mnt/etc/fstab

# ตั้งค่าระบบใน chroot
arch-chroot /mnt /bin/bash <<EOF

# ตั้งค่า timezone
ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime
hwclock --systohc

# ตั้งค่า locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_TIME=th_TH.UTF-8" >> /etc/locale.conf

touch /home/$username/.bashrc

echo "export LANG=en_US.UTF-8
export LC_TIME=th_TH.UTF-8" > /home/$username/.bashrc

# ตั้งค่า hostname
echo "flukedev" > /etc/hostname

# ตั้งค่า hosts file
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   flukedev.localdomain flukedev" >> /etc/hosts

useradd -m -G wheel,storage,video,audio,users,input -s /bin/bash $username

pacman -S grub --noconfirm
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# อนุญาตให้กลุ่ม wheel ใช้ sudo
pacman -S sudo --noconfirm
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

# ติดตั้ง bspwm, sxhkd, และเครื่องมืออื่นๆ
arch-chroot /mnt /bin/bash <<EOF

# ติดตั้ง bspwm, sxhkd, และอื่นๆ
pacman -S polybar dmenu picom nemo alacritty neovim git htop neofetch rofi fish xorg-xauth xorg-server xorg-xinit --noconfirm

# สร้างไฟล์ config สำหรับ bspwm และ sxhkd

mkdir -p /home/$username/.config/picom
mkdir -p /home/$username/.config/polybar

cp /etc/xdg/picom.conf /home/$username/.config/picom/picom.conf
cp /etc/polybar/config.ini /home/$username/.config/polybar/config.ini



# เปลี่ยนเจ้าของไฟล์ทั้งหมดเป็น $username
chown -R $username:$username /home/$username/.config

EOF

# ติดตั้ง ly display manager
arch-chroot /mnt /bin/bash <<EOF

pacman -S ly --noconfirm
systemctl enable ly

EOF

# ติดตั้ง dhcpcd สำหรับการเชื่อมต่อเครือข่าย
arch-chroot /mnt /bin/bash <<EOF

pacman -S dhcpcd --noconfirm
systemctl enable dhcpcd

echo "Congratulations $username"

EOF

echo "Installation complete!"