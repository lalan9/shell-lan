#!/bin/bash
# ====================================================
# IPv4 / IPv6 优先级切换脚本
# 支持 Debian / Ubuntu / CentOS / KVM / OpenVZ / LXC
#
# 1 = IPv4 优先
# 2 = IPv6 优先
# ====================================================

echo "======================================"
echo " IPv4 / IPv6 优先级设置"
echo "======================================"

echo ""
echo "请选择网络优先级："
echo "1) IPv4 优先"
echo "2) IPv6 优先"
echo ""

read -p "请输入选项 [1-2]: " CHOICE


GAI_CONF="/etc/gai.conf"


# 备份
if [ -f "$GAI_CONF" ] && [ ! -f "${GAI_CONF}.bak" ]; then
    cp "$GAI_CONF" "${GAI_CONF}.bak"
    echo "✔ 已备份 $GAI_CONF"
fi


case $CHOICE in


1)

echo ""
echo ">>> 设置 IPv4 优先"

cat > "$GAI_CONF" <<EOF
# IPv4 Priority

precedence ::1/128       50
precedence ::/0          40
precedence ::ffff:0:0/96 100
precedence 2002::/16     30
precedence 2001::/32      5
EOF


echo "✔ IPv4 优先设置完成"

;;


2)

echo ""
echo ">>> 设置 IPv6 优先"

cat > "$GAI_CONF" <<EOF
# IPv6 Priority

precedence ::1/128       50
precedence ::/0          100
precedence ::ffff:0:0/96 10
precedence 2002::/16     30
precedence 2001::/32      5
EOF


echo "✔ IPv6 优先设置完成"

;;


*)

echo "❌ 输入错误，请输入 1 或 2"
exit 1

;;

esac



echo ""
echo "======================================"
echo " 当前 DNS"
echo "======================================"

grep -E "^(nameserver|search|options)" /etc/resolv.conf || echo "无"


echo ""
echo "======================================"
echo " 默认出口测试"
echo "======================================"

curl -s --connect-timeout 5 https://icanhazip.com || echo "失败"



echo ""
echo "======================================"
echo " IPv4 测试"
echo "======================================"

curl -4 -s --connect-timeout 5 https://icanhazip.com || echo "IPv4失败"



echo ""
echo "======================================"
echo " IPv6 测试"
echo "======================================"

curl -6 -s --connect-timeout 5 https://icanhazip.com || echo "IPv6失败"



echo ""
echo "======================================"
echo " DNS 优先级验证"
echo "======================================"

getent ahosts google.com | awk '{print $1}' | uniq


echo ""
echo "======================================"
echo " 完成 ✅"
echo " 当前模式:"
case $CHOICE in
1)
echo "IPv4 优先"
;;
2)
echo "IPv6 优先"
;;
esac

echo "======================================"
