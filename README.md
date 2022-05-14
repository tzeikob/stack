# Stack

Stack is a shell script to bootstrap and automate the process of installing a development environment based on the [archlinux](https://archlinux.org/) distribution. The primary goal is to get as quickly as possible an environment with a development stack ready to use.

## What you should know

### We adopt an opt-in approach

Apart from the mandatory tasks during the installation, the script is implemented in an opt-in/out approach. The user is who decides, upon various options, with what he will go. The script will start iterating across a set of questions, gathering user input and doing tasks in incremental fashion. The tasks are grouped in the following main scopes:

* Disk partitioning
* Base packages
* Hardware drivers
* Host and users
* Desktop and look and feel
* Development Stack
* Utility Applications

### Why a tiling window manager?

Well, we think that a desktop environment handled by a tiling window manager offers the best user experience and is what gives you the boost in productivity and especially to keep the overall visual overhead to the minimum. It might take a while to get used to such an environment but after a short training period the benefits will start paying you back.

### Requirements and limitations

This script is meant to work only with UEFI systems and not with old legacy hardware, we wanted to keep things simple. Another thing you should be aware of is that during the boot time of the installation media the **secure boot** option should be disabled in your BIOS other wise the media wont boot.

## How to use it

### Create the bootable installation media

The first thing to do is to create a bootable media with the latest arclinux iso image file, which can be downloaded from the official [archlinux](https://archlinux.org/download/) page. Below you can find instructions how to create a bootable flash drive medium either in linux or windows.

#### Linux

Get a usb flash drive and plug it to your system, the drive should now be found in the list of available disks ready to be used. By executing the following command you should find the actual device path to that drive.

```sh
sudo fdisk -l
```

> **IMPORTANT**, always double check the device path corresponds to the correct usb drive otherwise you're taking the risk of wiping out data from other functional disks of your system.

Now assuming the device path to the usb drive is **/dev/sdx**, where in your case *x* should be any letter (*a*, *b*, *c*, etc.). Use the gdisk tool to clean the drive from existing partitions (*o* and then *w*), create a new clean linux partition (*n*, accept defaults and then *w*) and format it as **FAT32** with the following command:

```sh
sudo mkfs.fat -F 32 /dev/sdx1
```

> Where **/dev/sdx1** should be the device path to that partition in the **/dev/sdx** disk.

Then just run the following command to copy the files from the archlinux iso file to the drive.

```sh
sudo dd if=path/to/archlinux-version-x86_64.iso \
  of=/dev/sdx \
  bs=4M \
  conv=fsync \
  oflag=direct \
  status=progress
```

This will take a while copying files from the iso file to the bootable media drive.

#### Windows

In windows you can create a bootable installation media using the general purpose [rufus](https://rufus.ie/en) tool.

### Boot with the installation media

Once you are ready with the bootable media plug it to the system you want to apply the installation. Choose to boot with that drive and you will be immediately prompt with the archlinux installation menu. Pick the option *Arch Linux install medium* and wait until you get in the *archiso* as *root*.

> Note that you must disable the *secure boot* option in your BIOS otherwise the installation wont boot.

### Connect to the internet

If your system is using an ethernet cable to connect to the internet then you probably are ready to skip this step.

But in the case your only option is to connect wirelessly via wifi you should use the [iwctl](https://wiki.archlinux.org/title/Iwd) tool. By typing the following command you can check the available network interfaces:

```sh
ip link
```

If your system has a wifi adapter then the corresponding network interface will appear in the list (e.g. *wlan0*), then you can use iwctl to scan and connect to your network, like so:

```sh
iwctl

[iwd] device list
[iwd] station <device> scan
[iwd] station <device> get-networks
[iwd] station <device> connect <SSID>
```

In order to confirm you are actually connected to the internet please try to ping any public server like so:

```sh
ping -c 5 8.8.8.8
```

### Start the installation

To start the execution of the installation use the following command:

```sh
bash -c "$(curl -sLo- https://raw.githubusercontent.com/tzeikob/stack/master/bootstrap.sh)"
```

> In case fonts are tiny especially in 4k monitors, you can increase the size by running `setfont ter-132n`.