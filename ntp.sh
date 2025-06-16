#!/bin/bash

# 脚本功能：自动配置系统时区为北京时间，并启用NTP时间同步
# 兼容系统：Debian 11/12, CentOS 7.9
# 使用方法：sudo ./sync_time.sh

set -e

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误：此脚本必须使用root权限运行！${NC}" >&2
    exit 1
fi

# 检测系统类型
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
    OS="centos"
else
    echo -e "${RED}错误：不支持的操作系统！${NC}" >&2
    exit 1
fi

# 设置时区为Asia/Shanghai
echo -e "${YELLOW}[1/3] 设置时区为 Asia/Shanghai...${NC}"
timedatectl set-timezone Asia/Shanghai || {
    # 如果timedatectl不可用（如CentOS 7最小安装），使用传统方法
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo -e "${YELLOW}使用传统方法设置时区${NC}"
}

# 安装并配置NTP服务
echo -e "${YELLOW}[2/3] 配置NTP时间同步...${NC}"
case $OS in
    debian)
        # Debian使用systemd-timesyncd或chrony
        if ! command -v timedatectl &> /dev/null; then
            apt update && apt install -y systemd
        fi
        apt update && apt install -y chrony || {
            echo -e "${YELLOW}安装chrony失败，尝试使用systemd-timesyncd${NC}"
            apt install -y systemd-timesyncd
        }
        systemctl enable --now chronyd || systemctl enable --now systemd-timesyncd
        ;;
    centos)
        # CentOS 7使用ntpd或chrony
        if grep -q "CentOS Linux release 7" /etc/centos-release; then
            yum install -y chrony || yum install -y ntp
            systemctl enable --now chronyd || {
                systemctl enable --now ntpd
                ntpdate pool.ntp.org
            }
        else
            # CentOS 8+默认使用chrony
            yum install -y chrony
            systemctl enable --now chronyd
        fi
        ;;
esac

# 强制同步时间（针对首次运行）
echo -e "${YELLOW}[3/3] 强制同步时间...${NC}"
if command -v chronyc &> /dev/null; then
    chronyc makestep
elif command -v ntpdate &> /dev/null; then
    ntpdate pool.ntp.org
elif command -v timedatectl &> /dev/null; then
    timedatectl set-ntp true
fi

# 验证结果
echo -e "\n${GREEN}验证时间配置：${NC}"
timedatectl status 2>/dev/null || {
    echo -e "${YELLOW}当前时间：$(date)${NC}"
    echo -e "${YELLOW}时区：$(ls -l /etc/localtime | awk '{print $NF}')${NC}"
}

echo -e "\n${GREEN}[完成] 时间同步配置成功！${NC}"
