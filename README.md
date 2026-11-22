<div align="center">
  <img src="https://avatars.githubusercontent.com/u/245985800?s=200&v=4" alt="FasterEdge logo" width="100" />
  <h1>FasterEdgeOS</h1>
  <p>基于 Linux 内核与 FasterEdge 生态的轻量边缘计算操作系统</p>
</div>

## 一、项目简介

FasterEdgeOS 是一个面向边缘节点和集群设备的轻量 Linux 发行版。系统基于 Linux 内核、GNU C Library 和 BusyBox 构建，通过 overlay 机制集成 FasterEdge 运行环境及系统服务。

当前仓库保留了从源码构建系统镜像的能力，已实现的系统初始工具与后续规划：

- ✅ DontCrack-Manager 进程监管（系统初始工具，监管多个 DontCrack 实例，见第五节）
- ✅ Any2UTF8 文本/文件转 UTF-8 工具（内置常见编码集，免系统 iconv，自动探测编码）
- ✅ Any2PCD 文本/二进制点云转 PCD 工具（标准 PCD v0.7，零依赖，见第五节）
- ✅ FasterEdge 节点运行时（框架骨架演示，常驻监管，见第五节）
- ✅ FasterEdge2Api 集群拓扑与系统管理 API（常驻 HTTP 服务，带健康探针，见第五节）
- 系统健康检查、日志和资源状态（规划中）
- 带签名校验与回滚能力的远程更新（规划中）

> 当前版本处于基础系统改造阶段。已经具备 Linux Live ISO、BIOS/UEFI 和 x86/AArch64 构建基础；系统初始工具（DontCrack-Manager 多进程根管理器、Any2UTF8、Any2PCD、FasterEdge 节点运行时、FasterEdge2Api 集群 API）已通过 overlay bundle 接入，开箱即用。
> **多架构的真实状态**：`KERNEL_ARCH=arm64/arm` 目前只产出内核 `Image`/`zImage` 与 initramfs，ISO 引导链（Syslinux/systemd-boot）仍是 x86 专属、未在真机验证。详见第七节"可复现构建、多架构与供应链"中的降级宣称。

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
  libelf-dev libssl-dev file cpio gzip xz-utils \
  dosfstools e2fsprogs
```

`dosfstools` 与 `e2fsprogs` 是 FAT 启动镜像与 ext2 overlay 镜像能做到字节级可复现的
前提（`mkfs.vfat --invariant`、带固定 UUID 的 `mke2fs`）；缺失时脚本会退回 BusyBox
的 `mkfs` 并在 stderr 明确告警"产物不满足字节级可复现"。

AArch64 交叉构建与 QEMU 启动测试另需：

```bash
sudo apt install -y gcc-aarch64-linux-gnu qemu-system-aarch64
```

> ISO 引导链（BIOS 的 Syslinux、UEFI 的 systemd-boot）目前仅支持 x86。
> `KERNEL_ARCH=arm64` 只产出内核 `Image` 与 initramfs，不产出可引导 ISO。

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
KERNEL_ARCH=x86          # x86 / arm64 / arm（= 内核 Makefile 的 ARCH）
CROSS_COMPILE=           # 交叉编译前缀，留空为本机构建；arm64 交叉构建如 aarch64-linux-gnu-
SOURCE_DATE_EPOCH=       # 留空用默认 1767225600；设为 timestamp 则破坏可复现
```

`KERNEL_ARCH` 与 `CROSS_COMPILE` 的含义见 `src/02_build_kernel.sh` 的架构表：
`x86` 产 `arch/x86/boot/bzImage`，`arm64` 产 `arch/arm64/boot/Image`，`arm` 产
`arch/arm/boot/zImage`。三者都由同一张 case 表驱动，不再有硬编码的 x86 路径。

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

验证两次构建字节一致：

```bash
cd src
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run1.txt
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run2.txt
diff /tmp/run1.txt /tmp/run2.txt && echo "字节级可复现"
```

不编译就能跑的静态自检（语法 / 时间戳取值 / tar·gzip 字节一致 / 供应链覆盖率 / 架构参数化）：

```bash
cd src
./test_reproducible.sh
```

完整的覆盖率与降级宣称见第七节。

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

## 五、系统初始工具与 FasterEdge 服务部署

FasterEdgeOS 使用 overlay bundle 把额外的软件打进最终 rootfs。FasterEdge 相关组件放在：

```text
src/minimal_overlay/bundles/fasteredgeos/
```

