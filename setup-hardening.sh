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

# 6. 关闭硬件流量加速 (保留软件流加速，防止硬件 NAT 绕过防火墙导致出向 TTL 伪装穿透，并避免 MT7621 等机型 PPE 崩溃硬重启)
info "步骤 5/6: 优化流量转发加速策略 (关闭硬件加速，确保出向 TTL 100% 被改写，杜绝内核 Panic)..."
if uci get firewall.@defaults[0].flow_offloading_hw >/dev/null 2>&1; then
    uci set firewall.@defaults[0].flow_offloading_hw='0'
    uci commit firewall
    info "-> 已禁用 flow_offloading_hw (杜绝硬件 PPE 绕过 Netfilter)"
fi

if [ -f /etc/config/turboacc ]; then
    uci set turboacc.config.hw_flow='0' 2>/dev/null || true
    uci set turboacc.config.hw_wed='0' 2>/dev/null || true
    uci commit turboacc 2>/dev/null || true
    info "-> 已禁用 turboacc 硬件加速 (杜绝 Turbo ACC 开机自动重新开启硬件流)"
fi

# 7. 清理历史遗留的主动断网/高频看门狗任务
info "步骤 6/6: 清理历史遗留的主动断网与高频看门狗定时任务..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 【设计说明】不再自动安装 esurfing-renew.sh / esurfing-watchdog.sh。
#   - renew: 每次执行都会 ifdown wan 主动断网 25s~数分钟, 曾造成 2 小时断网
#   - watchdog: 高频重启会打断新版客户端 6 阶自愈, 可能触发 35 分钟防频控休眠
# 新版客户端已自带原生 Watchdog + procd 监管, 不需要任何第三方守护脚本。
# 两个脚本仍保留在仓库中, 供确认线路存在租期硬顶时手动下载使用, 但不随本脚本部署。
if [ -f "$SCRIPT_DIR/esurfing-renew.sh" ] || [ -f "$SCRIPT_DIR/esurfing-watchdog.sh" ]; then
    info "-> 检测到仓库含 renew/watchdog 脚本, 已按当前策略跳过安装 (需要时请手动复制到 /usr/bin/)"
fi

# 严格保护账号配置文件权限 (chmod 600，兼容新旧路径)
CFG_DIR=$(uci -q get esurfingclient.config.dir 2>/dev/null || echo "/etc/esurfingclient")
[ -f "$CFG_DIR/ESurfingClient.json" ] && chmod 600 "$CFG_DIR/ESurfingClient.json" 2>/dev/null || true
[ -f "/etc/config/esurfingclient" ] && chmod 600 "/etc/config/esurfingclient" 2>/dev/null || true

mkdir -p /etc/crontabs
touch /etc/crontabs/root

# 清理历史遗留的高频看门狗任务 (v2.2.1+ 已自带原生单调钟 Watchdog 与 6 阶自愈，高频强杀会导致触发 35 分钟防频控休眠)
sed -i '/esurfing-watchdog.sh/d' /etc/crontabs/root 2>/dev/null || true
sed -i '/每 2 分钟网络健康看门狗/d' /etc/crontabs/root 2>/dev/null || true
sed -i '/esurfingclient restart/d' /etc/crontabs/root 2>/dev/null || true

CRON_MODIFIED=0

# 【2026-11-13 重要变更】不再自动注入 05:30 的 esurfing-renew.sh 定时任务。
#
# 停用原因 (实测数据, 非推测):
#   1. 现代电信校园网 WAN 侧走 DHCP, 租期 2 小时, udhcpc 每小时自动续期,
#      从未出现过租期到期, WAN 层完全不需要脚本干预;
#   2. 认证会话实测可连续保持 24 小时以上 (11-12 05:31 → 11-13 05:30),
#      未观察到"48 小时硬顶"到期行为;
#   3. esurfing-renew.sh 每次执行都会 ifdown wan 主动断网, 链路重新协商
#      正常情况下 25 秒, 但交换机端口抖动时可长达 3~4 分钟甚至更久;
#   4. 2026-11-13 05:30 的真实故障: ifup 后 WAN 花了 3 分 24 秒才重新拿到 IP,
#      而旧脚本固定 sleep 5 就拉起认证进程, 导致其"无网启动 → 退出码 0 自杀",
#      而 procd 的 respawn 对退出码 0 不重生, 最终断网 2 小时直到人工发现。
#
# 结论: 该脚本"每天主动断网以规避可能的 48 小时硬顶", 属于以确定的小成本
#       对冲不确定的大风险, 在租期实际为 2 小时自动续期的线路上是净负担。
#
# 处理方式: 不再安装到 /usr/bin/, 也不写入 crontab;
#           主动清理历史上已注入的旧任务与残留注释。
#           同理清理 esurfing-watchdog.sh 的高频任务。
sed -i '/esurfing-renew\.sh/d' /etc/crontabs/root 2>/dev/null || true
sed -i '/每天清晨 05:30 优雅刷新租期/d' /etc/crontabs/root 2>/dev/null || true
sed -i '/已停用 2026-11-13.*主动断网/d' /etc/crontabs/root 2>/dev/null || true
sed -i '/esurfing-watchdog\.sh/d' /etc/crontabs/root 2>/dev/null || true
info "-> 已清理续约/看门狗定时任务 (不再部署这两个脚本，日常守护交给客户端自身 Watchdog)"

if ! grep -q 'rotate.log' /etc/crontabs/root 2>/dev/null; then
    cat << 'EOF' >> /etc/crontabs/root
# 每月 1 号凌晨 04:00 自动清理历史轮转日志兜底 (防 tmpfs 内存盘溢出)
0 4 1 * * rm -f /tmp/log/esurfing/logs/logs/*.rotate.log 2>/dev/null
EOF
    CRON_MODIFIED=1
    info "-> 已注入每月历史日志自动清理兜底任务"
fi

if [ "$CRON_MODIFIED" -eq 1 ]; then
    /etc/init.d/cron restart >/dev/null 2>&1 || true
else
    info "-> 计划任务已完整，跳过重复写入"
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
