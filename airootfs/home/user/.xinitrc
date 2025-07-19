#!/bin/sh

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

if [ -f $sysresources ]; then
  xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
  xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
  xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
  xmodmap "$usermodmap"
fi

if [ -d /etc/X11/xinit/xinitrc.d ]; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
  [ -x "$f" ] && . "$f"
 done

 unset f
fi

displays -qsn restore layout || displays -qs fix primary
displays -qs restore colors &
notifications -qs start &
security -qs init locker &
power -qs init screensaver &
system -qs check updates &
cloud -qs mount remotes &
desktop -qs start