该 bundle（系统初始工具）当前已实现：

- **根进程管理器**：编译并安装 `DontCrack-Manager`。单体的 DontCrack 一次只能管理一个
  进程；DontCrack-Manager 同时监管多个 DontCrack 实例（各自管理一个子进程），作为
  本无进程管理器 Live 环境的系统多进程根管理器。
- **DontCrack 单体**：编译并安装 `/usr/bin/dontcrack`（被根管理器监管的实例；
  demo 服务依赖它，缺失时该服务永远无法启动——CI 端到端验证覆盖）。
- **配置**：安装 `/etc/fasteredgeos/manager.yaml`（服务级 DontCrack 参数、依赖编排、
  健康探针、退避重启、优雅停机）。
- **开机启动**：安装 `/etc/autorun/20_dontcrack-manager.sh`，开机最先启动根管理器
  （setsid 后台运行，日志 `/var/log/fasteredgeos/manager.log`）。
- **演示子进程**：安装 `/usr/bin/fasteredgeos-demo`（由 demo 服务监管）。
- **目录初始化**：`/var/lib/fasteredgeos/` 与 `/var/log/fasteredgeos/`。

FasterEdgeOS 默认启用 FasterEdge 软件组合（开箱即用），普通构建命令会自动把这些系统初始工具打入镜像：

```text
OVERLAY_BUNDLES=dhcp,fasteredgeos,fasteredge,any2pcd,any2utf8,fasteredge2api,mll_hello,mll_logo,mll_source
```

除 `fasteredgeos`（DontCrack-Manager 根管理器，见上）外，其余 FasterEdge 软件组合 bundle：

```text
- **fasteredge**：FasterEdge 节点运行时。编译 `examples/demo` 为 `/usr/bin/fasteredge-demo`（一次性骨架演示），附带常驻包装器 `/usr/bin/fasteredge-node`，由根管理器监管。源码固定 commit，可设 `FE_SOURCE_DIR` 指向本地源码。详见 `src/minimal_overlay/bundles/fasteredge/README.md`。
- **fasteredge2api**：FasterEdge 集群 HTTP API 服务（常驻，子进程监听 `127.0.0.1:8080`，健康探针直连 `/healthz`；管理端口 11885）。源码固定 commit，可设 `FE2A_SOURCE_DIR` 指向本地源码。详见 `src/minimal_overlay/bundles/fasteredge2api/README.md`。
- **any2pcd**：bin / 文本 / CSV / PCD → 标准 PCD v0.7 点云转换工具（Go 标准库实现，零依赖）。
- **any2utf8**：文本/文件编码转换工具（内置 GBK / GB18030 / Big5 / Shift_JIS / UTF-16 等常见编码，不依赖系统 iconv 与 locale）。
```

其中 `fasteredge2api` / `any2pcd` / `any2utf8` 支持版本查询（当前 `1.0.20261116`）；离线升级可设置 `FE_SOURCE_DIR` / `FE2A_SOURCE_DIR` / `ANY2PCD_SOURCE_DIR` / `ANY2UTF8_SOURCE_DIR` 指向本地新版源码目录，构建时优先使用指定源码。详见各自 bundle 目录下的 `README.md`。

服务管理采用 BusyBox init 兼容方式，不依赖 systemd：

```text
BusyBox init
    ↓
/etc/inittab → /etc/04_bootscript.sh
    ↓
/etc/autorun/20_dontcrack-manager.sh
    ↓
DontCrack-Manager（根管理器，/etc/fasteredgeos/manager.yaml）
    ↓
DontCrack 实例 × N（各自管理一个子进程）
```

聚合状态查询（默认监听 `127.0.0.1:11884`）：

```text
# FEOS 系统基于 BusyBox(用 wget;宿主有 curl 时亦可直接用 curl)。
wget -q -O - http://127.0.0.1:11884/healthz
wget -q -O - http://127.0.0.1:11884/status
wget -q -O - --post-data='' http://127.0.0.1:11884/shutdown
```

后续将在此基础上接入：带签名校验与回滚能力的远程更新（远程更新仍按“下载 → 校验 →
安装 → 健康检查 → 切换或回滚”流程，禁止覆盖当前运行版本）。

