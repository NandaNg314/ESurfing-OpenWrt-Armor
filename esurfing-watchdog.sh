#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor - 双通道热备网络自愈看门狗
# 功能: 定时探测外网 204 放行状态，区分"需要认证"与"完全断网"，
#       仅在确认需要认证时打破官方指数退避并进行跨通道故障转移。
# ==============================================================================

FAIL_RECORD="/tmp/esurfing_watchdog_fails"
COOL_RECORD="/tmp/esurfing_watchdog_cooldown"
CONFIG_FILE="/etc/config/esurfingclient"
RUN_LOG="/var/log/esurfing/logs/logs/run.log"

# 自愈最小冷却期(秒)。官方退避为 60s -> 300s，机房注销冷却期为 30~60s，
# 低于 120s 的连续自愈会撞上注销窗口，反而制造失败。
COOLDOWN=120

# ------------------------------------------------------------------------------
# 三态探测: 0=在线(204/301)  1=需要认证(302)  2=完全不可达
# 与主程序 CheckNetwork.c 的判定口径保持一致，避免把"302 需要认证"误判为"断网"
# ------------------------------------------------------------------------------
probe_state() {
    for url in \
        "http://connect.rom.miui.com/generate_204" \
        "http://connectivitycheck.platform.hicloud.com/generate_204"
    do
        code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 6 "$url" 2>/dev/null)
        case "$code" in
            204|301) return 0 ;;
            302) return 1 ;;
        esac
    done

    # 两个 204 源都不通，再用主程序的备用源确认是否为"完全无法出网"
    code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 6 "http://1.1.1.1" 2>/dev/null)
    case "$code" in
        301|204|302) return 1 ;;
    esac

    return 2
}

probe_state
STATE=$?

# 1. 在线: 清空失败计数与冷却记录，静默退出
if [ "$STATE" -eq 0 ]; then
    rm -f "$FAIL_RECORD" "$COOL_RECORD"
    exit 0
fi

# 2. 二次复测过滤瞬时抖动 (302 已明确需要认证，无需等待)
if [ "$STATE" -eq 2 ]; then
    sleep 8
    probe_state
    STATE=$?
    if [ "$STATE" -eq 0 ]; then
        rm -f "$FAIL_RECORD" "$COOL_RECORD"
        exit 0
    fi
fi

# 3. 完全不可达持续存在时，先确认主程序是否已经在自己退避
#    主程序在 STATUS_ERROR 下每 10 秒重试、5 次后退出交给 procd，
#    这种场景重启反而会打断它的自愈，因此只在"需要认证"时才动手
if [ "$STATE" -eq 2 ]; then
    if [ -f "$RUN_LOG" ]; then
        RECENT=$(tail -n 200 "$RUN_LOG" 2>/dev/null | grep -cE '网络错误, 等待 10 秒后重试|需要认证|获取 Ticket 失败')
        if [ "$RECENT" -gt 0 ]; then
            logger -t esurfing-watchdog "外网不可达，但主程序正在自行重试，跳过本次自愈"
            exit 0
        fi
    fi
fi

# 4. 冷却期检查: 避免连续重启撞上机房 30~60 秒注销窗口
NOW=$(date +%s)
if [ -f "$COOL_RECORD" ]; then
    LAST=$(cat "$COOL_RECORD" 2>/dev/null || echo 0)
    case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
    if [ $((NOW - LAST)) -lt "$COOLDOWN" ]; then
        logger -t esurfing-watchdog "自愈冷却中 ($((NOW - LAST))s / ${COOLDOWN}s)，本次跳过"
        exit 0
    fi
fi

# 5. 累加连续失败计数
FAILS=0
if [ -f "$FAIL_RECORD" ]; then
    FAILS=$(cat "$FAIL_RECORD" 2>/dev/null || echo 0)
fi
case "$FAILS" in ''|*[!0-9]*) FAILS=0 ;; esac
FAILS=$((FAILS + 1))
echo "$FAILS" > "$FAIL_RECORD"

# 读取当前通道: jq 优先，缺失时退回 sed 提取，避免无 jq 环境下恒读为 1
# 注意要兼容主程序支持的两种写法: "channel": 3 与 "channel": "windows"/"ios" 等
read_channel() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.accounts[0].channel // 1' "$CONFIG_FILE" 2>/dev/null | head -n 1
        return
    fi

    raw=$(sed -n 's/.*"channel"[[:space:]]*:[[:space:]]*\([^,}]*\).*/\1/p' "$CONFIG_FILE" 2>/dev/null | head -n 1 | tr -d ' "')
    case "$raw" in
        [1-5]) echo "$raw" ;;
        windows) echo 1 ;;
        linux)   echo 2 ;;
        android) echo 3 ;;
        ios|iphone) echo 4 ;;
        macos|mac|osx) echo 5 ;;
        *) echo 1 ;;
    esac
}

CURRENT_CHN=$(read_channel)
case "$CURRENT_CHN" in ''|*[!0-9]*) CURRENT_CHN=1 ;; esac
case "$CURRENT_CHN" in [1-5]) ;; *) CURRENT_CHN=1 ;; esac

if [ "$STATE" -eq 1 ]; then
    logger -t esurfing-watchdog "确认需要重新认证 (连续 $FAILS 次, 当前通道: $CURRENT_CHN)"
else
    logger -t esurfing-watchdog "检测到外网不可达 (连续 $FAILS 次, 当前通道: $CURRENT_CHN)"
fi

# 安全切换配置通道函数 (优先 jq 原子写入，无 jq 时平滑降级为 sed)
switch_channel() {
    target_chn="$1"
    if command -v jq >/dev/null 2>&1; then
        jq ".accounts[0].channel = $target_chn" "$CONFIG_FILE" > /tmp/esurfing_cfg.tmp && \
            mv /tmp/esurfing_cfg.tmp "$CONFIG_FILE" && \
            chmod 600 "$CONFIG_FILE"
    else
        sed -i "s/\"channel\": [0-9]/\"channel\": $target_chn/" "$CONFIG_FILE"
    fi
}

# 一次性自愈动作: 记录冷却时间后重启服务
heal_restart() {
    echo "$NOW" > "$COOL_RECORD"
    /etc/init.d/esurfingclient restart
}

# 6. 阶梯式自愈
case $FAILS in
    1)
        logger -t esurfing-watchdog "阶段 1 自愈: 重启认证服务打破指数退避..."
        heal_restart
        ;;
    2)
        NEW_CHN=4
        if [ "$CURRENT_CHN" = "4" ]; then
            NEW_CHN=1
        fi
        logger -t esurfing-watchdog "阶段 2 故障转移: 切换至通道 $NEW_CHN 进行热备拨号..."
        switch_channel "$NEW_CHN"
        heal_restart
        ;;
    3)
        logger -t esurfing-watchdog "阶段 3 故障转移: 切换至备用通道 5 (macOS)..."
        switch_channel 5
        heal_restart
        ;;
    *)
        # 连续失败 4 次以上: 大概率是学校断电/光纤中断/欠费，降频保底重试
        if [ $((FAILS % 3)) -eq 0 ]; then
            logger -t esurfing-watchdog "阶段 4 保底重试: 恢复为默认通道 1 重新唤醒..."
            switch_channel 1
            heal_restart
        fi
        ;;
esac
