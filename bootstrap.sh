#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

export PATH=${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin

mkdir -p ~/.vnc
echo $VNCPASS | vncpasswd -f > ~/.vnc/passwd
chmod 0600 ~/.vnc/passwd

if [ "x${SHARED}" == "xTRUE" ]; then
    export SHARESTRING="-shared"
fi

printf "3\nn\nx\n" | sudo /opt/VirtualGL/bin/vglserver_config

for drm in /dev/dri/card*
do
if /opt/VirtualGL/bin/eglinfo ${drm}; then
    export VGL_DISPLAY=${drm}
    break
fi
done

export TVNC_WM=mate-session

/opt/websockify/run 5901 --web=/opt/noVNC --wrap-mode=ignore -- vncserver :1 -geometry $SIZEW"x"$SIZEH -depth $CDEPTH -vgl &

gsettings set org.gnome.desktop.lockdown disable-lock-screen true
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false

pulseaudio --start

echo "Session Running. Press [Return] to exit."
read