> CI 构建（`manual.yml`）已启用完整 FasterEdge 软件组合
> （`OVERLAY_BUNDLES=dhcp,fasteredgeos,fasteredge,any2pcd,any2utf8,fasteredge2api,...`）
> 并通过 `actions/setup-go` 提供 Go 1.27.4 工具链；本地构建需自行安装 Go 1.27.4+。
> `fasteredge` / `fasteredge2api` / `any2pcd` / `any2utf8` 的编译与 overlay
> 构建由 `check.yml` 独立门禁覆盖。

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

## 七、可复现构建、多架构与供应链

本节记录**可由仓库内脚本复现验证**的能力，以及**已明确降级**的宣称。每一条都
对应仓库里可执行的检查，不做无法验证的声明。

### 1. 一键自检

```bash
cd src
./test_reproducible.sh
```

退出码 0 表示全部通过。它覆盖 7 组检查（实测输出见下）：

| 组 | 检查内容 | 是否真实执行 |
| --- | --- | --- |
| [1] | 仓库内全部 `*.sh` 的 `bash -n` 语法检查 | 是 |
| [2] | `SOURCE_DATE_EPOCH` / `KBUILD_BUILD_TIMESTAMP` / `TZ=UTC` / `TAR_REPRODUCIBLE` / 固定 UUID 的取值与 export | 是（子进程回读） |
| [3] | 同一目录两次 `tar $TAR_REPRODUCIBLE` 打包字节一致、成员属主为 0/0 | 是（真实打包比对） |
| [4] | 两次 `gzip -n` 输出字节一致、gzip 头部 MTIME=0；两次 `xz --threads=1` 输出字节一致 | 是（真实压缩比对） |
| [5] | 每个 `download_source` 落点都有对应 `.sha256` sidecar（供应链覆盖率） | 是（静态解析，实测 38 个落点全部有 sidecar） |
| [6] | 每个 sidecar 内嵌文件名与文件名一致、哈希为 64 位十六进制 | 是 |
| [7] | `KERNEL_ARCH` 三个架构的 `KERNEL_IMAGE_TARGET` / `KERNEL_IMAGE_PATH` 符合内核约定，且无硬编码 x86 路径 | 是 |

CI 门禁：`.github/workflows/check.yml` 的 `reproducible` job 在每次 push / PR 执行同一脚本。

### 2. 可复现构建的实现方式

| 差异来源 | 固定手段 | 所在文件 |
| --- | --- | --- |
| 归档成员顺序、mtime、属主 | `tar --sort=name --mtime=@$SOURCE_DATE_EPOCH --owner=0 --group=0 --numeric-owner` | `src/common.sh` 的 `TAR_REPRODUCIBLE` |
| 内核构建时间戳 | `KBUILD_BUILD_TIMESTAMP=@$SOURCE_DATE_EPOCH`、`KBUILD_BUILD_USER/HOST` | `src/common.sh` |
| 宿主时区影响日期格式化 | `TZ=UTC` | `src/common.sh` |
| rootfs 归档顺序 | `find -print0 \| LC_ALL=C sort -z \| cpio -0` | `src/10_pack_rootfs.sh` |
| xz 压缩输出 | `xz -9 --check=crc32 --threads=1`（固定线程数） | `src/10_pack_rootfs.sh`、`mll_source/bundle.sh` |
| gzip 头部文件名/时间戳 | `gzip -n -9` | `src/15_generate_image.sh` |
| ext2 overlay 的 UUID/创建时间 | `mke2fs -U $FEOS_OVERLAY_FS_UUID -E root_owner=0:0` + `E2FSPROGS_FAKE_TIME=$SOURCE_DATE_EPOCH` | `src/11_generate_overlay.sh` |
| FAT（UEFI 启动镜像）内部时间戳 | `mkfs.vfat --invariant`（新版 dosfstools） | `src/13_prepare_iso.sh` |
| ISO 卷时间戳 / GPT disk GUID / 文件日期 | xorriso 的 mkisofs 模拟层原生读取 `SOURCE_DATE_EPOCH`（见 `xorrisofs(1)` 的 ENVIRONMENT VARIABLES） | `src/14_generate_iso.sh` |
| 源码归档文件名含日期 | `date -u -d "@$SOURCE_DATE_EPOCH" +"%d-%b-%Y"` | `mll_source/bundle.sh` |

验证"两次构建字节一致"的方法：

```bash
cd src
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run1.txt
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run2.txt
diff /tmp/run1.txt /tmp/run2.txt && echo "字节级可复现"
```

`14_generate_iso.sh` 结束时会自己打印 ISO 的 sha256，`15_generate_image.sh` 的产物
也可直接 `sha256sum`，便于在 CI 日志里留证。

