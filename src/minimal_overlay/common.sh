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

# 计算 make "jobs" 的数量
export NUM_JOBS="$((NUM_CORES * JOB_FACTOR))"

# 理想情况下，我们会在此处导出带 -j 等参数的 MAKE，让程序只需运行 $(MAKE) 而无需操心需要传递的额外标志
# export MAKE="${MAKE-make} -j $NUM_JOBS"

download_source() (
  url=$1  # 从此 URL 下载。
  file=$2 # 将资源保存到此文件中。

  local=`read_property USE_LOCAL_SOURCE`

  if [ "$local" = "true" -a ! -f $file  ] ; then
    echo "源文件 '$file' 不存在，将进行下载。"
    local=false
  fi

  if [ ! "$local" = "true" ] ; then
    echo "正在从 '$url' 下载 overlay 源文件。"
    echo "正在将 overlay 源文件保存到 '$file'".
    wget -O $file -c $url
  else
    echo "正在使用本地 overlay 源文件 '$file'。"
  fi
)

extract_source() (
  file=$1
  name=$2

  # 删除之前已解压源码的文件夹。
  echo "正在移除 '$name' 的 overlay 工作区，这可能需要一些时间。"
  rm -rf $OVERLAY_WORK_DIR/$name
  mkdir -p $OVERLAY_WORK_DIR/$name

  # 将源码解压到文件夹 'work/overlay/$source'。
  tar -xvf $file -C $OVERLAY_WORK_DIR/$name
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
