# iStoreOS 旁路由自动构建

基于 [iStoreOS](https://github.com/istoreos/istoreos) 当前维护的 `istoreos-24.10` 分支，为以下两个平台生成轻量旁路由固件：

- 通用 `x86_64`：同时生成传统 BIOS 与 UEFI 磁盘镜像。
- 斐讯 N1（Amlogic S905D）：使用 iStoreOS `armsr/armv8` rootfs 和 Ophub Flippy 6.12 内核打包。

两套固件均内置 [daed](https://github.com/daeuniverse/daed) 与 `luci-app-daede`，安装 `luci-theme-argon` 并将其设为默认主题；不包含 Wi-Fi、Samba/KSMBD、Docker、Podman、PassWall 等无关组件。

## 默认网络

固件按单网口旁路由配置：

| 项目 | 默认值 |
|---|---|
| 管理接口 | `eth0` |
| 管理地址 | `192.168.2.2/24` |
| 上级网关 | `192.168.2.1` |
| DNS | `192.168.2.1` |
| 用户名 | `root` |

如果主路由不是 `192.168.2.1`，请在刷写前修改相应平台的 `files/etc/config/network`，或首次启动后通过终端修改。旁路由通常还需要在主路由中把需要代理的客户端网关/DNS 指向 `192.168.2.2`。

## daed 支持

daed 使用 eBPF/XDP，构建配置启用了 Kernel BTF、BPF events、cgroup BPF、XDP sockets，以及 `kmod-sched-bpf`、`kmod-xdp-sockets-diag` 等运行依赖。LuCI 默认选择 daed 后端，可从“服务 → daede”进行配置。

N1 最终镜像使用外置 Flippy 内核。刷写后应先执行以下命令，确认实际内核提供 BTF，再启用透明代理：

```sh
test -r /sys/kernel/btf/vmlinux && echo BTF_OK || echo BTF_MISSING
daed --version
```

## 自动构建

工作流 `Build iStoreOS bypass routers` 使用矩阵并行构建 x86_64 与 N1，并在两者均成功后发布到同一个 Release。

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
└── n1/
    ├── config.seed
    └── files/etc/
```

## 安装提示

x86_64 镜像需要先解压 `.img.gz`，再写入独立磁盘；根据机器启动方式选择 BIOS 或 EFI 镜像。安装前确认 `eth0` 对应预期管理网卡，首次启动时建议只连接一张网卡。

N1 建议先从 U 盘启动验证网卡、BTF、daed 和重启功能，确认正常后再通过 Amlogic Service 写入 eMMC。写盘会覆盖目标设备数据，必须先备份原系统及关键分区。

## 上游项目

[iStoreOS](https://github.com/istoreos/istoreos) · [daed](https://github.com/daeuniverse/daed) · [openwrt-daede](https://github.com/kenzok8/openwrt-daede) · [amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt)
