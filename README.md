# Stack

Stack is an installation script to bootstrap and automate the process of setting up a development stack environment on the [archlinux](https://archlinux.org/) distribution.

## A quick overview

Stack is implemented in an opt-in/out approach where the user is who decides with what option he will go. The process will start by asking the user information about the system, after that the process will start executing various tasks in *no confirm* mode. These tasks are grouped in the following main scopes:

* Disk partitioning
* Bootstrap base system
* Configuration and drivers
* Desktop environment
* Stack applications

## Install a new system

### Partition installation media

Get a usb flash drive and plug it to your system, then execute the following command to find the actual device path to that drive.

```sh
sudo fdisk -l
```

> **IMPORTANT** is to always double check the device path to usb drive otherwise you're taking the risk of wiping out data from other functional disks of your system.

Now assuming the device path to the usb drive is **/dev/sdx**, where in your case *x* should be any letter (a, b, c, etc.). Use the gdisk tool to clean the drive from existing partitions (*o* and then *w*), create a new clean linux partition (*n*, accept defaults and then *w*) and format it as **FAT32**, like so:

```sh
sudo mkfs.fat -F 32 /dev/sdx1
```

> Where **/dev/sdx1** should be the device path to that partition in the **/dev/sdx** disk.

### Flush archlinux installation files

Download the latest [archiso](https://archlinux.org/download/) image file and run the following command to copy the files from the archlinux iso image file to the usb drive.

```sh
sudo dd if=path/to/archlinux-version-x86_64.iso \
  of=/dev/sdx \
  bs=4M \
  conv=fsync \
  oflag=direct \
  status=progress
```

### Boot with the installation media

Once you are ready with the installation media plug it to your system and choose to boot with that drive. In the archiso installation menu pick the option *Arch Linux install medium* and wait until you get logged as root user.

> **NOTE** that in UEFI systems you must disable the *secure boot* option in BIOS, otherwise the installation wont boot. After the installation you can enable it back again.

### Configure keyboard and fonts

In high-dpi screens you can increase the font size by running `setfont ter-132n`. For those who have a non-us keyboard you can set the key map that corresponds to yours keyboard layout by executing `loadkeys <key_map>`. You can list all the available key maps with the following command `ls /usr/share/kbd/keymaps/**/*.map.gz`.

### Connect to the internet

If your system is using an ethernet cable to connect to the internet then you probably are ready to skip this step, but in the case your only option is to connect via wifi you should use the [iwctl](https://wiki.archlinux.org/title/Iwd) tool. By typing the following command you can check the available network interfaces:

```sh
ip link
```

If your system has a wifi adapter then the corresponding network *device* will appear in the list (e.g. *wlan0*), then you can use iwctl to scan and connect to your network, like so:

```sh
iwctl

[iwd] device list
[iwd] station <device> scan
[iwd] station <device> get-networks
[iwd] station <device> connect <SSID>
```

### Download stack installation files

To download the stack installation files use git to clone them like so:

```sh
pacman -S git
git clone git@github.com:tzeikob/stack.git
```

### Start the installation

Finally you can start the installation with the following command:

```sh
./stack/install.sh
```