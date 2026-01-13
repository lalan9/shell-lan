#!/bin/bash

set -e

echo "=== 检查系统类型 ==="
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
else
    echo "不支持的系统"
    exit 1
fi
echo "系统类型: $OS"

echo "=== 检查 systemd-timesyncd ==="
if systemctl list-unit-files | grep -q systemd-timesyncd.service; then
    echo "systemd-timesyncd 已存在"
else
    echo "systemd-timesyncd 不存在，开始安装..."
    if [ "$OS" = "debian" ]; then
        apt update
        apt install -y systemd-timesyncd
    elif [ "$OS" = "centos" ]; then
        echo "CentOS 不自带 systemd-timesyncd，建议使用 chrony 替代"
        yum install -y chrony
        echo "已安装 chrony，使用 chrony 同步 NTP"
        echo "server ntp1.aliyun.com iburst" >> /etc/chrony.conf
        echo "server ntp1.tencent.com iburst" >> /etc/chrony.conf
        systemctl enable chronyd --now
        echo "当前时间:"
        date
        exit 0
    fi
fi

echo "=== 配置 NTP 服务器 ==="
cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=ntp1.aliyun.com ntp1.tencent.com
EOF

echo "=== 启动并开机自启 systemd-timesyncd ==="
systemctl enable systemd-timesyncd --now

echo "=== 设置时区为上海 ==="
timedatectl set-timezone Asia/Shanghai

echo "=== 显示状态 ==="
timedatectl status
echo "当前系统时间:"
date
