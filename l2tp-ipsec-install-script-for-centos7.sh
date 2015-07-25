#!/bin/bash
####################################################
#                                                  #
# This is a L2TP VPN installation for CentOS 7     #
# Version: 1.1.0 20140803                          #
# Author: Travis Lee                               #
# Website: http://www.stunnel.info                 #
#                                                  #
####################################################
#安装依赖的组件
yum -y update
yum localinstall http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm -y
yum install -y firewalld openswan ppp xl2tpd wget

#检测是否是root用户
if [[ $(id -u) != "0" ]]; then
    printf "\e[42m\e[31mError: You must be root to run this install script.\e[0m\n"
    exit 1
fi

#检测是否是CentOS 7或者RHEL 7
if [[ $(grep "release 7." /etc/redhat-release 2>/dev/null | wc -l) -eq 0 ]]; then
    printf "\e[42m\e[31mError: Your OS is NOT CentOS 7 or RHEL 7.\e[0m\n"
    printf "\e[42m\e[31mThis install script is ONLY for CentOS 7 and RHEL 7.\e[0m\n"
    exit 1
fi
clear

printf "
####################################################
#                                                  #
# This is a L2TP VPN installation for CentOS 7     #
# Version: 1.2.0 20150725                          #
# Author: Elvis Cheng                              #
# Website: http://ash0080.gitcafe.io               #
#                                                  #
####################################################
"

#获取服务器IP
serverip=`hostname -i`
printf "\e[33m$serverip\e[0m is the server IP?"
printf "If \e[33m$serverip\e[0m is \e[33mcorrect\e[0m, press enter directly."
printf "If \e[33m$serverip\e[0m is \e[33mincorrect\e[0m, please input your server IP."
printf "(Default server IP: \e[33m$serverip\e[0m):"
read serveriptmp
if [[ -n "$serveriptmp" ]]; then
    serverip=$serveriptmp
fi

#获取网卡接口名称
ethlist=`ifconfig | grep ": flags" | cut -d ":" -f1`
eth=$(printf "$ethlist\n" | head -n 1)
if [[ $(printf "$ethlist\n" | wc -l) -gt 2 ]]; then
    echo ======================================
    echo "Network Interface list:"
    printf "\e[33m$ethlist\e[0m\n"
    echo ======================================
    echo "Which network interface you want to listen for ocserv?"
    printf "Default network interface is \e[33m$eth\e[0m, let it blank to use default network interface: "
    read ethtmp
    if [ -n "$ethtmp" ]; then
        eth=$ethtmp
    fi
fi

#设置VPN拨号后分配的IP段
iprange="10.0.1"
echo "Please input IP-Range:"
printf "(Default IP-Range: \e[33m$iprange\e[0m): "
read iprangetmp
if [[ -n "$iprangetmp" ]]; then
    iprange=$iprangetmp
fi

#设置预共享密钥
mypsk="stunnel.info"
echo "Please input PSK:"
printf "(Default PSK: \e[33mstunnel.info\e[0m): "
read mypsktmp
if [[ -n "$mypsktmp" ]]; then
    mypsk=$mypsktmp
fi

#设置VPN用户名
username="stunnel"
echo "Please input VPN username:"
printf "(Default VPN username: \e[33mstunnel\e[0m): "
read usernametmp
if [[ -n "$usernametmp" ]]; then
    username=$usernametmp
fi

#随机密码
randstr() {
    index=0
    str=""
    for i in {a..z}; do arr[index]=$i; index=$(expr ${index} + 1); done
    for i in {A..Z}; do arr[index]=$i; index=$(expr ${index} + 1); done
    for i in {0..9}; do arr[index]=$i; index=$(expr ${index} + 1); done
    for i in {1..10}; do str="$str${arr[$RANDOM%$index]}"; done
    echo $str
}

#设置VPN用户密码
password=$(randstr)
printf "Please input \e[33m$username\e[0m's password:\n"
printf "Default password is \e[33m$password\e[0m, let it blank to use default password: "
read passwordtmp
if [[ -n "$passwordtmp" ]]; then
    password=$passwordtmp
fi

clear

#打印配置参数
clear
echo "Server IP:"
echo "$serverip"
echo
echo "Server Local IP:"
echo "$iprange.1"
echo
echo "Client Remote IP Range:"
echo "$iprange.10-$iprange.254"
echo
echo "PSK:"
echo "$mypsk"
echo
echo "Press any key to start..."

get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
char=$(get_char)
clear
mknod /dev/random c 1 9

rm -f /etc/ipsec.conf
touch /etc/ipsec.conf
#创建ipsec.conf配置文件
cat >>/etc/ipsec.conf<<EOF
version 2.0
config setup
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    oe=off
    protostack=netkey

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=$serveripaddress
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
EOF

#设置预共享密钥配置文件
rm -f /etc/ipsec.secrets
touch /etc/ipsec.secrets
cat >>/etc/ipsec.secrets<<EOF
#include /etc/ipsec.d/*.secrets
$serverip %any: PSK "$mypsk"
EOF

#创建xl2tpd.conf配置文件
mkdir -p /etc/xl2tpd
rm -f /etc/xl2tpd/xl2tpd.conf
touch /etc/xl2tpd/xl2tpd.conf
cat >>/etc/xl2tpd/xl2tpd.conf<<EOF
[global]
ipsec saref = yes
[lns default]
ip range = $iprange.10-$iprange.254
local ip = $iprange.1
refuse chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

#创建options.xl2tpd配置文件
mkdir -p /etc/ppp
rm -f /etc/ppp/options.xl2tpd
touch /etc/ppp/options.xl2tpd
cat >>/etc/ppp/options.xl2tpd<<EOF
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
name $VPN_SERVICENAME
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
EOF

#创建chap-secrets配置文件，即用户列表及密码
rm -f /etc/ppp/chap-secrets
touch /etc/ppp/chap-secrets
cat >>/etc/ppp/chap-secrets<<EOF
# Secrets for authentication using CHAP
# client     server     secret               IP addresses
$username          l2tpd     $password               *
EOF

#修改系统配置，允许IP转发
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p
for each in /proc/sys/net/ipv4/conf/*
do
echo 0 > $each/accept_redirects
echo 0 > $each/send_redirects
done

#允许防火墙端口
cat >/usr/lib/firewalld/services/l2tpd.xml<<EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>l2tpd</short>
  <description>L2TP IPSec</description>
  <port protocol="udp" port="500"/>
  <port protocol="udp" port="4500"/>
  <port protocol="udp" port="1701"/>
</service>
EOF

service firewalld start
firewall-cmd --permanent --add-service=l2tpd
firewall-cmd --permanent --add-service=ipsec
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload
#iptables --table nat --append POSTROUTING --jump MASQUERADE
#iptables -t nat -A POSTROUTING -s $iprange.0/24 -o $eth -j MASQUERADE
#iptables -t nat -A POSTROUTING -s $iprange.0/24 -j SNAT --to-source $serverip
#service iptables save

#允许开机启动
systemctl enable firewalld ipsec xl2tpd
systemctl restart firewalld ipsec xl2tpd
clear

#测试ipsec
ipsec verify

printf "
####################################################
#                                                  #
# This is a L2TP VPN installation for CentOS 7     #
# Version: 1.1.0 20140803                          #
# Author: Travis Lee                               #
# Website: http://www.stunnel.info                 #
#                                                  #
####################################################
if there are no [FAILED] above, then you can
connect to your L2TP VPN Server with the default
user/password below:
ServerIP: $serverip
username: $username
password: $password
PSK: $mypsk
"
