#!/bin/bash -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

sudo chown user:user /home/user
echo "user:$PASSWD" | sudo chpasswd
sudo rm -rf /tmp/.X*
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone > /dev/null
export PATH="${PATH}:/opt/VirtualGL/bin"

sudo /etc/init.d/dbus start
source /opt/gstreamer/gst-env

export DISPLAY=":0"
Xvfb -screen "${DISPLAY}" "8192x4096x${CDEPTH}" -dpi "${DPI}" +extension "RANDR" +extension "RENDER" +extension "GLX" +extension "MIT-SHM" -nolisten "tcp" -noreset -shmem &

# Wait for X11 to start
echo "Waiting for X socket"
until [ -S "/tmp/.X11-unix/X${DISPLAY/:/}" ]; do sleep 1; done
echo "X socket is ready"

selkies-gstreamer-resize "${SIZEW}x${SIZEH}"

if [ "$NOVNC_ENABLE" = "true" ]; then
  sudo x11vnc -display "${DISPLAY}" -passwd "${BASIC_AUTH_PASSWORD:-$PASSWD}" -shared -forever -repeat -xkb -xrandr "resize" -rfbport 5900 &
  /opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 8080 --heartbeat 10 &
fi

# Add custom processes below this section or within `supervisord.conf`
if [ -n "$(sudo nvidia-smi --query-gpu=uuid --format=csv | sed -n 2p)" ]; then
  export VGL_DISPLAY="egl"
  export VGL_REFRESHRATE="$REFRESH"
  vglrun +wm mate-session &
else
  mate-session &
fi

echo "Session Running. Press [Return] to exit."
read
