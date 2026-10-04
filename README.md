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
- **攻克电信动态挑战（AutoZSM）**：集成应对电信 2024 年升级后的 **动态 ZSM 算法**，摆脱老旧失效脚本。
- **直击根源解决业务限制**：走原生客户端私有协议通道，彻底避开 `13018000`（Web锁死）与 `140010`（客户端本地IP比对）。
- **OpenWrt 23.05 内核级防共享伪装装甲**：
  - **TTL / Hop Limit 强制锁定**：出向 IPv4 与 IPv6 数据包强制改写为 `64`，彻底抹除路由转发跳数痕迹。
  - **NTP 时钟流量内网劫持**：局域网 UDP 123 端口授时请求自动重定向至路由器本地时钟源，消除各设备硬件时钟频偏特征。
  - **暴露特征隐身**：禁用 UPnP、LLTD 拓扑发现及外网 ICMP Ping 响应，隐藏路由器网络暴露面。
- **工业级自愈与闪存保护**：
  - 由 OpenWrt `procd` 守护进程接管，异常崩溃 5 秒自动拉起。
  - 遇到学校断电、半夜断网或网络波动，内置指数退避机制自动等待并在网络恢复后秒级自愈。
  - 日志及临时状态写入内存盘（`tmpfs`），零闪存颗粒磨损。
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
| [`setup-hardening.sh`](./setup-hardening.sh) | Shell 脚本 | **OpenWrt 一键防多设备检测加固脚本**（自动注入出向 TTL=64、配置 NTP 局域网劫持与隐藏路由特征） |
| [`check-status.sh`](./check-status.sh) | Shell 脚本 | **一键状态健康自检脚本**（检查网卡、IP、拨号进程、防火墙计数、外网 DNS 与 204 放行） |
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
   前往 [BadGhost520/ESurfingClient-CVersion Releases](https://github.com/BadGhost520/ESurfingClient-CVersion/releases) 页面，下载对应架构的 `.ipk` 安装包上传至路由器 `/tmp` 目录（以 `v2.1.5-r1` 为例）：
   ```bash
   cd /tmp
   # 以 aarch64 (如 AX3000T) 为例：
   wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.1.5-r1/esurfingclient_2.1.5-1_aarch64_cortex-a53.ipk
   # 以 mipsel_24kc (如 MT7621) 为例：
   # wget https://github.com/BadGhost520/ESurfingClient-CVersion/releases/download/v2.1.5-r1/esurfingclient_2.1.5-1_mipsel_24kc.ipk

   # 执行安装
   opkg install esurfingclient_*.ipk
   ```

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
      "mark": "dorm",
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
> - `log_lv: 2`：**强烈推荐设为 `2`（告警级）**。若设为 `4`，客户端每 3 秒会向内存盘刷一条心跳日志，长期运行会挤占数兆 RAM；设为 `2` 可实现终身免维护且静默稳定。
> - `conn_timeout: 7` 与 `op_timeout: 10`：为兼顾校园网高峰期波动设置的最佳超时窗口。

启动服务并设置开机自启：
```bash
/etc/init.d/esurfingclient enable
/etc/init.d/esurfingclient start
```

---

### 步骤 4：网络层防多设备检测加固 (fw4 / nftables)

针对校园网常见的多设备检测手段（TTL 递减检测、时钟偏差检测、网络服务扫描），本项目提供了**一键自动化加固脚本**与**手动逐步配置**两种方式：

#### 方案 A：一键加固脚本（强烈推荐）

将仓库中的 `setup-hardening.sh` 上传至路由器 `/tmp` 目录并执行：

```bash
chmod +x /tmp/setup-hardening.sh
sh /tmp/setup-hardening.sh
```

*脚本会自动完成出向 TTL/HL=64 规则注入、本地 NTP 授时服务启用与局域网重定向劫持、关闭 UPnP/LLTD 并屏蔽外网 Ping。*

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

4. **关闭芯片级硬件流加速（关键避坑）**：
   ```bash
   # 保留软件流加速，禁用硬件加速 (flow_offloading_hw=0)
   # 防止芯片硬件 NAT 引擎绕过 Netfilter 防火墙导致出向 TTL=64 伪装穿透失效
   uci set firewall.@defaults[0].flow_offloading_hw='0' 2>/dev/null
   uci commit firewall

   # 重载防火墙使全部加固规则生效
   /etc/init.d/firewall restart
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

---

## ❓ 常见问题与技术避坑指南 (FAQ)

### Q1：为什么网页认证提示“拨号方式错误”（代码 `13018000`）？
- **原因**：这是运营商针对开通了“一人一号多终端”业务的账号策略。电信在后台对有线端口锁死了 Web 网页认证通道，前端代码明确注释“已办理一人一号多终端业务的用户，请使用客户端登录”。
- **解决**：无需尝试逆向网页端或识别验证码，直接在路由器上运行本项目提供的 `esurfingclient`（`channel: 1`）即可直接打通官方原生私有客户端协议。

### Q2：电脑接在路由器后打开客户端，为什么会提示“客户端IP地址不正确”（代码 `140010`）？
- **原因**：官方客户端在启动时会通过 Windows API 读取本地物理网卡 IP（如 `192.168.x.x`），并与网关重定向报上来的内网 IP（如 `10.x.x.x`）进行比对。比对不一致即判定存在二级路由，直接在本地弹窗拦截。
- **解决**：本项目的意义正在于**彻底丢弃电脑客户端**。所有认证由路由器在最前线自主完成，电脑开机即直接上网，永远不会触发官方客户端的本地环境检查。

### Q3：刚重启服务时提示“获取 Ticket 响应失败”，但几十秒后又能正常上线？
- **原因**：电信服务端在会话注销（`term.cgi`）与下发新 Ticket（`ticket.cgi`）之间存在几十秒的会话锁定保护期。
- **机制**：客户端内置了 60 秒指数退避保护机制，短暂等待后会自动获取到全新 Ticket 并完成登录，属于正常的网络自愈行为。

### Q4：宿舍半夜断电、断网或清晨来电后，路由器能否自动恢复？
- **支持**：核心服务通过 OpenWrt `procd` 守护进程管理（带有 `respawn 60 5 5` 保护）。遇到断网时会自动执行探测并静默重试，网络或电力恢复后无需人工干预即可秒级自动上线。

### Q5：多人连路由器 WiFi 同时打游戏、看视频，会被运营商检测到吗？
- **防护原理**：运营商多终端检测通常依赖三项特征：
  1. **TTL 步长不一致**（Android 默认为 64、Windows 默认为 128、iOS 默认为 64，经过路由器 NAT 减 1 后暴露）-> 本项目通过 `40-ttl-mangle.nft` 强制统一改写出向 TTL 为 64。
  2. **NTP 时钟偏差特征**（各设备微小晶振偏差形成的设备时钟指纹）-> 本项目将内网 NTP 授时请求统一重定向到路由器自身。
  3. **网络特征探测**（主动扫描 UPnP、Ping 回应）-> 本项目已全部禁用。  
  在此三重加固下，运营商机房 DPI 探针只能看到一台特征纯净的标准 Windows 终端。

---

## 🙏 致谢与参考开源项目 (Acknowledgements)

本项目在协议梳理、加固设计与工程落地过程中，参考并使用了以下杰出的开源项目，特此向原作者致以崇高的敬意：

1. **[BadGhost520/ESurfingClient-CVersion](https://github.com/BadGhost520/ESurfingClient-CVersion)**
   - **作者**：[BadGhost520](https://github.com/BadGhost520)
   - **致谢说明**：本项目核心拨号认证引擎直接采用了该项目编译的 OpenWrt 原生 C 语言客户端。该项目成功攻克并实现了广东/江苏等地电信天翼校园客户端 2024 年升级后的动态 ZSM 算法、Ticket 质询与 CDC-HTTP-PAP 协议握手，是本方案得以完全免电脑运行的核心技术支柱。
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
