#!/bin/sh
# ─────────────────────────────────────────────────────────────
# FasterEdge 开源项目
# Github: https://github.com/FasterEdge
# Gitee:  https://gitee.com/FasterEdge
# ─────────────────────────────────────────────────────────────

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME
mv `ls -d *` $BUNDLE_NAME

mkdir opt
mv graalvm opt

# 删除不必要的 Java 源码，它们只会占用宝贵空间。
rm -f opt/graalvm/src.zip

mkdir $WORK_DIR/overlay/$BUNDLE_NAME/bin
cd $WORK_DIR/overlay/$BUNDLE_NAME/bin

# 读取要额外安装的语言。
GRAALVM_LANGUAGES=`read_property GRAALVM_LANGUAGES`

LANGUAGES_LIST="$(echo $GRAALVM_LANGUAGES | tr ',' ' ')"

# 安装额外的语言
for LANGUAGE in $LANGUAGES_LIST
do
  ./../opt/$BUNDLE_NAME/bin/gu -c install org.graalvm.$LANGUAGE
done

for FILE in $(ls ../opt/$BUNDLE_NAME/bin)
do
  ln -s ../opt/$BUNDLE_NAME/bin/$FILE $FILE
done

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $WORK_DIR/overlay/$BUNDLE_NAME/* \
  $OVERLAY_ROOTFS

echo "GraalVM 已安装完成。"

cd $SRC_DIR
