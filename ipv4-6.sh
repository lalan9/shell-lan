#!/bin/bash
# ====================================================
# IPv4 优先 + IPv6 保留（Debian 11/12 / CentOS 7/8）
# 显示当前 DNS + IPv4 / IPv6 出口测试
# ====================================================

set -e

echo "======================================"
echo " 开始设置：IPv4 优先（保留 IPv6）"
echo "======================================"

GAI_CONF="/etc/gai.conf"

# ---------- 检查系统 ----------
if [ ! -f "$GAI_CONF" ]; then
    echo "❌ 未找到 $GAI_CONF，系统不支持 gai.conf"
    exit 1
fi

# ---------- 备份 ----------
if [ ! -f "${GAI_CONF}.bak" ]; then
    cp "$GAI_CONF" "${GAI_CONF}.bak"
    echo "✔ 已备份 $GAI_CONF -> ${GAI_CONF}.bak"
else
    echo "✔ 备份文件已存在，跳过"
fi

# ---------- 设置 IPv4 优先 ----------
if grep -q "^precedence ::ffff:0:0/96 100" "$GAI_CONF"; then
    echo "✔ IPv4 优先已存在，无需修改"
else
    sed -i 's/^#precedence ::ffff:0:0\/96 100/precedence ::ffff:0:0\/96 100/' "$GAI_CONF"
    if ! grep -q "^precedence ::ffff:0:0/96 100" "$GAI_CONF"; then
        echo "precedence ::ffff:0:0/96 100" >> "$GAI_CONF"
    fi
    echo "✔ 已设置 IPv4 优先"
fi

# ---------- 显示当前 DNS ----------
echo
echo "======================================"
echo " 当前 DNS 服务器"
echo "======================================"
grep -E "^(nameserver|search|options)" /etc/resolv.conf || echo "未检测到 DNS"

# ---------- IPv4 / IPv6 出口测试 ----------
echo
echo "======================================"
echo " 当前 出口（curl test.ipw.cn）"
echo "======================================"
curl -4 -s --connect-timeout 5 https://test.ipw.cn || echo "IPv4 请求失败"

echo
echo "======================================"
echo " 当前 IPv6 出口（curl 6.ipw.cn）"
echo "======================================"
curl -6 -s --connect-timeout 5 https://6.ipw.cn || echo "IPv6 请求失败"

# ---------- getent 验证 ----------
echo
echo "======================================"
echo " DNS 解析优先级测试（getent ahosts）"
echo "======================================"
getent ahosts google.com | awk '{print $1}' | uniq

echo
echo "======================================"
echo " 设置完成 ✅"
echo " IPv4 已优先，IPv6 仍然可用"
echo "======================================"
