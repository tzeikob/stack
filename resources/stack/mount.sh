#!/usr/bin/env bash

source ~/.config/stack/utils.sh

MOUNT_HOME="$HOME/mount"

mount_local_disk () {
  require "udisks2"

  lsblk
  askme "Enter the device name: "
  local DEVICE="$REPLY"

  if grep -qs "$DEVICE " /proc/mounts; then
    echo "Found existing device with name $DEVICE"
    askme "Do you want to unmount it?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      sync &&
      udisksctl unmount -b "/dev/$DEVICE"

      if [[ "$?" -eq 0 ]]; then
        echo "Device $DEVICE unmounted successfully"
        echo "Powering device off..."

        udisksctl power-off -b "/dev/$DEVICE"
      else
        echo "Failed to umount device $DEVICE"
      fi
    fi
  else
    udisksctl mount -b "/dev/$DEVICE" &&
      echo "Device $DEVICE mounted successfully" ||
      echo "Failed to mount device $DEVICE"

    if [ -d "/run/media/$USER" ] && [ ! -L "$MOUNT_HOME/local" ]; then
      ln -s "/run/media/$USER" "$MOUNT_HOME/local"
    fi
  fi
}

mount_network_disk () {
  require "glib2"

  askme "Enter the connection protocol:" "smb" "nfs"
  local PROTOCOL="$REPLY"

  askme "Enter the host name:"
  local HOST="$REPLY"

  askme "Enter the shared folder:"
  local SHARED_FOLDER="$REPLY"

  local DEVICE="$PROTOCOL://$HOST/$SHARED_FOLDER"

  if gio mount -l | grep -q "$DEVICE"; then
    echo "Found existing network disk with name $DEVICE"
    askme "Do you want to unmount it?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      sync &&
      gio mount -u "$DEVICE" &&
        echo "Device $DEVICE unmounted successfully" ||
        echo "Failed to umount device $DEVICE"
    fi
  else
    gio mount "$DEVICE" &&
      echo "Device $DEVICE mounted successfully" ||
      echo "Failed to mount device from $DEVICE"

    if [ -d "/run/user/${UID}/gvfs" ] && [ ! -L "$MOUNT_HOME/nas" ]; then
      ln -s "/run/user/${UID}/gvfs" "$MOUNT_HOME/nas"
    fi
  fi
}

unmount_remote () {
  require "rclone" "fuse"

  local REMOTE_NAME=$1

  echo "Unmounting remote $REMOTE_NAME..."

  local MOUNT_POINTS=($(grep -E "$REMOTE_NAME:.* fuse.rclone" /proc/mounts | awk '{print $2}'))

  for MOUNT_POINT in ${MOUNT_POINTS[@]}; do
    fusermount -uz "$MOUNT_POINT"

    if [[ "$?" -eq 0 ]]; then
      find "$MOUNT_POINT" -maxdepth 0 -empty -exec rm -rf {} \;
      echo "Local folder $MOUNT_POINT has been unmounted"
    else
      echo "Failed to unmount $MOUNT_POINT, make sure folder isn't busy"
    fi
  done

  rclone config delete "$REMOTE_NAME" &&
    echo "Remote $REMOTE_NAME deleted successfully" ||
    echo "Failed to delete remote $REMOTE_NAME"
}

mount_remote () {
  require "rclone"

  local STORAGE=$1

  askme "Enter the name of the remote:"
  local REMOTE_NAME="$REPLY"

  if rclone listremotes | grep -qw "$REMOTE_NAME:"; then
    echo "Found existing remote with name $REMOTE_NAME"
    askme "Do you want to unmount it?" "yes" "no"

    [ "$REPLY" = "yes" ] && unmount_remote "$REMOTE_NAME"
  else
    askme "Enter the client ID:"
    local CLIENT_ID="$REPLY"

    askme "Enter the client secret:"
    local CLIENT_SECRET="$REPLY"

    if [ "$STORAGE" = "drive" ]; then
      askme "Enter the root folder ID:"
      local ROOT_FOLDER="$REPLY"
    fi

    local MOUNT_FOLDER="$MOUNT_HOME/$REMOTE_NAME"

    rclone config create "$REMOTE_NAME" "$STORAGE" client_id="$CLIENT_ID" client_secret="$CLIENT_SECRET" \
      $([ "$STORAGE" = "drive" ] && echo "root_folder_id="$ROOT_FOLDER" scope=drive") &&
    mkdir -p "$MOUNT_FOLDER" &&
    rclone mount "$REMOTE_NAME:" "$MOUNT_FOLDER" \
      --umask=002 --gid=$(id -g) --uid=$(id -u) --timeout=1h \
      --poll-interval=15s --dir-cache-time=1000h --vfs-cache-mode=full \
      --vfs-cache-max-size=150G --vfs-cache-max-age=12h --daemon &&
      echo "Remote $REMOTE_NAME mounted successfully"

    if [[ ! "$?" -eq 0 ]]; then
      echo "Failed to mount remote $REMOTE_NAME"

      rclone config delete "$REMOTE_NAME"
      find "$MOUNT_FOLDER" -maxdepth 0 -empty -exec rm -rf {} \;
    fi
  fi
}

askme "Which type of storage to mount?" "local" "nas" "cloud"

if [ "$REPLY" = "local" ]; then
  mount_local_disk
elif [ "$REPLY" = "nas" ]; then
  mount_network_disk
elif [ "$REPLY" = "cloud" ]; then
  askme "Which storage provider to sync with?" "drive" "dropbox"

  mount_remote "$REPLY"
fi