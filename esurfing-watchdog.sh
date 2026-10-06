#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor - 双通道热备网络自愈看门狗
# 功能: 定时双重检测外网 204 放行状态，当遭遇机房踢线或动态算法缺陷 (如 cdy 5) 时，
#       自动打破指数退避并进行跨通道故障转移 (Channel 1 <-> Channel 4)，秒级自愈。
# ==============================================================================

FAIL_RECORD="/tmp/esurfing_watchdog_fails"
CONFIG_FILE="/etc/config/esurfingclient"

# 双重 204 检测 (主源: 华为, 备源: 小米)
is_online() {
    if curl -I -s --connect-timeout 3 http://connectivitycheck.platform.hicloud.com/generate_204 | grep -q "204"; then
        return 0
    fi
    if curl -I -s --connect-timeout 3 http://connect.rom.miui.com/generate_204 | grep -q "204"; then
        return 0
    fi
    return 1
}

# 1. 网络正常时: 清空失败计数，静默退出 (0 开销，0 闪存磨损)
if is_online; then
    [ -f "$FAIL_RECORD" ] && rm -f "$FAIL_RECORD"
    exit 0
fi

# 2. 发现网络异常: 二次等待 8 秒复测，过滤瞬时网络抖动
sleep 8
if is_online; then
    [ -f "$FAIL_RECORD" ] && rm -f "$FAIL_RECORD"
    exit 0
fi

# 3. 确认网络断开，读取并累加连续失败计数 (严格校验整数，杜绝空值崩溃)
FAILS=0
if [ -f "$FAIL_RECORD" ]; then
    FAILS=$(cat "$FAIL_RECORD" 2>/dev/null || echo 0)
fi
case "$FAILS" in ''|*[!0-9]*) FAILS=0 ;; esac
FAILS=$((FAILS + 1))
echo "$FAILS" > "$FAIL_RECORD"

CURRENT_CHN=$(jq -r '.accounts[0].channel // 1' "$CONFIG_FILE" 2>/dev/null || echo 1)

logger -t esurfing-watchdog "检测到外网断开 (连续失败 $FAILS 次, 当前通道: $CURRENT_CHN)"

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

# 4. 根据失败次数执行智能阶梯式自愈
case $FAILS in
    1)
        # 第一次重试: 重启认证服务打破官方 20 分钟指数退避，重新发起算法握手
        logger -t esurfing-watchdog "阶段 1 自愈: 重启认证服务打破指数退避..."
        /etc/init.d/esurfingclient restart
        ;;
    2)
        # 第二次重试依然失败 (避开特定通道算法缺陷，如 Windows cdy 5): 故障转移至 iOS 通道
        NEW_CHN=4
        if [ "$CURRENT_CHN" = "4" ]; then
            NEW_CHN=1
        fi
        logger -t esurfing-watchdog "阶段 2 故障转移: 切换至通道 $NEW_CHN 进行热备拨号..."
        switch_channel "$NEW_CHN"
        /etc/init.d/esurfingclient restart
        ;;
    3)
        # 第三次重试: 尝试 macOS 通道 (Channel 5)
        logger -t esurfing-watchdog "阶段 3 故障转移: 切换至备用通道 5 (macOS)..."
        switch_channel 5
        /etc/init.d/esurfingclient restart
        ;;
    *)
        # 连续失败 4 次以上: 说明学校断电、光纤中断或欠费，每 3 轮保底重试一次，杜绝频繁重启刷日志
        if [ $((FAILS % 3)) -eq 0 ]; then
            logger -t esurfing-watchdog "阶段 4 保底重试: 恢复为默认通道 1 重新唤醒..."
            switch_channel 1
            /etc/init.d/esurfingclient restart
        fi
        ;;
esac
