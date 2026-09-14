# iStoreOS 旁路由自动构建

基于 [iStoreOS](https://github.com/istoreos/istoreos) 当前维护的 `istoreos-24.10` 分支，为以下平台生成轻量路由固件：

- 通用 `x86_64`：同时生成传统 BIOS 与 UEFI 磁盘镜像。
- 斐讯 N1（Amlogic S905D）：使用 iStoreOS `armsr/armv8` rootfs 和 Ophub Flippy 6.12 内核打包。
- 极路由 HiWiFi HC5962（MT7621）：生成 NAND `factory.bin` 与 `sysupgrade.bin`，保留独立 WAN 口和三个有线 LAN 口。

x86_64 与 N1 内置 [daed](https://github.com/daeuniverse/daed)；HC5962 内置 PassWall，并只选择 sing-box 代理核心。所有固件均安装 `luci-theme-argon` 并将其设为默认主题，不包含 Wi-Fi、Samba/KSMBD、Docker 或 Podman。

## 默认网络

三个平台的实际默认地址如下。`192.168.2.1` 只用于 x86_64/N1 的上级网关和 DNS，不是这些固件的管理地址。

| 平台 | 管理地址 | 上级连接 | 上级网关/DNS |
|---|---|---|---|
| x86_64 | `192.168.2.2/24` | `eth0` 单网口旁路由 | `192.168.2.1` |
| N1 | `192.168.2.2/24` | `eth0` 单网口旁路由 | `192.168.2.1` |
| HC5962 | `192.168.3.1/24` | 独立 WAN 口，通过 DHCP 获取 | 由 WAN DHCP 下发 |

默认用户名均为 `root`。

### x86_64 与 N1

如果主路由不是 `192.168.2.1`，请在刷写前修改相应平台的 `files/etc/config/network`，或首次启动后通过终端修改。旁路由通常还需要在主路由中把需要代理的客户端网关/DNS 指向 `192.168.2.2`。

### HC5962

HC5962 使用独立的有线路由拓扑：

| 接口 | 默认配置 |
|---|---|
| WAN | DHCP 自动获取上级地址 |
| WAN6 | DHCPv6 |
| LAN1/LAN2/LAN3 | `br-lan` 有线桥 |
| LAN 管理地址 | `192.168.3.1/24` |

上级路由连接 WAN，终端连接任意 LAN 口。LAN 与 WAN 使用不同网段，以避免路由冲突；默认防火墙和 DHCP 服务继续负责 LAN 客户端联网。

## daed 支持

daed 使用 eBPF/XDP，构建配置启用了 Kernel BTF、BPF events、cgroup BPF、XDP sockets，以及 `kmod-sched-bpf`、`kmod-xdp-sockets-diag` 等运行依赖。LuCI 默认选择 daed 后端，可从“服务 → daede”进行配置。

N1 最终镜像使用外置 Flippy 内核。刷写后应先执行以下命令，确认实际内核提供 BTF，再启用透明代理：

```sh
test -r /sys/kernel/btf/vmlinux && echo BTF_OK || echo BTF_MISSING
daed --version
```

## 自动构建

工作流 `Build iStoreOS bypass routers` 使用矩阵并行构建 x86_64、N1 与 HC5962，并在全部成功后发布到同一个 Release。

- 修改 `.github/`、`build/`、`platforms/` 或 README 后推送到 `master` 自动触发。
- 每月 1 日和 16 日北京时间 08:00 自动构建。
- 支持在 Actions 页面手动运行。
- Release 标签为 `istoreos-bypass_<日期>_<运行序号>`。
- Release 同时包含固件、最终 `.config`、源码版本和 SHA-256 校验文件。

目录结构：

```text
.github/workflows/build-istoreos-bypass.yml
build/prepare-packages.sh
platforms/
├── common/files/etc/uci-defaults/90-default-argon-theme
├── x86_64/
│   ├── config.seed
│   └── files/etc/config/network
├── hc5962/
│   ├── config.seed
│   └── files/etc/config/network
└── n1/
    ├── config.seed
    └── files/etc/
```

## 安装提示

x86_64 镜像需要先解压 `.img.gz`，再写入独立磁盘；根据机器启动方式选择 BIOS 或 EFI 镜像。安装前确认 `eth0` 对应预期管理网卡，首次启动时建议只连接一张网卡。

N1 建议先从 U 盘启动验证网卡、BTF、daed 和重启功能，确认正常后再通过 Amlogic Service 写入 eMMC。写盘会覆盖目标设备数据，必须先备份原系统及关键分区。

HC5962 首次从原厂系统刷入时使用 `factory.bin`；已经运行兼容 OpenWrt/iStoreOS 时才使用 `sysupgrade.bin`。刷机前必须备份 bootloader、factory、bdinfo 等原始分区，并核对具体硬件型号。

## 上游项目

[iStoreOS](https://github.com/istoreos/istoreos) · [daed](https://github.com/daeuniverse/daed) · [Openwrt-Passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) · [openwrt-daede](https://github.com/kenzok8/openwrt-daede) · [amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt)
