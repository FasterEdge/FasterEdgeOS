#!/bin/sh

set -e

. ../../common.sh

echo "正在移除旧的 'Apache Felix' 构建产物，这可能需要一些时间。"
rm -rf "${DEST_DIR:?}"
mkdir -p $DEST_DIR/opt/felix
mkdir -p $DEST_DIR/bin
mkdir -p $DEST_DIR/etc/autorun

cd $WORK_DIR/overlay/felix
set -- felix-*
if [ "$#" -ne 1 ] || [ ! -d "$1" ] ; then
  echo "目录缺失: felix-*，无法继续。"
  exit 1
fi
cd "$1"

cat << CEOF > bin/felix-start.sh
#!/bin/sh

cd /opt/felix
java -jar bin/felix.jar

CEOF

chmod +rx bin/felix-start.sh

cp -r * $DEST_DIR/opt/felix
cp $SRC_DIR/90_felix.sh $DEST_DIR/etc/autorun

cd $DEST_DIR

ln -s ../opt/felix/bin/felix-start.sh bin/felix-start

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

echo "bundle 'Apache Felix' 已安装完成。"

cd $SRC_DIR

