#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor
# OpenWrt 广东天翼校园网认证与防检测网关一键健康诊断脚本
# 项目主页: https://github.com/NandaNg314/ESurfing-OpenWrt-Armor
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

# 检查配置文件路径 (兼容新版 /etc/esurfingclient 与旧版 /etc/config)
CFG_DIR=$(uci -q get esurfingclient.config.dir 2>/dev/null || echo "/etc/esurfingclient")
if [ -f "$CFG_DIR/ESurfingClient.json" ]; then
    pass "找到主配置文件: $CFG_DIR/ESurfingClient.json (v2.3.0+ 标准路径)"
elif [ -f "/etc/config/esurfingclient" ] && grep -q "accounts" /etc/config/esurfingclient; then
    pass "找到主配置文件: /etc/config/esurfingclient (旧版兼容路径)"
else
    warn "未找到有效的 ESurfing 配置文件，请检查 $CFG_DIR/ESurfingClient.json"
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

LOG_USAGE_KB=$(du -sk /tmp/log/esurfing 2>/dev/null | awk '{print $1}' || echo "0")
case "$LOG_USAGE_KB" in ''|*[!0-9]*) LOG_USAGE_KB=0 ;; esac
if [ "$LOG_USAGE_KB" -gt 20480 ]; then
    warn "认证日志目录占用较大 (${LOG_USAGE_KB}KB)，建议检查 /etc/config/esurfingclient 的 log_lv 是否为 4 (INFO) 或 2 (ERROR)"
elif [ "$LOG_USAGE_KB" -gt 0 ]; then
    pass "认证日志目录占用健康 (${LOG_USAGE_KB}KB / tmpfs 内存安全)"
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
ALLOW_PING_IDX=$(uci show firewall 2>/dev/null | grep "name='Allow-Ping'" | sed -n "s/.*@rule\[\([0-9]*\)\].*/\1/p" | head -n1)
if [ -n "$ALLOW_PING_IDX" ]; then
    ALLOW_PING_STATUS=$(uci get "firewall.@rule[$ALLOW_PING_IDX].enabled" 2>/dev/null || echo "1")
    if [ "$ALLOW_PING_STATUS" = "0" ]; then
        pass "WAN 口外网 ICMP Ping 响应已关闭 (防网络扫描探测)"
    else
        warn "WAN 口仍开启了 Allow-Ping 响应规则"
    fi
else
    pass "WAN 口外网 ICMP Ping 响应已关闭 (未配置 Allow-Ping 规则)"
fi

# 3.6 检查硬件流量加速 (必须禁用，防止出向 TTL 改写穿透及 MT7621 等机型 PPE 崩溃)
HW_FLOW=$(uci get firewall.@defaults[0].flow_offloading_hw 2>/dev/null || echo "0")
TURBO_HW_FLOW=$(uci get turboacc.config.hw_flow 2>/dev/null || echo "0")
if [ "$HW_FLOW" = "0" ] && [ "$TURBO_HW_FLOW" = "0" ]; then
    pass "硬件流加速已正确禁用 (避免芯片 PPE 异常崩溃并确保 TTL 伪装 100% 生效)"
else
    fail "检测到硬件流加速已启用 (firewall=$HW_FLOW, turboacc=$TURBO_HW_FLOW)！"
    fail "  这可能导致 MT7621 等机型在 Wi-Fi 高并发时触发内核 Panic 硬重启，且会导致出向 TTL 穿透"
    fail "  修复建议：执行 setup-hardening.sh 或手动关闭 flow_offloading_hw"
fi

echo ""

# 4. 外网联通性检测
info "4. 测试公网真实联通性..."

# 4.1 先取学校 DNS（由校园网 DHCP 下发），用于区分「DNS 死锁」与「真的没网」
SCHOOL_DNS=$(grep '^nameserver' /tmp/resolv.conf.d/resolv.conf.auto 2>/dev/null | head -n1 | awk '{print $2}')
# 兼容旧版本路径
[ -n "$SCHOOL_DNS" ] || SCHOOL_DNS=$(grep '^nameserver' /tmp/resolv.conf.auto 2>/dev/null | head -n1 | awk '{print $2}')

if ping -c 2 -W 3 223.5.5.5 >/dev/null 2>&1; then
    pass "公共 DNS (223.5.5.5) 连通测试通过"
