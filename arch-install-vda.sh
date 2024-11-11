#!/bin/bash

# ตรวจสอบว่าเป็น root หรือไม่
if [ "$(id -u)" -ne 0 ]; then
  echo "กรุณารันสคริปต์นี้ด้วยสิทธิ์ root"
  exit 1
fi

# ตั้งค่าพาร์ติชัน (sda1 สำหรับ boot, sda2 สำหรับ swap, sda3 สำหรับ root)
echo "Creating partitions..."
(
  echo o       # สร้าง MBR ใหม่
  echo n       # สร้างพาร์ติชันใหม่
  echo p       # Primary partition
  echo 1       # พาร์ติชันที่ 1 สำหรับ boot
  echo         # ค่าเริ่มต้นสำหรับ first sector
  echo +1G     # ขนาด 1GB สำหรับ boot

  echo n       # สร้างพาร์ติชันใหม่
  echo p       # Primary partition
  echo 2       # พาร์ติชันที่ 2 สำหรับ swap
  echo         # ค่าเริ่มต้นสำหรับ first sector
  echo +2G     # ขนาด 2GB สำหรับ swap

  echo n       # สร้างพาร์ติชันใหม่
  echo p       # Primary partition
  echo 3       # พาร์ติชันที่ 3 สำหรับ root
  echo         # ค่าเริ่มต้นสำหรับ first sector
  echo         # ใช้พื้นที่ที่เหลือทั้งหมด (17GB)

  echo a       # ทำให้พาร์ติชันที่ 1 bootable
  echo 1       # กำหนดพาร์ติชัน bootable เป็น sda1

  echo w       # เขียนการตั้งค่า
) | fdisk /dev/vda

# ฟอร์แมตพาร์ติชัน
mkfs.ext4 /dev/vda1        # ฟอร์แมต boot เป็น ext4
mkfs.ext4 /dev/vda3        # ฟอร์แมต root เป็น ext4
mkswap /dev/vda2           # ฟอร์แมต swap
swapon /dev/vda2           # เปิดใช้งาน swap

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

# ติดตั้งและตั้งค่า polybar, picom
echo 'sxhkd &' >> /home/user/.config/bspwm/bspwmrc
echo 'picom &' >> /home/user/.config/bspwm/bspwmrc
echo 'polybar mybar &' >> /home/user/.config/bspwm/bspwmrc
echo 'exec bspwm' > /home/user/.xinitrc

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

# ติดตั้ง Alacritty, PulseAudio และ font
arch-chroot /mnt /bin/bash <<EOF

# ติดตั้งแพ็กเกจพื้นฐานอื่นๆ
pacman -S alacritty git curl noto-fonts noto-fonts-cjk noto-fonts-emoji --noconfirm

# ติดตั้ง PulseAudio สำหรับจัดการเสียง
pacman -S pulseaudio pulseaudio-alsa pavucontrol --noconfirm

# เพิ่มการตั้งค่าเรียกใช้ Alacritty, PulseAudio และโปรแกรมพื้นฐาน
echo 'alacritty &' >> /home/user/.config/bspwm/bspwmrc
echo 'pavucontrol &' >> /home/user/.config/bspwm/bspwmrc
echo 'exec bspwm' >> /home/user/.xinitrc

chown -R user:user /home/user/.config

EOF

echo "Installation complete! You can now reboot."