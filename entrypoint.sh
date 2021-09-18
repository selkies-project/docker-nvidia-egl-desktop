#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

sudo chown -R user:user /home/user /opt/tomcat
echo "user:$PASSWD" | sudo chpasswd
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone > /dev/null
export PATH="${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin:/opt/tomcat/bin"

sudo /etc/init.d/ssh start
sudo /etc/init.d/dbus start
pulseaudio --start

mkdir -p ~/.vnc
echo "$PASSWD" | /opt/TurboVNC/bin/vncpasswd -f > ~/.vnc/passwd
chmod 0600 ~/.vnc/passwd

printf "3\nn\nx\n" | sudo /opt/VirtualGL/bin/vglserver_config
for DRM in /dev/dri/card*; do
  if /opt/VirtualGL/bin/eglinfo "$DRM"; then
    export VGL_DISPLAY="$DRM"
    break
  fi
done

export TVNC_WM=mate-session
/opt/TurboVNC/bin/vncserver :0 -geometry "${SIZEW}x${SIZEH}" -depth "$CDEPTH" -dpi 96 -vgl -alwaysshared -noreset &

mkdir -p ~/.guacamole
echo "<user-mapping>
    <authorize username=\"user\" password=\"$PASSWD\">
        <connection name=\"VNC\">
            <protocol>vnc</protocol>
            <param name=\"hostname\">localhost</param>
            <param name=\"port\">5900</param>
            <param name=\"autoretry\">10</param>
            <param name=\"password\">$PASSWD</param>
            <param name=\"enable-sftp\">true</param>
            <param name=\"sftp-hostname\">localhost</param>
            <param name=\"sftp-username\">user</param>
            <param name=\"sftp-password\">$PASSWD</param>
            <param name=\"sftp-directory\">/home/user</param>
            <param name=\"enable-audio\">true</param>
            <param name=\"audio-servername\">localhost</param>
        </connection>
        <connection name=\"SSH\">
            <protocol>ssh</protocol>
            <param name=\"hostname\">localhost</param>
            <param name=\"username\">user</param>
            <param name=\"password\">$PASSWD</param>
            <param name=\"enable-sftp\">true</param>
        </connection>
    </authorize>
</user-mapping>
" > ~/.guacamole/user-mapping.xml
chmod 0600 ~/.guacamole/user-mapping.xml

/opt/tomcat/bin/catalina.sh run &
guacd -b 0.0.0.0 -f &

echo "Session Running. Press [Return] to exit."
read