### 3. 供应链锁定（fail-closed）

所有源归档都必须有同名 `.sha256` sidecar，缺失即**中止构建**，不再"跳过校验"：

```text
src/source/<主链归档名>.sha256          内核 / glibc / busybox / syslinux / systemd-boot
src/source/overlay/<overlay 归档名>.sha256   各 overlay bundle
```

sidecar 内容格式固定为 `sha256sum` 的原生输出（大写或小写十六进制 + 两个空格 + 文件名），
校验方式为 `( cd <目录> && sha256sum -c <文件名>.sha256 )`。sidecar 的**文件名必须
逐字符等于 `01_get.sh` 里的落点文件名**（例如 `cf_cli` 落点是 `cf-cli.tgz`，不是上游
的 `cf8-cli_8.19.0_linux_x86-64.tgz`）。`[5]`/`[6]` 两项检查就是用来守住这条不变量的。

`make clean` 只删除 `source/` 下的归档，保留 `*.sha256`，避免一次清理就把下次构建
变成"sidecar 缺失"。

**已知例外**：`USE_LOCAL_SOURCE=true` 且文件已存在时，`download_source` 走本地分支、
**不做** sha256 校验（沿用原有语义，未改动）。这是刻意的取舍——离线分发时代替校验的
是分发介质本身的完整性。若需要强制校验，请把 `USE_LOCAL_SOURCE` 置为 `false`。

### 4. 多架构（x86 / AArch64）

`KERNEL_ARCH` 与 `CROSS_COMPILE` 参数化后：

```bash
# x86_64/AArch64 本机构建（默认）
KERNEL_ARCH=x86    CROSS_COMPILE=                make all

# 在 x86_64 主机上交叉构建 AArch64 内核 + initramfs
sudo apt install -y gcc-aarch64-linux-gnu
KERNEL_ARCH=arm64  CROSS_COMPILE=aarch64-linux-gnu-  make all
```

`02_build_kernel.sh` 与 `mll_logo/bundle.sh` 共用同一张架构表；arm64 且
`CROSS_COMPILE` 为空时脚本直接报错退出，不静默产出错误架构的内核。
`qemu-bios.sh` / `qemu-uefi.sh` / `qemu-bios-console.sh` 按 `KERNEL_ARCH` 选择
`qemu-system-<arch>`，未知架构同样报错退出。

### 5. 覆盖率与降级宣称（必须如实告知）

**已实测通过（本仓库内可复现）**

- `bash -n`：`scripts/lint.sh` 覆盖 208 个 shell 脚本（含无扩展名、按 shebang 识别的
  `src/minimal_rootfs/init` 等），全部通过，exit 0；`test_reproducible.sh` 的 `[1]`
  另外对 205 个 `*.sh` 做同检查。
- shellcheck（v0.10.0，`-S error -S warning`）：全部 208 个脚本无 error / warning，
  `scripts/lint.sh` exit 0。仅剩 `info`/`style` 级提示：`SC1091`（无法跟踪 `. ./common.sh`）、
  `SC2006`（历史遗留的反引号写法）以及 `test_reproducible.sh` 里的 `SC2031`——那是
  `-x` 跟随 `common.sh` 后对其内部 `export SRC_DIR="$PWD"` 的连锁误报，本脚本不受影响。
- `tar` / `gzip` 层的字节级一致：`test_reproducible.sh` 的 `[3]`/`[4]` 真实打包压缩比对。
- 供应链覆盖率：38 个 `download_source` 落点全部有 sidecar（`[5]`），全部 sidecar 自洽（`[6]`）。
- `KERNEL_ARCH` 参数化与语法/lint 门禁（`[7]`、`[1]`）。

**已实现但未在本环境实测（明确降级宣称）**

- **完整 ISO 端到端字节一致**：未实测。需要真实构建（约 1 小时）+ `xorriso`、
  `e2fsprogs`、`dosfstools`、loop 设备与 root 权限，本仓库的验证环境不具备。
  已按 `xorrisofs(1)` 的 `SOURCE_DATE_EPOCH` 语义实现，但**没有两次构建的实际
  哈希比对记录**。请在 Linux 工作机上按本节"2. 可复现构建的实现方式"里的命令自行验证后再宣称。
- **AArch64 / ARM 的 ISO 引导链**：未实测。`FIRMWARE_TYPE=bios/uefi/both` 与
  Syslinux / systemd-boot 引导文件仍是 x86 专属；arm64/arm 目前只保证产出内核
  `Image`/`zImage` 与 initramfs，**不能引导**。真机/`qemu-system-aarch64` 启动未验证。
