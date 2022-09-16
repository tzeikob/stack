#!/bin/sh

picom --fade-in-step=1 --fade-out-step=1 --fade-delta=0 &
~/.config/feh/fehbg &
exec bspwm
