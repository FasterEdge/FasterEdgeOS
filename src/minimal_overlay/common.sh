#!/bin/sh

set -e

# 所有软件包共用的代码。应包含在每个软件包的
# 每个 *.sh 文件的顶部。

export SRC_DIR=`realpath --no-symlinks $PWD`
export MAIN_SRC_DIR=`realpath --no-symlinks $SRC_DIR/../../../`
export WORK_DIR=$MAIN_SRC_DIR/work
export SOURCE_DIR=$MAIN_SRC_DIR/source
export OVERLAY_WORK_DIR=$WORK_DIR/overlay
export OVERLAY_SOURCE_DIR=$SOURCE_DIR/overlay
export OVERLAY_ROOTFS=$WORK_DIR/overlay_rootfs
export BUNDLE_NAME=`basename $SRC_DIR`
export DEST_DIR=$WORK_DIR/overlay/$BUNDLE_NAME/${BUNDLE_NAME}_installed
export CONFIG=$MAIN_SRC_DIR/.config
export SYSROOT=$WORK_DIR/sysroot

# 该函数从主 '.config' 文件中读取属性。
# 如果当前目录中存在本地 '.config' 文件，
# 且该属性也出现在本地 '.config' 文件中，
# 则属性值会被本地文件中找到的值覆盖。
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
    prop_value="`grep -i ^${prop_name}= $CONFIG | cut -f2- -d'=' | xargs`"

    if [ -f $SRC_DIR/.config ] ; then
      # 在本地 '.config' 文件中搜索。
      prop_value_local="`grep -i ^${prop_name}= $SRC_DIR/.config | cut -f2- -d'=' | xargs`"

      if [ ! "$prop_value_local" = "" ] ; then
        # 用本地值覆盖原始值。
        prop_value="$prop_value_local"
      fi
    fi
  fi

  echo "$prop_value"
)

# 读取常用的配置属性。
export JOB_FACTOR="`read_property JOB_FACTOR`"
export CFLAGS="`read_property CFLAGS`"
export NUM_CORES="$(grep ^processor /proc/cpuinfo | wc -l)"

# 计算 make "jobs" 的数量。可用环境变量 NUM_JOBS 覆盖
# (CI/内存受限环境的稳定性: 并行任务过多可能 OOM/卡死)。
export NUM_JOBS="${NUM_JOBS:-$((NUM_CORES * JOB_FACTOR))}"

# 理想情况下，我们会在此处导出带 -j 等参数的 MAKE，让程序只需运行 $(MAKE) 而无需操心需要传递的额外标志
# export MAKE="${MAKE-make} -j $NUM_JOBS"

download_source() (
  url=$1  # 从此 URL 下载。
  file=$2 # 将资源保存到此文件中。

  local=`read_property USE_LOCAL_SOURCE`

  if [ "$local" = "true" -a ! -f "$file"  ] ; then
    echo "源文件 '$file' 不存在，将进行下载。"
    local=false
  fi

  if [ ! "$local" = "true" ] ; then
    echo "正在从 '$url' 下载 overlay 源文件。"
    echo "正在将 overlay 源文件保存到 '$file'".
    # 下载重试: 实测 GNU wget 的 --tries 对 SSL 握手失败("Unable to
    # establish SSL connection", exit 4)视为 fatal 不重试, 因此这里用
    # shell 循环兜底: 无论 wget 因何失败都重试, 偶发网络/SSL 故障不会
    # 让整个 ~1 小时构建功亏一篑。与主链 src/common.sh 的 download_source
    # 保持同一加固(重试 + sidecar 校验), 覆盖 adopt_openjdk/coreutils 等
    # bundle 级源码下载(此前仅主链 01/03/06 有此防护)。
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
    # 在 'source/overlay' 目录放置 '<归档文件名>.sha256'（内容形如 "<hash>  <文件名>"），
    # 则下载后强制校验；校验失败立即中止构建（fail-closed）。
    # 若未提供 sidecar，则打印警告并继续（fail-open，兼容旧流程）。
    checksum_file="${file}.sha256"
    if [ -f "$checksum_file" ] ; then
      echo "正在校验 '$file' 的 SHA-256 校验和（$checksum_file）..."
      ( cd "$OVERLAY_SOURCE_DIR" && sha256sum -c "$(basename "$checksum_file")" ) || {
        echo "错误: '$file' 校验和不匹配，可能存在篡改或下载不完整，已中止构建。" >&2
        exit 1
      }
    else
      echo "警告: 未找到 '$checksum_file'，跳过校验和验证。"
      echo "      建议为固定版本源码提供 sidecar 校验和，防止供应链篡改。"
    fi
  else
    echo "正在使用本地 overlay 源文件 '$file'。"
  fi
)

extract_source() (
  file=$1
  name=$2

  # 删除之前已解压源码的文件夹。
  echo "正在移除 '$name' 的 overlay 工作区，这可能需要一些时间。"
  rm -rf "${OVERLAY_WORK_DIR:?}/${name:?}"
  mkdir -p $OVERLAY_WORK_DIR/$name

  # 将源码解压到文件夹 'work/overlay/$source'。
  # --no-same-owner: 防止归档内的 uid/gid 覆盖构建用户身份（root 解压时的标准加固，
  # 与主链 src/common.sh 的 extract_source 一致）。
  tar --no-same-owner -xvf $file -C $OVERLAY_WORK_DIR/$name
)

make_target() (
  make -j $NUM_JOBS "$@"
)

make_clean() (
  target=$1

  if [ "$target" = "" ] ; then
    target=clean
  fi

  if [ -f Makefile ] ; then
    echo "正在准备 '$BUNDLE_NAME' 工作区，这可能需要一些时间。"
    make_target $target
  else
    echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
  fi
)

reduce_size() (
  while [ ! "$1" = "" ] ; do
    if [ -d $1 ] ; then
      for file in $1/* ; do
        reduce_size $file
      done
    elif [ -f $1 ] ; then
      set +e
      strip -g $1 2>/dev/null
      set -e
    fi

    shift
  done
)

install_to_overlay() (
  # 使用 '--remove-destination'，$OVERLAY_ROOTFS 中所有可能已存在的
  # 软链接都会被正确覆盖。

  if [ "$#" = "2" ] ; then
    cp -r --remove-destination \
      $DEST_DIR/$1 \
      $OVERLAY_ROOTFS/$2
  elif [ "$#" = "1" ] ; then
    cp -r --remove-destination \
      $DEST_DIR/$1 \
      $OVERLAY_ROOTFS
  elif [ "$#" = "0" ] ; then
    cp -r --remove-destination \
      $DEST_DIR/* \
      $OVERLAY_ROOTFS
  fi
)
