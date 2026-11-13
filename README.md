# ESurfing-OpenWrt-Armor

> **OpenWrt 校园网（天翼校园宽带）全自主自动化认证与防多设备检测网关装甲**  
> *让路由器 100% 独立接管拨号认证、动态算号与网络层防封伪装，全宿舍设备免客户端无感共享高速宽带。*

[![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05+-blue.svg)](https://openwrt.org/)
[![Firewall](https://img.shields.io/badge/Firewall-fw4%20(nftables)-green.svg)](https://openwrt.org/docs/guide-user/firewall/firewall_configuration)
[![Protocol](https://img.shields.io/badge/Protocol-CDC--HTTP--PAP%20%2F%20ZSM-orange.svg)](https://github.com/BadGhost520/ESurfingClient-CVersion)
[![Architectures](https://img.shields.io/badge/Arch-aarch64%20%7C%20mipsel%20%7C%20x86__64%20%7C%20arm-lightgrey.svg)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

---

> ## ⚠️ 两条必须先看的前提
>
> **① 请使用上游最新版客户端：[BadGhost520/ESurfingClient-CVersion](https://github.com/BadGhost520/ESurfingClient-CVersion) 的 `v2.3.1-r5` 或更新版本。**
> 新版已内置单调钟 `Watchdog` 线程与 6 阶快速自愈、动态 ZSM 算法密钥池、302 自动学习认证地址，**本项目的可靠性完全建立在这个基础之上**。用 v2.1.5 等旧版会出现本项目所有守护策略都不生效、且无法按本文档排障的情况。
>
> **② 本项目仓库里的两个"守护脚本"默认都不要用，也不要用旧教程里的定时任务。**
> - `esurfing-renew.sh` — **不要挂 cron**。它每次执行都会 `ifdown wan` 主动断网，曾在真实环境造成 **2 小时** 断网（详见 [FAQ Q6](#q6)）。仅在你**确认**所在线路存在租期到期踢线时手动执行一次。
> - `esurfing-watchdog.sh` — **不要挂 cron**。新版客户端已自带自愈，外部高频杀进程会打断原生退避，并可能触发机房 `35 分钟` 防频控休眠。
>
> **本项目真正的价值是**：TTL/HopLimit=64 伪装、NTP 劫持、UPnP/LLTD 隐身、MT7621 硬件加速避坑、DNS 死锁修复，以及这些排障经验。**守护全靠客户端自身 + procd，不需要额外脚本。**

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
  - **守护交给客户端自身，不装任何第三方脚本**：v2.2.1+ / v2.3.1+ 已内置单调钟 `Watchdog` 线程与 6 阶快速自愈，`procd` 负责进程监管。仓库里的 `esurfing-watchdog.sh` 与 `esurfing-renew.sh` **均不推荐使用，也不要挂 cron**——前者会被视为高频强杀而打断原生自愈、可能触发机房 35 分钟防频控休眠；后者每次执行都会主动断网（详见 FAQ Q6）。
- **不再每日主动断网（2026-11-13 变更）**：实测现代电信校园网 WAN 侧走 DHCP（租期 2 小时、每小时自动续期），认证会话可连续保持 24 小时以上，未观察到「48 小时硬顶」到期。原「清晨 05:30 主动 ifdown wan 重置会话」的做法每次都会主动断网 25 秒至数分钟，风险大于收益，已默认停用（脚本保留，可按需手动执行）。详见 [FAQ Q6](#q6)。
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
| [`setup-hardening.sh`](./setup-hardening.sh) | Shell 脚本 | **OpenWrt 一键防多设备检测加固脚本**（自动注入出向 TTL=64、配置 NTP 局域网劫持、隐藏路由特征、关闭崩溃级硬件流加速，并清理历史遗留的高频看门狗/续约定时任务） |
| [`check-status.sh`](./check-status.sh) | Shell 脚本 | **一键状态健康自检脚本**（检查网卡、IP、拨号进程、防火墙计数、外网 DNS 与 204 放行、硬件流加速配置与定时计划） |
| [`esurfing-watchdog.sh`](./esurfing-watchdog.sh) | Shell 脚本 | ⚠️ **不推荐使用，勿挂 cron**（新版客户端已自带 6 阶自愈，外部高频重启会打断原生退避并可能触发机房 35 分钟防频控。保留仅供排障参考，且**不做通道切换**，永远锁定 Channel 1） |
| [`esurfing-renew.sh`](./esurfing-renew.sh) | Shell 脚本 | ⚠️ **不推荐使用，勿挂 cron**（每次执行都会 `ifdown wan` 主动断网 25s~数分钟，曾在真实环境造成 2 小时断网。仅在你**确认**线路存在租期到期踢线时手动执行一次） |
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

### ⚠️ 部署前必读：**必须使用 v2.3.1-r5 或更新的客户端**

> **本项目只支持 `esurfingclient` v2.3.1-r5 及以上版本。** 低于该版本请先升级，否则本项目的守护策略、配置路径、排障方法**全部不适用**。

**先查你的版本：**

```sh
opkg list-installed | grep esurfingclient
# 或
/usr/bin/esurfingclient --help 2>&1 | head -3
```

**输出不是 `2.3.1-r5` 或更高 → 请先去升级**，不要继续往下部署：

```sh
cd /tmp
# 把 ARCH 换成你自己的架构（见下一步「常见芯片架构速查表」）
ARCH=mipsel_24kc

wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.3.1-r5/esurfingclient_2.3.1-5_${ARCH}.ipk
wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.3.1-r5/luci-app-esurfingclient_2.3.1-5_all.ipk
opkg install esurfingclient_*.ipk luci-app-esurfingclient_*.ipk
```

> 国内下载慢可在 URL 前加反代前缀，如 `https://ghproxy.net/https://github.com/...`
>
> 最新版本号以 [上游 Releases](https://github.com/BadGhost520/ESurfingClient-CVersion/releases) 为准。本文档编写时最新为 **v2.3.1-r5（2026-11-06 发布）**。

**用旧版会发生什么（不是危言耸听）：**

| 后果 | 说明 |
| --- | --- |
| **配置路径不对** | v2.2.x 及以下把 JSON 裸写在 `/etc/config/esurfingclient`，本文档按 v2.3.0+ 的 `/etc/esurfingclient/ESurfingClient.json` 写，直接找不到配置 |
| **没有任何自愈** | v2.1.5 无内置 Watchdog，断线后需外部脚本强杀打破退避；而本项目已按新版策略**不再挂外挂看门狗**，结果就是断了没人管 |
| **容易封号** | v2.1.5 无频控保护；v2.2.x 是"60 秒登录 2 次休眠 35 分钟"，新版才是完整风控 |
| **认证大范围失败** | 旧版算法密钥表过期，2026 年认证服务器已换密钥池，动态算号会失败 |

不同版本的能力对比：

| 对比维度 | v2.1.5 (❌ 不支持本项目) | v2.2.1-r7 (⚠️ 勉强可用) | **v2.3.1+ (✅ 本项目要求)** |
| :--- | :--- | :--- | :--- |
| **自愈守护架构** | 依赖外部脚本强杀服务打破退避 | 内置单调钟 `Watchdog.c` 守护线程 | **单调钟 Watchdog + 进程监管体系**，卡死自动自杀由 `procd` 秒级拉起 |
| **Windows 密钥池** | 旧版算法表，易遭遇密钥失效 | 支持基础 Windows 通道 | **按探测结果重构裁剪算法表**，补齐 25 组新密钥，动态算号极速通过 |
| **学习认证地址** | 静态截取 | 依赖特定重定向 | **恢复从 302 自动学习认证地址**，认证服务器动态测速自选，gwip 自动绑定网关 |
| **配置架构 (OpenWrt)**| 纯 JSON 裸写在 `/etc/config` (易冲撞 UCI)| 纯 JSON 裸写在 `/etc/config` | **标准解耦**：配置归档至 `/etc/esurfingclient/ESurfingClient.json`，UCI 仅管目录 |
| **心跳与退避机制** | 粗暴退出或长间隔等待 | 6 阶快速退避（1s~30s） | **区分网络抖动与服务端拒绝**，连续两次 302 才重认，防锁号风控安全休眠 |
| **防锁号风控保护** | ❌ 无频控，易被机房封号 | 60 秒内登录 2 次休眠 35 分钟 | **机房风控多重防护**，杜绝短时频繁认证被拉黑封号 |

- 完美适配广东电信 2026 最新认证服务器测速与 302 自动重定向。
- 架构规范，不再冲撞 OpenWrt 的 UCI 机制。
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

   > 💡 **建议使用最新版**（推荐当前最新的 `v2.3.1-r5`）。
   > 若你使用了 smartdns / AdGuard Home / mosdns 等接管 DNS 的软件，
   > **安装前务必先读 [FAQ Q7](#faq)**，否则认证会在第一步直接因无法解析而退出。

   ```bash
   cd /tmp

   # 以 mipsel_24kc（小米路由 3G/4、红米 AC2100 等 MT7621 机型）为例，最新 v2.3.1-r5：
   wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.3.1-r5/esurfingclient_2.3.1-5_mipsel_24kc.ipk
   wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.3.1-r5/luci-app-esurfingclient_2.3.1-5_all.ipk

   # 以 aarch64_cortex-a53（小米 AX3000T、红米 AX6000 等 MT7981 机型）为例，最新 v2.3.1-r5：
   # wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.3.1-r5/esurfingclient_2.3.1-5_aarch64_cortex-a53.ipk
   # wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.3.1-r5/luci-app-esurfingclient_2.3.1-5_all.ipk

   # 执行安装 (建议主程序与 LuCI 界面一同安装)
   opkg install esurfingclient_*.ipk luci-app-esurfingclient_*.ipk
   ```

   > 📌 若国内网络下载 GitHub Releases 较慢，可在 URL 前添加反代加速前缀（如 `https://ghproxy.net/https://github.com/...`）。

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

> 💡 **版本配置路径说明**：
> - **v2.3.0+（最新版）**：配置 JSON 标准路径为 `/etc/esurfingclient/ESurfingClient.json`（系统通过 `/etc/config/esurfingclient` 里的 `option dir '/etc/esurfingclient'` 引导）；
> - **v2.2.x 及以下旧版**：配置 JSON 位于 `/etc/config/esurfingclient`。

创建并编辑配置文件（以最新版为例），填入你的宽带账号与密码（文件权限必须设为 `600`，杜绝密码泄露）：

```bash
# 确保配置目录就绪
mkdir -p /etc/esurfingclient

cat << 'EOF' > /etc/esurfingclient/ESurfingClient.json
{
  "enabled": true,
  "web_external_acc": false,
  "log_lv": 4,
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
chmod 600 /etc/esurfingclient/ESurfingClient.json
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

只需 `setup-hardening.sh` 一个文件即可，上传至路由器 `/tmp` 后执行：

```bash
cd /tmp
chmod +x setup-hardening.sh
sh setup-hardening.sh
```

*脚本会自动完成：出向 TTL/HL=64 规则注入、本地 NTP 授时服务启用与局域网重定向劫持、关闭 UPnP/LLTD、屏蔽外网 Ping、关闭导致内核 Panic 猝死重启的硬件流加速，并**主动清理**历史遗留的高频外部看门狗与清晨续约定时任务。*

> **注意**：脚本会**主动删除** `crontab` 里已有的 `esurfing-renew.sh` / `esurfing-watchdog.sh` 任务。这是有意为之——这两类任务会造成确定性断网或触发机房频控（原因见 [FAQ Q6](#q6)）。日常守护由客户端自带的 Watchdog + procd 完成。

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

5. **计划任务：只加日志清理，不加快守护脚本**：
   ```bash
   # ⚠️ 不要把 esurfing-renew.sh / esurfing-watchdog.sh 挂进 crontab
   #   - renew 每次执行都会 ifdown wan 主动断网 25 秒至数分钟（详见 FAQ Q6）
   #   - watchdog 的高频重启会打断新版客户端自带的 6 阶自愈，并可能触发
   #     机房「60 秒登录 2 次休眠 35 分钟」的防频控机制
   # 日常守护交给客户端自身 Watchdog + procd 即可，无需任何第三方脚本。

   # 仅添加日志清理（防 tmpfs 内存盘被轮转日志占满）
   cat << 'EOF' >> /etc/crontabs/root
   # 每月 1 号凌晨 04:00 自动清理历史轮转日志兜底 (防 tmpfs 内存盘溢出)
   0 4 1 * * rm -f /tmp/log/esurfing/logs/logs/*.rotate.log 2>/dev/null
   EOF

   /etc/init.d/cron restart
   ```

   如果你是从旧版教程升级过来的，`crontab` 里可能还残留着旧的续约任务，执行下面命令清理（或直接跑 `setup-hardening.sh`，它会自动清理）：

   ```bash
   sed -i '/esurfing-renew\.sh/d' /etc/crontabs/root
   sed -i '/esurfing-watchdog\.sh/d' /etc/crontabs/root
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

### Q6：需要每天主动重置会话吗？「48 小时租期」还成立吗？为什么严禁盲目切通道？

> **⚠️ 2026-11-13 重要更新**：本节原「清晨 05:30 主动 ifdown wan 重置会话」的建议**已作废并默认停用**。下面是完整的实测复盘。

#### 一、原「48 小时硬顶」假设与现代线路实测不符

原方案假设「电信机房对每次宽带认证设置约 48 小时的单次会话租期硬顶」，据此设计了每天 05:30 主动下线 WAN 重连的 `esurfing-renew.sh`。但在真实线路（广东电信校园网 / 惠州学院）上采集到的事实是：

| 观测项 | 实测结果 | 说明 |
| --- | --- | --- |
| WAN 侧协议 | **DHCP** | 租期 `7200` 秒（2 小时） |
| DHCP 续期 | **每小时自动续期一次** | `udhcpc: lease of 10.77.99.59 obtained ... lease time 7200`，连续多日未出现过期 |
| 认证会话持续 | **连续 24 小时以上** | `11-12 05:31 已认证登录` → `11-13 05:30` 仍在线，没有到期迹象 |
| 「48 小时被踢」记录 | **从未观察到** | 全部历史日志中不存在 |

**结论**：至少在该线路上，WAN 层由 DHCP 自动续期全权兜底，认证会话也没有 48 小时到期行为。「每天主动断网重置」属于**用确定的小损失，去对冲一个并不存在的风险**。

#### 二、真实故障复盘：每天 05:30 的主动断网本身成了最大的断网源

2026-11-13 发生了一次**持续 2 小时**的断网，根因就是 renew 脚本本身：

```
05:30:01  cron 触发 esurfing-renew.sh
05:30:12  ifdown wan          → 主动断网，旧认证进程随后退出（退出码 0）
05:30:37  ifup wan            → 脚本 sleep 25 后拉起
05:30:46  Link is Up 1Gbps
05:30:47  Link is down        → 交换机端口重新协商，链路反复抖动
05:30:35  脚本 sleep 5 结束，start 认证进程
          ↑ 此时 WAN 还没有 IP，认证进程"无网启动"
          → 等不到网络 → 退出码 0 自杀
          → procd 的 respawn 对退出码 0 不重生
05:33:56  脚本 60 秒轮询 204 全部失败，打印"待原生 Watchdog 持续自愈"后退出
          ↑ 但进程已经死了，原生 Watchdog 无从生效
05:34:00  WAN 才真正拿到 IP（比 ifup 晚了 3 分 24 秒）
07:31     人工发现并手动 start，立即认证成功
```

**关键教训有三条：**

1. **`sleep 5` 是错误假设**：它假设 `ifup` 后 WAN 会在 5 秒内就绪。平时确实如此，但遇到端口重新协商时可能长达数分钟，此时认证进程必然"无网启动 → 自杀"。
2. **退出码 0 不会被 procd 重生**：init 脚本里的 `procd_set_param respawn 60 5 5` 只处理异常退出。认证进程正常退出（退出码 0）后，状态会变成 `active with no instances`，**没有任何机制会自动拉起**。
3. **"等待原生 Watchdog 自愈"是错误兜底**：原生 Watchdog 只在**进程存活**时才有意义。进程已死时这句提示没有任何实际作用，只会让人误以为还有兜底。

#### 三、现在的处理方式

- **默认不再注入 05:30 定时任务**，`setup-hardening.sh` 还会主动清理历史上已注入的旧任务；
- **`esurfing-renew.sh` 脚本文件仍然保留**（安装到 `/usr/bin/`），以便在**确认**线路存在租期硬顶时随时手动执行一次；
- 该脚本本身已修复上述两个缺陷：
  - `ifup` 之后改为**轮询等待 WAN 真正就绪**（有 IPv4 地址 + 有走 wan 的默认路由，最长 180 秒），不再死等 5 秒；
  - `start` 之后**校验认证实例是否真的出现**，10 秒内没有实例则明确报错退出，不再"假成功"。

**如果你所在线路确实存在租期到期被踢线**，手动执行一次即可（执行期间会断网 25 秒至数分钟，请避开用网高峰）：

```bash
/usr/bin/esurfing-renew.sh
```

执行后可用 `logread | grep esurfing-renew` 查看结果：

```
esurfing-renew: WAN 已就绪 (等待 3 秒)
esurfing-renew: 清晨会话刷新成功，已放行上网！(用时 5 秒)
```

出现 `警告: ifup 后等待 180 秒 WAN 仍未就绪` 或 `错误: start 后 10 秒内仍未出现认证实例` 时，说明本次刷新失败，请检查 WAN 物理链路与 `/etc/init.d/esurfingclient status`。

#### 四、切勿盲目进行"多通道热备"（仍然有效的致命避坑）

- 部分脚本或用户在遇到断网或重试失败时，喜欢把配置切到 `Channel 4 (iOS)` 或 `Channel 5 (macOS)`；
- **真实高校机房大坑**：国内绝大多数高校（如广东电信一人一号高校）在 BRAS/AC 端口上**锁定了只允许 Windows 原生客户端通道（Channel 1，UA: CCTP/WinSVR5/1068）**。一旦切为 iOS/macOS 通道，机房直接返回鉴权失败或拒绝响应；
- 连续失败会让进程在 60 秒内退出超过 5 次，触发 `procd` 的崩溃保护（停止拉起实例，变成 `active with no instances`），**导致全屋整天彻底断网**。

#### 五、关于外部看门狗 `esurfing-watchdog.sh` 的现状

- 在旧版（v2.1.5）客户端下，断网后指数退避较长，外部看门狗每 2 分钟强制重启来打破死等；
- **在 v2.2.1+ / v2.3.1+ 最新版下，强烈建议不要挂载高频外挂看门狗**：新版已内置单调钟 Watchdog 线程与 6 阶快速自愈，外部频繁杀进程会打断原生的 61 秒自愈，甚至触发 `60 秒内登录 2 次即休眠 35 分钟` 的防锁风控。日常守护交给原生状态机 + procd 即可。
- **注意**：早期版本的该脚本以 `/etc/config/esurfingclient`（UCI 文件）作为配置路径，而 v2.3.0+ 的账号 JSON 实际位于 `/etc/esurfingclient/ESurfingClient.json`，导致其中的通道读取/切换逻辑永远失效。若确需使用，请确认版本已修正该路径。

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
