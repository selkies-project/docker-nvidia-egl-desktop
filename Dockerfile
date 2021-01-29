FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04
#FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu18.04

LABEL maintainer "https://github.com/ehfd"

# Make all NVIDIA GPUS visible
ARG NVIDIA_VISIBLE_DEVICES=all
# Supress interactive menu while installing keyboard-configuration
ARG DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES all

# Default options (password is 'vncpasswd')
ENV VNCPASS vncpasswd
ENV SIZEW 1920
ENV SIZEH 1080
ENV CDEPTH 24

# Install locales to prevent errors
RUN apt-get clean && \
    apt-get update && \
    apt-get install --no-install-recommends -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install desktop
RUN apt-get update && apt-get install -y software-properties-common
RUN apt-get install -y \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        wget \
        gzip \
        zip \
        unzip \
        gcc \
        git \
        libc6-dev \
        libglu1 \
        libglu1:i386 \
        libsm6 \
        libxv1 \
        libxv1:i386 \
        make \
        python \
        python-numpy \
        python3 \
        python3-numpy \
        x11-xkb-utils \
        xauth \
        xfonts-base \
        xkb-data \
        libxtst6 \
        libxtst6:i386 \
        mlocate \
        nano \
        vim \
        htop \
        firefox \
        libpci3 \
        supervisor \
        net-tools \
        ubuntu-mate-core \
        ubuntu-mate-desktop && \
    rm -rf /var/lib/apt/lists/*

# Install Vulkan
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan1 \
        vulkan-utils && \
    rm -rf /var/lib/apt/lists/* && \
    VULKAN_API_VERSION=`dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9]+(\.[0-9]+)(\.[0-9]+)'` && \
    mkdir -p /etc/vulkan/icd.d/ && \
    echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
        \"library_path\": \"libGLX_nvidia.so.0\",\n\
        \"api_version\" : \"${VULKAN_API_VERSION}\"\n\
    }\n\
}" > /etc/vulkan/icd.d/nvidia_icd.json

# Sound driver including PulseAudio and GTK library
# If you want to use sounds on docker, try 'pulseaudio --start'
RUN apt-get update && apt-get install -y --no-install-recommends \
        alsa \
        pulseaudio \
        libgtk2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# VirtualGL and TurboVNC
ARG VIRTUALGL_VERSION=2.6.80
ARG TURBOVNC_VERSION=2.2.80
RUN curl -fsSL -O https://s3.amazonaws.com/virtualgl-pr/dev/linux/virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    rm virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    chmod u+s /usr/lib/libvglfaker.so && \
    chmod u+s /usr/lib/libdlfaker.so && \
    curl -fsSL -O https://s3.amazonaws.com/turbovnc-pr/dev/linux/turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    rm turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    rm -rf /var/lib/apt/lists/* && \
    echo "no-remote-connections\n\
no-httpd\n\
no-x11-tcp-connections\n\
no-pam-sessions\n\
permitted-security-types = VNC, otp\
" > /etc/turbovncserver-security.conf

ENV PATH ${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin

# noVNC and Websockify
ARG NOVNC_VERSION=1.1.0
ARG WEBSOCKIFY_VERSION=0.8.0
RUN curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar -xzf - -C /opt && \
    curl -fsSL https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz | tar -xzf - -C /opt && \
    mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC && \
    mv /opt/websockify-${WEBSOCKIFY_VERSION} /opt/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    cd /opt/websockify && make && cd /

# X server segfault error mitigation
RUN apt-get update && apt-get install -y --no-install-recommends \
        dbus-x11 \
        libdbus-c++-1-0v5 && \
    rm -rf /var/lib/apt/lists/*

# Create user with password ${VNCPASS}
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1000 user && \
    useradd -ms /bin/bash user -u 1000 -g 1000 && \
    # Remove 'render' group in Ubuntu 18.04
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,input,lpadmin,netdev,plugdev,render,scanner,ssh,sudo,tape,tty,video,voice user && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R user:user /home/user && \
    echo "user:${VNCPASS}" | chpasswd

COPY bootstrap.sh /bootstrap.sh
RUN chmod 755 /bootstrap.sh
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 755 /etc/supervisord.conf

EXPOSE 5901

USER user
WORKDIR /home/user

ENTRYPOINT ["/usr/bin/supervisord"]
