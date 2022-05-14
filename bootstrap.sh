#!/usr/bin/env bash

VERSION="0.1.0"

BLANK="^(""|[ *])$"
YES="^([Yy][Ee][Ss]|[Yy])$"

abort () {
  echo -e "\n$1"
  echo -e "Process exiting with code: $2"

  exit $2
}

echo -e "Stack v$VERSION"
echo -e "Starting base installation process"