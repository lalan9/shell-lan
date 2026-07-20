#!/bin/bash

# ====================================================
# SSH端口 + root登录设置脚本
#
# 支持:
# Debian 9-13
# Ubuntu 18.04-24.04
# CentOS 7/8/Stream
# Rocky Linux
# AlmaLinux
# openEuler 欧拉
# Anolis OS
# Alibaba Cloud Linux
# TencentOS
# 麒麟 / UOS 等国产Linux
# ====================================================


# ----------颜色----------

color_echo(){

case $1 in

red)
COLOR="\033[31m\033[01m"
;;

green)
COLOR="\033[32m\033[01m"
;;

yellow)
COLOR="\033[33m\033[01m"
;;

*)
COLOR="\033[0m"
;;

esac

echo -e "${COLOR}$2\033[0m"

}



# ----------检测包管理----------

detect_package(){

if command -v apt >/dev/null 2>&1
then

PKG="apt"
INSTALL="apt -y install"
UPDATE="apt update"

elif command -v dnf >/dev/null 2>&1
then

PKG="dnf"
INSTALL="dnf -y install"
UPDATE="dnf makecache"

elif command -v yum >/dev/null 2>&1
then

PKG="yum"
INSTALL="yum -y install"
UPDATE="yum makecache"

elif command -v zypper >/dev/null 2>&1
then

PKG="zypper"
INSTALL="zypper -n install"
UPDATE="zypper refresh"

else

color_echo red "不支持的系统，没有找到软件包管理器"
exit 1

fi

}



# ----------系统检测----------

detect_system(){

if [ -f /etc/os-release ]
then

. /etc/os-release

OS=$ID
NAME=$PRETTY_NAME

else

OS="unknown"

fi


echo
color_echo yellow "检测系统:"
echo "$NAME"


case "$OS" in

debian|ubuntu)

SYSTEM="Debian/Ubuntu"

;;

centos|rhel|rocky|almalinux|fedora)

SYSTEM="RHEL/CentOS系列"

;;

openEuler|openeuler)

SYSTEM="openEuler欧拉"

;;

anolis)

SYSTEM="Anolis"

;;

uos|kylin|neokylin)

SYSTEM="国产Linux"

;;

*)

SYSTEM="其他Linux"

;;

esac


color_echo green "系统类型: $SYSTEM"


detect_package


}



# ----------安装SSH----------

install_ssh(){

if ! command -v sshd >/dev/null 2>&1
then

color_echo yellow "正在安装openssh..."

$UPDATE

$INSTALL openssh-server openssh-client

fi


}



# ----------输入----------

read_input(){

echo

read -p "输入SSH端口(默认22): " sshport

sshport=${sshport:-22}


read -p "输入root密码(留空自动生成): " password


if [ -z "$password" ]
then

password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

fi


}



# ----------SSH配置----------

configure_ssh(){


SSH_CONFIG="/etc/ssh/sshd_config"


cp $SSH_CONFIG ${SSH_CONFIG}.bak.$(date +%F-%H%M)


# Port

grep -q "^Port" $SSH_CONFIG \
&& sed -i "s/^Port.*/Port $sshport/" $SSH_CONFIG \
|| echo "Port $sshport" >> $SSH_CONFIG



# root登录

sed -i \
's/^#\?PermitRootLogin.*/PermitRootLogin yes/' \
$SSH_CONFIG


grep -q "^PermitRootLogin" $SSH_CONFIG \
|| echo "PermitRootLogin yes" >> $SSH_CONFIG



# 密码登录

sed -i \
's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
$SSH_CONFIG


grep -q "^PasswordAuthentication" $SSH_CONFIG \
|| echo "PasswordAuthentication yes" >> $SSH_CONFIG



# 设置密码

echo "root:$password" | chpasswd



}



# ----------重启SSH----------

restart_ssh(){


if systemctl list-unit-files | grep -q ssh.service
then

systemctl restart ssh

elif systemctl list-unit-files | grep -q sshd.service
then

systemctl restart sshd

else

service ssh restart || service sshd restart

fi


}



# ----------防火墙提醒----------

firewall_notice(){

echo

color_echo yellow "注意:"
echo "如果开启云防火墙，请放行端口: $sshport"


if command -v firewall-cmd >/dev/null 2>&1
then

firewall-cmd --permanent \
--add-port=${sshport}/tcp >/dev/null 2>&1

firewall-cmd --reload >/dev/null 2>&1

fi


if command -v ufw >/dev/null 2>&1
then

ufw allow $sshport/tcp >/dev/null 2>&1

fi


}



# ----------主程序----------

main(){

clear

color_echo green "
=================================
 SSH ROOT登录配置工具
=================================
"


detect_system

install_ssh

read_input

configure_ssh

restart_ssh

firewall_notice



echo

color_echo green "=============================="
color_echo green "设置完成"
echo
color_echo yellow "SSH端口: $sshport"
color_echo yellow "用户名: root"
color_echo yellow "密码: $password"
color_echo green "=============================="


}


main
