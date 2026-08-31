#!/bin/sh

set -e

SRC_DIR=$(pwd)

# 找到主源码目录
cd ..
MAIN_SRC_DIR=$(pwd)
cd $SRC_DIR

if [ "$1" = "--skip-clean" ] ; then
  SKIP_CLEAN=true
  shift
fi

if [ "$1" = "" ] ; then
  # 从 '.config' 读取 'OVERLAY_BUNDLES' 属性
  OVERLAY_BUNDLES="$(grep -i ^OVERLAY_BUNDLES $MAIN_SRC_DIR/.config | cut -f2 -d'=')"
else
  OVERLAY_BUNDLES=$1
fi

if [ "$OVERLAY_BUNDLES" = "" ] ; then
  echo "没有需要构建的 overlay 软件包。"
  exit 1
fi

if [ ! "$SKIP_CLEAN" = "true" ] ; then
  ./overlay_clean.sh
fi

if [ "$OVERLAY_BUNDLES" = "all" ] ; then
  BUNDLES_LIST=`ls $SRC_DIR/bundles`
else
  BUNDLES_LIST="$(echo $OVERLAY_BUNDLES | tr ',' ' ')"
fi

for BUNDLE in $BUNDLES_LIST
do
  BUNDLE_DIR=$SRC_DIR/bundles/$BUNDLE

  if [ ! -d $BUNDLE_DIR ] ; then
      echo "错误 - 找不到 overlay 软件包目录 '$BUNDLE_DIR'。"
      exit 1
  fi

  # 处理依赖关系 开始
  if [ -f $BUNDLE_DIR/bundle_deps ] ; then
    echo "overlay 软件包 '$BUNDLE' 依赖以下 overlay 软件包："
    cat $BUNDLE_DIR/bundle_deps

    while read line; do
      # 去除软件包名称中的所有空白字符
      BUNDLE_DEP=`echo $line | awk '{print $1}'`

      case "$BUNDLE_DEP" in
      \#*)
        # 这是注释行。
        continue
        ;;
      esac

      if [ "$BUNDLE_DEP" = "" ] ; then
        continue
      elif [ -d $MAIN_SRC_DIR/work/overlay/$BUNDLE_DEP ] ; then
        echo "overlay 软件包 '$BUNDLE_DEP' 已经准备就绪。"
      else
        echo "正在准备 overlay 软件包 '$BUNDLE_DEP'。"
        cd $SRC_DIR
        ./overlay_build.sh --skip-clean $BUNDLE_DEP
        echo "overlay 软件包 '$BUNDLE_DEP' 已准备就绪。"
      fi
    done < $BUNDLE_DIR/bundle_deps
  fi
  # 处理依赖关系 结束

  BUNDLE_SCRIPT=$BUNDLE_DIR/bundle.sh

  if [ ! -f $BUNDLE_SCRIPT ] ; then
    echo "错误 - 找不到 overlay 软件包脚本文件 '$BUNDLE_SCRIPT'。"
    exit 1
  fi

  cd $BUNDLE_DIR

  echo "正在构建 overlay 软件包 '$BUNDLE'。"
  $BUNDLE_SCRIPT

  cd $SRC_DIR
done

cd $SRC_DIR
