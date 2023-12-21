#!/bin/sh

# Load locale variables from locale.conf file
. /etc/locale.conf

# Define default LANG to C if not already defined
LANG=${LANG:-C}

# Export locale variables
export LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY \
       LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT \
       LC_IDENTIFICATION

