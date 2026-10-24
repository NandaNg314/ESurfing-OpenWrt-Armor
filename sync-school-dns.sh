#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor - 学校 DNS 自动同步
#
# 用途
#   把校园网 DHCP 下发的「学校 DNS」自动同步为 smartdns 的上游之一，
#   防止校园网更换 DNS 地址后，v2.2.0 客户端陷入「认证↔DNS」死锁。
#
# 背景（详见 README FAQ Q7）
#   校园网在未认证状态下，Portal 会拦截所有公网 DNS，只放行学校自己的 DNS。
#   v2.2.0 移除了备用 IP 兜底，两个联网检测目标全是域名，
#   因此 DNS 一旦不可用，认证会在第一步直接 FATAL 退出。
#
# 设计要点
#   - IP 未变化时直接退出，不重启 smartdns（平时零开销、零打扰）
#   - 只认形似 IPv4 的地址，自动排除 ::1 等 IPv6
#   - 找不到 SchoolDNS 条目时自动新增，不会重复添加
#   - 变更时写 syslog，便于事后追溯
#
# 使用
#   1. 安装: cp sync-school-dns.sh /usr/bin/ && chmod 755 /usr/bin/sync-school-dns.sh
#   2. 挂钩: 见 README，或手动加到 /etc/hotplug.d/iface/ 让 WAN ifup 时触发
#   3. 手动跑一次: /usr/bin/sync-school-dns.sh
# ==============================================================================

RESOLV="/tmp/resolv.conf.d/resolv.conf.auto"
UCI_NAME="SchoolDNS"
TAG="sync-school-dns"

# 兼容部分固件的旧路径
[ -f "$RESOLV" ] || RESOLV="/tmp/resolv.conf.auto"

[ -f "$RESOLV" ] || exit 0

# 取第一个 nameserver（跳过注释行）
DNS=$(grep '^nameserver' "$RESOLV" 2>/dev/null | head -n1 | awk '{print $2}')

# 非空且形似 IPv4 才处理（排除 ::1 之类的 IPv6 地址）
case "$DNS" in
    ''|*[!0-9.]*) exit 0 ;;
esac

# 找现有的 SchoolDNS 条目索引
IDX=$(uci show smartdns 2>/dev/null \
      | grep -E "\.name='${UCI_NAME}'" \
      | sed -n "s/.*@server\[\([0-9]*\)\].*/\1/p" \
      | head -n1)

if [ -n "$IDX" ]; then
    CUR=$(uci get "smartdns.@server[$IDX].ip" 2>/dev/null)
    if [ "$CUR" = "$DNS" ]; then
        exit 0   # 没变化，什么都不做
    fi
    uci set "smartdns.@server[$IDX].ip=$DNS"
    logger -t "$TAG" "学校 DNS 变更: ${CUR:-空} -> $DNS"
else
    uci add smartdns server >/dev/null
    uci set smartdns.@server[-1].enabled='1'
    uci set smartdns.@server[-1].name="$UCI_NAME"
    uci set smartdns.@server[-1].port='53'
    uci set smartdns.@server[-1].type='udp'
    uci set smartdns.@server[-1].ip="$DNS"
    logger -t "$TAG" "已新增学校 DNS 上游: $DNS"
fi

uci commit smartdns

# 只有真的变了才重启 smartdns
/etc/init.d/smartdns restart >/dev/null 2>&1
logger -t "$TAG" "smartdns 已重启，生效上游: $DNS"
