FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04

LABEL maintainer "https://github.com/ehfd"

# Make all NVIDIA GPUS visible, but we want to manually install drivers
ARG NVIDIA_VISIBLE_DEVICES=all
# Supress interactive menu while installing keyboard-configuration
ARG DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES all

ARG VIRTUALGL_VERSION=2.6.80
ARG TURBOVNC_VERSION=2.2.80
ARG WEBSOCKIFY_VERSION=0.8.0
ARG NOVNC_VERSION=1.1.0

# Install desktop
RUN apt-get update && apt-get install -y software-properties-common
RUN apt-get install -y \
        ca-certificates \
        curl \
        wget \
        gzip \
        unzip \
        gcc \
        libc6-dev \
        libglu1 \
        libglu1:i386 \
        libsm6 \
        libxv1 \
        libxv1:i386 \
        make \
        python \
        python-numpy \
        x11-xkb-utils \
        xauth \
        xfonts-base \
        xkb-data \
        libxtst6 \
        libxtst6:i386 \
        mlocate \
        vim \
        htop \
        firefox \
        qt5-default \
        libpci3 \
        supervisor \
        net-tools \
        ubuntu-mate-core \
        ubuntu-mate-desktop && \
        rm -rf /var/lib/apt/lists/*

# Install Vulkan
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan1 vulkan-utils && \
    rm -rf /var/lib/apt/lists/*

# Sound driver including PulseAudio and GTK library
# If you want to use sounds on docker, try `pulseaudio --start`
RUN apt-get update && apt-get install -y --no-install-recommends \
      alsa pulseaudio libgtk2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# VirtualGL and TurboVNC
RUN curl -fsSL -O https://s3.amazonaws.com/virtualgl-pr/dev/linux/virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    rm virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    chmod u+s /usr/lib/libvglfaker.so && \
    chmod u+s /usr/lib/libdlfaker.so && \
    curl -fsSL -O https://s3.amazonaws.com/turbovnc-pr/dev/linux/turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    rm turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

ENV PATH ${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin

# noVNC and Websockify
RUN curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar -xzf - -C /opt && \
    curl -fsSL https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz | tar -xzf - -C /opt && \
    mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC && \
    mv /opt/websockify-${WEBSOCKIFY_VERSION} /opt/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    cd /opt/websockify && make

RUN echo 'no-remote-connections\n\
no-httpd\n\
no-x11-tcp-connections\n\
no-pam-sessions\n\
permitted-security-types = VNC, otp\
' > /etc/turbovncserver-security.conf

COPY bootstrap.sh /bootstrap.sh
RUN chmod 755 /bootstrap.sh
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 755 /etc/supervisord.conf

# Create user with password 'vncpasswd'
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo && \
    groupadd -g 1000 user && \
    useradd -ms /bin/bash user -u 1000 -g 1000 && \
    usermod -a -G adm,audio,cdrom,disk,games,lpadmin,sudo,dip,plugdev,tty,video user && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R user:user /home/user/ && \
    echo 'user:vncpasswd' | chpasswd && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 5901

USER user
WORKDIR /home/user

ENTRYPOINT ["/usr/bin/supervisord"]
