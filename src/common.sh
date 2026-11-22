#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 以下变量均显式 export: 各阶段脚本(01_*~16_*)通过 ". ./common.sh" 加载后使用,
# 对 shellcheck 单文件分析而言属于"外部引用"(SC2034)。
export SRC_DIR="$PWD"
export CONFIG="$SRC_DIR/.config"
export SOURCE_DIR="$SRC_DIR/source"
export WORK_DIR="$SRC_DIR/work"
export KERNEL_INSTALLED="$WORK_DIR/kernel/kernel_installed"
export GLIBC_OBJECTS="$WORK_DIR/glibc/glibc_objects"
export GLIBC_INSTALLED="$WORK_DIR/glibc/glibc_installed"
export BUSYBOX_INSTALLED="$WORK_DIR/busybox/busybox_installed"
export SYSROOT="$WORK_DIR/sysroot"
export ROOTFS="$WORK_DIR/rootfs"
export OVERLAY_ROOTFS="$WORK_DIR/overlay_rootfs"
export ISOIMAGE="$WORK_DIR/isoimage"
export ISOIMAGE_OVERLAY="$WORK_DIR/isoimage_overlay"

# 该函数从主 '.config' 文件中读取属性。
#
# 使用 () 而不是 {} 作为函数体，是符合 POSIX 规范的执行子 shell
# 的方式，因此函数中的所有变量实际上都会成为局部作用域变量。
# 请注意，大多数 shell 支持 'local' 关键字，但它不符合 POSIX 规范。
read_property() (
  # 我们要查找的属性。
  prop_name=$1

  # 属性的值，初始设置为空字符串。
  prop_value=

  if [ ! "$prop_name" = "" ] ; then
    # 在主 '.config' 文件中搜索。
    prop_value=$(grep -i "^${prop_name}=" "$CONFIG" | cut -f2- -d'=' | xargs)
  fi

  echo "$prop_value"
)

# 从主 '.config' 文件中读取常用属性。
export JOB_FACTOR
JOB_FACTOR=$(read_property JOB_FACTOR)
export CFLAGS
CFLAGS=$(read_property CFLAGS)
NUM_CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)

# 计算稍后要使用的 'make' 任务数。可用环境变量 NUM_JOBS 覆盖
# (CI/内存受限环境的稳定性: 内核编译并行任务过多可能 OOM/卡死)。
NUM_JOBS="${NUM_JOBS:-$((NUM_CORES * JOB_FACTOR))}"

# ---------------------------------------------------------------------------
# 可复现构建 (Reproducible Builds)
#
# 构建链中所有会产生时间戳/顺序差异的来源都必须固定:
#   1. SOURCE_DATE_EPOCH - GNU tar/gzip/xz/cpio/内核 KBUILD_BUILD_TIMESTAMP 等
#      都遵循该环境变量(reproducible-builds.org 规范)。
#   2. tar 打包使用 --sort=name --mtime=@$SOURCE_DATE_EPOCH --owner=0
#      --group=0 --numeric-owner, 保证成员顺序与元数据不依赖文件系统状态。
#   3. gzip 使用 -n(不写入文件名与时间戳)。
#   4. mkfs 使用固定 UUID/hash-seed 与显式时间戳。
#
# 取值优先级: 环境变量 SOURCE_DATE_EPOCH > .config 中 SOURCE_DATE_EPOCH >
# 固定默认值。若设为 'timestamp' 则回退为当前时间(不推荐, 仅调试用)。
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}"
if [ "$SOURCE_DATE_EPOCH" = "" ] ; then
  SOURCE_DATE_EPOCH=`read_property SOURCE_DATE_EPOCH`
fi
if [ "$SOURCE_DATE_EPOCH" = "" ] || [ "$SOURCE_DATE_EPOCH" = "timestamp" ] ; then
  # 固定默认值 1767225600 = 2026-01-01T00:00:00Z。与 reproducible-builds.org
  # 建议一致: 使用一个确定性的时刻, 而不是构建时的墙上时钟。取整数年起点
  # 而非某个 tag 的提交时间, 是因为 tag 时间会随发布不断变化, 换 tag 就换
  # 默认值会让历史构建无法复现。
  SOURCE_DATE_EPOCH_DEFAULT=1767225600
  if [ "$SOURCE_DATE_EPOCH" = "timestamp" ] ; then
    SOURCE_DATE_EPOCH=`date -u +%s`
  else
    SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH_DEFAULT
  fi
  echo "SOURCE_DATE_EPOCH 未配置, 使用默认值 $SOURCE_DATE_EPOCH。"
fi
export SOURCE_DATE_EPOCH

