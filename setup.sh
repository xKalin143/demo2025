#!/bin/bash

apt-get update && apt-get install nano iptables tzdata nginx -y

echo "ISP" > /etc/hostname
echo "HOSTNAME=ISP" > /etc/sysconfig/network

cd /etc/net/ifaces/
cp -r ens33 ens34
cp -r ens33 ens35

cat <<EOF > /etc/net/ifaces/ens34/options
BOOTPROTO=static
TYPE=eth
SYSTEMD_BOOTPROTO=static
CONFIG_IPV4=yes
EOF

echo "172.16.40.1/28" > /etc/net/ifaces/ens34/ipv4address

cp /etc/net/ifaces/ens34/options /etc/net/ifaces/ens35/options
echo "172.16.50.1/28" > /etc/net/ifaces/ens35/ipv4address

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

iptables -t nat -A POSTROUTING -s 172.16.40.0/28 -o ens33 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.50.0/28 -o ens33 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

service iptables start
echo "@reboot root service iptables start" >> /etc/crontab

ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime

reboot