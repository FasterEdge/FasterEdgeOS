#!/bin/sh

set -e

# 加载公共属性与函数。
. ./common.sh

echo "*** 生成系统镜像开始 ***"

# 清理旧的构建产物。
rm -f $SRC_DIR/fasteredgeos_image.tgz
rm -rf $WORK_DIR/fasteredgeos_image
mkdir -p $WORK_DIR/fasteredgeos_image

if [ -d $ROOTFS ] ; then
  # 复制 rootfs。
  cp -r $ROOTFS/* \
    $WORK_DIR/fasteredgeos_image
else
  echo "rootfs 不存在，无法继续。"
  exit 1
fi

if [ -d $OVERLAY_ROOTFS ] && \
   [ ! "`ls -A $OVERLAY_ROOTFS`" = "" ] ; then

  echo "正在把 overlay 软件合并进系统镜像。"

  # 复制 overlay 内容。
  # 使用 '--remove-destination' 确保 $WORK_DIR/fasteredgeos_image
  # 中已有的软链接能被正确覆盖。
  cp -r --remove-destination $OVERLAY_ROOTFS/* \
    $WORK_DIR/fasteredgeos_image
  cp -r --remove-destination $SRC_DIR/minimal_overlay/rootfs/* \
    $WORK_DIR/fasteredgeos_image
else
  echo "系统镜像将不包含 overlay 软件。"
fi

cd $WORK_DIR/fasteredgeos_image

# 生成系统镜像文件（普通 'tgz' 压缩包）。
tar -zcf $SRC_DIR/fasteredgeos_image.tgz *

cat << CEOF

  ##################################################################
  #                                                                #
  #  已生成 FasterEdgeOS 系统镜像 'fasteredgeos_image.tgz'。       #
  #                                                                #
  #  可用 Docker 导入该镜像：                                      #
  #                                                                #
  #    docker import fasteredgeos_image.tgz fasteredgeos:latest    #
  #                                                                #
  #  然后这样进入 FasterEdgeOS Shell：                             #
  #                                                                #
  #    docker run -it fasteredgeos /bin/sh                         #
  #                                                                #
  ##################################################################

CEOF

echo "*** 生成系统镜像结束 ***"