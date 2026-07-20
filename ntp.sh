#!/bin/bash

set -e

SERVICE_NAME="ntp-manager"

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"


echo_color(){
    echo -e "${1}${2}${RESET}"
}


check_root(){

if [ "$EUID" != "0" ]; then
    echo_color $RED "请使用 root 执行"
    exit 1
fi

}



detect_os(){

if [ -f /etc/os-release ]; then

    . /etc/os-release

    OS=$ID
    VERSION=$VERSION_ID

else

    echo_color $RED "无法识别系统"
    exit 1

fi


echo

echo_color $GREEN "系统:"
echo "$PRETTY_NAME"

}



install_pkg(){

case "$OS" in


debian|ubuntu)

    apt update

    ;;


centos|rhel|rocky|almalinux|openEuler|anolis|alinux|tencentos)

    yum makecache || dnf makecache

    ;;

esac

}



install_time_service(){


case "$OS" in


debian|ubuntu)


echo_color $YELLOW "使用 systemd-timesyncd"


if ! command -v timedatectl >/dev/null
then

apt install -y systemd

fi


SERVICE="systemd-timesyncd"


;;



centos|rhel|rocky|almalinux|openEuler|anolis|alinux|tencentos)


echo_color $YELLOW "使用 chrony"


if ! command -v chronyd >/dev/null
then

yum install -y chrony || dnf install -y chrony

fi


SERVICE="chronyd"


;;


*)

echo_color $RED "未知系统，尝试 chrony"

yum install -y chrony || true

SERVICE="chronyd"


;;

esac


}




input_ntp(){


echo

echo_color $GREEN "请输入NTP服务器"

echo "例如:"
echo "ntp.aliyun.com"
echo "ntp.tencent.com"
echo "ntp1.bdtime.cn (北斗)"

echo

read -p "NTP地址(多个空格分开): " NTP


if [ -z "$NTP" ];then

NTP="ntp.aliyun.com ntp.tencent.com ntp1.bdtime.cn"

fi


}



config_time(){


timedatectl set-timezone Asia/Shanghai



if [ "$SERVICE" = "systemd-timesyncd" ];then


cat >/etc/systemd/timesyncd.conf <<EOF

[Time]
NTP=$NTP
FallbackNTP=ntp.aliyun.com ntp.tencent.com ntp1.bdtime.cn
EOF


systemctl enable systemd-timesyncd
systemctl restart systemd-timesyncd



else



cp /etc/chrony.conf /etc/chrony.conf.bak 2>/dev/null || true


sed -i '/^server/d' /etc/chrony.conf
sed -i '/^pool/d' /etc/chrony.conf



for n in $NTP
do

echo "server $n iburst" >> /etc/chrony.conf

done



systemctl enable chronyd
systemctl restart chronyd


fi



}




create_command(){


cat >/usr/local/bin/ntp <<'EOF'

#!/bin/bash


echo "================================"
echo "       NTP 时间同步控制面板"
echo "================================"


echo

echo "当前时间:"
date


echo

echo "同步状态:"
timedatectl status


echo

echo "================================"
echo "NTP服务器"
echo "================================"


if command -v chronyc >/dev/null
then

chronyc sources -v

else

systemctl status systemd-timesyncd --no-pager

fi



echo

echo "================================"
echo "北斗时间源"
echo "================================"


echo "推荐:"
echo "ntp1.bdtime.cn"
echo "ntp2.bdtime.cn"


echo

echo "IPv4:"
curl -4 -s ip.sb || true


echo

echo "IPv6:"
curl -6 -s ip.sb || true


echo

echo "================================"

EOF


chmod +x /usr/local/bin/ntp



}



show_status(){


echo

echo_color $GREEN "配置完成"

echo

timedatectl status


echo

echo "输入:"
echo

echo " ntp "

echo

echo "进入时间同步控制面板"


}



main(){


check_root

detect_os

install_pkg

install_time_service

input_ntp

config_time

create_command

show_status


}


main
