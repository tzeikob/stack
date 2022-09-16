#!/bin/sh

xsetroot -cursor_name left_ptr

udiskie --notify-command "ln -s /run/media/$USER $HOME/media/local" &
picom --fade-in-step=1 --fade-out-step=1 --fade-delta=0 &
~/.config/feh/fehbg &
exec bspwm
