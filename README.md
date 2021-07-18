# docker-nvidia-egl-desktop

MATE Desktop container for NVIDIA GPUs without using an X Server, directly accessing the GPU with EGL to emulate GLX using VirtualGL and TurboVNC. Does not require `/tmp/.X11-unix` host sockets. Designed for Kubernetes.

Use [docker-nvidia-glx-desktop](https://github.com/ehfd/docker-nvidia-glx-desktop) for a MATE Desktop container with Vulkan support for NVIDIA GPUs by spawning its own X Server without using `/tmp/.X11-unix` host sockets.

Requires NVIDIA GPU drivers and corresponding container toolkits to be set up on the host for allocating GPUs.

Connect to the spawned noVNC WebSocket instance with a browser in port 5901, no installed VNC client is required (password for the default user is 'vncpasswd').

Wine and Winetricks are bundled by default, comment out the installation section in **Dockerfile** if the user wants to remove them from the container.

For building Ubuntu 18.04 containers, in **Dockerfile** change `FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04` to `FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu18.04`, then remove the `render` group in the command that adds secondary groups to the default user.

Note: Requires access to the corresponding **/dev/dri/cardX** and **/dev/dri/renderDX** DRM devices of the allocated NVIDIA GPU. Check out [smarter-device-manager](https://gitlab.com/arm-research/smarter/smarter-device-manager) or [k8s-hostdev-plugin](https://github.com/bluebeach/k8s-hostdev-plugin) for provisioning this in Kubernetes clusters without privileged access.

For Docker this will be sufficient (the container will not use DRM devices it is not allocated to, falling back to software acceleration if no devices work):

```
docker run --gpus 1 --device=/dev/dri:rw -it -e SIZEW=1920 -e SIZEH=1080 -e CDEPTH=24 -e SHARED=TRUE -e VNCPASS=vncpasswd -p 5901:5901 ehfd/nvidia-egl-desktop:latest
```

This work was supported in part by NSF awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, the University of California Office of the President, and the University of California San Diego’s California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
