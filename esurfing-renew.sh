#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor - 清晨无感租期重置与保活自愈脚本
# ==============================================================================

CONFIG_FILE="/etc/config/esurfingclient"

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
ifdown wan >/dev/null 2>&1
renew_sleep 10
ifup wan >/dev/null 2>&1
renew_sleep 5

# 3. 确保以主通道 (Channel 1) 重新发起握手
switch_channel 1

/etc/init.d/esurfingclient start >/dev/null 2>&1
renew_sleep 8

# 4. 首次验证: 如果成功上线，写入系统日志并安全退出
if is_online; then
    logger -t esurfing-renew "清晨会话刷新成功，已在线！(通道 1)"
    exit 0
fi

# 5. 若首次未放行 (可能遭遇算法池 cdy 5 或机房残留)，等待 15 秒二次验证
renew_sleep 15
if is_online; then
    logger -t esurfing-renew "清晨会话在二次等待后上线！"
    exit 0
fi

# 6. 若依然未上线，自动热备故障转移至 iOS 通道 (Channel 4，彻底规避算法缺陷)
logger -t esurfing-renew "通道 1 握手受阻，自动故障转移至 iOS 通道 4..."
switch_channel 4

/etc/init.d/esurfingclient restart >/dev/null 2>&1
renew_sleep 8

if is_online; then
    logger -t esurfing-renew "iOS 备用通道 4 握手成功，清晨续约完成！"
    exit 0
fi

logger -t esurfing-renew "警告: 刷新流程执行完毕，已交由看门狗接管持续巡检。"
