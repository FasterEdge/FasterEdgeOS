#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 加载公共属性与函数。
. ./common.sh

echo "*** 生成系统镜像开始 ***"

# 清理旧的构建产物。
rm -f "$SRC_DIR/fasteredgeos_image.tgz"
rm -rf "${WORK_DIR:?}"/fasteredgeos_image
mkdir -p "$WORK_DIR/fasteredgeos_image"

if [ -d "$ROOTFS" ] ; then
  # 复制 rootfs。
  cp -r "$ROOTFS"/* \
    "$WORK_DIR/fasteredgeos_image"
else
  echo "rootfs 不存在，无法继续。"
  exit 1
fi

if [ -d "$OVERLAY_ROOTFS" ] && \
   [ -n "$(ls -A "$OVERLAY_ROOTFS")" ] ; then

  echo "正在把 overlay 软件合并进系统镜像。"

  # 复制 overlay 内容。
  # 使用 '--remove-destination' 确保 $WORK_DIR/fasteredgeos_image
  # 中已有的软链接能被正确覆盖。
  cp -r --remove-destination "$OVERLAY_ROOTFS"/* \
    "$WORK_DIR/fasteredgeos_image"
  cp -r --remove-destination "$SRC_DIR"/minimal_overlay/rootfs/* \
    "$WORK_DIR/fasteredgeos_image"
else
  echo "系统镜像将不包含 overlay 软件。"
fi

cd "$WORK_DIR/fasteredgeos_image"

# 可复现打包(与 10_pack_rootfs.sh 同一套约束):
#   --sort=name            成员顺序固定, 不依赖目录遍历顺序
#   --mtime=@SOURCE_DATE_EPOCH / --owner=0 --group=0 --numeric-owner
#                          元数据固定, 不依赖构建主机时间与用户身份
#   gzip -n                不在 gzip 头部写入文件名与时间戳
# 变量 $TAR_REPRODUCIBLE 由 common.sh 统一导出, 避免多处重复定义漂移。
tar $TAR_REPRODUCIBLE -cf - * | gzip -n -9 > $SRC_DIR/fasteredgeos_image.tgz

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