# 导出供内核构建(scripts/mkcompile_h 会读取)与后续脚本使用。
export KBUILD_BUILD_TIMESTAMP="@$SOURCE_DATE_EPOCH"
export KBUILD_BUILD_USER=fasteredgeos
export KBUILD_BUILD_HOST=fasteredgeos

# TZ 固定: 避免宿主时区影响任何日期格式化输出。
export TZ=UTC

# tar 的可复现打包选项(顺序/元数据全部固定)。提取源码的解压路径仍然
# 使用 --no-same-owner, 与此处打包用途不同。
TAR_REPRODUCIBLE="--sort=name --mtime=@$SOURCE_DATE_EPOCH --owner=0 --group=0 --numeric-owner"
export TAR_REPRODUCIBLE

# 固定文件系统标识: 由 FasterEdgeOS 命名空间派生, 不随构建时间变化。
# 用于 overlay 的 ext2 镜像(11_generate_overlay.sh) 与 UEFI FAT 镜像
# (13_prepare_iso.sh)。缺少这些固定值, mke2fs/mkfs.vfat 会写入随机 UUID,
# 两次构建的产物字节必然不同。
FEOS_OVERLAY_FS_UUID=6f1e0c2a-9d1b-4a37-8f5e-2c7b41d0e9a3
FEOS_UEFI_FAT_VOLUME_ID=46f5310a
export FEOS_OVERLAY_FS_UUID FEOS_UEFI_FAT_VOLUME_ID

download_source() (
  url=$1  # 从此 URL 下载。
  file=$2 # 将资源保存到此文件中。

  local=`read_property USE_LOCAL_SOURCE`

  if [ "$local" = "true" ] && [ ! -f "$file" ] ; then
    echo "源文件 '$file' 不存在，将进行下载。"
    local=false
  fi

  if [ ! "$local" = "true" ] ; then
    echo "正在从 '$url' 下载源文件。"
    echo "正在将源文件保存到 '$file'".
    # 下载重试: 实测 GNU wget 的 --tries 对 SSL 握手失败("Unable to
    # establish SSL connection", exit 4)视为 fatal 不重试, 因此这里用
    # shell 循环兜底: 无论 wget 因何失败都重试, 偶发网络/SSL 故障不会
    # 让整个 ~1 小时构建功亏一篑。
    attempt=1
    while [ "$attempt" -le 5 ] ; do
      if wget -O "$file" -c --timeout=30 --waitretry=5 "$url" ; then
        break
      fi
      echo "下载失败(尝试 $attempt/5), 5 秒后重试: $url"
      sleep 5
      attempt=$((attempt + 1))
    done
    [ -f "$file" ] || {
      echo "错误: 从 '$url' 下载失败(已重试 5 次), 中止构建。" >&2
      exit 1
    }

    # 供应链完整性校验（强制，fail-closed）：
    # 必须在对应目录放置 '<归档文件名>.sha256'（内容形如 "<hash>  <文件名>"）。
    # 校验失败或 sidecar 缺失都会立即中止构建——不允许"跳过校验"的构建。
    # 这与 2026-11 之前的 fail-open 行为不同：论文级工程载体要求
    # "下载内容可验证" 是可度量指标，缺 sidecar 即视为供应链缺口。
    checksum_file="${file}.sha256"
    if [ -f "$checksum_file" ] ; then
      echo "正在校验 '$file' 的 SHA-256 校验和（$checksum_file）..."
      ( cd "$SOURCE_DIR" && sha256sum -c "$(basename "$checksum_file")" ) || {
        echo "错误: '$file' 校验和不匹配，可能存在篡改或下载不完整，已中止构建。" >&2
        exit 1
      }
    else
      echo "错误: 未找到 '$checksum_file'，供应链校验 sidecar 缺失。" >&2
      echo "      本仓库要求所有源归档都必须提供 sha256 sidecar（fail-closed）。" >&2
      echo "      生成方式: sha256sum <归档文件名> > '<归档文件名>.sha256'，" >&2
      echo "      然后放入 'source' 目录并提交到版本库。" >&2
      exit 1
    fi
  else
    echo "正在使用本地源文件 '$file'。"
  fi
)

extract_source() (
  file=$1
  name=$2

  # 删除之前已解压源码的文件夹。
  echo "正在移除 '$name' 工作区，这可能需要一些时间。"
  rm -rf "${WORK_DIR:?}/${name:?}"
  mkdir -p "${WORK_DIR:?}/${name:?}"

  # 将源码解压到文件夹 'work/$source'。
  # --no-same-owner: 防止归档内的 uid/gid 覆盖构建用户身份（root 解压时的标准加固）。
  tar --no-same-owner -xf "$file" -C "$WORK_DIR/$name"
)
