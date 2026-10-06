#!/bin/sh
# ==============================================================================
# ESurfing-OpenWrt-Armor - 清晨无感租期重置与保活自愈脚本
# ==============================================================================

CONFIG_FILE="/etc/config/esurfingclient"

is_online() {
    curl -I -s --connect-timeout 3 http://connectivitycheck.platform.hicloud.com/generate_204 | grep -q "204" || \
    curl -I -s --connect-timeout 3 http://connect.rom.miui.com/generate_204 | grep -q "204"
}

logger -t esurfing-renew "开始执行清晨 05:30 租期无感刷新..."

# 1. 停止当前服务并主动释放旧会话
/etc/init.d/esurfingclient stop >/dev/null 2>&1 || true

# 2. 刷新 WAN 口租约，给机房 BRAS 预留充分的注销释放时间 (避免撞上冷却期)
ifdown wan >/dev/null 2>&1
sleep 10
ifup wan >/dev/null 2>&1
sleep 5

# 3. 确保以主通道 (Channel 1) 重新发起握手
if command -v jq >/dev/null 2>&1; then
    jq '.accounts[0].channel = 1' "$CONFIG_FILE" > /tmp/cfg.tmp && mv /tmp/cfg.tmp "$CONFIG_FILE" && chmod 600 "$CONFIG_FILE"
else
    sed -i 's/"channel": [0-9]/"channel": 1/' "$CONFIG_FILE"
fi

/etc/init.d/esurfingclient start >/dev/null 2>&1
sleep 8

# 4. 首次验证: 如果成功上线，写入系统日志并安全退出
if is_online; then
    logger -t esurfing-renew "清晨会话刷新成功，已在线！(通道 1)"
    exit 0
fi

# 5. 若首次未放行 (可能遭遇算法池 cdy 5 或机房残留)，等待 15 秒二次验证
sleep 15
if is_online; then
    logger -t esurfing-renew "清晨会话在二次等待后上线！"
    exit 0
fi

# 6. 若依然未上线，自动热备故障转移至 iOS 通道 (Channel 4，彻底规避算法缺陷)
logger -t esurfing-renew "通道 1 握手受阻，自动故障转移至 iOS 通道 4..."
if command -v jq >/dev/null 2>&1; then
    jq '.accounts[0].channel = 4' "$CONFIG_FILE" > /tmp/cfg.tmp && mv /tmp/cfg.tmp "$CONFIG_FILE" && chmod 600 "$CONFIG_FILE"
else
    sed -i 's/"channel": [0-9]/"channel": 4/' "$CONFIG_FILE"
fi

/etc/init.d/esurfingclient restart >/dev/null 2>&1
sleep 8

if is_online; then
    logger -t esurfing-renew "iOS 备用通道 4 握手成功，清晨续约完成！"
    exit 0
fi

logger -t esurfing-renew "警告: 刷新流程执行完毕，已交由看门狗接管持续巡检。"
