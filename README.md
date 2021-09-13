# Stak

Stak is an open source tool to speed up and automate the setup and installation process of your development stack on debian and gnome based linux distributions. Some of the feature are:

* System upgrade
* System configuration
* Third-party software installation
* Look and feel configuration

The purpose of this tool is to create development stack environments taking into consideration broadly adopted development standards.

## How to use it

### Run it as a standalone bash script

Just copy, paste and execute the following command in your prompt:

```sh
bash -c  "$(wget -qO- https://git.io/JuSGv)"
```

Otherwise you can download the script file to your local folder, make it executable and run it like so:

```sh
wget https://raw.githubusercontent.com/tzeikob/stak/master/script.sh

chmod +x ./script.sh

./script
```

### Install and run it as Snap application

In case you want to have the tool available in your system, the easiest way is to install it via the Snap store, like so:

```sh
sudo snap install stak --classic
```

There you go, you can execute the stak in the prompt:

```sh
stak
```

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-black.svg)](https://snapcraft.io/stak)