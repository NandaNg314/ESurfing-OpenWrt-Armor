# ESurfing-OpenWrt-Armor

> **OpenWrt 校园网（天翼校园宽带）全自主自动化认证与防多设备检测网关装甲**  
> *让路由器 100% 独立接管拨号认证、动态算号与网络层防封伪装，全宿舍设备免客户端无感共享高速宽带。*

[![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05+-blue.svg)](https://openwrt.org/)
[![Firewall](https://img.shields.io/badge/Firewall-fw4%20(nftables)-green.svg)](https://openwrt.org/docs/guide-user/firewall/firewall_configuration)
[![Protocol](https://img.shields.io/badge/Protocol-CDC--HTTP--PAP%20%2F%20ZSM-orange.svg)](https://github.com/BadGhost520/ESurfingClient-CVersion)
[![Architectures](https://img.shields.io/badge/Arch-aarch64%20%7C%20mipsel%20%7C%20x86__64%20%7C%20arm-lightgrey.svg)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

---

## 🌟 项目简介与核心痛点解决

在高校宿舍使用天翼校园宽带时，大家通常面临三大严苛限制：
1. **电脑客户端强绑定**：电脑必须 24 小时开机并挂载官方客户端，电脑关机、睡眠或拔插网线全屋断网；
2. **多设备共享检测封禁**：多台手机、电脑或平板同时连 WiFi 时，运营商 DPI 设备通过 TTL 递减、时钟指纹或网络扫描检测到“私接二级路由”，直接强制弹窗或中断网络；
3. **电信 2024 年协议升级与业务锁死**：办理“一人一号多终端”业务后，电信后台对有线端口永久锁死 Web 网页认证（报错 `13018000`），且官方客户端在本地比对网卡 IP 时检测二级路由拦截拨号（报错 `140010`）。

**ESurfing-OpenWrt-Armor** 为解决上述痛点而生。本项目是一套面向 OpenWrt 23.05+ (基于新一代 `fw4 / nftables`) 的**完整交付级网关加固方案**。

### 核心特性：
- **100% 路由器独立运行**：路由器开机全自主完成握手、Ticket 获取与心跳保活；电脑无需开机，随开随关。
- **攻克电信动态挑战（AutoZSM）**：集成应对电信升级后的 **动态 ZSM 算法**，原生支持 Windows/iOS/macOS 多通道私有协议。
- **直击根源解决业务限制**：走原生客户端私有协议通道，彻底避开 `13018000`（Web锁死）与 `140010`（客户端本地IP比对）。
- **拥抱最新守护架构与纯净自愈**：
  - **最新 v2.2.1+ 原生内核级看门狗协同**：上游新版已内置单调钟 `Watchdog` 线程与 6 阶快速心跳自愈，彻底告别外部脚本粗暴杀进程打破退避的旧时代，避免触发机房与客户端的频控惩罚；
  - **保留应急跨通道热备（Failover）**：提供可选的双通道故障转移脚本（`esurfing-watchdog.sh`），在遭遇特定算法缺陷或通道临时失效时支持一键跨通道调度（Windows ⇄ iOS ⇄ macOS）。
- **清晨无感会话重置**：每天清晨 05:30 自动静默刷新一次会话，清零电信机房 48 小时租期，彻底杜绝白天/晚间黄金用网期被踢线。
- **OpenWrt 23.05 内核级防共享伪装装甲**：
  - **TTL / Hop Limit 强制锁定**：出向 IPv4 与 IPv6 数据包强制改写为 `64`，彻底抹除路由转发跳数痕迹。
  - **NTP 时钟流量内网劫持**：局域网 UDP 123 端口授时请求自动重定向至路由器本地时钟源，消除各设备硬件时钟频偏特征。
  - **暴露特征隐身**：禁用 UPnP、LLTD 拓扑发现及外网 ICMP Ping 响应，隐藏路由器网络暴露面。
- **芯片级防崩溃加固（关键避坑）**：
  - 强制关闭导致 MT7621 等机型在 Wi-Fi 高并发下触发内核 Panic 猝死硬重启的硬件加速（`flow_offloading_hw=0`），兼顾千兆纯软加速与 100% 长期不宕机。
- **工业级稳定性与闪存保护**：
  - 由 OpenWrt `procd` 守护进程接管，异常崩溃 5 秒自动拉起。
  - 运行日志与临时状态严格受限于内存盘（`tmpfs`），零闪存磨损。
- **极简自动化交付**：内置一键加固脚本与一键自检体检工具，几秒完成部署并直观输出自检结果。

---

## 💡 为什么需要本项目？（与上游协议库的定位区别）

在折腾校园网网关时，很多同学常问：*“既然上游已经有开源拨号库，为什么还需要本项目？”*

用软件工程的比喻来说：
> **上游开源项目（如 BadGhost520 的 ESurfingClient-CVersion）制造了强劲的“发动机”（底层的 C 语言协议握手与动态 ZSM 算号解包）；**  
> **本项目则打造了完整的“整车交付方案”（包含防共享风控装甲、底层防火墙适配、故障诊断避坑图谱与无人值守守护体系）。**

### 核心差异对比：

| 关注维度 | 上游拨号库 (如 ESurfingClient-CVersion) | ESurfing-OpenWrt-Armor (本项目) |
| :--- | :--- | :--- |
| **主要定位** | 底层 C 语言协议引擎与命令行拨号工具 | **宿舍全屋设备共享上网的开箱即用网关方案** |
| **防多设备检测** | ❌ 仅负责建立连接，不涉及多设备流量伪装 | **内置出向 TTL=64、NTP 劫持、UPnP 禁用等全套防封规则** |
| **新固件防火墙适配**| ❌ 依赖老版 iptables 或需用户自理 | **原生适配 OpenWrt 23.05 的新一代 `fw4 (nftables)` 规则系统** |
| **真实业务避坑图谱**| ❌ 不涉及高校特定业务报错分析 | **详细拆解 `13018000`（Web锁死）与 `140010`（路由拦截）的成因与解决方案** |
| **开箱交付形态** | 需熟悉交叉编译或 Linux 极客手动配置 | **提供一键自动化加固脚本 (`setup-hardening.sh`) 与全自动体检脚本 (`check-status.sh`)** |

---

## 📁 仓库文件清单

| 文件 | 类型 | 用途说明 |
| :--- | :--- | :--- |
| [`setup-hardening.sh`](./setup-hardening.sh) | Shell 脚本 | **OpenWrt 一键防多设备检测加固脚本**（自动注入出向 TTL=64、配置 NTP 局域网劫持、隐藏路由特征、关闭崩溃级硬件流加速并部署清晨续约系统） |
| [`check-status.sh`](./check-status.sh) | Shell 脚本 | **一键状态健康自检脚本**（检查网卡、IP、拨号进程、防火墙计数、外网 DNS 与 204 放行、硬件流加速配置与定时计划） |
| [`esurfing-watchdog.sh`](./esurfing-watchdog.sh) | Shell 脚本 | **双通道网络故障转移脚本（可选）**（三态探针区分 204 在线 / 302 需认证 / 完全不可达，带 120 秒冷却期，主要用于特定算法缺陷时手动/低频跨通道热备） |
| [`esurfing-renew.sh`](./esurfing-renew.sh) | Shell 脚本 | **清晨优雅租期重置与保活脚本**（清晨主动带冷释放重置会话，预留机房释放缓冲与自检，彻底重置 48 小时租期） |
| [`sync-school-dns.sh`](./sync-school-dns.sh) | Shell 脚本 | **学校 DNS 自动同步**（把校园网 DHCP 下发的学校 DNS 自动同步为 smartdns 上游，防止 DNS 软件导致「认证↔DNS」死锁，IP 不变时零开销） |
| [`40-ttl-mangle.nft`](./40-ttl-mangle.nft) | nftables 规则 | OpenWrt 23.05+ (fw4) 原生出向流量锁定 TTL/HopLimit=64 规则片段 |
| [`esurfingclient.example.json`](./esurfingclient.example.json) | 配置模板 | 天翼校园客户端脱敏配置文件模板（严格限制为 `chmod 600`，内置 Windows 客户端 Channel 1 通道参数） |
| [`README.md`](./README.md) | 文档 | 完整通用部署指南、架构原理与深度故障避坑图谱 |
| [`.gitignore`](./.gitignore) | 配置文件 | 忽略临时文件、运行日志、明文密码凭据及系统缓存，杜绝敏感信息误提交 |
| [`LICENSE`](./LICENSE) | 许可证 | 宽松且规范的 **MIT License** 开源许可证 |

---

## 📐 网络拓扑架构

```text
宿舍墙壁校园网插座 (VLAN / DHCP: 10.x.x.x)
        │
        ▼ (网线)
[ OpenWrt 路由器 WAN 口 ] ── (克隆原电脑网卡物理 MAC)
  - 硬件平台: MT7981 / MT7621 / x86_64 / IPQ 等任意架构
  - 系统版本: OpenWrt 23.05+ (fw4 / nftables)
  - 核心服务: esurfingclient (C 语言原生客户端进程, procd 守护)
        │
        ├─────► 无线 WiFi AP (2.4G / 5G 双频并发, 全屋设备 NAT 伪装)
        │         └─► 手机 / iPad / Switch / 智能设备 (免客户端直接无感上网)
        │
        └─────► LAN 局域网口 (网线)
                  └─► PC 电脑 / 主机 (随时关机休眠，不影响全宿舍网络)
```

---

## 🚀 通用部署教程（全机型适用）

### ⚠️ 部署前必读：客户端版本选择（强烈推荐 v2.2.1+）

本项目全面推荐并深度适配 `esurfingclient` **v2.2.1-r7+ 最新版**。不同阶段版本在**核心健壮性与自愈逻辑**上有质的飞跃：

```sh
opkg list-installed | grep esurfingclient
# 或
/usr/bin/esurfingclient --help 2>&1 | head -3
```

| 对比维度 | v2.1.5 (老旧版) | v2.2.0 (过渡版) | v2.2.1+ (最新推荐版, 如 v2.2.1-r7) |
| :--- | :--- | :--- | :--- |
| **自愈守护架构** | 依赖外部脚本强杀服务打破退避 | 仍存在退避死等，易陷入等待 | **内置单调钟 `Watchdog.c` 守护线程**，卡死自动自杀由 `procd` 秒级拉起 |
| **心跳断线重试** | 粗暴退出或长间隔等待 | 失败即退避 | **6 阶快速退避（1s~30s, 61秒自愈窗口）**，网络抖动静默自愈 |
| **防锁号风控保护** | ❌ 无频控，易被机房封号 | ❌ 无频控 | **60 秒内登录 2 次即自动休眠 35 分钟**，彻底杜绝短时频繁认证被拉黑 |
| **联网检测** | `generate_204` + `1.1.1.1` IP 兜底 | 纯双域名检测（无 IP 兜底） | **并发双路（DNS + 固定 IP）并行探测**，3s 连接 / 4s 超时极速收敛 |
| **对外部看门狗的需求**| 需常驻外部 2 分钟看门狗 | 需外部看门狗打破退避 | **严禁外部频繁杀进程**（会误触发 35 分钟防频控休眠），完全由原生状态机接管 |
| **日志纯净度** | 大量探测失败噪音 | 报错清晰，日常较多心跳日志 | **日常心跳降为 DEBUG**，Syslog 极度纯净，零 Flash/内存损耗 |

**强烈推荐直接使用 v2.2.1+（最新版）**：
- 日志极度纯净、错误定位精准、自带高健壮性单调钟 Watchdog。
- **特别提醒**：新版本自带完善自愈与频控保护，**本项目部署时已默认移除每 2 分钟的外挂强杀看门狗**，避免外部脚本打断原生的 61 秒自愈并触发 35 分钟锁定。
- ⚠️ **唯一前置要求**：如果你使用了 `smartdns` / `AdGuard Home` / `mosdns` 等接管 DNS 的软件，**安装前务必先阅读 [FAQ Q7](#faq)**（运行 `sync-school-dns.sh` 同步学校 DNS），避免在未认证状态下陷入「认证↔DNS」死锁。

---

### 步骤 1：查询路由器架构并安装拨号核心

不同型号的路由器对应不同的 CPU 架构。请先通过 SSH 登录 OpenWrt 路由器终端（默认通常为 `ssh root@192.168.1.1` 或自定义 LAN IP）。

1. **查看你的路由器架构**：
   ```bash
   opkg print-architecture | tail -n 2
   # 或查看系统发行版信息
   cat /etc/openwrt_release
   ```

2. **常见芯片架构速查表**：
   | 路由器常见芯片方案 | OpenWrt 架构标识 | 代表机型 |
   | :--- | :--- | :--- |
   | **MediaTek Filogic 820 (MT7981)** | `aarch64_cortex-a53` | 小米 AX3000T、红米 AX6000、H3C NX30 Pro、360 T7 |
   | **MediaTek MT7621** | `mipsel_24kc` | 小米路由 3G / 4、红米 AC2100、极路由 B70、新路由 3 |
   | **Qualcomm IPQ5000 / IPQ6000 / IPQ807x** | `arm_cortex-a7_neon-vfpv4` / `aarch64` | 各类高通方案 Wi-Fi 6 路由器 |
   | **x86 软路由** | `x86_64` | J4125、N5105、各类工控机 / PVE / ESXi 虚拟机 |

3. **下载并安装上游二进制包**：

   前往 [BadGhost520/ESurfingClient-CVersion Releases](https://github.com/BadGhost520/ESurfingClient-CVersion/releases) 页面，
   按第 1 步查到的架构下载对应 `.ipk`，上传至路由器 `/tmp` 目录。

   > 💡 **建议使用最新版**（推荐当前最新的 `v2.2.1-r7`）。
   > 若你使用了 smartdns / AdGuard Home / mosdns 等接管 DNS 的软件，
   > **安装前务必先读 [FAQ Q7](#faq)**，否则认证会在第一步直接因无法解析而退出。

   ```bash
   cd /tmp

   # 以 mipsel_24kc（小米路由 3G/4、红米 AC2100 等 MT7621 机型）为例，最新 v2.2.1-r7：
   wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.2.1-r7/esurfingclient_2.2.1-7_mipsel_24kc.ipk
   wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.2.1-r7/luci-app-esurfingclient_2.2.1-7_all.ipk

   # 以 aarch64_cortex-a53（小米 AX3000T、红米 AX6000 等 MT7981 机型）为例，最新 v2.2.1-r7：
   # wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.2.1-r7/esurfingclient_2.2.1-7_aarch64_cortex-a53.ipk
   # wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.2.1-r7/luci-app-esurfingclient_2.2.1-7_all.ipk

   # 执行安装 (建议主程序与 LuCI 界面一同安装)
   opkg install esurfingclient_*.ipk luci-app-esurfingclient_*.ipk
   ```

   > 📌 上面 URL 中的版本号会随上游发布变化。若链接失效，请到 Releases 页面
   > 找到当前最新 tag，把 URL 里的 `v2.2.1-r7` 和文件名中的版本号一并替换即可。

---

### 步骤 2：克隆设备 MAC 地址

高校校园网端口往往会记录你此前通过电脑直连认证时的网卡物理 MAC。将路由器 WAN 口 MAC 改为电脑的物理 MAC 可避免端口绑定拦截：

```bash
# 将 <YOUR_DEVICE_MAC> 替换为你的电脑网卡物理 MAC (如 aa:bb:cc:dd:ee:ff)
uci set network.wan.macaddr='<YOUR_DEVICE_MAC>'
uci commit network

# 热重载 WAN 口重新向校园网 DHCP 请求内网 IP（耗时 2~3 秒，不会断开 SSH）
ifdown wan && ifup wan
```

---

### 步骤 3：配置认证凭据

创建并编辑 `/etc/config/esurfingclient`，填入你的宽带账号与密码（文件权限必须设为 `600`，杜绝密码泄露）：

```bash
cat << 'EOF' > /etc/config/esurfingclient
{
  "enabled": true,
  "web_external_acc": false,
  "log_lv": 2,
  "log_dir": "/var/log/esurfing/logs",
  "conn_timeout": 7,
  "op_timeout": 10,
  "web_port": 8888,
  "accounts": [
    {
      "username": "<你的宽带账号>",
      "password": "<你的宽带密码>",
      "channel": 1,
      "mark": "",
      "time_windows": []
    }
  ]
}
EOF

# 严格锁定凭据文件权限
chmod 600 /etc/config/esurfingclient
```

> **参数说明**：
> - `channel: 1`：使用 Windows 客户端协议通道（User-Agent: `CCTP/WinSVR5/1068`），匹配 CDC-HTTP-PAP 协议与动态 ZSM 算号规则。
> - `log_lv: 4`：**推荐设为 `4`（INFO）或 `2`（告警级）**。切勿设为 `6`（VERBOSE），否则客户端每秒都会向内存盘狂刷底层报文与 curl 调试日志，堆积数十兆轮转日志挤占路由器 RAM；设为 `4` 或 `2` 并配合本项目的月度清理计划，可确保关键断网排查信息完整且终身免维护。
> - `conn_timeout: 7` 与 `op_timeout: 10`：为兼顾校园网高峰期波动设置的最佳超时窗口。
> - `mark: ""`：**单拨场景必须留空**。该字段供 mwan3 多拨绑定接口使用，主程序会用 `strtoul(value, NULL, 16)` 按 **十六进制** 解析；写成 `"dorm"`、`"home"` 这类备注名会被解析成 `0xd`、`0x0` 之类的错误标记，导致 curl 请求被 `ip rule` 的 `unreachable` 兜底规则丢弃，表现为周期性 `主检测 URL 无法连通` 超时。多拨用户请填写 `ip rule show` 里的真实标记值（如 `"0x100"`、`"0x200"`）。

启动服务并设置开机自启：
```bash
/etc/init.d/esurfingclient enable
/etc/init.d/esurfingclient start
```

---

### 步骤 4：网络层防多设备检测与高可用自愈加固

针对校园网常见的多设备检测手段（TTL 递减检测、时钟偏差检测、网络服务扫描）以及机房断线、退避假死问题，本项目提供了**一键自动化加固脚本**与**手动逐步配置**两种方式：

#### 方案 A：一键加固脚本（强烈推荐）

将仓库中的脚本（`setup-hardening.sh`、`esurfing-renew.sh`、`check-status.sh`，以及可选的 `esurfing-watchdog.sh`）上传至路由器 `/tmp` 目录并执行：

```bash
cd /tmp
chmod +x setup-hardening.sh esurfing-renew.sh check-status.sh
sh setup-hardening.sh
```

*脚本会自动完成出向 TTL/HL=64 规则注入、本地 NTP 授时服务启用与局域网重定向劫持、关闭 UPnP/LLTD、屏蔽外网 Ping、关闭导致内核 Panic 猝死重启的硬件流加速，并自动配置清晨 05:30 优雅租期重置计划任务（针对 v2.2.1+ 最新版自动清理外部高频冲突看门狗）。*

---

#### 方案 B：手动分步加固

<details>
<summary>👉 点击展开查看手动配置细节</summary>

1. **统一出向流量 TTL / Hop Limit 为 64**：
   在 OpenWrt 23.05 的 `fw4` 规则目录中添加自定义 nftables 片段：
   ```bash
   cat << 'EOF' > /etc/nftables.d/40-ttl-mangle.nft
   chain mangle_postrouting_ttl {
       type filter hook postrouting priority 300; policy accept;
       oifname "wan" ip ttl set 64 counter
       oifname "wan" ip6 hoplimit set 64 counter
   }
   EOF
   ```

2. **局域网 NTP 时钟重定向（防时钟偏差特征检测）**：
   开启路由器本地 NTP 授时服务，并将局域网发往外部的 UDP 123 端口流量强制重定向至路由器：
   ```bash
   # 开启本地 NTP 服务
   uci set system.ntp.enable_server='1'
   uci commit system
   /etc/init.d/sysntpd restart

   # 配置防火墙 DNAT 劫持
   uci add firewall redirect
   uci set firewall.@redirect[-1].name='Redirect-NTP'
   uci set firewall.@redirect[-1].src='lan'
   uci set firewall.@redirect[-1].proto='udp'
   uci set firewall.@redirect[-1].src_dport='123'
   uci set firewall.@redirect[-1].dest_port='123'
   uci set firewall.@redirect[-1].target='DNAT'
   uci commit firewall
   ```

3. **关闭暴露特征与 WAN 口 ICMP Ping**：
   ```bash
   # 关闭 UPnP
   uci set upnpd.config.enabled='0' 2>/dev/null; uci commit upnpd 2>/dev/null
   /etc/init.d/miniupnpd stop 2>/dev/null && /etc/init.d/miniupnpd disable 2>/dev/null

   # 禁用 LLTD 拓扑发现
   /etc/init.d/lltd stop 2>/dev/null && /etc/init.d/lltd disable 2>/dev/null

   # 禁用 WAN 口 Ping 响应 (Allow-Ping)
   uci set firewall.@rule[1].enabled='0'
   uci commit firewall
   ```

4. **关闭芯片级硬件流加速（核心避坑，防路由器硬重启与 TTL 穿透）**：
   ```bash
   # 保留软件流加速，禁用硬件加速 (flow_offloading_hw=0)
   # 彻底根治 MT7621 等机型在 Wi-Fi 高并发下 PPE 硬件表崩溃引发的内核 Panic 硬重启
   uci set firewall.@defaults[0].flow_offloading_hw='0' 2>/dev/null
   uci commit firewall

   # 若固件安装了 Turbo ACC 插件，务必同步关闭 turboacc 中的硬件流加速与硬件 WED
   if [ -f /etc/config/turboacc ]; then
       uci set turboacc.config.hw_flow='0' 2>/dev/null
       uci set turboacc.config.hw_wed='0' 2>/dev/null
       uci commit turboacc 2>/dev/null
   fi

   # 重载防火墙使全部加固规则生效
   /etc/init.d/firewall restart
   ```

5. **部署清晨优雅租期重置计划（预防 48 小时机房踢线）**：
   ```bash
   # 安装清晨优雅续约脚本
   cp esurfing-renew.sh /usr/bin/esurfing-renew.sh
   chmod +x /usr/bin/esurfing-renew.sh

   # 挂载计划任务 (v2.2.1+ 自带单调钟 Watchdog 与 6 阶自愈，无需外部每 2 分钟挂载看门狗)
   cat << 'EOF' >> /etc/crontabs/root
   # 每天清晨 05:30 优雅刷新租期 (带冷释放与自检，彻底重置机房 48 小时租期)
   30 5 * * * /usr/bin/esurfing-renew.sh >/dev/null 2>&1
   # 每月 1 号凌晨 04:00 自动清理历史轮转日志兜底 (防 tmpfs 内存盘溢出)
   0 4 1 * * rm -f /tmp/log/esurfing/logs/logs/*.rotate.log 2>/dev/null
   EOF

   /etc/init.d/cron restart
   ```
</details>

---

## 🔍 运维排查与自检指令

### 1. 一键全自动综合健康体检（推荐）

将仓库中的 `check-status.sh` 上传至路由器 `/tmp` 目录并运行：

```bash
chmod +x /tmp/check-status.sh
sh /tmp/check-status.sh
```

**自检覆盖以下关键维度：**
- [x] **物理网卡与 DHCP**：检查 WAN 口 IP 获取状态及 MAC 克隆持久化配置；
- [x] **进程状态**：探测 `esurfingclient` 核心拨号进程及最新的运行握手日志；
- [x] **防检测规则**：检查 `mangle_postrouting_ttl` 链的数据包改写计数、本地 NTP 监听端口与局域网重定向规则；
- [x] **公网连通性**：实测 223.5.5.5 DNS 连通性与 `generate_204` 探测代码（排查是否存在 Portal 网页重定向拦截）。

---

### 2. 常用单项排查指令

- **查看实时拨号与心跳日志**：
  ```bash
  tail -f /var/log/esurfing/logs/logs/run.log
  ```
  *正常连接时会显示动态解包成功、Ticket 获取成功、认证成功以及周期性发送心跳包。*

- **验证出向 TTL 改写规则命中包数**：
  ```bash
  nft list chain inet fw4 mangle_postrouting_ttl
  ```
  *查看规则末尾的 `counter packets ... bytes ...`，只要有上网流量经过 WAN 口，计数器即会持续增加。*

- **检查 MAC 克隆是否已持久化**：
  ```bash
  uci get network.wan.macaddr   # 检查配置文件 MAC
  ip link show dev wan          # 检查内核硬件接口生效 MAC
  ```

- **启停/重启认证服务**：
  ```bash
  /etc/init.d/esurfingclient restart
  /etc/init.d/esurfingclient status
  ```

### 3. 版本回滚（升级 v2.2.0 后无法正常工作时）

如果升级后认证反复失败，可以先回滚到旧版**临时恢复网络**：

```sh
# 1. 备份当前版本
cp /usr/bin/esurfingclient /root/esurfingclient.$(date +%s).bak

# 2. 恢复旧版二进制（从你自己的备份，或重新下载旧版 ipk）
cp /root/esurfingclient-2.1.5-r1.bin /usr/bin/esurfingclient
chmod 755 /usr/bin/esurfingclient

# 3. 重启验证
/etc/init.d/esurfingclient restart
sleep 60
curl -s -o /dev/null -w '%{http_code}\n' http://connect.rom.miui.com/generate_204
#   204 = 成功
```

> ⚠️ **不推荐长期靠旧版规避问题。**
> v2.1.5 的 IP 兜底会**掩盖 DNS 故障**——网络看起来正常，实际 DNS 早就坏了，
> 直到兜底也失效那天才集体爆发（这是本项目遇到过的真实案例：DNS 从配置 smartdns 那天起就是坏的，
> 因为兜底一直能用，一年都没发现）。
>
> **回滚只用于临时救急，根本问题（DNS 上游）仍应修好后再升回 v2.2.0。**

---

## ❓ 常见问题与技术避坑指南 (FAQ)

### Q1：为什么网页认证提示“拨号方式错误”（代码 `13018000`）？
- **原因**：这是运营商针对开通了“一人一号多终端”业务的账号策略。电信在后台对有线端口锁死了 Web 网页认证通道，前端代码明确注释“已办理一人一号多终端业务的用户，请使用客户端登录”。
- **解决**：无需尝试逆向网页端或识别验证码，直接在路由器上运行本项目提供的 `esurfingclient`（`channel: 1`）即可直接打通官方原生私有客户端协议。

### Q2：电脑接在路由器后打开客户端，为什么会提示“客户端IP地址不正确”（代码 `140010`）？
- **原因**：官方客户端在启动时会通过 Windows API 读取本地物理网卡 IP（如 `192.168.x.x`），并与网关重定向报上来的内网 IP（如 `10.x.x.x`）进行比对。比对不一致即判定存在二级路由，直接在本地弹窗拦截。
- **解决**：本项目的意义正在于**彻底丢弃电脑客户端**。所有认证由路由器在最前线自主完成，电脑开机即直接上网，永远不会触发官方客户端的本地环境检查。

### Q3：刚重启路由器或重启认证服务后，为什么会有几十秒弹窗提示“需要重新认证”，但随后又自动恢复？
- **现象描述**：手动重启服务或路由器刚开机时，打开网页在短时间内会看到校园网 302 重定向页面（或后台日志提示 `[ERROR] [DialerTicket.c:38] 获取 Ticket 响应失败`），但在约 60 秒后突然自动恢复正常并畅快上网。
- **底层原因**：电信机房服务端（BRAS/AC）对每个物理端口的在线会话有 **30 ~ 60 秒的注销冷却锁定期**。当服务刚重启发起连接时，电信机房认为上一轮会话仍在注销流程中，暂不发放新 Ticket（返回 HTTP 200 空内容）。
- **关键避坑警示（切勿连续频繁重启服务）**：
  客户端内置了**指数退避自愈机制**（第 1 次重试等待 60 秒，第 2 次重试等待 300 秒）。**如果在断网的几十秒真空期内慌乱连续执行重启命令，反而会导致退避重试时间被拉长至 5 分钟！** 遇到刚重启后的短暂断网无需慌张，更不要频繁拔插网线或重启服务，只需**静待 60 秒**，客户端会在第 61 秒全自动重新拉取 Ticket 并秒级自愈上线。

### Q4：路由器重启、半夜断电断网或清晨来电后，多久才能自动恢复上网？
- **时间预估**：路由器从通电开机到全屋设备畅通上网，**全流程通常耗时约 45 ~ 60 秒**（路由器系统指示灯变绿或 WiFi 信号亮起后，约 **10 ~ 15 秒** 内即可无感上网），全程无需任何人工干预。
- **开机自愈全流程拆解**：
  1. **硬件与 OpenWrt 系统启动**（约 30 ~ 40 秒）：芯片上电，Linux 内核加载，无线与网络驱动初始化。
  2. **WAN 口获取内网 IP**（约 2 ~ 3 秒）：物理网卡连通，向校园网 DHCP 服务器获取 `10.x.x.x` 内网地址。
  3. **服务守护就绪与网络探测**（约 10 秒）：
     - `esurfingclient` 服务开机优先级为 `S99`（随系统最后启动）；
     - 服务脚本内置 `wait_network` 守护循环，检测到 WAN 口网关与默认路由就绪后自动启动认证进程。
  4. **全自动动态握手登录**（约 1 ~ 3 秒）：
     - 自动触发 Portal 探测并抓取重定向参数；
     - 毫秒级完成动态 ZSM 解密、获取 Ticket 并通过 PAP 认证，随后接入心跳保活循环。
- **特殊情况**：若断电瞬间恰好遇到电信旧会话尚未超时的极罕见情况，加上 60 秒的会话冷却退避期，最长约 1.5 ~ 2 分钟也会自动秒级自愈恢复。

### Q5：多人连路由器 WiFi 同时打游戏、看视频，会被运营商检测到吗？
- **防护原理**：运营商多终端检测通常依赖三项特征：
  1. **TTL 步长不一致**（Android 默认为 64、Windows 默认为 128、iOS 默认为 64，经过路由器 NAT 减 1 后暴露）-> 本项目通过 `40-ttl-mangle.nft` 强制统一改写出向 TTL 为 64。
  2. **NTP 时钟偏差特征**（各设备微小晶振偏差形成的设备时钟指纹）-> 本项目将内网 NTP 授时请求统一重定向到路由器自身。
  3. **网络特征探测**（主动扫描 UPnP、Ping 回应）-> 本项目已全部禁用。  
  在此三重加固下，运营商机房 DPI 探针只能看到一台特征纯净的标准 Windows 终端。

### Q6：怎么避免电信 48 小时租期到期踢线与断网长时间等待？
- **痛点深度拆解**：
  1. **机房 48 小时强制下线**：电信机房对每次宽带认证设置了约 48 小时的单次会话租期硬顶。若上次拨号在晚上，跑满 48 小时后恰好会在晚间黄金用网期触发被踢下线；
  2. **OpenWrt 后台进程无 48 小时重连**：反编译与源码分析证实，OpenWrt 守护进程以 `--role auth` 启动，主循环中根本没有主动重连逻辑，完全被动等待机房踢线；
  3. **即使客户端重连也是从开机算起**：若你在晚上 20:30 重启了路由器，48 小时到期依然在两天后的 20:30 黄金开黑期断网！
- **解决方案（本项目核心神器 `esurfing-renew.sh`）**：
  - **清晨 05:30 优雅租期重置**：
    - **杜绝盲目重启撞冷却**：若在 05:30 机械执行服务重启，由于旧会话刚登出，极易撞上机房 30~60 秒注销冷却期而首次失败。本项目专属脚本 `esurfing-renew.sh` 在停用服务后，**主动下线 WAN 口并休眠 10 秒**，为机房 BRAS 预留充足的旧会话注销时间；
    - **重新握手与自检闭环**：重新拉起 WAN 口并启动服务后，脚本会**主动探测 204 放行状态**；确认 100% 通畅后才退出；
    - **清零 48 小时计时器**：每天清晨自动将租期倒计时归零，**48 小时强制踢线永远不会在白天或晚间用网高峰期发生**！
  - **关于外部看门狗 `esurfing-watchdog.sh` 的退役说明**：
    - 在旧版（v2.1.5）客户端下，断网后指数退避较长，外部看门狗每 2 分钟强制重启打破死等；
    - **在 v2.2.1+ 最新版下，强烈建议停止挂载每 2 分钟的外挂看门狗**！因为新版已内置单调钟 Watchdog 线程与 6 阶快速自愈，外部频繁杀进程会打断原生的 61 秒自愈，甚至触发新版 `60 秒内登录 2 次即休眠 35 分钟` 的防锁风控。将日常守护全权交由原生状态机 + procd 即可。

### Q7：装了 smartdns / AdGuard Home / mosdns 后，认证程序反复失败、日志报「联网检测全部失败」？

> **这是 v2.2.0 才暴露出来的高频坑，v2.1.5 及以下不会遇到。**

#### ⚡ 先做这一步：30 秒判断你是否需要读本节

**没装任何 DNS 软件的用户请直接跳过本节**——原生 dnsmasq 会自动读取学校 DHCP 下发的 DNS，不存在这个问题。

```sh
uci get dhcp.@dnsmasq[0].noresolv 2>/dev/null || echo "未设置(默认 0)"
```

| 返回值 | 你的情况 | 需要处理吗 |
| :--- | :--- | :--- |
| `0` 或「未设置」 | **原生 dnsmasq**，或装了 DNS 软件但未接管全部 DNS | ❌ **不用管，跳过本节** |
| `1` | 有软件**接管了全部 DNS** | ⬇️ **继续往下读** |

**两种状态的本质区别**：

```
noresolv = 0（默认）
    → dnsmasq 自动读 /tmp/resolv.conf.d/resolv.conf.auto
    → 里面就是学校 DHCP 下发的 DNS
    → 未认证时也能解析 → 认证正常完成 ✅

noresolv = 1
    → dnsmasq 不再读系统 DNS，学校 DNS 被丢弃
    → 若 DNS 软件上游又没有它 → 死锁 ❌
```

> **本节适用人群**：使用了 smartdns / AdGuard Home / mosdns 等，**且设置成「接管全部 DNS」**的用户。
> 只是装了但没接管的，`noresolv` 仍是 `0`，不受影响。
>
> 💡 **即使你现在没装任何 DNS 软件，也建议记住这条命令**：将来装了任何 DNS 插件后，
> 先跑一次确认 `noresolv` 的值，能避免莫名其妙认证失败。

---

- **现象**：认证进程反复退出，日志循环如下：
  ```
  [WARN] [CheckNetwork.c:208] 联网检测全部失败: hicloud/dns=0 hicloud/ip1=0 hicloud/ip2=0 miui/dns=0 ...
  [WARN] [DialerNet.c:339] 网络错误, 重试: 第 1 次, 最多 5 次
  [FATAL] [DialerNet.c:336] 超过最多重试次数
  ```
  或提示 `还没拿到认证页面地址 (last_location 为空): 请先用浏览器打开任意 http 网站触发跳转`。

- **根因一（版本差异，关键）**：**v2.2.0 移除了备用 IP 兜底**。

  | 版本 | 联网检测目标 | DNS 坏掉时 |
  | :--- | :--- | :--- |
  | v2.1.5 | `connect.rom.miui.com` + **`http://1.1.1.1` 兜底** | 降级到 IP URL，**照常认证成功** |
  | **v2.2.0** | `connect.rom.miui.com` + `connectivitycheck.platform.hicloud.com`（**两者都是域名，无 IP 兜底**） | **直接 FATAL 退出** |

  > 实测：v2.2.0 二进制中 `1.1.1.1` 出现次数为 **0**。所以 **DNS 一旦不可用，v2.2.0 100% 卡死在第一步，连认证请求都不会发出**。

- **根因二（DNS 死锁）**：校园网在**未认证状态**下，Portal 会拦截所有公网 DNS（腾讯 / 阿里 / 火山 / 114 全部超时），**只放行学校自己的 DNS**。若你的 DNS 软件（smartdns / AdGuard / mosdns）上游配置的全是公网 DNS，就会形成死锁：
  ```
  要认证 → 需解析 Portal 域名 → 需 DNS → 但 DNS 要认证后才通 → 认证不了
  ```

---

#### 🔍 自查：你是不是 smartdns 用户里的「必中人群」

> **smartdns 用户是最容易踩这个坑的一类**，因为默认部署方式就是「接管全部 DNS」，天然满足触发条件。

逐条对号入座，**中 2 条以上基本就是这个问题**：

```sh
# ① 是否装了 smartdns 并接管了 dnsmasq
opkg list-installed | grep -q smartdns && echo "装了 smartdns"
uci get dhcp.@dnsmasq[0].server 2>/dev/null    # 出现 127.0.0.1#6053 之类 → 已被接管

# ② dnsmasq 是否被设为不读系统 DNS（这是最关键的标志）
uci get dhcp.@dnsmasq[0].noresolv 2>/dev/null
#   返回 1 → dnsmasq 不会去读 resolv.conf.auto，也就拿不到学校 DNS

# ③ smartdns 的上游里有没有学校 DNS
cat /tmp/resolv.conf.d/resolv.conf.auto          # 学校下发的 DNS
uci show smartdns | grep -E "\.ip='"
#   如果上面这个学校 DNS 没出现在 smartdns 的 ip 列表里 → 死锁跑不掉

# ④ 验证死锁是否存在
ping -c2 223.5.5.5                                # 不通
ping -c2 <学校DNS>                                # 通   ← 这个组合 = 确认死锁
```

**为什么 smartdns 用户必中**：

| smartdns 的典型配置 | 后果 |
| :--- | :--- |
| `noresolv='1'`（接管 DNS 的标准做法） | dnsmasq **不再读** `resolv.conf.auto`，学校 DNS 被丢弃 |
| `server='127.0.0.1#6053'` | 所有解析强制走 smartdns |
| smartdns 上游只配公网 DNS（默认模板就是） | 未认证时**全部超时**，链路断死 |

三个条件凑齐，就组成了一个闭环：**学校 DNS 明明下发到手了，却因为 `noresolv=1` 被丢掉，而 smartdns 又没有任何一个能在未认证时工作的上游。**

> **注意**：`noresolv='1'` 本身**没有错**，它是 smartdns 正常工作的前提。错的是**上游遗漏了学校 DNS**。所以修法是「补上游」，**不是**去改 `noresolv`。

---

- **解决方案**：把**学校 DNS** 加为 DNS 软件的上游之一。以 smartdns 为例：
  ```sh
  # 1. 自动取出学校 DNS（无需知道具体是多少，不同学校不一样）
  SCHOOL_DNS=$(grep '^nameserver' /tmp/resolv.conf.d/resolv.conf.auto 2>/dev/null | head -n1 | awk '{print $2}')
  echo "本校 DNS: $SCHOOL_DNS"
  #   ⚠️ 如果这里是空的，说明 WAN 不是 DHCP 模式（如静态 IP / PPPoE），
  #     请向学校网络中心确认 DNS，或见下方「非 DHCP 情况」说明。

  # 2. 加入 smartdns 上游（直接引用上面的变量，不要硬编码别人学校的 IP）
  uci add smartdns server
  uci set smartdns.@server[-1].enabled='1'
  uci set smartdns.@server[-1].name='SchoolDNS'
  uci set smartdns.@server[-1].ip="$SCHOOL_DNS"
  uci set smartdns.@server[-1].port='53'
  uci set smartdns.@server[-1].type='udp'
  uci commit smartdns
  /etc/init.d/smartdns restart

  # 3. 验证：先清缓存，再重启认证，冷缓存下也应能自己认证成功
  /etc/init.d/smartdns stop; rm -f /etc/smartdns/smartdns.cache; /etc/init.d/smartdns start
  /etc/init.d/esurfingclient restart
  sleep 60 && curl -4 -s -o /dev/null -w '%{http_code}\n' http://connect.rom.miui.com/generate_204
  #   204 = 成功
  ```

  **⚠️ 必须清缓存验证**，否则 `serve-expired` 的过期缓存会造成「看着修好了其实没修」的假象。

- **更省事的做法**：直接用本仓库的
  [`sync-school-dns.sh`](./sync-school-dns.sh)，它**自动从 DHCP 读取学校 DNS**，
  不写死任何 IP，学校换了也会自动跟随：
  ```sh
  cp sync-school-dns.sh /usr/bin/ && chmod 755 /usr/bin/sync-school-dns.sh
  /usr/bin/sync-school-dns.sh     # 手动跑一次立即生效
  ```
  再挂到 hotplug，WAN 每次拿到地址时自动同步：
  ```sh
  cat > /etc/hotplug.d/iface/99-sync-school-dns <<'HOOK'
  #!/bin/sh
  [ "$ACTION" = "ifup" ] || [ "$ACTION" = "ifupdate" ] || exit 0
  case "$INTERFACE" in wan*) /usr/bin/sync-school-dns.sh ;; esac
  HOOK
  chmod 755 /etc/hotplug.d/iface/99-sync-school-dns
  ```

- **非 DHCP 情况**（WAN 用静态 IP / PPPoE，拿不到自动下发的 DNS）：
  `resolv.conf.auto` 会是空的，脚本会自动跳过、不做任何破坏性操作。
  此时需要手动向学校网络中心确认 DNS，并用上面的「步骤 2」手工填入。

- **其他 DNS 软件的对应做法**：

  | 软件 | 加学校 DNS 的位置 |
  | :--- | :--- |
  | **smartdns** | `uci add smartdns server`（上方命令），或 `custom.conf` 里加 `server <学校DNS>` |
  | **AdGuard Home** | 网页后台 → 设置 → DNS 设置 → 上游 DNS 服务器，追加学校 DNS |
  | **mosdns** | 配置文件的 `forward` / `upstream` 列表中追加学校 DNS |
  | **dnsmasq（原生）** | 无需操作。`noresolv='0'` 时它会自动读 `resolv.conf.auto`，天然包含学校 DNS |

- **⚠️ 学校 DNS 是 DHCP 动态下发的，会变**。硬编码迟早失效，届时死锁复现。推荐用本仓库的
  [`sync-school-dns.sh`](./sync-school-dns.sh) 自动跟随（见下方文件清单），IP 变化时自动同步，平时零开销。

- **顺带提醒**：DNS 软件的上游里保留学校 DNS **不会削弱优选效果**。`response-mode fastest-ip` 仍是多上游并发竞争取最快，学校 DNS 只是多了一个候选，不独占、不屏蔽常规域名。

### Q8：为什么路由器（如小米 3G、红米 AC2100、新路由 3 等 MT7621 机型）在 Wi-Fi 高并发或多设备连网时突然莫名其妙猝死硬重启？

- **现象描述**：
  平时上网正常，但宿舍几台手机/电脑同时连上 Wi-Fi 刷视频、下载大文件或打游戏时，路由器突然所有指示灯熄灭或闪烁，**整机瞬间断电式硬重启**；重启后查看系统日志没有任何报错，闪存崩溃日志也是空的。
- **底层根因（芯片级 PPE 硬件加速陷阱）**：
  这是由于开启了 **芯片硬件流加速 (`flow_offloading_hw=1` / MediaTek PPE HWNAT)** 造成的致命内核崩溃！
  1. **MT7621 根本没有无线硬件卸载引擎**：MT7621 芯片的 PPE 引擎仅针对 MT7530 有线以太网交换芯片，硬件上根本不支持 MT7603/MT7612 无线芯片的流卸载（无线硬件卸载 WED 是新一代 Filogic 芯片的专属）。
  2. **网桥流表错位引发内核 Panic**：当 OpenWrt 防火墙开启硬件加速时，系统会将无线 AP 接口（`phy0-ap0`/`phy1-ap0`）硬塞入 `flags offload` 流表。多台设备连 Wi-Fi 发起高并发连接时，数据帧触发 MediaTek PPE 描述符环错位与内存越界访问（触发内核 Oops: `Kernel panic - not syncing: Fatal exception`）。配合 Linux 默认的 `panic=3`，系统在 3 秒内直接触发 SoC 硬件复位立即硬重启！
- **彻底解决办法**：
  **必须彻底关闭硬件流量加速 (`flow_offloading_hw=0`)，只保留纯软件流量加速 (`flow_offloading=1`)**。
  MT7621 双核四线程 880MHz 跑纯软件 Fastpath（nft_flow_offload）跑满千兆线速毫无压力，CPU 占用极低，且 100% 稳定绝不再猝死：
  ```sh
  # 1. 关闭防火墙硬件流加速
  uci set firewall.@defaults[0].flow_offloading_hw='0'
  uci commit firewall

  # 2. 若安装了 Turbo ACC 插件，务必同步关闭 turboacc 的硬件加速 (防止开机被重置)
  if [ -f /etc/config/turboacc ]; then
      uci set turboacc.config.hw_flow='0'
      uci set turboacc.config.hw_wed='0'
      uci commit turboacc
  fi

  # 3. 重启防火墙生效
  /etc/init.d/firewall restart
  ```

---

## 🙏 致谢与参考开源项目 (Acknowledgements)

本项目在协议梳理、加固设计与工程落地过程中，参考并使用了以下杰出的开源项目，特此向原作者致以崇高的敬意：

1. **[BadGhost520/ESurfingClient-CVersion](https://github.com/BadGhost520/ESurfingClient-CVersion)**
   - **作者**：[BadGhost520](https://github.com/BadGhost520)
   - **致谢说明**：本项目核心拨号认证引擎直接采用了该项目编译的 OpenWrt 原生 C 语言客户端。该项目成功攻克并实现了广东电信天翼校园客户端 2024 年升级后的动态 ZSM 算法、Ticket 质询与 CDC-HTTP-PAP 协议握手，是本方案得以完全免电脑运行的核心技术支柱。
2. **[Pandaft/ESurfingPy-CLI](https://github.com/Pandaft/ESurfingPy-CLI)**
   - **作者**：[Pandaft](https://github.com/Pandaft)
   - **致谢说明**：在协议逆向分析阶段，参考了该项目对广东天翼校园网 Portal 接口字段规范、错误状态码字典（如 `13018000`）的梳理。
3. **[CurtisYan/InterKnot_Auth_ForMac](https://github.com/CurtisYan/InterKnot_Auth_ForMac)**
   - **作者**：[CurtisYan](https://github.com/CurtisYan)
   - **致谢说明**：参考了其关于看门狗检测、自愈重连机制的流程设计思路。

---

## 📄 开源许可与免责声明

- 本方案文档与部署配置规则基于 **MIT License** 开放分享。
- 本方案集成的底层拨号客户端遵循原作者的 **Apache License 2.0**。
- 本项目仅供网络工程技术交流与个人宿舍合法网络管理学习研究使用，使用者须严格遵守所在高校与网络运营商的校园网使用规范。
