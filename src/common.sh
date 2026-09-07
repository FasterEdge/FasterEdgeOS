#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

SRC_DIR=$PWD
CONFIG=$SRC_DIR/.config
SOURCE_DIR=$SRC_DIR/source
WORK_DIR=$SRC_DIR/work
KERNEL_INSTALLED=$WORK_DIR/kernel/kernel_installed
GLIBC_OBJECTS=$WORK_DIR/glibc/glibc_objects
GLIBC_INSTALLED=$WORK_DIR/glibc/glibc_installed
BUSYBOX_INSTALLED=$WORK_DIR/busybox/busybox_installed
SYSROOT=$WORK_DIR/sysroot
ROOTFS=$WORK_DIR/rootfs
OVERLAY_ROOTFS=$WORK_DIR/overlay_rootfs
ISOIMAGE=$WORK_DIR/isoimage
ISOIMAGE_OVERLAY=$WORK_DIR/isoimage_overlay

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
    prop_value=`grep -i ^${prop_name}= $CONFIG | cut -f2- -d'=' | xargs`
  fi

  echo $prop_value
)

# 从主 '.config' 文件中读取常用属性。
JOB_FACTOR=`read_property JOB_FACTOR`
CFLAGS=`read_property CFLAGS`
NUM_CORES=$(grep ^processor /proc/cpuinfo | wc -l)

# 计算稍后要使用的 'make' 任务数。可用环境变量 NUM_JOBS 覆盖
# (CI/内存受限环境的稳定性: 内核编译并行任务过多可能 OOM/卡死)。
NUM_JOBS="${NUM_JOBS:-$((NUM_CORES * JOB_FACTOR))}"

download_source() (
  url=$1  # 从此 URL 下载。
  file=$2 # 将资源保存到此文件中。

  local=`read_property USE_LOCAL_SOURCE`

  if [ "$local" = "true" -a ! -f "$file" ] ; then
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

    # 供应链完整性校验（可选但强烈建议）：
    # 在 'source' 目录放置 '<归档文件名>.sha256'（内容形如 "<hash>  <文件名>"），
    # 则下载后强制校验；校验失败立即中止构建（fail-closed）。
    # 若未提供 sidecar，则打印警告并继续（fail-open，兼容旧流程）。
    checksum_file="${file}.sha256"
    if [ -f "$checksum_file" ] ; then
      echo "正在校验 '$file' 的 SHA-256 校验和（$checksum_file）..."
      ( cd "$SOURCE_DIR" && sha256sum -c "$(basename "$checksum_file")" ) || {
        echo "错误: '$file' 校验和不匹配，可能存在篡改或下载不完整，已中止构建。" >&2
        exit 1
      }
    else
      echo "警告: 未找到 '$checksum_file'，跳过校验和验证。"
      echo "      建议为固定版本源码提供 sidecar 校验和，防止供应链篡改。"
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
  rm -rf "$WORK_DIR/$name"
  mkdir -p "$WORK_DIR/$name"

  # 将源码解压到文件夹 'work/$source'。
  # --no-same-owner: 防止归档内的 uid/gid 覆盖构建用户身份（root 解压时的标准加固）。
  tar --no-same-owner -xf "$file" -C "$WORK_DIR/$name"
)
