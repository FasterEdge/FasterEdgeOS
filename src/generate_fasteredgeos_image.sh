#!/bin/sh

set -e

SRC_DIR=$PWD
STATUS=xxx
TEMP_DIR=xxx
FEOS_ISO=xxx

finalWords() {
cat << CEOF

  ##################################################################
  #                                                                #
  #  已生成 FasterEdgeOS 镜像 'fasteredgeos_image.tgz'。           #
  #                                                                #
  #  可以这样在 Docker 中导入 FasterEdgeOS 镜像：                  #
  #                                                                #
  #    docker import fasteredgeos_image.tgz fasteredgeos:latest    #
  #                                                                #
  #  然后可以这样在 Docker 容器中运行 FasterEdgeOS Shell：         #
  #                                                                #
  #    docker run -it fasteredgeos /bin/sh                         #
  #                                                                #
  ##################################################################

CEOF
}

cleanup() {
  chmod -R ugo+rw $TEMP_DIR
  rm -rf $TEMP_DIR
}

buildImage() {
  rm -f $SRC_DIR/fasteredgeos_image.tgz
  cd $TEMP_DIR/image_root
  tar -zcf $SRC_DIR/fasteredgeos_image.tgz *
  cd $SRC_DIR
}

prepareImage() {
  mkdir $TEMP_DIR/image_root
  cp -r $TEMP_DIR/rootfs_extracted/* $TEMP_DIR/image_root

  if [ -d $TEMP_DIR/iso_extracted/fasteredgeos/rootfs ] ; then
  # 复制 overlay 内容。
  # 使用 '--remove-destination' 确保 '$TEMP_DIR/image_root'
  # 中已有的软链接能被正确覆盖。
    cp -r --remove-destination $TEMP_DIR/iso_extracted/fasteredgeos/rootfs/* \
      $TEMP_DIR/image_root
  fi
}

extractRootfs() {
  xz -d -k $TEMP_DIR/iso_extracted/rootfs.xz
  mkdir $TEMP_DIR/rootfs_extracted
  cp $TEMP_DIR/iso_extracted/rootfs $TEMP_DIR/rootfs_extracted
  cd $TEMP_DIR/rootfs_extracted
  cpio -F rootfs -i
  rm -f rootfs
  cd $SRC_DIR
}

extractISO() {
  xorriso -osirrox on -indev $FEOS_ISO -extract / $TEMP_DIR/iso_extracted
  chmod ugo+rw $TEMP_DIR/iso_extracted
}

prepareTempDir() {
  if [ -d fasteredgeos_image ] ; then
    chmod -R ugo+rw fasteredgeos_image
    rm -rf fasteredgeos_image
  fi

  TEMP_DIR=$SRC_DIR/fasteredgeos_image
}

checkPrerequsites() {
  if [ "$1" = "" ] ; then
    if [ -f fasteredgeos.iso ] ; then
      echo "正在使用 'fasteredgeos.iso' ISO 镜像。"
      FEOS_ISO=fasteredgeos.iso
    else
      echo "ISO 镜像 'fasteredgeos.iso' 不存在，无法继续。"
      exit 1
    fi
  elif [ ! -f "$1" ] ; then
    echo "找不到 ISO 镜像 `$1`，无法继续。"
    exit 1
  else
    FEOS_ISO=$1
  fi

  STATUS=OK

  if [ "`which docker`" = "" ] ; then
    STATUS=ERROR
    echo "错误：找不到 'docker'。"
  fi

  if [ "`which xorriso`" = "" ] ; then
    STATUS=ERROR
    echo "错误：找不到 'xorriso'。"
  fi

  if [ "$STATUS" = "ERROR" ] ; then
    echo "需要先安装 'docker' 和 'xorriso'，无法继续。"
    exit 1
  fi
}

main() {
  checkPrerequsites "$@"
  prepareTempDir
  extractISO
  extractRootfs
  prepareImage
  buildImage
  cleanup
  finalWords
}

main "$@"
