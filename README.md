# docker-nvidia-egl-desktop

Xfce Desktop container designed for Kubernetes with direct access to the GPU with EGL using VirtualGL and Vulkan for GPUs with WebRTC and HTML5, providing an open source remote cloud graphics or game streaming platform. Does not require `/tmp/.X11-unix` host sockets or host configuration.

Use [docker-nvidia-glx-desktop](https://github.com/ehfd/docker-nvidia-glx-desktop) for an Xfce Desktop container with better performance, with fully optimized OpenGL and Vulkan for NVIDIA GPUs by spawning its own fully isolated X Server instead of using `/tmp/.X11-unix` host sockets.

**Read the [Troubleshooting](#troubleshooting) section first before raising an issue. Support is also available with the [Selkies Discord](https://discord.gg/wDNGDeSW5F).**

### Usage

This container is composed fully of vendor-neutral applications and protocols except the NVIDIA base container itself, meaning that **there is nothing stopping you from using this container with GPUs of other vendors including AMD and Intel**. Use the respective vendor's container toolkit/runtime or Kubernetes device plugin and make sure that it provisions `/dev/dri/card[n]` devices, then set the environment variable `WEBRTC_ENCODER` to the value `x264enc`, `vp8enc`, or `vp9enc` if using the selkies-gstreamer WebRTC interface. An experimental hardware accelerated `WEBRTC_ENCODER` interface `vaapih264enc` for AMD and Intel GPUs with the selkies-gstreamer WebRTC interface is also available. However, this is not officially supported and you must solve your own problems. This container also supports running without any GPUs with software fallback (set `WEBRTC_ENCODER` to the value `x264enc`, `vp8enc`, or `vp9enc` if using the selkies-gstreamer WebRTC interface).

Wine, Winetricks, Lutris, and PlayOnLinux are bundled by default. Comment out the section where it is installed within `Dockerfile` if the user wants to remove them from the container.

There are two web interfaces that can be chosen in this container, the first being the default [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC HTML5 interface (requires a TURN server or host networking), and the second being the fallback [noVNC](https://github.com/novnc/noVNC) WebSocket HTML5 interface. While the noVNC interface does not support audio forwarding and remote cursors for gaming, it can be useful for troubleshooting the selkies-gstreamer WebRTC interface or using this container with low bandwidth environments.

The noVNC interface can be enabled by setting `NOVNC_ENABLE` to `true`. When using the noVNC interface, all environment variables related to the selkies-gstreamer WebRTC interface are ignored, with the exception of `BASIC_AUTH_PASSWORD`. As with the selkies-gstreamer WebRTC interface, the noVNC interface password will be set to `BASIC_AUTH_PASSWORD`, and uses `PASSWD` by default if not set. The noVNC interface also additionally accepts the `NOVNC_VIEWPASS` environment variable, where a view only password with only the ability to observe the desktop without controlling can also be set.

The container requires host NVIDIA GPU driver versions of at least **450.80.02** and preferably **470.42.01**, with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) to be also configured on the host for allocating GPUs. All Maxwell or later generation GPUs in the consumer, professional, or datacenter lineups will not have significant issues running this container, although the selkies-gstreamer high performance NVENC backend may not be available (see the next paragraph). Kepler GPUs are untested and likely does not support the NVENC backend, but can be mostly functional using fallback software acceleration.

The high performance NVENC backend for the selkies-gstreamer WebRTC interface is only supported in GPUs listed as supporting `H.264 (AVCHD)` under the `NVENC - Encoding` section of NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new). If you are using software fallback without allocated GPUs or your GPU is not listed as supporting `H.264 (AVCHD)`, add the environment variable `WEBRTC_ENCODER` with the value `x264enc`, `vp8enc`, or `vp9enc` in your container configuration for falling back to software acceleration, which also has a very good performance depending on your CPU.

The username is `user` in both the container user account and the web authentication prompt. The environment variable `PASSWD` is the password of the container user account, and `BASIC_AUTH_PASSWORD` is the password for the HTML5 interface authentication prompt. If `ENABLE_BASIC_AUTH` is set to `true` for selkies-gstreamer (not required for noVNC) but `BASIC_AUTH_PASSWORD` is unspecified, the HTML5 interface password will default to `PASSWD`.
> NOTES: Only one web browser can be connected at a time with the selkies-gstreamer WebRTC interface. If the signaling connection works, but the WebRTC connection fails, read the [Using a TURN Server](#using-a-turn-server) section.

#### Running with Docker

1. Run the container with Docker (or other similar container CLIs like Podman):

```
docker run --gpus 1 -it --tmpfs /dev/shm:rw -e TZ=UTC -e SIZEW=1920 -e SIZEH=1080 -e REFRESH=60 -e DPI=96 -e CDEPTH=24 -e PASSWD=mypasswd -e WEBRTC_ENCODER=nvh264enc -e BASIC_AUTH_PASSWORD=mypasswd -p 8080:8080 ghcr.io/ehfd/nvidia-egl-desktop:latest
```
> NOTES: The container tags available are `latest` and `20.04` for Ubuntu 20.04 and `18.04` for Ubuntu 18.04. Replace all instances of `mypasswd` with your desired password. `BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified. The container must not be run in privileged mode.

The environment variable `VGL_DISPLAY` can also be passed to the container, but only do so after you understand what it implicates with VirtualGL, valid values being either `egl[n]`, or `/dev/dri/card[n]` only when `--device=/dev/dri` was used for the container.

Change `WEBRTC_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the selkies-gstreamer interface if you are using software fallback without allocated GPUs or your GPU doesn't support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

2. Connect to the web server with a browser on port 8080. You may also separately configure a reverse proxy to this port for external connectivity.
> NOTES: Additional configurations and environment variables for the selkies-gstreamer WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [selkies-gstreamer main script](https://github.com/selkies-project/selkies-gstreamer/blob/master/src/selkies_gstreamer/__main__.py).

3. (Not Applicable for noVNC) **Read carefully if the selkies-gstreamer WebRTC HTML5 interface does not connect.** Choose whether to use host networking or a TURN server. The selkies-gstreamer WebRTC HTML5 interface will likely just start working if you add `--network host` to the above `docker run` command. However, this may be restricted or be undesired because of security reasons. If so, check if the container starts working after omitting `--network host`. If it does not work, you need a TURN server. Read the [Using a TURN Server](#using-a-turn-server) section and add the environment variables `-e TURN_HOST=`, `-e TURN_PORT=`, and pick one of `-e TURN_SHARED_SECRET=` or both `-e TURN_USERNAME=` and `-e TURN_PASSWORD=` environment variables to the `docker run` command based on your authentication method.

#### Running with Kubernetes

1. Create the Kubernetes Secret with your authentication password:

```bash
kubectl create secret generic my-pass --from-literal=my-pass=YOUR_PASSWORD
```
> NOTES: Replace `YOUR_PASSWORD` with your desired password, and change the name `my-pass` to your preferred name of the Kubernetes secret with the `egl.yml` file changed accordingly as well. It is possible to skip the first step and directly provide the password with `value:` in `egl.yml`, but this exposes the password in plain text.

2. Create the pod after editing the `egl.yml` file to your needs, explanations are available in the file:

```bash
kubectl create -f egl.yml
```
> NOTES: The container tags available are `latest` and `20.04` for Ubuntu 20.04 and `18.04` for Ubuntu 18.04. `BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified.

Change `WEBRTC_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the selkies-gstreamer interface if you are using software fallback without allocated GPUs or your GPU doesn't support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

3. Connect to the web server spawned at port 8080. You may configure the ingress endpoint or reverse proxy that your Kubernetes cluster provides to this port for external connectivity.
> NOTES: Additional configurations and environment variables for the selkies-gstreamer WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [selkies-gstreamer main script](https://github.com/selkies-project/selkies-gstreamer/blob/master/src/selkies_gstreamer/__main__.py).

4. (Not Applicable for noVNC) **Read carefully if the selkies-gstreamer WebRTC HTML5 interface does not connect.** Choose whether to use host networking or a TURN server. The selkies-gstreamer WebRTC HTML5 interface will likely just start working if you uncomment `hostNetwork: true` in `egl.yml`. However, this may be restricted or be undesired because of security reasons. If so, check if the container starts working after commenting out `hostNetwork: true`. If it does not work, you need a TURN server. Read the [Using a TURN Server](#using-a-turn-server) section and fill in the environment variables `TURN_HOST` and `TURN_PORT`, then pick one of `TURN_SHARED_SECRET` or both `TURN_USERNAME` and `TURN_PASSWORD` environment variables based on your authentication method.

#### Using a TURN Server

Note that this section is only required for the selkies-gstreamer WebRTC HTML5 interface. For an easy fix to when the signaling connection works, but the WebRTC connection fails, add the option `--network host` to your Docker command, or uncomment `hostNetwork: true` in your `egl.yml` file when using Kubernetes (note that your cluster may have not allowed this, resulting in an error). This exposes your container to the host network, which disables network isolation. If this does not fix the connection issue (normally when the host is behind another firewall) or you cannot use this fix for security or technical reasons, read the below text.

In most cases when either of your server or client has a permissive firewall, the default Google STUN server configuration will work without additional configuration. However, when connecting from networks that cannot be traversed with STUN, a TURN server is required. Provide the TURN server address, port, and shared secret in order to take advantage of the TURN relay capabilities and improve connection success.

[Open Relay](https://www.metered.ca/tools/openrelay) is a free TURN server instance that may be used for personal purposes, but may not be optimal for production usage.

An open source TURN server that can be used is [coTURN](https://github.com/coturn/coturn), and an [example container](https://hub.docker.com/r/coturn/coturn) `coturn/coturn:latest` is available. For dynamic IP addresses, [dynamic-coturn](https://github.com/mreichardt95/dynamic-coturn) is a container implementation which restarts the TURN server whenever the public IP address gets changed. [Pion TURN](https://github.com/pion/turn) is another TURN server implementation compatible with all major operating systems including Windows.

It is possible to install [coTURN](https://github.com/coturn/coturn) on your own server or PC, as long as ports can be opened. In short, `/etc/turnserver.conf` must have either `use-auth-secret` and `static-auth-secret=(PUT RANDOM 64 BYTE BASE64 KEY HERE)`, or `lt-cred-mech` and `user=yourusername:yourpassword`. Other optional, but useful parameters include `min-port=` and `max-port=` for setting your relay ports between TURN servers, and `cert=` and `pkey=` options for TURN over TLS/DTLS. Install coTURN from your package repository, or use its container image with Docker/Podman or Kubernetes.

##### Deploy coTURN with Docker

In order to deploy a coTURN container, use the following command (consult this [example configuration](https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf) for more options which may also be used as command line arguments). You should be able to expose these ports to the internet. Change `-p 49160-49200:49160-49200/udp` and `--min-port=49160 --max-port=49200` as appropriate. Simply using `--network host` instead of specifying `-p 49160-49200:49160-49200/udp` is also fine if possible.

For time-limited shared secret TURN authentication:

```
docker run -d -p 3478:3478 -p 3478:3478/udp -p 49160-49200:49160-49200/udp coturn/coturn -n --min-port=49160 --max-port=49200 --use-auth-secret --static-auth-secret=(PUT RANDOM 64 BYTE BASE64 KEY HERE)
```

For legacy long-term TURN authentication:

```
docker run -d -p 3478:3478 -p 3478:3478/udp -p 49160-49200:49160-49200/udp coturn/coturn -n --min-port=49160 --max-port=49200 --lt-cred-mech --user=yourusername:yourpassword
```

If you want to use TURN over TLS/DTLS, you must have a valid hostname, and also provision a valid certificate issued from a legitimate certificate authority such as [ZeroSSL](https://zerossl.com/features/acme/) (Let's Encrypt may have issues depending on the OS) and provide the certificate and private files to the coTURN container with `-v /mylocalpath/coturncert.pem:/etc/coturncert.pem -v /mylocalpath/coturnkey.pem:/etc/coturnkey.pem` and add command line arguments `-n --cert=/etc/coturncert.pem --pkey=/etc/coturnkey.pem`.

More information available in the [coTURN container image](https://hub.docker.com/r/coturn/coturn) or the [coTURN repository](https://github.com/coturn/coturn) website.

##### Configuring with Docker

With Docker (or Podman), use the `-e` option to add the `TURN_HOST`, `TURN_PORT` environment variables. This is the hostname or IP and the port of the TURN server (3478 in most cases).

You may set `TURN_PROTOCOL` to `tcp` if you are only able to open TCP ports for the coTURN container to the internet, or if the UDP protocol is blocked or throttled in your client network. You may also set `TURN_TLS` to `true` with the `-e` option if TURN over TLS/DTLS was properly configured.

You also require to provide either just `TURN_SHARED_SECRET` for time-limited shared secret TURN authentication, or both `TURN_USERNAME` and `TURN_PASSWORD` for legacy long-term TURN authentication, depending on your TURN server configuration. Provide just one of these authentication methods, not both.

##### Deploy coTURN With Kubernetes

You are recommended to use a `ConfigMap` for creating the configuration file for coTURN. Use the [example coTURN configuration](https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf) as a reference to create a `ConfigMap` which mounts to `/etc/turnserver.conf`. The only mandatory lines are either `use-auth-secret` and `static-auth-secret=(PUT RANDOM 64 BYTE BASE64 KEY HERE)` or `lt-cred-mech` and `user=yourusername:yourpassword`.

Use `Deployment` or `DaemonSet` and use `containerPort` and `hostPort` under `ports:` to open port 3478 (or any other port you set in `/etc/turnserver.conf` with `listening-port=`).

Then you must also open all ports between `min-port=` and `max-port=` that you set in `/etc/turnserver.conf`, but this may be skipped if `hostNetwork: true` is used instead.

Under `args:` set `-c /etc/turnserver.conf` and use the `coturn/coturn:latest` image.

If you want to use TURN over TLS/DTLS, use [cert-manager](https://cert-manager.io) to issue a valid certificate with the correct hostname from preferably ZeroSSL (Let's Encrypt may have issues based on the OS), then mount the certificate and private key in the container. Do not forget to include the options `cert=` and `pkey=` in `/etc/turnserver.conf` to the correct path of the certificate and the key.

More information available in the [coTURN container image](https://hub.docker.com/r/coturn/coturn) or the [coTURN repository](https://github.com/coturn/coturn) website.

##### Configuring With Kubernetes

Your TURN server will use only one out of two ways to authenticate the client, so only provide one type of authentication method. The time-limited shared secret TURN authentication requires to only provide the Base64 encoded `TURN_SHARED_SECRET`. The legacy long-term TURN authentication requires to provide both `TURN_USERNAME` and `TURN_PASSWORD` credentials.

###### Time-Limited Shared Secret Authentication

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

###### Legacy Long-Term Authentication

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

### Comparison

[docker-nvidia-glx-desktop](https://github.com/ehfd/docker-nvidia-glx-desktop): It's generally recommended to use docker-nvidia-glx-desktop when possible for maximum capabilities and performance. It starts its own X server inside the container without exposure to security risks. However, docker-nvidia-egl-desktop is versatile in various environments and has less processes running, meaning less possible errors. It is also possible to be used in HPC clusters with Apptainer/Singularity available, and sharing a GPU with multiple containers is also possible. Unofficial support for Intel and AMD GPUs is also available.

[Sunshine](https://github.com/LizardByte/Sunshine): This repository is an open-source server for NVIDIA's GameStream protocol, supporting all clients that can install [Moonlight](https://github.com/moonlight-stream). Try it if you don't need username/password authentication and you don't need to use containers. [Games on Whales](https://github.com/games-on-whales/gow) is a container implementation of Sunshine. However, many container ports have to be accessible to the internet, and because of its requirement for the `/dev/uinput` device, unsafe `privileged` access for containers are required. The [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project, which is integrated to our container, does not require more than one port open from the container (TURN server may be required but can be deployed in a different environment with flexibility), and has almost equal performance while using only a web browser as a client.

[x11docker](https://github.com/mviereck/x11docker): This has a lot of features and is very solid if you are the sole user in full control of the host. However, it starts a lot of processes in the host and is nearly impossible to contain the environment. Kubernetes is also not supported. The docker-nvidia-egl-desktop repository contains everything in the container, with the only requirement being the NVIDIA Container Toolkit with adequate `NVIDIA_DRIVER_CAPABILITIES`, meaning that the container is portable anywhere Docker/Podman or Kubernetes can be run.

[Xpra](https://github.com/Xpra-org/xpra): This is a feature-complete all-in-one remote desktop application optimized for Linux, although not exactly meant for full screen workloads and its HTML5 web interface is not optimized for intensive graphics workloads. Supports various protocols and various hardware acceleration methods.

[KasmVNC](https://github.com/kasmtech/KasmVNC): This almost landed as a replacement for the existing [noVNC](https://github.com/novnc/noVNC) fallback installation, as it incorporates improved functionalities. However, performance compared to [x11vnc](https://github.com/LibVNC/x11vnc) combined with [noVNC](https://github.com/novnc/noVNC) was not much better.

[Parsec](https://parsec.app): Parsec is not open-source. However, it brings top-level performance on Windows or Mac hosts. Try it if you don't need to use containers. But the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project uses the same APIs and isn't that far back in terms of performance.

[CloudRetro](https://github.com/giongto35/cloud-game) and [CloudMorph](https://github.com/giongto35/cloud-morph): This uses WebRTC in a web browser, like the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project. The principles of this project are pretty similar to our project. However, hardware acceleration across various GPUs is currently not implemented. Hardware acceleration is critical to remote desktop and workload performance, and therefore you should use our repository if you need hardware acceleration.

[neko](https://github.com/m1k1o/neko): Uses WebRTC in a web browser with a text chat, containers can be used, but hardware acceleration is very limited. Use this if you want the best performance while requiring multiple users to be able to access the screen. However, note that you can always use conference software such as [Zoom](https://zoom.us), [Jitsi](https://meet.jit.si), or [BigBlueButton](https://bigbluebutton.org) to share your screen while using our container.

[RustDesk](https://github.com/rustdesk/rustdesk): This is an open-source TeamViewer or AnyDesk. You can use this to have other people control your container if you need to.

[Weylus](https://github.com/H-M-H/Weylus): This is a very interesting project, and has many technologies in common. Use this if you want to turn your tablet or smartphone to a graphic tablet for your PC.

[GamingAnywhere](https://github.com/chunying/gaminganywhere): This is the father of all open-source remote desktop and game streaming protocols. However, it has been created a long time ago and thus reached its end of life.

### Troubleshooting

#### The container doesn't work.

Check that the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) is configured in the host. If you did that, scroll down.

#### I want to use a specific GPU for OpenGL rendering when I have multiple GPUs in one container.

Use the `VGL_DISPLAY` environment variable, but only do so after you understand what it implicates with VirtualGL. Valid values are either `egl[n]`, or `/dev/dri/card[n]` only when `--device=/dev/dri` was used for the container (`[n]` is the order of the GPUs, where simply `egl` without the number is the same as `egl0`). Note that `docker --gpus 1` means any single GPU, not the GPU device ID of 1. Use `docker --gpus '"device=1,2"'` to provision GPUs with device IDs 1 and 2 to the container.

#### Vulkan does not work.

Make sure that the `NVIDIA_DRIVER_CAPABILITIES` environment variable is set to `all` or includes all of `utility`, `graphics`, `video`, and `display`. The `display` capability is especially crucial to Vulkan, but the container does start without `display`, even with its name. AMD and Intel GPUs are not tested and therefore Vulkan is not guaranteed to work. A Vulkan ICD file is probably required to be added. People are welcome to share their experiences, however.

---
This project involved a collaboration effort with [Itopia](https://itopia.com)'s [Dan Isla](https://github.com/danisla) (founder of the [Selkies Project](https://github.com/selkies-project)), incorporating the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC remote desktop streaming application. Commercial support for this container may be available from [Itopia](https://itopia.com).

This work was supported in part by NSF awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, OAC-2112167, CNS-2120019, the University of California Office of the President, and the University of California San Diego's California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
