#!/usr/bin/env bash

local POSTFIX=""
if [[ "$1" =~ ^nvme ]]; then
  echo "This is an NVMe disk"
else
  echo "This is an non-NVMe disk"
fi

echo "Exiting..."
