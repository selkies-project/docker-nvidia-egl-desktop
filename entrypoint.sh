#!/bin/bash -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

sudo chown user:user /home/user
echo "user:$PASSWD" | sudo chpasswd
sudo rm -rf /tmp/.X*
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone > /dev/null
export PATH="${PATH}:/opt/VirtualGL/bin"
export LD_LIBRARY_PATH="/usr/lib/libreoffice/program:${LD_LIBRARY_PATH}"

sudo /etc/init.d/dbus start
source /opt/gstreamer/gst-env

export DISPLAY=":0"
export __GL_SYNC_TO_VBLANK="0"
export __NV_PRIME_RENDER_OFFLOAD="1"
Xvfb "${DISPLAY}" -ac -screen "0" "8192x4096x${CDEPTH}" -dpi "${DPI}" +extension "RANDR" +extension "GLX" +iglx +extension "MIT-SHM" +render -nolisten "tcp" -noreset -shmem &

# Wait for X11 to start
echo "Waiting for X socket"
until [ -S "/tmp/.X11-unix/X${DISPLAY/:/}" ]; do sleep 1; done
echo "X socket is ready"

selkies-gstreamer-resize "${SIZEW}x${SIZEH}"

if [ "${NOVNC_ENABLE,,}" = "true" ]; then
  if [ -n "$NOVNC_VIEWPASS" ]; then export NOVNC_VIEWONLY="-viewpasswd ${NOVNC_VIEWPASS}"; else unset NOVNC_VIEWONLY; fi
  x11vnc -display "${DISPLAY}" -passwd "${BASIC_AUTH_PASSWORD:-$PASSWD}" -shared -forever -repeat -xkb -snapfb -threads -xrandr "resize" -rfbport 5900 ${NOVNC_VIEWONLY} &
  /opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 8080 --heartbeat 10 &
fi

# Add custom processes below this section, or within `supervisord.conf` to perform service management like systemd
if [ -n "$(nvidia-smi --query-gpu=uuid --format=csv | sed -n 2p)" ]; then
  export VGL_DISPLAY="${VGL_DISPLAY:-egl}"
  export VGL_REFRESHRATE="$REFRESH"
  vglrun +wm xfce4-session &
else
  xfce4-session &
fi

# Fix selkies-gstreamer keyboard mapping
if [ "${NOVNC_ENABLE,,}" != "true" ]; then
  sudo xmodmap -e "keycode 94 shift = less less"
fi

echo "Session Running. Press [Return] to exit."
read
