#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor - 清晨无感租期重置与保活自愈脚本
# ==============================================================================

# 动态适配配置文件路径:
# 优先读取 OpenWrt UCI 中的真实配置目录 (v2.3.0+ 将 JSON 统一归档至 /etc/esurfingclient/ESurfingClient.json)
# 向下兼容旧版直接位于 /etc/config/esurfingclient 的形态
CFG_DIR=$(uci -q get esurfingclient.config.dir 2>/dev/null || echo "/etc/esurfingclient")
if [ -f "$CFG_DIR/ESurfingClient.json" ]; then
    CONFIG_FILE="$CFG_DIR/ESurfingClient.json"
elif [ -f "/etc/config/esurfingclient" ] && grep -q "accounts" /etc/config/esurfingclient; then
    CONFIG_FILE="/etc/config/esurfingclient"
else
    CONFIG_FILE="/etc/esurfingclient/ESurfingClient.json"
fi

# 互斥锁: 本脚本执行期间会 ifdown wan、停服务，此时看门狗的探测必然失败。
# 由看门狗检测该文件并跳过自愈，避免两者互相打断 (详见 esurfing-watchdog.sh)
RENEW_LOCK="/tmp/esurfing_renew.lock"

# 无论正常结束还是被 kill 都要清掉锁，否则看门狗会一直跳过自愈。
# 注意 ash 的 trap 要等当前前台命令 (如 sleep) 结束才执行，所以这里显式
# exit，避免被停之后脚本还继续往下跑完整个流程
release_lock() {
    rm -f "$RENEW_LOCK"
    exit 0
}
trap release_lock EXIT INT TERM HUP

# 已有实例在跑就退出 (cron 重复触发或手动执行时)
if [ -f "$RENEW_LOCK" ]; then
    OLD_PID=$(cat "$RENEW_LOCK" 2>/dev/null || echo 0)
    case "$OLD_PID" in ''|*[!0-9]*) OLD_PID=0 ;; esac
    # 上一次异常退出留下的死锁 (进程已不存在) 直接接管
    if [ "$OLD_PID" -ne 0 ] && kill -0 "$OLD_PID" 2>/dev/null; then
        logger -t esurfing-renew "已有续约进程在运行 (pid $OLD_PID)，本次退出"
        trap - EXIT INT TERM HUP
        exit 0
    fi
fi

echo $$ > "$RENEW_LOCK"

# 被信号中断后立即退出的 sleep，避免 trap 迟迟不触发
renew_sleep() {
    sleep "$1" &
    wait $!
}

# 判定是否已放行上网
# 注意: 不能只 grep "204"。校园网已认证时 204 源返回 204，未认证时返回 302，
# 若只认 204 会把"需要认证"和"完全不通"混为一谈；同时 301 也是正常的放行响应
is_online() {
    for url in \
        "http://connectivitycheck.platform.hicloud.com/generate_204" \
        "http://connect.rom.miui.com/generate_204"
    do
        code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 6 "$url" 2>/dev/null)
        case "$code" in
            204|301) return 0 ;;
        esac
    done
    return 1
}

# 切换认证通道: 优先 jq 原子写入，无 jq 时用 sed。
# BusyBox sed 不支持 0,/re/ 地址范围，且要求冒号后有一个空格，
# 因此分两步替换字符串写法与数字写法，兼容 "ios" 与 3 两种通道配置
switch_channel() {
    target_chn="$1"
    if command -v jq >/dev/null 2>&1; then
        if jq ".accounts[0].channel = $target_chn" "$CONFIG_FILE" > /tmp/cfg.tmp 2>/dev/null; then
            mv /tmp/cfg.tmp "$CONFIG_FILE" && chmod 600 "$CONFIG_FILE"
            return 0
        fi
        rm -f /tmp/cfg.tmp
        logger -t esurfing-renew "通道切换失败 (jq 解析配置出错)，保持原通道"
        return 1
    fi
    sed -i 's/"channel"[[:space:]]*:[[:space:]]*"[^"]*"/"channel": '"$target_chn"'/' "$CONFIG_FILE"
    sed -i 's/"channel"[[:space:]]*:[[:space:]]*[0-9][0-9]*/"channel": '"$target_chn"'/' "$CONFIG_FILE"
}

logger -t esurfing-renew "开始执行清晨 05:30 租期无感刷新..."

