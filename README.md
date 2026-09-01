<div align="center">
  <img src="https://avatars.githubusercontent.com/u/245985800?s=200&v=4" alt="FasterEdge logo" width="100" />
  <h1>FasterEdgeOS</h1>
  <p>基于 Linux 内核与 FasterEdge 生态的轻量边缘计算操作系统</p>
</div>

## 一、项目简介

FasterEdgeOS 是一个面向边缘节点和集群设备的轻量 Linux 发行版。系统基于 Linux 内核、GNU C Library 和 BusyBox 构建，通过 overlay 机制集成 FasterEdge 运行环境及系统服务。

当前仓库保留了从源码构建系统镜像的能力，后续将逐步集成：

- FasterEdge 节点运行时
- FasterEdge2Api 集群拓扑与系统管理 API
- FasterEdgeOS 进程监管与服务管理
- 系统健康检查、日志和资源状态
- 带签名校验与回滚能力的远程更新

> 当前版本处于基础系统改造阶段。已经具备 Linux Live ISO、BIOS/UEFI 和 x86/AArch64 构建基础；FasterEdge 服务的自动部署正在通过 overlay bundle 接入。

## 二、系统组成

```text
Linux Kernel
    ↓
GNU C Library
    ↓
BusyBox 用户空间
    ↓
FasterEdgeOS 基础 rootfs
    ↓
overlay bundles
    ↓
FasterEdgeOS ISO / rootfs 镜像
```

系统启动后提供最小化 Shell、网络基础能力和 overlay 软件。FasterEdgeOS 自有组件建议安装到以下位置：

```text
/usr/bin/                         可执行程序
/etc/fasteredgeos/                系统配置
/etc/init.d/                      服务启动脚本
/var/lib/fasteredgeos/            运行数据、版本和更新状态
/var/log/fasteredgeos/            系统服务日志
/opt/fasteredgeos/releases/       A/B 版本目录
```

## 三、快速构建

构建主机建议使用 Debian/Ubuntu Linux。macOS、Windows 建议通过 Linux 虚拟机或 CI 构建。

> **使用 GitHub Actions 自动构建**：仓库内置 `.github/workflows/manual.yml`，
> 可在 GitHub 页面手动触发（Actions → Run workflow），或在推送 `v*` 标签
> （如 `v0.1.0`）时自动构建。构建完成后会以 artifact 形式交付
> `fasteredgeos.iso` 与 `fasteredgeos_image.tgz`（Docker 镜像，`docker import`
> 即可使用），保留 14 天。

> **工具链要求**：当前 glibc 2.44 需要 GCC 12.1+、binutils 2.39+、GNU make 4.0+。
> 推荐使用 Ubuntu 24.04+（gcc 13.2 / binutils 2.42 / make 4.3）；Ubuntu 22.04 需
> 自行安装新版 gcc/binutils，否则 glibc 构建会失败。

### 1. 安装依赖

```bash
sudo apt update
sudo apt install -y \
  wget make gawk gcc bc bison flex xorriso rsync \
  libelf-dev libssl-dev file cpio gzip xz-utils
```

AArch64 构建和 QEMU 测试还需要：

```bash
sudo apt install -y qemu-system-aarch64 bzip2 dosfstools
```

### 2. 配置构建参数

编辑：

```bash
vi src/.config
```

常用参数：

```text
FIRMWARE_TYPE=bios       # bios / uefi / both
OVERLAY_TYPE=folder      # folder / sparse
OVERLAY_LOCATION=iso     # iso / rootfs
BUILD_KERNEL_MODULES=false
JOB_FACTOR=1
```

### 3. 构建 FasterEdgeOS

```bash
cd src
make all
```

构建完成后生成：

```text
src/fasteredgeos.iso
src/fasteredgeos_image.tgz
```

如果需要重新构建：

```bash
cd src
make clean
make all
```

## 四、启动与测试

### BIOS 模式

```bash
cd src
./qemu-bios.sh
```

### UEFI 模式

```bash
cd src
./qemu-uefi.sh
```

### Docker rootfs 测试

```bash
cd src
docker import fasteredgeos_image.tgz fasteredgeos:latest
docker run --rm -it fasteredgeos:latest /bin/sh
```

### 写入 USB

> 写入设备会覆盖目标磁盘，请确认设备路径后再执行。

```bash
cd src
sudo ./write_to_media.sh /dev/sdX
```

## 五、FasterEdge 服务自动部署计划

FasterEdgeOS 使用 overlay bundle 把额外的软件打进最终 rootfs。FasterEdge 相关组件放在：

```text
src/minimal_overlay/bundles/fasteredgeos/
```

该 bundle 负责：

- 编译或安装 `fasteredge2api`
- 安装 FasterEdge 运行时和配置
- 安装 `fasteredge-supervisor`
- 创建 `/etc/init.d/` 服务脚本
- 初始化 `/etc/fasteredgeos/`、`/var/lib/fasteredgeos/` 和日志目录
- 在系统启动时自动启动基础服务

配置启用后，普通构建命令会自动把 FasterEdgeOS 服务打入镜像：

```text
OVERLAY_BUNDLES=dhcp,fasteredgeos
```

服务管理采用 BusyBox init 兼容方式，不依赖 systemd：

```text
BusyBox init
    ↓
/etc/inittab
    ↓
/etc/init.d/fasteredge-supervisor
    ↓
fasteredge2api + FasterEdge 节点服务
```

## 六、系统管理与远程更新

FasterEdge2Api 将作为系统管理入口，逐步提供：

