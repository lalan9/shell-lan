#!/bin/bash
# ====================================================
# IPv4 优先 + IPv6 保留（兼容 KVM / OpenVZ / LXC 容器）
# 支持 Debian 11/12 / CentOS 7/8
# 显示当前 DNS + IPv4 / IPv6 出口测试
# ====================================================

set -e

echo "======================================"
echo " 开始设置：IPv4 优先（保留 IPv6）"
echo "======================================"

GAI_CONF="/etc/gai.conf"

# ---------- 1. 处理标准系统的 gai.conf ----------
if [ ! -f "$GAI_CONF" ]; then
    echo "⚠️ 未找到 $GAI_CONF，正在为你自动创建默认配置..."
    cat << EOF > "$GAI_CONF"
# /etc/gai.conf 默认配置（由脚本自动初始化）
precedence  ::1/128       50
precedence  ::/0          40
precedence  ::ffff:0:0/96 100
precedence  2002::/16     30
precedence  2001::/32      5
EOF
    echo "✔ $GAI_CONF 创建成功"
else
    if [ ! -f "${GAI_CONF}.bak" ]; then
        cp "$GAI_CONF" "${GAI_CONF}.bak"
        echo "✔ 已备份 $GAI_CONF -> ${GAI_CONF}.bak"
    fi

    if grep -q "^precedence ::ffff:0:0/96 100" "$GAI_CONF"; then
        echo "✔ $GAI_CONF 中 IPv4 优先已存在"
    else
        sed -i 's/^#precedence ::ffff:0:0\/96 100/precedence ::ffff:0:0\/96 100/' "$GAI_CONF"
        if ! grep -q "^precedence ::ffff:0:0/96 100" "$GAI_CONF"; then
            echo "precedence ::ffff:0:0/96 100" >> "$GAI_CONF"
        fi
        echo "✔ 已在 $GAI_CONF 中设置 IPv4 优先"
    fi
fi

# ---------- 2. 针对 CentOS 7 / OpenVZ / LXC 的双重保险别名设置 ----------
# 检查是否为 CentOS 7
if [ -f /etc/redhat-release ] && grep -q "release 7" /etc/redhat-release; then
    echo "ℹ 检测到 CentOS 7 系统，正在注入工具级 IPv4 别名以确保完全兼容..."
    
    # 写入全局 bashrc，防止 OpenVZ 容器下 gai.conf 失效
    if ! grep -q "alias curl='curl -4'" /etc/bashrc; then
        cat << 'EOF' >> /etc/bashrc

# IPv4 优先兼容性设置 (By Script)
alias curl='curl -4'
alias wget='wget -4'
EOF
        echo "✔ 已将 curl/wget 别名写入 /etc/bashrc"
    else
        echo "✔ curl/wget 别名已存在，跳过"
    fi
    
    # 让别名在当前运行的脚本进程中临时生效
    alias curl='curl -4'
    alias wget='wget -4'
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
echo " 当前 默认 出口测试"
echo "======================================"
# 这里去掉 -4，直接测试系统默认会不会走 IPv4
curl -s --connect-timeout 5 https://icanhazip.com || echo "默认出口请求失败"

echo
echo "======================================"
echo " 强制 IPv6 出口测试"
echo "======================================"
# 这里的 \curl 是为了绕过刚刚设置的别名，强制走纯 IPv6 测试
\curl -6 -s --connect-timeout 5 https://icanhazip.com || echo "IPv6 请求失败"

# ---------- getent 验证 ----------
echo
echo "======================================"
echo " DNS 解析优先级测试（getent ahosts）"
echo "======================================"
getent ahosts google.com | awk '{print $1}' | uniq || true

echo
echo "======================================"
echo " 设置完成 ✅"
echo " IPv4 已优先，IPv6 仍然可用"
echo " 注意：CentOS 7 用户请执行 'source /etc/bashrc' 刷新当前终端"
echo "======================================"