# 1. 停止当前服务并主动释放旧会话
/etc/init.d/esurfingclient stop >/dev/null 2>&1 || true

# 2. 刷新 WAN 口租约，给机房 BRAS 预留充分的注销释放时间 (避免撞上冷却期)
# 电信机房 BRAS/AC 对每个物理端口会话有 30 秒左右的注销锁定期，
# 停用 WAN 后休眠 25 秒，确保旧会话在机房彻底注销，避免开机发起认证时撞车返回空 Ticket
ifdown wan >/dev/null 2>&1
renew_sleep 25
ifup wan >/dev/null 2>&1

# 2.1 轮询等待 WAN 真正就绪，而不是死等固定秒数。
#
# 【为什么不能只 sleep 5】2026-11-13 05:30 那次故障的根因:
#   ifup 之后交换机端口重新协商, 物理链路反复 up/down,
#   WAN 直到 05:34 才拿到 IP —— 比旧版固定 sleep 5 晚了 3 分半。
#   认证进程在无网状态下启动, 等不到网络就"退出码 0"自杀;
#   而 procd 的 respawn 对退出码 0 不重生, 结果断网 2 小时无人知晓。
#   平时 WAN 通常 3~5 秒就绪, 所以旧代码大多数日子能侥幸成功。
#
# 判定条件 = 有 IPv4 地址 且 有走 wan 的默认路由, 两者同时满足才算真的通。
# 上限 180 秒: 覆盖今早实测的 3 分 24 秒, 又不至于无限等下去。
wan_ready() {
    ip -4 addr show dev wan 2>/dev/null | grep -q 'inet ' || return 1
    ip route show default 2>/dev/null | grep -q 'dev wan' || return 1
    return 0
}

wan_wait=0
while [ $wan_wait -lt 180 ]; do
    wan_ready && break
    renew_sleep 5
    wan_wait=$((wan_wait + 5))
done

# WAN 迟迟不就绪时直接放弃本轮, 不启动认证进程。
# 因为此时 start 一定是"无网启动 -> 自杀", 反而让状态更糟;
# 保持服务停止, 等 hotplug 或人工介入时 WAN 恢复后再认证更安全。
if ! wan_ready; then
    logger -t esurfing-renew "警告: ifup 后等待 180 秒 WAN 仍未就绪 (无 IP 或无默认路由)，放弃本次刷新以免认证进程无网自杀"
    exit 1
fi
logger -t esurfing-renew "WAN 已就绪 (等待 ${wan_wait} 秒)"

# 3. 严格锁定并确保以主通道 (Channel 1, Windows 客户端通道) 发起握手
# 惠州学院校园网办理天翼校园宽带一人一号后，只放行 Windows 原生通道 (Channel 1)，
# 切勿擅自切为 iOS (Channel 4) 或 macOS (Channel 5)，否则会直接触发机房鉴权失败与死锁
switch_channel 1

/etc/init.d/esurfingclient start >/dev/null 2>&1

# 3.1 校验认证实例是否真的起来了。
# init 脚本在"账号列表为空"时会静默 return 0 (不报错也不起进程),
# procd 对退出码 0 也不会重生, 所以只看 start 的返回值会把"假成功"当成已恢复。
inst_wait=0
while [ $inst_wait -lt 10 ]; do
    if pgrep -f 'esurfingclient --role auth' >/dev/null 2>&1; then
        break
    fi
    renew_sleep 1
    inst_wait=$((inst_wait + 1))
done

if ! pgrep -f 'esurfingclient --role auth' >/dev/null 2>&1; then
    logger -t esurfing-renew "错误: start 后 10 秒内仍未出现认证实例 (active with no instances)，本次刷新失败，需人工执行 /etc/init.d/esurfingclient start"
    exit 1
fi

# 4. 轮询验证放行状态 (最长等待 60 秒，覆盖客户端 6 阶快速退避窗口)
retries=0
while [ $retries -lt 12 ]; do
    renew_sleep 5
    if is_online; then
        logger -t esurfing-renew "清晨会话刷新成功，已放行上网！(用时 $((retries * 5 + 5)) 秒)"
        exit 0
    fi
    retries=$((retries + 1))
done

logger -t esurfing-renew "警告: 刷新 60 秒后尚未放行，保持 Channel 1 待主程序原生 Watchdog 持续自愈。"
