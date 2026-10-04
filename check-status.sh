#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor
# OpenWrt 广东天翼校园网认证与防检测网关一键健康诊断脚本
# 项目主页: https://github.com/your-username/ESurfing-OpenWrt-Armor
# ==============================================================================

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

pass() {
    printf "  [${COLOR_GREEN}PASS${COLOR_RESET}] %s\n" "$1"
}

warn() {
    printf "  [${COLOR_YELLOW}WARN${COLOR_RESET}] %s\n" "$1"
}

fail() {
    printf "  [${COLOR_RED}FAIL${COLOR_RESET}] %s\n" "$1"
}

info() {
    printf "${COLOR_CYAN}[INFO] %s${COLOR_RESET}\n" "$1"
}

echo "============================================================"
echo "    OpenWrt 校园网网关状态与防多设备检测自检程序"
echo "============================================================"
echo ""

# 1. 检查 WAN 口物理链路与 MAC 克隆
info "1. 检查 WAN 口物理网卡与 IP 配置..."
WAN_IFNAME=$(uci get network.wan.device 2>/dev/null || uci get network.wan.ifname 2>/dev/null || echo "wan")
CONFIG_MAC=$(uci get network.wan.macaddr 2>/dev/null || echo "未设置")
ACTIVE_MAC=$(cat /sys/class/net/$WAN_IFNAME/address 2>/dev/null || ip link show dev wan 2>/dev/null | grep -oE "link/ether [0-9a-f:]{17}" | awk '{print $2}' || echo "未知")

WAN_IPV4=$(ip -4 addr show dev $WAN_IFNAME 2>/dev/null | grep -oE "inet [0-9.]+" | awk '{print $2}' || echo "")
WAN_IPV6=$(ip -6 addr show dev $WAN_IFNAME scope global 2>/dev/null | grep -oE "inet6 [0-9a-f:]+" | awk '{print $2}' | head -n1 || echo "")

if [ -n "$WAN_IPV4" ]; then
    pass "WAN 口 IPv4 已获取: $WAN_IPV4"
else
    fail "WAN 口未获取到 IPv4 地址，请检查网线连接与校园网 DHCP"
fi

if [ -n "$WAN_IPV6" ]; then
    pass "WAN 口 IPv6 已获取: $WAN_IPV6"
else
    warn "WAN 口无公网 IPv6 (若校园网不支持 IPv6 可忽略)"
fi

if [ "$CONFIG_MAC" != "未设置" ] && [ "$CONFIG_MAC" = "$ACTIVE_MAC" ]; then
    pass "WAN 口 MAC 克隆已生效: $ACTIVE_MAC"
elif [ "$CONFIG_MAC" = "未设置" ]; then
    warn "未配置 WAN 口 MAC 克隆 (当前 MAC: $ACTIVE_MAC)"
else
    warn "配置文件 MAC ($CONFIG_MAC) 与当前网卡生效 MAC ($ACTIVE_MAC) 不一致，建议执行 ifdown wan && ifup wan"
fi

echo ""

# 2. 检查拨号进程 esurfingclient 状态
info "2. 检查天翼校园客户端进程 (esurfingclient)..."
ESURFING_PID=$(pgrep -f "/usr/bin/esurfingclient" 2>/dev/null || pgrep esurfingclient 2>/dev/null || true)

if [ -n "$ESURFING_PID" ]; then
    pass "esurfingclient 进程正在运行 (PID: $ESURFING_PID)"
else
    fail "esurfingclient 未运行，请检查 /etc/init.d/esurfingclient start"
fi

LOG_FILE="/var/log/esurfing/logs/logs/run.log"
if [ -f "$LOG_FILE" ]; then
    pass "找到认证日志文件: $LOG_FILE"
    echo "  --- 最近 3 条运行日志 ---"
    tail -n 3 "$LOG_FILE" | while read -r line; do
        echo "  | $line"
    done
    echo "  -------------------------"
else
    warn "未找到运行日志 $LOG_FILE (若刚启动或未开调试日志可忽略)"
fi

echo ""

# 3. 检查防共享检测加固 (fw4 / nftables)
info "3. 检查网络层防检测规则 (TTL 锁定 / NTP 劫持)..."

# 3.1 检查出向 TTL 改写规则
if command -v nft >/dev/null 2>&1; then
    TTL_RULE=$(nft list chain inet fw4 mangle_postrouting_ttl 2>/dev/null || true)
    if [ -n "$TTL_RULE" ]; then
        PACKETS_COUNT=$(echo "$TTL_RULE" | grep -oE "counter packets [0-9]+" | head -n1 | awk '{print $3}')
        pass "出向 TTL=64 / Hop Limit=64 规则已生效 (已改写 $PACKETS_COUNT 个数据包)"
    else
        fail "未检测到 mangle_postrouting_ttl 规则链，请检查 /etc/nftables.d/40-ttl-mangle.nft"
    fi
else
    warn "系统未安装 nftables 命令行工具，跳过链检查"
fi

# 3.2 检查 NTP 授时服务与端口
NTP_PORT=$(netstat -anu 2>/dev/null | grep ":123 " || true)
if [ -n "$NTP_PORT" ]; then
    pass "路由器本地 NTP 授时服务 (UDP 123) 正常监听"
else
    warn "路由器本地 NTP 服务未监听 UDP 123，请检查 /etc/init.d/sysntpd status"
fi

# 3.3 检查 NTP 局域网重定向
NTP_REDIRECT=$(uci show firewall 2>/dev/null | grep "Redirect-NTP" || true)
if [ -n "$NTP_REDIRECT" ]; then
    pass "防火墙局域网 NTP 重定向规则已就绪"
else
    warn "未找到名为 Redirect-NTP 的防火墙规则"
fi

# 3.4 检查 UPnP / LLTD 暴露特征
UPNP_STATUS=$(uci get upnpd.config.enabled 2>/dev/null || echo "0")
if [ "$UPNP_STATUS" = "0" ]; then
    pass "UPnP 服务已禁用 (防局域网暴露)"
else
    warn "UPnP 服务仍处于启用状态，建议运行 setup-hardening.sh 禁用"
fi

# 3.5 检查 WAN 口 ICMP Ping 响应
ALLOW_PING=$(uci show firewall 2>/dev/null | grep "Allow-Ping" | grep -v "\.enabled='0'" || true)
if [ -z "$ALLOW_PING" ]; then
    pass "WAN 口外网 ICMP Ping 响应已关闭 (防网络扫描探测)"
else
    warn "WAN 口仍开启了 Allow-Ping 响应规则"
fi

echo ""

# 4. 外网联通性检测
info "4. 测试公网真实联通性..."
if ping -c 2 -W 3 223.5.5.5 >/dev/null 2>&1; then
    pass "公共 DNS (223.5.5.5) 连通测试通过"
else
    fail "无法 ping 通公共 DNS 223.5.5.5，请检查网络认证状态"
fi

HTTP_CODE=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "http://connect.rom.miui.com/generate_204" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "204" ]; then
    pass "HTTP 探测 (generate_204) 返回 204，网络已完全打通且无 Portal 网页拦截！"
elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    fail "HTTP 探测发生 302 重定向，当前网络被 Portal 拦截，说明客户端未认证成功或欠费"
else
    warn "HTTP 探测返回代码: $HTTP_CODE"
fi

echo ""
echo "============================================================"
info "自检流程完成！"
echo "============================================================"
