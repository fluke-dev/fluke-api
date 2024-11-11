#!/bin/bash

# ตรวจสอบว่าเป็น root หรือไม่
if [ "$(id -u)" -ne 0 ]; then
  echo "กรุณารันสคริปต์นี้ด้วยสิทธิ์ root"
  exit 1
fi

# เปิด cfdisk เพื่อให้ผู้ใช้แบ่งพาร์ติชันเอง
echo "Launching cfdisk... Please create the following partitions manually:"
echo "- Boot partition (e.g., 1 GB, primary, type Linux, marked as bootable)"
echo "- Swap partition (e.g., 2 GB, primary, type Linux swap)"
echo "- Root partition (remaining space, primary, type Linux)"
cfdisk /dev/vda

# ฟอร์แมตพาร์ติชัน
echo "Formatting partitions..."
mkfs.ext4 /dev/vda1         # ฟอร์แมต boot เป็น ext4
mkswap /dev/vda2            # ฟอร์แมต swap
swapon /dev/vda2            # เปิดใช้งาน swap
mkfs.ext4 /dev/vda3         # ฟอร์แมต root เป็น ext4

# เมาท์พาร์ติชัน
mount /dev/vda3 /mnt
mkdir /mnt/boot
mount /dev/vda1 /mnt/boot

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

# ตั้งค่า hostname
echo "arch-bspwm" > /etc/hostname

# ตั้งค่า hosts file
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   arch-bspwm.localdomain arch-bspwm" >> /etc/hosts

# ตั้งรหัสผ่าน root
echo "Set root password:"
passwd

# ติดตั้ง GRUB สำหรับ BIOS
pacman -S grub --noconfirm
grub-install --target=i386-pc /dev/vda
grub-mkconfig -o /boot/grub/grub.cfg

# สร้าง user ใหม่
useradd -m -G wheel -s /bin/bash user
echo "Set password for user:"
passwd user

# อนุญาตให้กลุ่ม wheel ใช้ sudo
pacman -S sudo --noconfirm
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

# ติดตั้ง bspwm, sxhkd, และเครื่องมืออื่นๆ
arch-chroot /mnt /bin/bash <<EOF

# ติดตั้ง bspwm, sxhkd, และอื่นๆ
pacman -S bspwm sxhkd polybar dmenu picom st xorg-server xorg-xinit --noconfirm

# สร้างไฟล์ config สำหรับ bspwm และ sxhkd
mkdir -p /home/user/.config/bspwm
mkdir -p /home/user/.config/sxhkd
cp /usr/share/doc/bspwm/examples/bspwmrc /home/user/.config/bspwm/bspwmrc
cp /usr/share/doc/bspwm/examples/sxhkdrc /home/user/.config/sxhkd/sxhkdrc
chmod +x /home/user/.config/bspwm/bspwmrc

# ตั้งค่า dmenu
echo 'super + d' >> /home/user/.config/sxhkd/sxhkdrc
echo '    dmenu_run' >> /home/user/.config/sxhkd/sxhkdrc

# เปลี่ยนเจ้าของไฟล์ทั้งหมดเป็น user
chown -R user:user /home/user/.config

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

EOF

echo "Installation complete! You can now reboot."