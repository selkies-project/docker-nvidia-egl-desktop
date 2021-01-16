#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

echo "user:${VNCPASS}" | sudo chpasswd

mkdir -p ~/.vnc
echo $VNCPASS | vncpasswd -f > ~/.vnc/passwd
chmod 0600 ~/.vnc/passwd

if [ "x${SHARED}" == "xTRUE" ]
then
    export SHARESTRING="-shared"
fi

pulseaudio --start

printf "3\nn\nx\n" | sudo /opt/VirtualGL/bin/vglserver_config

for DRM in /dev/dri/card*
do
if /opt/VirtualGL/bin/eglinfo $DRM
then
    export VGL_DISPLAY=$DRM
    break
fi
done

export TVNC_WM=mate-session

/opt/websockify/run 5901 --web=/opt/noVNC --wrap-mode=ignore -- vncserver :1 -geometry $SIZEW"x"$SIZEH -depth $CDEPTH -vgl &

echo "Session Running. Press [Return] to exit."
read
