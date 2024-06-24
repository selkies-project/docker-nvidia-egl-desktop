#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

trap "echo TRAPed signal" HUP INT QUIT TERM

# Create and modify permissions of XDG_RUNTIME_DIR
mkdir -pm700 /tmp/runtime-ubuntu
chown ubuntu:ubuntu /tmp/runtime-ubuntu
chmod 700 /tmp/runtime-ubuntu
# Make user directory owned by the default ubuntu user
chown ubuntu:ubuntu /home/ubuntu || sudo-root chown ubuntu:ubuntu /home/ubuntu || chown ubuntu:ubuntu /home/ubuntu/* || sudo-root chown ubuntu:ubuntu /home/ubuntu/* || echo 'Failed to change user directory permissions, there may be permission issues'
# Change operating system password to environment variable
(echo "$PASSWD"; echo "$PASSWD";) | sudo passwd ubuntu
# Remove directories to make sure the desktop environment starts
rm -rf /tmp/.X* ~/.cache
# Change time zone from environment variable
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | tee /etc/timezone > /dev/null
# Add Lutris directories to path
export PATH="${PATH:+${PATH}:}/usr/local/games:/usr/games"
# Add LibreOffice to library path
export LD_LIBRARY_PATH="/usr/lib/libreoffice/program${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Configure joystick interposer
export SDL_JOYSTICK_DEVICE=/dev/input/js0
mkdir -pm777 /dev/input || sudo-root mkdir -pm777 /dev/input || echo 'Failed to create joystick interposer directory'
touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || sudo-root touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || echo 'Failed to create joystick interposer devices'

# Set default display
export DISPLAY="${DISPLAY:-:0}"
# PipeWire-Pulse server socket location
export PIPEWIRE_LATENCY="32/48000"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

if [ -z "$(ldconfig -p | grep 'libEGL_nvidia.so.0')" ] || [ -z "$(ldconfig -p | grep 'libGLX_nvidia.so.0')" ]; then
  # Install NVIDIA userspace driver components including X graphic libraries, keep contents same as docker-nvidia-glx-desktop
  export NVIDIA_DRIVER_ARCH="$(dpkg --print-architecture | sed -e 's/arm64/aarch64/' -e 's/armhf/32bit-ARM/' -e 's/i.*86/x86/' -e 's/amd64/x86_64/' -e 's/unknown/x86_64/')"
  if [ -z "${NVIDIA_DRIVER_VERSION}" ]; then
    # Driver version is provided by the kernel through the container toolkit, prioritize kernel driver version if available
    if [ -f "/proc/driver/nvidia/version" ]; then
      export NVIDIA_DRIVER_VERSION="$(head -n1 </proc/driver/nvidia/version | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9\.]+/) {print $i; exit}}')"
    # Use NVML version for compatibility with Windows Subsystem for Linux
    elif command -v nvidia-smi >/dev/null 2>&1; then
      export NVIDIA_DRIVER_VERSION="$(nvidia-smi --version | grep 'NVML version' | cut -d: -f2 | tr -d ' ')"
    else
      echo "Failed to find NVIDIA GPU driver version. You might not be using the NVIDIA container toolkit. Exiting."
      exit 1
    fi
  fi
  cd /tmp
  # If version is different, new installer will overwrite the existing components
  if [ ! -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Check multiple sources in order to probe both consumer and datacenter driver versions
    curl -fsSL -O "https://international.download.nvidia.com/XFree86/Linux-${NVIDIA_DRIVER_ARCH}/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || curl -fsSL -O "https://international.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || { echo "Failed NVIDIA GPU driver download. Exiting."; exit 1; }
  fi
  # Extract installer before installing
  sh "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" -x
  cd "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
  # Run NVIDIA driver installation without the kernel modules and host components
  sudo ./nvidia-installer --silent \
                    --accept-license \
                    --no-kernel-module \
                    --install-compat32-libs \
                    --no-nouveau-check \
                    --no-nvidia-modprobe \
                    --no-systemd \
                    --no-rpms \
                    --no-backup \
                    --no-check-for-alternate-installs
  rm -rf /tmp/NVIDIA* && cd ~
fi

# Run Xvfb server with required extensions
/usr/bin/Xvfb "${DISPLAY}" -screen 0 "8192x4096x${DISPLAY_CDEPTH}" -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" +iglx +render -nolisten "tcp" -ac -noreset -shmem &

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Resize the screen to the provided size
/usr/local/bin/selkies-gstreamer-resize "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}"

# Run the KasmVNC fallback web interface if enabled
if [ "$(echo ${KASMVNC_ENABLE} | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  export KASM_DISPLAY=":50"
  yq -i '
  .command_line.prompt = false |
  .desktop.allow_resize = '$(echo ${SELKIES_ENABLE_RESIZE-false} | tr '[:upper:]' '[:lower:]')' |
  .logging.log_dest = "/tmp/kasmvnc.log" |
  .network.ssl.require_ssl = '$(echo ${SELKIES_ENABLE_HTTPS-false} | tr '[:upper:]' '[:lower:]')' |
  .encoding.max_frame_rate = '${DISPLAY_REFRESH}' |
  .server.advanced.kasm_password_file = "'${XDG_RUNTIME_DIR}'/.kasmpasswd"
  ' /etc/kasmvnc/kasmvnc.yaml
  if [ -n "${SELKIES_HTTPS_CERT}" ]; then yq -i '.network.ssl.pem_certificate = "'${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem}'"' /etc/kasmvnc/kasmvnc.yaml; fi
  if [ -n "${SELKIES_HTTPS_KEY}" ]; then yq -i '.network.ssl.pem_certificate = "'${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key}'"' /etc/kasmvnc/kasmvnc.yaml; fi
  if [ "$(echo ${SELKIES_ENABLE_RESIZE} | tr '[:upper:]' '[:lower:]')" = "true" ]; then export KASM_RESIZE_FLAG="-r"; fi
  (echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}"; echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}";) | kasmvncpasswd -u "${SELKIES_BASIC_AUTH_USER:-${USER}}" -o "${XDG_RUNTIME_DIR}/.kasmpasswd"
  if [ "$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')" = "false" ]; then export NO_KASM_AUTH_FLAG="-disableBasicAuth"; fi
  if [ -n "$KASMVNC_VIEWPASS" ]; then (echo "${KASMVNC_VIEWPASS}"; echo "${KASMVNC_VIEWPASS}";) | kasmvncpasswd -u "view" "${XDG_RUNTIME_DIR}/.kasmpasswd"; fi
  kasmvncserver "${KASM_DISPLAY}" -websocketPort 8080 -geometry "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}" -depth "${DISPLAY_CDEPTH}" -FrameRate "${DISPLAY_REFRESH}" -fg -noxstartup -AlwaysShared ${NO_KASM_AUTH_FLAG}
  until [ -S "/tmp/.X11-unix/X${KASM_DISPLAY#*:}" ]; do sleep 0.5; done;
  kasmxproxy -a "${DISPLAY}" -v "${KASM_DISPLAY}" -f "${DISPLAY_REFRESH}" ${KASM_RESIZE_FLAG} &
fi

# Use VirtualGL to run the KDE desktop environment with OpenGL if the GPU is available, otherwise use OpenGL with llvmpipe
export XDG_SESSION_ID="${DISPLAY#*:}"
export QT_LOGGING_RULES='*.debug=false;qt.qpa.*=false'
if [ -n "$(nvidia-smi --query-gpu=uuid --format=csv,noheader | head -n1)" ] || [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
  export VGL_REFRESHRATE="${DISPLAY_REFRESH}"
  /usr/bin/vglrun -d "${VGL_DISPLAY:-egl}" +wm /usr/bin/startplasma-x11 &
else
  /usr/bin/startplasma-x11 &
fi

# Start Fcitx input method framework
/usr/bin/fcitx &

# Add custom processes right below this line, or within `supervisord.conf` to perform service management similar to systemd

echo "Session Running. Press [Return] to exit."
read
