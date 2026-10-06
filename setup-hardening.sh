#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor
# OpenWrt 23.05+ (fw4 / nftables) 校园网防共享检测与网络层加固一键配置脚本
# 项目主页: https://github.com/your-username/ESurfing-OpenWrt-Armor
# 适用固件: OpenWrt 23.05 或更高版本 (基于 fw4 / nftables 防火墙架构)
# ==============================================================================

set -e

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

info() {
    printf "${COLOR_GREEN}[INFO] %s${COLOR_RESET}\n" "$1"
}

warn() {
    printf "${COLOR_YELLOW}[WARN] %s${COLOR_RESET}\n" "$1"
}

error() {
    printf "${COLOR_RED}[ERROR] %s${COLOR_RESET}\n" "$1"
}

echo "============================================================"
echo "    OpenWrt 校园网防共享检测与网络加固配置程序"
echo "============================================================"

# 1. 检查运行环境
if [ "$(id -u)" -ne 0 ]; then
    error "本脚本必须以 root 权限运行，请先执行 su 或 sudo su"
    exit 1
fi

if ! command -v fw4 >/dev/null 2>&1; then
    warn "未检测到 fw4 命令，当前系统可能不是 OpenWrt 23.05+，nftables 规则可能无法生效！"
fi

# 2. 配置出向 TTL & IPv6 Hop Limit = 64
info "步骤 1/4: 配置出向数据包 TTL / Hop Limit 强制锁定为 64..."
mkdir -p /etc/nftables.d
cat << 'EOF' > /etc/nftables.d/40-ttl-mangle.nft
# OpenWrt 23.05 (fw4 / nftables)
# Custom mangle rule for fixing outgoing TTL and IPv6 Hop Limit to 64
chain mangle_postrouting_ttl {
	type filter hook postrouting priority 300; policy accept;
	oifname "wan" ip ttl set 64 counter
	oifname "wan" ip6 hoplimit set 64 counter
}
EOF
info "-> 已生成 /etc/nftables.d/40-ttl-mangle.nft"

# 3. 启用本地 NTP 授时服务并配置局域网 NTP 劫持
info "步骤 2/4: 配置本地 NTP 授时与局域网 UDP 123 流量重定向..."
uci set system.ntp.enable_server='1'
uci commit system
/etc/init.d/sysntpd restart >/dev/null 2>&1 || true

# 检查是否已存在名为 Redirect-NTP 的防火墙规则，避免重复添加
EXISTING_RULE=""
for i in $(seq 0 20); do
    RULE_NAME=$(uci get firewall.@redirect[$i].name 2>/dev/null || true)
    if [ "$RULE_NAME" = "Redirect-NTP" ]; then
        EXISTING_RULE="$i"
        break
    fi
done

if [ -z "$EXISTING_RULE" ]; then
    uci add firewall redirect >/dev/null
    uci set firewall.@redirect[-1].name='Redirect-NTP'
    uci set firewall.@redirect[-1].src='lan'
    uci set firewall.@redirect[-1].proto='udp'
    uci set firewall.@redirect[-1].src_dport='123'
    uci set firewall.@redirect[-1].dest_port='123'
    uci set firewall.@redirect[-1].target='DNAT'
    uci commit firewall
    info "-> 已添加防火墙 NTP 局域网劫持规则 (Redirect-NTP)"
else
    info "-> 防火墙规则 Redirect-NTP 已存在，跳过重复创建"
fi

# 4. 关闭 UPnP 与 LLTD 拓扑发现
info "步骤 3/4: 关闭 UPnP、LLTD 等局域网暴露特征服务..."
if [ -f /etc/config/upnpd ]; then
    uci set upnpd.config.enabled='0' 2>/dev/null || true
    uci commit upnpd 2>/dev/null || true
fi
if [ -f /etc/init.d/miniupnpd ]; then
    /etc/init.d/miniupnpd stop 2>/dev/null || true
    /etc/init.d/miniupnpd disable 2>/dev/null || true
fi

if [ -f /etc/init.d/lltd ]; then
    /etc/init.d/lltd stop 2>/dev/null || true
    /etc/init.d/lltd disable 2>/dev/null || true
fi
info "-> UPnP 与 LLTD 服务已禁用"

# 5. 关闭 WAN 口 Ping 响应 (Allow-Ping)
info "步骤 4/5: 关闭 WAN 口 ICMP Ping 响应..."
ALLOW_PING_IDX=""
for i in $(seq 0 20); do
    RULE_NAME=$(uci get firewall.@rule[$i].name 2>/dev/null || true)
    if [ "$RULE_NAME" = "Allow-Ping" ]; then
        ALLOW_PING_IDX="$i"
        break
    fi
done

if [ -n "$ALLOW_PING_IDX" ]; then
    uci set firewall.@rule["$ALLOW_PING_IDX"].enabled='0'
    uci commit firewall
    info "-> 已禁用 WAN 口 Allow-Ping 规则"
else
    warn "-> 未在 firewall 配置中找到名为 Allow-Ping 的规则，请按需手动检查"
fi

# 6. 关闭硬件流量加速 (保留软件流加速，防止硬件 NAT 绕过防火墙导致出向 TTL 伪装穿透)
info "步骤 5/6: 优化流量转发加速策略 (关闭硬件加速，确保出向 TTL 100% 被改写)..."
if uci get firewall.@defaults[0].flow_offloading_hw >/dev/null 2>&1; then
    uci set firewall.@defaults[0].flow_offloading_hw='0'
    uci commit firewall
    info "-> 已禁用 flow_offloading_hw (杜绝硬件 PPE 绕过 Netfilter)"
fi

# 7. 部署断网秒级自愈看门狗与清晨 48 小时租期预防性刷新
info "步骤 6/6: 配置断网秒级自愈看门狗与 48 小时租期预防性刷新计划..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/esurfing-watchdog.sh" ]; then
    cp "$SCRIPT_DIR/esurfing-watchdog.sh" /usr/bin/esurfing-watchdog.sh
    chmod +x /usr/bin/esurfing-watchdog.sh
    info "-> 已安装自愈看门狗脚本至 /usr/bin/esurfing-watchdog.sh"
fi

mkdir -p /etc/crontabs
touch /etc/crontabs/root
if ! grep -q 'esurfing-watchdog.sh' /etc/crontabs/root 2>/dev/null; then
    cat << 'EOF' >> /etc/crontabs/root
# 每天清晨 05:30 静默轮换一次会话，重置电信 48 小时租期，避开白天/晚间断网
30 5 * * * /etc/init.d/esurfingclient restart >/dev/null 2>&1
# 每 2 分钟网络健康看门狗：断网自动秒级自愈，打破指数退避长等待
*/2 * * * * /usr/bin/esurfing-watchdog.sh >/dev/null 2>&1
EOF
    /etc/init.d/cron restart >/dev/null 2>&1 || true
    info "-> 已注入清晨防踢线与自愈看门狗计划任务"
else
    info "-> 计划任务已存在，跳过重复写入"
fi

# 8. 重启防火墙使规则生效
info "正在重载防火墙服务 (fw4 restart)..."
/etc/init.d/firewall restart >/dev/null 2>&1

echo ""
echo "============================================================"
info "防共享检测与网络加固配置已成功应用！"
echo "============================================================"
echo "你可以使用以下命令验证加固状态："
echo "  1. 验证 TTL 改写计数:   nft list chain inet fw4 mangle_postrouting_ttl"
echo "  2. 验证 NTP 服务状态:   netstat -anu | grep :123"
echo "  3. 运行完整诊断脚本:   sh check-status.sh"
echo "============================================================"
