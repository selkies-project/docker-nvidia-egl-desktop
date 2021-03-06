#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

export PATH="${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin"

echo "user:$VNCPASS" | sudo chpasswd

mkdir -p ~/.vnc
echo "$VNCPASS" | /opt/TurboVNC/bin/vncpasswd -f >~/.vnc/passwd
chmod 0600 ~/.vnc/passwd

if [ "x$SHARED" == "xTRUE" ]; then
  export SHARESTRING="-alwaysshared"
fi

printf "3\nn\nx\n" | sudo /opt/VirtualGL/bin/vglserver_config

for DRM in /dev/dri/card*; do
  if /opt/VirtualGL/bin/eglinfo "$DRM"; then
    export VGL_DISPLAY="$DRM"
    break
  fi
done

export TVNC_WM=mate-session

/opt/TurboVNC/bin/vncserver :0 -geometry "${SIZEW}x${SIZEH}" -depth "$CDEPTH" -vgl -noreset "$SHARESTRING" &

/opt/noVNC/utils/launch.sh --vnc localhost:5900 --listen 5901 &

# Comment this out in Ubuntu 18.04
pulseaudio --start

echo "Session Running. Press [Return] to exit."
read
