# docker-nvidia-egl-desktop

KDE Plasma Desktop container designed for Kubernetes with direct access to the GPU with EGL using [VirtualGL](https://github.com/VirtualGL/virtualgl) and Vulkan for GPUs with WebRTC and HTML5, providing an open source remote cloud graphics or game streaming platform. Does not require `/tmp/.X11-unix` host sockets or host configuration.

Use [docker-nvidia-glx-desktop](https://github.com/selkies-project/docker-nvidia-glx-desktop) for a KDE Plasma Desktop container with better performance, with fully optimized OpenGL and Vulkan for NVIDIA GPUs by spawning its own fully isolated X Server instead of using `/tmp/.X11-unix` host sockets.

**Read the [Troubleshooting](#troubleshooting) section first before raising an issue. Support is also available with the [Selkies Discord](https://discord.gg/wDNGDeSW5F). Please redirect issues or discussions regarding the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC HTML5 interface to the [project](https://github.com/selkies-project/selkies-gstreamer).**

## Usage

This container is composed fully of vendor-neutral applications and protocols except the NVIDIA base container itself, meaning that **there is nothing stopping you from using this container with GPUs of other vendors including AMD and Intel**. Use the respective vendor's container toolkit/runtime or Kubernetes device plugin and make sure that it provisions `/dev/dri/card[n]` devices, then set the environment variable `WEBRTC_ENCODER` to the value `x264enc`, `vp8enc`, or `vp9enc` if using the selkies-gstreamer WebRTC interface. Install relevant drivers inside the container as well, including `mesa-va-drivers` and `mesa-vulkan-drivers`. However, this is not officially supported and you must solve your own problems. This container also supports running without any GPUs with software fallback (set `WEBRTC_ENCODER` to the value `x264enc`, `vp8enc`, or `vp9enc` if using the selkies-gstreamer WebRTC interface).

Wine, Winetricks, Lutris, and PlayOnLinux are bundled by default. Comment out the section where it is installed within `Dockerfile` if the user wants to remove them from the container.

There are two web interfaces that can be chosen in this container, the first being the default [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC HTML5 interface (requires a TURN server or host networking), and the second being the fallback [noVNC](https://github.com/novnc/noVNC) WebSocket HTML5 interface. While the noVNC interface does not support audio forwarding and remote cursors for gaming, it can be useful for troubleshooting the selkies-gstreamer WebRTC interface or using this container with low bandwidth environments.

The noVNC interface can be enabled by setting `NOVNC_ENABLE` to `true`. When using the noVNC interface, all environment variables related to the selkies-gstreamer WebRTC interface are ignored, with the exception of `BASIC_AUTH_PASSWORD`. As with the selkies-gstreamer WebRTC interface, the noVNC interface password will be set to `BASIC_AUTH_PASSWORD`, and uses `PASSWD` by default if not set. The noVNC interface also additionally accepts the `NOVNC_VIEWPASS` environment variable, where a view only password with only the ability to observe the desktop without controlling can also be set.

The container requires host NVIDIA GPU driver versions of at least **450.80.02** and preferably **470.42.01**, with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) to be also configured on the host for allocating GPUs. All Maxwell or later generation GPUs in the consumer, professional, or datacenter lineups will not have significant issues running this container, although the selkies-gstreamer high performance NVENC backend may not be available (see the next paragraph). Kepler GPUs are untested and likely does not support the NVENC backend, but can be mostly functional using fallback software acceleration.

The high performance NVENC backend for the selkies-gstreamer WebRTC interface is only supported in GPUs listed as supporting `H.264 (AVCHD)` under the `NVENC - Encoding` section of NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new). If you are using software fallback without allocated GPUs or your GPU is not listed as supporting `H.264 (AVCHD)`, add the environment variable `WEBRTC_ENCODER` with the value `x264enc`, `vp8enc`, or `vp9enc` in your container configuration for falling back to software acceleration, which also has a very good performance depending on your CPU.

The username is `user` in both the container user account and the web authentication prompt. The environment variable `PASSWD` is the password of the container user account, and `BASIC_AUTH_PASSWORD` is the password for the HTML5 interface authentication prompt. If `ENABLE_BASIC_AUTH` is set to `true` for selkies-gstreamer (not required for noVNC) but `BASIC_AUTH_PASSWORD` is unspecified, the HTML5 interface password will default to `PASSWD`.
> NOTES: Only one web browser can be connected at a time with the selkies-gstreamer WebRTC interface. If the signaling connection works, but the WebRTC connection fails, read the [Using a TURN Server](#using-a-turn-server) section.

### Running with Docker

1. Run the container with Docker (or other similar container CLIs like Podman):

```
docker run --gpus 1 -it --tmpfs /dev/shm:rw -e TZ=UTC -e SIZEW=1920 -e SIZEH=1080 -e REFRESH=60 -e DPI=96 -e CDEPTH=24 -e PASSWD=mypasswd -e WEBRTC_ENCODER=nvh264enc -e BASIC_AUTH_PASSWORD=mypasswd -p 8080:8080 ghcr.io/selkies-project/nvidia-egl-desktop:latest
```
> NOTES: The container tags available are `latest` and `22.04` for Ubuntu 22.04, `20.04` for Ubuntu 20.04, and `18.04` for Ubuntu 18.04. Replace all instances of `mypasswd` with your desired password. `BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified. The container must not be run in privileged mode.

The environment variable `VGL_DISPLAY` can also be passed to the container, but only do so after you understand what it implicates with VirtualGL, valid values being either `egl[n]`, or `/dev/dri/card[n]` only when `--device=/dev/dri` was used for the container.

Change `WEBRTC_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the selkies-gstreamer interface if you are using software fallback without allocated GPUs or your GPU does not support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

2. Connect to the web server with a browser on port 8080. You may also separately configure a reverse proxy to this port for external connectivity.
> NOTES: Additional configurations and environment variables for the selkies-gstreamer WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [selkies-gstreamer main script](https://github.com/selkies-project/selkies-gstreamer/blob/master/src/selkies_gstreamer/__main__.py).

3. (Not Applicable for noVNC) **Read carefully if the selkies-gstreamer WebRTC HTML5 interface does not connect.** Choose whether to use host networking or a TURN server. The selkies-gstreamer WebRTC HTML5 interface will likely just start working if you add `--network host` to the above `docker run` command. However, this may be restricted or be undesired because of security reasons. If so, check if the container starts working after omitting `--network host`. If it does not work, you need a TURN server. Read the [Using a TURN Server](#using-a-turn-server) section and add the environment variables `-e TURN_HOST=`, `-e TURN_PORT=`, and pick one of `-e TURN_SHARED_SECRET=` or both `-e TURN_USERNAME=` and `-e TURN_PASSWORD=` environment variables to the `docker run` command based on your authentication method.

### Running with Kubernetes

1. Create the Kubernetes Secret with your authentication password:

```bash
kubectl create secret generic my-pass --from-literal=my-pass=YOUR_PASSWORD
```
> NOTES: Replace `YOUR_PASSWORD` with your desired password, and change the name `my-pass` to your preferred name of the Kubernetes secret with the `egl.yml` file changed accordingly as well. It is possible to skip the first step and directly provide the password with `value:` in `egl.yml`, but this exposes the password in plain text.

2. Create the pod after editing the `egl.yml` file to your needs, explanations are available in the file:

```bash
kubectl create -f egl.yml
```
> NOTES: The container tags available are `latest` and `22.04` for Ubuntu 22.04, `20.04` for Ubuntu 20.04, and `18.04` for Ubuntu 18.04. `BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified.

Change `WEBRTC_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the selkies-gstreamer interface if you are using software fallback without allocated GPUs or your GPU does not support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

3. Connect to the web server spawned at port 8080. You may configure the ingress endpoint or reverse proxy that your Kubernetes cluster provides to this port for external connectivity.
> NOTES: Additional configurations and environment variables for the selkies-gstreamer WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [selkies-gstreamer main script](https://github.com/selkies-project/selkies-gstreamer/blob/master/src/selkies_gstreamer/__main__.py).

4. (Not Applicable for noVNC) **Read carefully if the selkies-gstreamer WebRTC HTML5 interface does not connect.** Choose whether to use host networking or a TURN server. The selkies-gstreamer WebRTC HTML5 interface will likely just start working if you uncomment `hostNetwork: true` in `egl.yml`. However, this may be restricted or be undesired because of security reasons. If so, check if the container starts working after commenting out `hostNetwork: true`. If it does not work, you need a TURN server. Read the [Using a TURN Server](#using-a-turn-server) section and fill in the environment variables `TURN_HOST` and `TURN_PORT`, then pick one of `TURN_SHARED_SECRET` or both `TURN_USERNAME` and `TURN_PASSWORD` environment variables based on your authentication method.

## Using a TURN server

Note that this section is only required for the selkies-gstreamer WebRTC HTML5 interface. For an easy fix to when the signaling connection works, but the WebRTC connection fails, add the option `--network host` to your Docker command, or uncomment `hostNetwork: true` in your `egl.yml` file when using Kubernetes (note that your cluster may have not allowed this, resulting in an error). This exposes your container to the host network, which disables network isolation. If this does not fix the connection issue (normally when the host is behind another firewall) or you cannot use this fix for security or technical reasons, read the below text.

In most cases when either of your server or client has a permissive firewall, the default Google STUN server configuration will work without additional configuration. However, when connecting from networks that cannot be traversed with STUN, a TURN server is required.

### Deploying a TURN server

**Read the instructions from [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer#using-a-turn-server) if want to deploy a TURN server or use a public TURN server instance.**

### Configuring with Docker

With Docker (or Podman), use the `-e` option to add the `TURN_HOST`, `TURN_PORT` environment variables. This is the hostname or IP and the port of the TURN server (3478 in most cases).

You may set `TURN_PROTOCOL` to `tcp` if you are only able to open TCP ports for the coTURN container to the internet, or if the UDP protocol is blocked or throttled in your client network. You may also set `TURN_TLS` to `true` with the `-e` option if TURN over TLS/DTLS was properly configured.

You also require to provide either just `TURN_SHARED_SECRET` for time-limited shared secret TURN authentication, or both `TURN_USERNAME` and `TURN_PASSWORD` for legacy long-term TURN authentication, depending on your TURN server configuration. Provide just one of these authentication methods, not both.

### Configuring with Kubernetes

Your TURN server will use only one out of two ways to authenticate the client, so only provide one type of authentication method. The time-limited shared secret TURN authentication requires to only provide the Base64 encoded `TURN_SHARED_SECRET`. The legacy long-term TURN authentication requires to provide both `TURN_USERNAME` and `TURN_PASSWORD` credentials.

#### Time-limited shared secret authentication

1. Create a secret containing the TURN shared secret:

```bash
kubectl create secret generic turn-shared-secret --from-literal=turn-shared-secret=MY_TURN_SHARED_SECRET
```
> NOTES: Replace `MY_TURN_SHARED_SECRET` with the shared secret of the TURN server, then changing the name `turn-shared-secret` to your preferred name of the Kubernetes secret, with the `egl.yml` file also being changed accordingly.

2. Uncomment the lines in the `egl.yml` file related to TURN server usage, updating the `TURN_HOST` and `TURN_PORT` environment variable as needed:

```yaml
- name: TURN_HOST
  value: "turn.example.com"
- name: TURN_PORT
  value: "3478"
- name: TURN_SHARED_SECRET
  valueFrom:
    secretKeyRef:
      name: turn-shared-secret
      key: turn-shared-secret
- name: TURN_PROTOCOL
  value: "udp"
- name: TURN_TLS
  value: "false"
```
> NOTES: It is possible to skip the first step and directly provide the shared secret with `value:`, but this exposes the shared secret in plain text. Set `TURN_PROTOCOL` to `tcp` if you were able to only open TCP ports while creating your own coTURN Deployment/DaemonSet, or if your client network throttles or blocks the UDP protocol.

#### Legacy long-term authentication

1. Create a secret containing the TURN password:

```bash
kubectl create secret generic turn-password --from-literal=turn-password=MY_TURN_PASSWORD
```
> NOTES: Replace `MY_TURN_PASSWORD` with the password of the TURN server, then changing the name `turn-password` to your preferred name of the Kubernetes secret, with the `egl.yml` file also being changed accordingly.

2. Uncomment the lines in the `egl.yml` file related to TURN server usage, updating the `TURN_HOST`, `TURN_PORT`, and `TURN_USERNAME` environment variable as needed:

```yaml
- name: TURN_HOST
  value: "turn.example.com"
- name: TURN_PORT
  value: "3478"
- name: TURN_USERNAME
  value: "username"
- name: TURN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: turn-password
      key: turn-password
- name: TURN_PROTOCOL
  value: "udp"
- name: TURN_TLS
  value: "false"
```
> NOTES: It is possible to skip the first step and directly provide the TURN password with `value:`, but this exposes the TURN password in plain text. Set `TURN_PROTOCOL` to `tcp` if you were able to only open TCP ports while creating your own coTURN Deployment/DaemonSet, or if your client network throttles or blocks the UDP protocol.

## Comparison

<details>
  <summary>Open Section</summary>
[docker-nvidia-glx-desktop](https://github.com/selkies-project/docker-nvidia-glx-desktop): It's generally recommended to use docker-nvidia-glx-desktop when possible for maximum capabilities and performance. It starts its own X server inside the container without exposure to security risks. However, docker-nvidia-egl-desktop is versatile in various environments and has less processes running, meaning less possible complications in restricted environments. It is also possible to be used in HPC clusters with Apptainer/Singularity available, and sharing a GPU with multiple containers is also possible. Unofficial support for Intel and AMD GPUs is also available.

[Sunshine](https://github.com/LizardByte/Sunshine): This repository is an open-source server for NVIDIA's GameStream protocol, supporting all clients that can install [Moonlight](https://github.com/moonlight-stream). Try it if you don't need username/password authentication and you don't need to use containers. [Games on Whales](https://github.com/games-on-whales/gow) is a container implementation of Sunshine. However, many container ports have to be accessible to the internet, and because of its requirement for the `/dev/uinput` device, unsafe `privileged` access for containers are required. The [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project, which is integrated to our container, does not require more than one port open from the container (TURN server may be required but can be deployed in a different environment with flexibility), and has almost equal performance while using only a web browser as a client.

[x11docker](https://github.com/mviereck/x11docker): This has a lot of features and is very solid if you are the sole user in full control of the host. However, it starts a lot of processes in the host and is nearly impossible to contain the environment. Kubernetes is also not supported. The docker-nvidia-egl-desktop repository contains everything in the container, with the only requirement being the NVIDIA Container Toolkit with adequate `NVIDIA_DRIVER_CAPABILITIES`, meaning that the container is portable anywhere Docker/Podman or Kubernetes can be run.

[Xpra](https://github.com/Xpra-org/xpra): This is a feature-complete all-in-one remote desktop application optimized for Linux, although not exactly meant for full screen workloads and its HTML5 web interface is not optimized for intensive graphics workloads. Supports various protocols and various hardware acceleration methods.

[KasmVNC](https://github.com/kasmtech/KasmVNC): This almost landed as a replacement for the existing [noVNC](https://github.com/novnc/noVNC) fallback installation, as it incorporates improved functionalities. However, performance compared to [x11vnc](https://github.com/LibVNC/x11vnc) combined with [noVNC](https://github.com/novnc/noVNC) was not much better.

[Parsec](https://parsec.app): Parsec is not open-source. However, it brings top-level performance on Windows or Mac hosts. Try it if you don't need to use containers. But the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project uses the same APIs and isn't that far back in terms of performance.

[CloudRetro](https://github.com/giongto35/cloud-game) and [CloudMorph](https://github.com/giongto35/cloud-morph): This uses WebRTC in a web browser, like the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project. The principles of this project are pretty similar to our project. However, hardware acceleration across various GPUs is currently not implemented. Hardware acceleration is critical to remote desktop and workload performance, and therefore you should use our repository if you need hardware acceleration.

[neko](https://github.com/m1k1o/neko): Uses WebRTC in a web browser with a text chat, and it is also designed for containers (uses GStreamer too), but I had a hard time in conditions where more than one port can't be exposed or when using reverse proxies. Use this if you want good performance while requiring multiple users to be able to access the screen. However, note that you can always use conference software such as [Zoom](https://zoom.us), [Jitsi](https://meet.jit.si), or [BigBlueButton](https://bigbluebutton.org) to share your screen while using our container.

[RustDesk](https://github.com/rustdesk/rustdesk): This is an open-source TeamViewer or AnyDesk. You can use this to have other people control your node if you need to.

[Weylus](https://github.com/H-M-H/Weylus): This is a very interesting project, and has many technologies in common. Use this if you want to turn your tablet or smartphone to a graphic tablet for your PC.

[GamingAnywhere](https://github.com/chunying/gaminganywhere): This is the father of all open-source remote desktop and game streaming protocols. However, it has been created a long time ago and thus reached its end of life.
</details>

## Troubleshooting

### The container does not work.

Check that the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) is properly configured in the host. After that, check the environment variable `NVIDIA_DRIVER_CAPABILITIES` after starting a shell interface inside the container.

`NVIDIA_DRIVER_CAPABILITIES` should be set to `all`, or include a comma-separated list of `compute` (requirement for CUDA and OpenCL, or for the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC remote desktop interface), `utility` (requirement for `nvidia-smi` and NVML), `graphics` (requirement for OpenGL and part of the requirement for Vulkan), `video` (required for encoding or decoding videos using NVIDIA GPUs, or for the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC remote desktop interface), `display` (the other requirement for Vulkan), and optionally `compat32` if you use Wine or 32-bit graphics applications.

If you checked everything here, scroll down.

### I want to use `systemd`, `polkit`, FUSE mounts, or sandboxed (containerized) application distribution systems like Flatpak, Snapcraft (snap), AppImage, and etc.

**Use the option `--appimage-extract-and-run` or `--appimage-extract` with your AppImage to run them in a container. Alternatively, set `export APPIMAGE_EXTRACT_AND_RUN=1` to your current shell. For controlling PulseAudio, use `pactl` instead of `pacmd` as the latter corrupts the audio system within the container. Use `sudoedit` to edit protected files in the desktop instead of using `sudo` followed by the name of the editor.**

<details>
  <summary>Open Long Answer</summary>
For `systemd`, `polkit`, FUSE mounts, or other sandboxed application distribution systems, do not use them with containers. You can use them if you add unsafe capabilities to your containers, but it will break the isolation of the containers. This is especially bad if you are using Kubernetes. For controlling PulseAudio, use `pactl` instead of `pacmd` as the latter corrupts the audio system within the container. Because `polkit` does not work, use `sudoedit` to edit protected files with the GUI instead of using `sudo` followed by the name of the editor. There will likely be an alternative way to install the applications, including [Personal Package Archives](https://launchpad.net/ubuntu/+ppas). For some applications, there will be options to disable sandboxing when running or options to extract files before running.
</details>

### OpenGL does not work for certain applications.

This is likely an issue with [VirtualGL](https://github.com/VirtualGL/virtualgl), which is used to translate GLX commands to EGL commands and use OpenGL without Xorg. Some applications, including research workloads, show this problem. This **cannot** be solved by raising an issue here or contacting me.

First, check that the application works with [docker-nvidia-glx-desktop](https://github.com/selkies-project/docker-nvidia-glx-desktop). If it works, it is indeed a problem associated with [VirtualGL](https://github.com/VirtualGL/virtualgl). If it does not, raise an issue here. Second, use the error messages found with verbose mode and search similar issues for your application. Third, if there are no similar issues, raise the issue to the repository or contact the maintainers. Fourth, if the maintainers request that it should be redirected to [VirtualGL](https://github.com/VirtualGL/virtualgl), raise an issue there after confirming [VirtualGL](https://github.com/VirtualGL/virtualgl) does not have similar issues raised. Note that in this case, you may have to wait for a new [VirtualGL](https://github.com/VirtualGL/virtualgl) release and for this repository to use the new release.

### Vulkan does not work.

Make sure that the `NVIDIA_DRIVER_CAPABILITIES` environment variable is set to `all`, or includes both `graphics` and `display`. The `display` capability is especially crucial to Vulkan, but the container does start without noticeable issues other than Vulkan without `display`, despite its name. AMD and Intel GPUs are not tested and therefore Vulkan is not guaranteed to work. A Vulkan ICD file is probably required to be added and related drivers like `mesa-vulkan-drivers` should be installed inside the container. People are welcome to share their experiences, however.

### I want to use a specific GPU for OpenGL rendering when I have multiple GPUs in one container.

Use the `VGL_DISPLAY` environment variable, but only do so after you understand what it implicates with [VirtualGL](https://github.com/VirtualGL/virtualgl). Valid values are either `egl[n]`, or `/dev/dri/card[n]` only when `--device=/dev/dri` was used for the container (`[n]` is the order of the GPUs, where simply `egl` without the number is the same as `egl0`). Note that `docker --gpus 1` means any single GPU, not the GPU device ID of 1. Use `docker --gpus '"device=1,2"'` to provision GPUs with device IDs 1 and 2 to the container.

---
This project involved a collaboration effort with members of the [Selkies Project](https://github.com/selkies-project), incorporating the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC remote desktop streaming application. Commercial support for this container is available with [itopia Spaces](https://itopiaspaces.com).

This work was supported in part by National Science Foundation (NSF) awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, OAC-2112167, CNS-2100237, CNS-2120019, the University of California Office of the President, and the University of California San Diego's California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
