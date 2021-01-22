# docker-nvidia-egl-desktop

MATE Desktop container for NVIDIA GPUs without using an X Server, directly
accessing the GPU with EGL to emulate GLX using VirtualGL and TurboVNC. Does not
require `/tmp/.X11-unix` host sockets.

Use
[docker-nvidia-glx-desktop](https://github.com/ehfd/docker-nvidia-glx-desktop)
for a MATE Desktop container with Vulkan support for NVIDIA GPUs by spawning its
own X Server without `/tmp/.X11-unix` host sockets.

Requires NVIDIA GPU drivers and corresponding container toolkits for allocating
GPUs to be set up on the host.

Connect to the spawned noVNC WebSocket instance with a browser in port 5901, no
VNC client required (password for the default user is 'vncpasswd').

Note: Requires access to the corresponding **/dev/dri/cardX** and
**/dev/dri/renderDX** DRM devices of the allocated NVIDIA GPU. Check out
[k8s-hostdev-plugin](https://github.com/bluebeach/k8s-hostdev-plugin) for
provisioning this in Kubernetes clusters without privileged access.

For building Ubuntu 18.04 containers, in **Dockerfile** change
`FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04` to
`FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu18.04` and remove the `render` group
in the command adding secondary groups to the default user, then in
**bootstrap.sh** comment out `pulseaudio --start`.

For Docker this will be sufficient (the container will not use DRM devices it is
not allocated to):

```
docker run --gpus 1 --device=/dev/dri:rw -it -e SIZEW=1920 -e SIZEH=1080 -e CDEPTH=24 -e SHARED=TRUE -e VNCPASS=vncpasswd -p 5901:5901 ehfd/nvidia-egl-desktop:latest
```
