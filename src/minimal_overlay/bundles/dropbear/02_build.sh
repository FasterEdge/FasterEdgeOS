#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 Dropbear 源码目录（由 ls 找到），例如 'dropbear-2016.73'。
cd $(ls -d dropbear-*)

if [ -f Makefile ] ; then
  echo "正在准备 'Dropbear' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 'Dropbear' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 'Dropbear'。"
./configure \
  --prefix=/usr \
  --disable-zlib \
  --disable-loginfunc
  CFLAGS="$CFLAGS"

echo "正在编译 'Dropbear'。"
make -j $NUM_JOBS

echo "正在安装 'Dropbear'。"
make -j $NUM_JOBS install DESTDIR="$DEST_DIR"

mkdir -p $DEST_DIR/etc/dropbear

# 创建 Dropbear SSH 配置 开始

for key_type in rsa dss ecdsa; do
  echo "正在生成 '$key_type' 主机密钥。"
  $DEST_DIR/usr/bin/dropbearkey \
    -t $key_type \
    -f $DEST_DIR/etc/dropbear/dropbear_${key_type}_host_key
done

# 创建用户/组配置文件。
touch $DEST_DIR/etc/passwd
touch $DEST_DIR/etc/group

# 为 root 添加组 0。
echo "root:x:0:" \
  > $DEST_DIR/etc/group

# 添加密码为 'toor' 的 root 用户。
echo "root:AprZpdBUhZXss:0:0:Minimal Root,,,:/root:/bin/sh" \
  > $DEST_DIR/etc/passwd

# 为 root 用户创建主目录。
mkdir -p $DEST_DIR/root

# 创建 Dropbear SSH 配置 结束

echo "正在精简 'Dropbear' 的体积。"
set +e
strip -g \
  $DEST_DIR/usr/bin/* \
  $DEST_DIR/usr/sbin/*
set -e

mkdir -p $OVERLAY_ROOTFS/usr

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/etc \
  $OVERLAY_ROOTFS
cp -r --remove-destination $DEST_DIR/usr/bin \
  $OVERLAY_ROOTFS/usr
cp -r --remove-destination $DEST_DIR/usr/sbin \
  $OVERLAY_ROOTFS/usr

mkdir -p "$OVERLAY_ROOTFS/etc/autorun"
install -m 0755 "$SRC_DIR/20_dropbear.sh" "$OVERLAY_ROOTFS/etc/autorun/"

echo "bundle 'Dropbear' 已安装完成。"

cd $SRC_DIR
