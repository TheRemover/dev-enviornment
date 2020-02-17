#!/bin/bash

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

apt-get update > /dev/null
echo "Installing XFCE"
DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils > /dev/null
echo "Installing XRDP"
apt install -y xrdp > /dev/null
echo "Configuring XRDP"
adduser xrdp ssl-cert 
echo "exec startxfce4" >> /etc/xrdp/xrdp.ini
sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config