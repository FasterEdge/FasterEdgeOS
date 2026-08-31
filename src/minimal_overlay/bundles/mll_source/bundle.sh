#!/bin/sh

set -e

. ../../common.sh

# 准备目标工作区。
mkdir -p "$WORK_DIR/overlay/$BUNDLE_NAME"
cd $WORK_DIR/overlay/$BUNDLE_NAME

# 移除旧的源码。
rm -rf $DEST_DIR

# 创建所需的 overlay bundle 目录。
mkdir -p $DEST_DIR/usr/src
mkdir -p $DEST_DIR/etc/autorun

# 将所有源码文件复制到 '/usr/src'。
cp $MAIN_SRC_DIR/*.sh $DEST_DIR/usr/src
cp $MAIN_SRC_DIR/.config $DEST_DIR/usr/src
cp $MAIN_SRC_DIR/README $DEST_DIR/usr/src
cp $MAIN_SRC_DIR/*.txt $DEST_DIR/usr/src

# 将所有源码目录复制到 '/usr/src'。
for MINIMAL_DIR in `ls -d $MAIN_SRC_DIR/minimal*/` ; do
  cp -r $MINIMAL_DIR $DEST_DIR/usr/src
done

# 复制辅助 'autorun' 脚本。
cp $SRC_DIR/90_src.sh $DEST_DIR/etc/autorun

cd $DEST_DIR/usr/src

# 删除 '.keep' 文件，我们用它们来跟踪原本为空的文件夹。
find * -type f -name '.keep' -exec rm {} +

# 使用 '--remove-destination' 可以正确覆盖 '$OVERLAY_ROOTFS'
# 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

# 准备 'tar.xz' 源码归档 - 开始。

# 生成辅助变量。
DATE_PARSED=`LANG=en_US ; date +"%d-%b-%Y"`
ARCHIVE_PREFIX=fasteredgeos_
ARCHIVE_DIR=${ARCHIVE_PREFIX}${DATE_PARSED}
ARCHIVE_FILE=${ARCHIVE_DIR}_src.tar.xz

# 移除旧的源码归档产物。
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME/${ARCHIVE_PREFIX}*

# 将所有源码复制到新的临时目录。
cp -r $DEST_DIR/usr/src \
  $WORK_DIR/overlay/$BUNDLE_NAME/$ARCHIVE_DIR

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 生成 'tar.xz' 源码归档。
tar -cpf - $ARCHIVE_DIR | xz -9 - \
  > $WORK_DIR/overlay/$BUNDLE_NAME/$ARCHIVE_FILE

# 准备 'tar.xz' 源码归档 - 结束。

echo "Bundle '$BUNDLE_NAME' 已安装。"

cd $SRC_DIR