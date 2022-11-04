#!/usr/bin/env bash

s="device:ase re kourada:ff:f"

s1=$(echo $s | cut -d ":" -f 1)
s2=$(echo $s | cut -d ":" -f 2-)

echo $s
echo $s1
echo $s2
