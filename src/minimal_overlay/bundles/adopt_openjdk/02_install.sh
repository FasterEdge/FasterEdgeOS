#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

. ../../common.sh

cd $OVERLAY_WORK_DIR/$BUNDLE_NAME
mv * adoptopenjdk

rm -rf "${DEST_DIR:?}"
mkdir -p $DEST_DIR/bin
mkdir -p $DEST_DIR/opt

mv adoptopenjdk $DEST_DIR/opt

cd $DEST_DIR/bin

for FILE in ../opt/adoptopenjdk/bin/*
do
  [ -e "$FILE" ] || continue
  ln -s "$FILE" "$(basename "$FILE")"
done

install_to_overlay

echo "$BUNDLE_NAME 已安装完成。"

cd $SRC_DIR
