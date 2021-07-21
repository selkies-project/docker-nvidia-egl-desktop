# docker-nvidia-egl-desktop

MATE Desktop container for NVIDIA GPUs without using an X Server, directly accessing the GPU with EGL using VirtualGL, TurboVNC, and Guacamole. Does not require `/tmp/.X11-unix` host sockets. Designed for Kubernetes, also supporting audio forwarding.

Use [docker-nvidia-glx-desktop](https://github.com/ehfd/docker-nvidia-glx-desktop) for a more performant MATE Desktop container also including Vulkan support for NVIDIA GPUs by spawning its own X Server without using `/tmp/.X11-unix` host sockets.

Requires NVIDIA GPU drivers and corresponding container toolkits to be set up on the host for allocating GPUs.

Connect to the spawned Apache Guacamole instance with a web browser in port 8080 (the username is "user" and the default password is "mypasswd"). No VNC client installation is required. Press Ctrl+Alt+Shift to toggle the configuration option in Guacamole. Click the fullscreen button in your web browser settings or press F11 after pressing Ctrl+Alt+Shift to bring up fullscreen.

Wine and Winetricks are bundled by default, comment out the installation section in **Dockerfile** if the user wants to remove them from the container.

For building Ubuntu 18.04 containers, in **Dockerfile** change `FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04` to `FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu18.04`.

Note: Requires access to the corresponding **/dev/dri/cardX** and **/dev/dri/renderDX** DRM devices of the allocated NVIDIA GPU. Check out [smarter-device-manager](https://gitlab.com/arm-research/smarter/smarter-device-manager) or [k8s-hostdev-plugin](https://github.com/bluebeach/k8s-hostdev-plugin) for provisioning this in Kubernetes clusters without privileged access.

For Docker this will be sufficient (the container will not use DRM devices it is not allocated to, falling back to software acceleration if no devices work):

```
docker run --gpus 1 --device=/dev/dri:rw -it -e SIZEW=1920 -e SIZEH=1080 -e CDEPTH=24 -e SHARED=TRUE -e PASSWD=mypasswd -p 8080:8080 ehfd/nvidia-egl-desktop:latest
```

This work was supported in part by NSF awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, the University of California Office of the President, and the University of California San Diego’s California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