- 节点和网卡信息
- 进程、服务和运行状态
- CPU、内存、磁盘和系统健康状态
- FasterEdge 集群拓扑与 peer 管理
- Cloud/Edge 节点状态
- 更新检查、下载、安装和回滚

远程更新采用版本目录切换方式：

```text
/opt/fasteredgeos/releases/0.1.0/
/opt/fasteredgeos/releases/0.2.0/
/opt/fasteredgeos/current -> releases/0.2.0
```

更新必须经过：

```text
下载 → SHA256/签名校验 → 空间检查 → 安装 → 健康检查 → 切换或回滚
```

所有远程管理操作应使用 HTTPS，并只允许经过授权的管理员令牌执行。

## 七、安全说明

### 1. 组件版本与已知 CVE 修复情况

| 组件 | 旧版本（含已知漏洞） | 现版本 | 说明 |
| --- | --- | --- | --- |
| Linux 内核 | 5.18.3（2022-11 EOL，无安全维护） | 6.6.155（LTS，维护至 2026-12） | 修复海量内核 CVE |
| GNU C Library | 2.35（CVE-2023-4911 Looney Tunables、CVE-2024-2961 iconv 溢出、CVE-2025-4802 LD_LIBRARY_PATH 等） | 2.44（最新稳定版） | 修复上述所有已公开漏洞 |
| BusyBox | 1.34.1（CVE-2022-48174 ash 栈溢出（CRITICAL）、CVE-2022-28391 netstat RCE 等） | 1.37.0（最新稳定版） | 1.38.0 尚为 unstable，暂不采用 |
| Syslinux | 6.03（2014，上游已停止维护） | 6.03（保持不变） | 无更新版本；仅 BIOS 引导阶段使用，风险面小 |
| Systemd-boot | 2018 快照（上游 fork） | 2018 快照（保持不变） | 无更新版本；仅 UEFI 引导阶段使用 |

### 2. 安全加固措施（本仓库已实施）

- 构建 CFLAGS 移除了 `-fno-stack-protector` 与 `-U_FORTIFY_SOURCE`，改为启用
  `-fstack-protector-strong`（栈保护），BusyBox 构建时另行开启 `-D_FORTIFY_SOURCE=2`。
- 内核构建（`src/02_build_kernel.sh`）显式启用 `STACKPROTECTOR_STRONG`、
  `FORTIFY_SOURCE` 与 `SECURITY_DMESG_RESTRICT`（限制非特权用户读取内核日志）。
- CI 构建环境补充 `rsync`（内核 6.6+ `headers_install` 所需）。

### 3. 已知设计取舍（Live 系统特性）

- **root 无密码**：系统默认以无密码 root 直接进入 shell（传统 Live 系统设计）。
  只建议在隔离环境或开发调试中使用。生产部署请至少执行：

  ```sh
  passwd root
  ```

  并将 `/etc/passwd` / `/etc/shadow` 写入持久化介质（见下文）。
- **多虚拟终端 root 会话**：init 默认在 `tty1~4` 各启动一个 root shell。
  如需收紧，可编辑 `/etc/inittab` 删除多余的 `tty2~tty4` respawn 行。
- **Dropbear（SSH）未默认启用**：`OVERLAY_BUNDLES` 默认不含 `dropbear`，
  无网络登录暴露面；启用时请务必设置 root 密码并改用密钥认证。

### 4. 持久化与更新

- Live 模式（`OVERLAY_TYPE=folder` + `OVERLAY_LOCATION=iso`）下，除非提供可写
  的 `fasteredgeos/rootfs+work` 分区或 `fasteredgeos.img` 镜像，否则所有修改在
  重启后丢失。生产环境请使用可写持久化介质，或在升级流程中重建镜像。
- 远程更新必须遵循“下载 → SHA256/签名校验 → 空间检查 → 安装 → 健康检查 →
  切换或回滚”流程（详见“系统管理与远程更新”章节），禁止覆盖当前运行版本。

## 八、目录说明

```text
FasterEdgeOS/
├── src/                         # 系统源码与构建入口
│   ├── .config                  # 主构建配置
│   ├── Makefile                 # make all/clean/qemu/test
│   ├── 00_* ~ 16_*              # 分阶段构建脚本
│   ├── minimal_boot/             # BIOS/UEFI 启动文件
│   ├── minimal_config/           # 内核和 BusyBox 配置
│   ├── minimal_overlay/          # overlay bundle
│   ├── minimal_rootfs/           # 基础 rootfs
│   └── common.sh                 # 构建公共函数
├── LICENSE                       # 开源许可证
└── README.md                     # 中文项目说明
```

## 九、开发约定

- 所有新增系统组件优先实现为 `src/minimal_overlay/bundles/` 下的独立 bundle。
- 服务必须兼容 BusyBox init，不默认依赖 systemd。
- 构建脚本使用 POSIX Shell，并在失败时立即退出。
- 网络更新必须校验下载内容，禁止直接覆盖当前运行版本。
- 管理 API 默认只监听可信网络；生产环境必须启用 TLS。
- 修改构建流程后至少执行 shell 语法检查和 QEMU/Docker 基础验证。

## 十、相关项目

- [FasterEdge](https://github.com/FasterEdge/FasterEdge)：边缘计算框架。
- [FasterEdge2Api](https://github.com/FasterEdge/FasterEdge2Api)：FasterEdge 集群拓扑与系统管理 HTTP API。

## License

本项目遵循仓库中的 [LICENSE](LICENSE) 文件。系统中使用的 Linux、GNU C Library、BusyBox 和其他第三方组件分别遵循其原始许可证。
