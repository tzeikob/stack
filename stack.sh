#!/usr/bin/env bash

shopt -s nocasematch

kernels=${1:-"all"}
country=${2:-"germany"}

echo -e "Starting the stack installation process..."

echo -e "\nSetting keyboard layout..."

read -p "Enter the key map of your keyboard: [us] " keymap
keymap=${keymap:-"us"}

keymap_path=$(find /usr/share/kbd/keymaps/ -type f -name "$keymap.map.gz")

while [ -z "$keymap_path" ]; do
  echo -e "Invalid key map: '$keymap'"
  read -p "Please enter a valid keymap: [us] " keymap
  keymap=${keymap:-"us"}

  keymap_path=$(find /usr/share/kbd/keymaps/ -type f -name "$keymap.map.gz")
done

echo "KEYMAP=$keymap" > /etc/vconsole.conf
loadkeys $keymap

echo -e "Keyboard layout has been set to '$keymap'"

echo -e "\nSetting up the local timezone..."

resolved_timezone=$(curl -sLo- https://ipapi.co/timezone?format=json)
read -p "What is your current timezone? [$resolved_timezone]: " timezone
timezone=${timezone:-$resolved_timezone}

while [ ! -f "/usr/share/zoneinfo/$timezone" ]; do
  echo -e "Invalid timezone: '$timezone'"
  read -p "Please enter a valid timezone: [$resolved_timezone] " timezone
  timezone=${timezone:-$resolved_timezone}
done

ln -sf /usr/share/zoneinfo/$timezone /etc/localtime

echo -e "Local timezone has been set to '$timezone'"

echo -e "\nEnabling NTP synchronization..."

timedatectl set-ntp true
timedatectl status

hwclock --systohc

echo -e "System clock synchronized to the hardware clock"

echo -e "\nSetting up system locales..."

read -p "Enter locales separated by spaces (e.g. en_US el_GR): [en_US] " locales
locales=${locales:-"en_US"}

for locale in $locales; do
  while [ -z "$locale" ] || ! grep -q "$locale" /etc/locale.gen; do
    echo -e "Invalid locale name: '$locale'"
    read -p "Re-enter the locale: " locale
  done

  sed -i "s/#\($locale.*\)/\1/" /etc/locale.gen
  echo -e "Locale '$locale' added for generation"
done

locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

echo -e "Locales have been genereated successfully"

echo -e "\nSetting up hostname and hosts..."

read -p "Enter the host name of your system: [arch] " hostname
hostname=${hostname:-"arch"}

echo $hostname >> /etc/hostname

echo "" >> /etc/hosts
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $hostname" >> /etc/hosts

echo -e "Hostname and hosts have been set to '$hostname'"

echo -e "\nSetting up users and passwords..."

echo -e "Adding password for the root user..."

passwd

echo -e "Creating the new sudoer user..."

read -p "Enter the name of the sudoer user: [bob] " username
username=${username:-"bob"}

useradd -m -G wheel $username

echo -e "Adding password for the user '$username'..."

passwd $username

echo -e "Adding user '$username' to the group of sudoers..."

sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo -e "User '$username' has now sudo priviledges"

echo -e "\nSetting up the swap file..."

read -p "Enter the size of the swap file in GB (0 to skip): [0] " swapsize
swapsize=${swapsize:-0}

while [[ ! $swapsize =~ ^[0-9]+$ ]]; do
  echo -e "Invalid swap file size: '$swapsize'"
  read -p "Please enter a valid size in GB (0 to skip): [0] " swapsize
  swapsize=${swapsize:-0}
done

if [[ $swapsize -gt 0 ]]; then
  echo -e "Swap file size set to '${swapsize}GB'"

  echo -e "Creating the swap file..."

  dd if=/dev/zero of=/swapfile bs=1M count=$(expr $swapsize \* 1024) status=progress
  chmod 0600 /swapfile
  mkswap -U clear /swapfile

  echo -e "Enabling swap..."

  swapon /swapfile && free -m

  cp /etc/fstab /etc/fstab.bak
  echo "/swapfile none swap defaults 0 0" | tee -a /etc/fstab

  echo -e "Swap file has been set successfully to '/swapfile'"
else
  echo -e "No swap file will be set"
fi

echo -e "\nRefreshing the mirror list from servers in '$country'..."

reflector --country $country --age 8 --sort age --save /etc/pacman.d/mirrorlist
pacman -Syy

echo -e "The mirror list is now up to date"

sed -i "s/# --country.*/--country $country/" /etc/xdg/reflector/reflector.conf

echo -e "Reflector mirror country set to '$country'"

echo -e "\nInstalling extra base packages..."

pacman -S base-devel pacman-contrib grub efibootmgr mtools dosfstools gdisk parted \
  bash-completion man-db man-pages texinfo \
  cups bluez bluez-utils \
  terminus-font vim nano git htop tree arch-audit

echo -e "\nInstalling power management utilities..."

pacman -S acpi acpid acpi_call

echo -e "\nInstalling network utility packages..."

pacman -S networkmanager dialog wireless_tools netctl inetutils dnsutils \
  wpa_supplicant openssh nfs-utils openbsd-netcat nftables iptables-nft ipset

echo -e "\nInstalling audio drivers and packages..."

pacman -S alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack

echo -e "\nInstalling cpu drivers..."

read -p "What proccessor is your system running on? [AMD/intel] " cpu_vendor
cpu_vendor=${cpu_vendor:-"amd"}

while [[ ! $cpu_vendor =~ ^(amd|intel)$ ]]; do
  echo -e "Invalid cpu vendor: '$cpu_vendor'"
  read -p "Please enter a valid cpu vendor: [AMD/intel] " cpu_vendor
  cpu_vendor=${cpu_vendor:-"amd"}
done

if [[ $cpu_vendor =~ ^intel$ ]]; then
  cpu_vendor="intel"
  cpu_pkg="intel-ucode"
else
  cpu_vendor="amd"
  cpu_pkg="amd-ucode"
fi

echo -e "CPU vendor set to '$cpu_vendor'"

pacman -S $cpu_pkg

echo -e "CPU packages have been installed"

echo -e "\nInstalling gpu drivers..."

read -p "What video card is your system using? [NVIDIA/amd/intel/virtual] " gpu_vendor
gpu_vendor=${gpu_vendor:-"nvidia"}

while [[ ! $gpu_vendor =~ ^(nvidia|amd|intel|virtual)$ ]]; do
  echo -e "Invalid gpu vendor: '$gpu_vendor'"
  read -p "Please enter a valid gpu vendor: [NVIDIA/amd/intel/virtual] " gpu_vendor
  gpu_vendor=${gpu_vendor:-"nvidia"}
done

if [[ $gpu_vendor =~ ^amd$ ]]; then
  gpu_vendor="amd"
  gpu_pkg="xf86-video-ati" # or try messa
  gpu_module="amdgpu"
elif [[ $gpu_vendor =~ ^intel$ ]]; then
  gpu_vendor="intel"
  gpu_pkg="xf86-video-intel" # or try mesa
  gpu_module="i915"
elif [[ $gpu_vendor =~ ^virtual$ ]]; then
  gpu_vendor="virtual"
  gpu_pkg="xf86-video-vmware virtualbox-guest-utils"
  gpu_module=""
else
  gpu_vendor="nvidia"

  if [[ $kernels =~ ^stable$ ]]; then
    gpu_pkg="nvidia"
  elif [[ $kernels =~ ^lts$ ]]; then
    gpu_pkg="nvidia-lts"
  else
    gpu_pkg="nvidia nvidia-lts"
  fi

  gpu_pkg="$gpu_pkg nvidia-utils nvidia-settings"
  gpu_module="nvidia"
fi

if [ ! -z "$gpu_pkg" ]; then
  echo -e "GPU vendor set to '$gpu_vendor'"

  pacman -S $gpu_pkg

  echo -e "GPU packages have been installed"
else
  echo -e "No gpu packages will be installed"
fi

if [ ! -z "$gpu_module" ]; then
  echo -e "\nRe-generating initramfs for the '$gpu_vendor' gpu modules..."

  sed -i "s/MODULES=(\(.*\))$/MODULES=(\1 $gpu_module)/" /etc/mkinitcpio.conf
  sed -i "s/MODULES=( \(.*\))$/MODULES=(\1)/" /etc/mkinitcpio.conf

  mkinitcpio -P

  echo -e "Images have been re-genereated successfully"
fi

echo -e "\nInstalling the bootloader via GRUB..."

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub
sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub
sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

if [[ $gpu_vendor =~ ^virtual$ ]]; then
  mkdir -p /boot/EFI/BOOT
  cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI
fi

echo -e "Bootloader has been installed"

echo -e "\nHardening system's security..."

sed -i 's;# dir = /var/run/faillock;dir = /var/lib/faillock;' /etc/security/faillock.conf

echo -e "Faillocks set to be persistent after system reboot"

sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

echo -e "Disable permission for SSH with the root user"

echo -e "Setting up a simple stateful firewall..."

nft flush ruleset
nft add table inet my_table
nft add chain inet my_table my_input '{ type filter hook input priority 0 ; policy drop ; }'
nft add chain inet my_table my_forward '{ type filter hook forward priority 0 ; policy drop ; }'
nft add chain inet my_table my_output '{ type filter hook output priority 0 ; policy accept ; }'
nft add chain inet my_table my_tcp_chain
nft add chain inet my_table my_udp_chain
nft add rule inet my_table my_input ct state related,established accept
nft add rule inet my_table my_input iif lo accept
nft add rule inet my_table my_input ct state invalid drop
nft add rule inet my_table my_input meta l4proto ipv6-icmp accept
nft add rule inet my_table my_input meta l4proto icmp accept
nft add rule inet my_table my_input ip protocol igmp accept
nft add rule inet my_table my_input meta l4proto udp ct state new jump my_udp_chain
nft add rule inet my_table my_input 'meta l4proto tcp tcp flags & (fin|syn|rst|ack) == syn ct state new jump my_tcp_chain'
nft add rule inet my_table my_input meta l4proto udp reject
nft add rule inet my_table my_input meta l4proto tcp reject with tcp reset
nft add rule inet my_table my_input counter reject with icmpx port-unreachable

mv /etc/nftables.conf /etc/nftables.conf.bak
nft -s list ruleset > /etc/nftables.conf

echo -e "Firewall ruleset has been saved to '/etc/nftables.conf'"

echo -e "Security configuration has been completed"

echo -e "\nEnabling system services..."

systemctl enable systemd-timesyncd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable acpid
systemctl enable cups
systemctl enable sshd
systemctl enable fstrim.timer
systemctl enable nftables
systemctl enable reflector.timer
systemctl enable paccache.timer

if [[ $gpu_vendor =~ ^virtual$ ]]; then
  systemctl enable vboxservice
fi

echo -e "\nThe stack script has been completed"
echo -e "Exiting the stack installation script..."