- **`OVERLAY_TYPE=sparse` 分支**：未实测。需要 root + loop 设备（Windows/WSL 无此环境）。
- **`mkfs.vfat --invariant` 与 `mke2fs -E root_owner`**：未实测。宿主机未安装
  `dosfstools` / `e2fsprogs`，只做了参数存在性探测；脚本在缺少这些工具时会打印
  显式警告并退回旧路径。
- **`USE_LOCAL_SOURCE=true` 的 sidecar 校验**：按设计不校验（见第 3 节例外说明）。

**会破坏字节级可复现、但脚本已显式告警的降级路径**

- 宿主缺 `mke2fs` 时退回 BusyBox `mkfs.ext2`：UUID/时间戳未固定，stderr 明确
  打印"产物不满足字节级可复现"。
- 宿主 `mkfs.vfat` 不支持 `--invariant` 时：FAT 内部时间戳仍随构建时间变化，
  同样打印显式警告。
两者都是**有噪音的降级**，不会静默通过。

**评测口径说明**

"可复现"在本仓库的定义是：给定相同的源码树、`.config` 与 `SOURCE_DATE_EPOCH`，
在满足依赖要求的 Linux 构建机上，`fasteredgeos.iso` 与 `fasteredgeos_image.tgz`
的 sha256 应当相同。当前仓库能自动化验证的是该链条上除 ISO/EXT2/FAT 打包之外的
所有环节（见上表），因此本仓库的宣称强度为：**供应链锁定与 tar/gzip/cpio/xz 层
字节级可复现已实测；ISO/文件系统镜像层的字节级可复现为"按规范实现、待真机验证"**。

## 八、安全说明

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

## 九、目录说明

```text
FasterEdgeOS/
├── src/                         # 系统源码与构建入口
│   ├── .config                  # 主构建配置
│   ├── Makefile                 # make all/clean/qemu-bios/qemu-uefi/test
│   ├── 00_* ~ 16_*              # 分阶段构建脚本
│   ├── test_reproducible.sh     # 可复现与供应链自检（一键运行）
│   ├── source/                  # 主链源码归档 + *.sha256 sidecar
│   ├── source/overlay/          # overlay 源码归档 + *.sha256 sidecar
│   ├── minimal_boot/             # BIOS/UEFI 启动文件
│   ├── minimal_config/           # 内核和 BusyBox 配置
│   ├── minimal_overlay/          # overlay bundle
│   ├── minimal_rootfs/           # 基础 rootfs
│   └── common.sh                 # 构建公共函数
├── scripts/                      # 一键静态检查 lint.sh
├── LICENSE                       # 开源许可证
└── README.md                     # 中文项目说明
```

## 十、开发约定

- 所有新增系统组件优先实现为 `src/minimal_overlay/bundles/` 下的独立 bundle。
- 服务必须兼容 BusyBox init，不默认依赖 systemd。
- 构建脚本使用 POSIX Shell，并在失败时立即退出。
- 网络更新必须校验下载内容，禁止直接覆盖当前运行版本。
- 管理 API 默认只监听可信网络；生产环境必须启用 TLS。
- 修改构建流程后至少执行 shell 语法检查、`src/test_reproducible.sh` 和 QEMU/Docker 基础验证。
- 一键静态检查入口为 `scripts/lint.sh`（本机 Git Bash 与 CI 均可运行）：依次执行 `bash -n`、`sh -n`、shellcheck（`-S error -S warning`，未安装时自动退化为仅双语法检查）以及 `tools/*.mjs` 与 YAML/JSON 的解析校验；`LINT_STRICT=1` 会把 shellcheck 提到 style 级。提交前请保证其 exit 0。
- 新增任何需要下载的源码（主链或 overlay bundle）时，必须同时提交对应的 `.sha256` sidecar，否则 `download_source` 会以 fail-closed 方式中止构建。

## 十一、相关项目

- [FasterEdge](https://github.com/FasterEdge/FasterEdge)：边缘计算框架。
- [FasterEdge2Api](https://github.com/FasterEdge/FasterEdge2Api)：FasterEdge 集群拓扑与系统管理 HTTP API。

## License

本项目遵循仓库中的 [LICENSE](LICENSE) 文件。系统中使用的 Linux、GNU C Library、BusyBox 和其他第三方组件分别遵循其原始许可证。
