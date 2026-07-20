#!/bin/bash

set -e


echo "================================"
echo "       NTP 时间同步配置"
echo "       离线模式"
echo "================================"


# ----------------------------
# 输入 NTP
# ----------------------------

echo
echo "请输入 NTP 地址"
echo
echo "例如:"
echo "ntp.aliyun.com"
echo "ntp.tencent.com"
echo "ntp1.bdtime.cn (北斗)"
echo

read -p "NTP地址(多个空格分开): " NTP


if [ -z "$NTP" ];then
    NTP="ntp.aliyun.com ntp.tencent.com ntp1.bdtime.cn"
fi



# ----------------------------
# 检测同步工具
# ----------------------------


TYPE=""



# chrony

if command -v chronyc >/dev/null 2>&1; then

    if systemctl list-unit-files 2>/dev/null | grep -q chronyd; then

        TYPE="chrony"
        SERVICE="chronyd"

    elif systemctl list-unit-files 2>/dev/null | grep -q chrony; then

        TYPE="chrony"
        SERVICE="chrony"

    fi

fi



# systemd-timesyncd

if [ -z "$TYPE" ]; then

    if systemctl list-unit-files 2>/dev/null | grep -q systemd-timesyncd; then

        TYPE="timesyncd"
        SERVICE="systemd-timesyncd"

    fi

fi



# ntpd

if [ -z "$TYPE" ]; then

    if command -v ntpq >/dev/null 2>&1; then

        TYPE="ntpd"
        SERVICE="ntp"

    fi

fi



# ntpsec

if [ -z "$TYPE" ]; then

    if command -v ntpsec-ntpq >/dev/null 2>&1; then

        TYPE="ntpsec"
        SERVICE="ntpsec"

    fi

fi



if [ -z "$TYPE" ];then

    echo
    echo "================================"
    echo "没有检测到系统时间同步工具"
    echo "================================"
    echo
    echo "已存在:"
    echo " - chrony"
    echo " - systemd-timesyncd"
    echo " - ntpd"
    echo " - ntpsec"
    echo
    echo "脚本不会自动安装"
    exit 1

fi



echo
echo "检测到:"
echo "$TYPE"
echo



# ----------------------------
# 配置 chrony
# ----------------------------

if [ "$TYPE" = "chrony" ];then


echo "配置 chrony"


CONF="/etc/chrony.conf"


if [ -f /etc/chrony/chrony.conf ];then
    CONF="/etc/chrony/chrony.conf"
fi



cp "$CONF" "$CONF.bak.$(date +%F_%H%M%S)"


sed -i '/^server /d;/^pool /d' "$CONF"


for i in $NTP
do

echo "server $i iburst" >> "$CONF"

done



systemctl enable "$SERVICE" 2>/dev/null || true

systemctl restart "$SERVICE" 2>/dev/null || true



fi





# ----------------------------
# systemd-timesyncd
# ----------------------------

if [ "$TYPE" = "timesyncd" ];then


echo "配置 systemd-timesyncd"


mkdir -p /etc/systemd


cat >/etc/systemd/timesyncd.conf <<EOF

[Time]

NTP=$NTP

EOF



systemctl enable systemd-timesyncd 2>/dev/null || true

systemctl restart systemd-timesyncd 2>/dev/null || true


fi





# ----------------------------
# ntpd
# ----------------------------

if [ "$TYPE" = "ntpd" ];then


echo "配置 ntpd"


CONF="/etc/ntp.conf"


if [ -f "$CONF" ];then


cp "$CONF" "$CONF.bak.$(date +%F_%H%M%S)"


sed -i '/^server /d' "$CONF"



for i in $NTP
do

echo "server $i iburst" >> "$CONF"

done


systemctl enable ntp 2>/dev/null || true

systemctl restart ntp 2>/dev/null || true


fi


fi





# ----------------------------
# ntpsec
# ----------------------------

if [ "$TYPE" = "ntpsec" ];then


echo "配置 ntpsec"


CONF="/etc/ntpsec/ntp.conf"


cp "$CONF" "$CONF.bak.$(date +%F_%H%M%S)"


sed -i '/^server /d' "$CONF"



for i in $NTP
do

echo "server $i iburst" >> "$CONF"

done


systemctl enable ntpsec 2>/dev/null || true

systemctl restart ntpsec 2>/dev/null || true


fi





# ----------------------------
# 时区
# ----------------------------


timedatectl set-timezone Asia/Shanghai 2>/dev/null || true





# ----------------------------
# 创建控制面板
# ----------------------------


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
timedatectl


echo
echo "================================"
echo "当前同步源"
echo "================================"


if command -v chronyc >/dev/null 2>&1;then

chronyc sources -v


elif command -v ntpq >/dev/null 2>&1;then

ntpq -p


else

systemctl status systemd-timesyncd --no-pager

fi



echo
echo "================================"
echo "北斗时间源"
echo "================================"


echo "域名:"
echo "ntp1.bdtime.cn"
echo "ntp2.bdtime.cn"


echo

if command -v dig >/dev/null 2>&1;then

echo "IPv4:"
dig +short ntp1.bdtime.cn A


echo
echo "IPv6:"
dig +short ntp1.bdtime.cn AAAA

fi


echo

EOF


chmod +x /usr/local/bin/ntp





echo
echo "================================"
echo "配置完成"
echo "================================"


echo
echo "同步工具:"
echo "$TYPE"


echo
echo "输入:"
echo
echo " ntp "
echo
echo "查看同步状态"



echo

ntp