else
    # 公网 DNS 不通时，必须区分「Portal 未认证拦截」和「真实断网」
    if [ -n "$SCHOOL_DNS" ] && ping -c 2 -W 3 "$SCHOOL_DNS" >/dev/null 2>&1; then
        warn "公网 DNS (223.5.5.5) 不通，但学校 DNS ($SCHOOL_DNS) 可达"
        warn "  → 这是「Portal 未认证」的特征，不是线路故障。请勿查线路，直接查认证状态。"
        # 进一步判断是否是 DNS 软件上游缺少学校 DNS 导致的死锁
        if [ -f /etc/config/smartdns ]; then
            if uci show smartdns 2>/dev/null | grep -q "\.ip='${SCHOOL_DNS}'"; then
                pass "  smartdns 上游已包含学校 DNS，死锁风险已排除；问题在认证本身"
            else
                fail "  smartdns 上游缺少学校 DNS ($SCHOOL_DNS)！这将导致「认证↔DNS」死锁"
                fail "  修复：见 README FAQ Q7，或运行 /usr/bin/sync-school-dns.sh"
            fi
        fi
    else
        fail "无法 ping 通公共 DNS 223.5.5.5，且学校 DNS 也不可达，请检查 WAN 口与物理链路"
    fi
fi

HTTP_CODE=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "http://connect.rom.miui.com/generate_204" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "204" ]; then
    pass "HTTP 探测 (generate_204) 返回 204，网络已完全打通且无 Portal 网页拦截！"
elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    fail "HTTP 探测发生 302 重定向，当前网络被 Portal 拦截，说明客户端未认证成功或欠费"
elif [ "$HTTP_CODE" = "000" ]; then
    # 000 通常是 DNS 解析失败（域名查不到），也可能是连接被丢
    warn "HTTP 探测返回 000（多为域名解析失败），尝试用裸 IP 二次确认..."
    IP_CODE=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "http://220.181.104.183/generate_204" 2>/dev/null || echo "000")
    if [ "$IP_CODE" != "000" ]; then
        fail "裸 IP 可达 ($IP_CODE) 但域名不可达 → 确认是 DNS 解析故障，不是断网"
        fail "  请检查 dnsmasq / smartdns 上游，以及 FAQ Q7（校园网 DNS 死锁）"
    else
        warn "裸 IP 同样不可达，请结合上方 DNS 三态判定结论综合判断"
    fi
else
    warn "HTTP 探测返回代码: $HTTP_CODE"
fi

echo ""

# 5. 检查自愈机制与定时维护计划
info "5. 检查守护自愈架构与定时维护计划..."

# 检测客户端版本 (v2.2.1+ 已自带原生 Watchdog 线程与 6 阶快速退避)
CLIENT_VER=$(opkg list-installed 2>/dev/null | grep -E "^esurfingclient " | awk '{print $3}' || true)
[ -n "$CLIENT_VER" ] || CLIENT_VER=$(/usr/bin/esurfingclient --version 2>&1 | grep -oE "v?[0-9]+\.[0-9]+\.[0-9]+(-r[0-9]+)?" | head -n1 || echo "未知")

if echo "$CLIENT_VER" | grep -qE "2\.2\.[1-9]|2\.[3-9]\."; then
    pass "当前为 esurfingclient $CLIENT_VER 现代化版本 (内置单调钟 Watchdog 与 6 阶自愈)"
    IS_MODERN=1
else
    info "当前客户端版本: $CLIENT_VER"
    IS_MODERN=0
fi

if [ -x "/usr/bin/esurfing-renew.sh" ]; then
    pass "清晨优雅续约脚本已安装且具备执行权限 (/usr/bin/esurfing-renew.sh)"
else
    warn "未检测到可执行的清晨续约脚本 (/usr/bin/esurfing-renew.sh)"
fi

CRON_JOB=$(crontab -l 2>/dev/null || cat /etc/crontabs/root 2>/dev/null || true)
if echo "$CRON_JOB" | grep -q "esurfing-renew.sh"; then
    pass "Crontab 每天清晨 05:30 优雅续约任务已挂载 (预防 48 小时踢线)"
else
    warn "Crontab 中未找到清晨 05:30 优雅续约任务 (esurfing-renew.sh)"
fi

if echo "$CRON_JOB" | grep -q "esurfing-watchdog.sh"; then
    if [ "$IS_MODERN" -eq 1 ]; then
        warn "检测到 Crontab 中仍挂载了每 2 分钟 esurfing-watchdog.sh 任务！"
        warn "  在 v2.2.1+ 下外部高频重启可能打断上游优雅自愈并误触发 35 分钟防频控休眠，建议移除"
    else
        pass "Crontab 每 2 分钟自愈看门狗任务已挂载 (旧版兼容模式)"
    fi
else
    if [ "$IS_MODERN" -eq 1 ]; then
        pass "现代化纯净守护架构已生效 (无需高频外部看门狗，全权由原生 Watchdog + procd 接管)"
    else
        warn "Crontab 中未找到 esurfing-watchdog.sh 任务 (旧版本建议挂载)"
    fi
fi

if echo "$CRON_JOB" | grep -q "rotate.log"; then
    pass "Crontab 每月日志自动清理兜底任务已挂载"
else
    warn "Crontab 中未找到每月日志清理任务，建议运行 setup-hardening.sh 注入"
fi

echo ""
echo "============================================================"
info "自检流程完成！"
echo "============================================================"
