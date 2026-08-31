#!/bin/sh

# 有任何错误则立即退出 shell 进程
set -e

# 导入公共变量和函数
. ../../common.sh


# 按约定，overlay bundle 有一个 "source" 文件夹，源码会下载到这里。
# 如果源码来自网络，这样即使构建过程被中断，下载也可以继续。
# 在我们的简单用例中，我们直接复制文件 "hello.c"，以此来模拟
# （大概）它已经被下载。
#
# 主要的 overlay 源码文件夹是 "minimal/src/source/overlay"，本 bundle
# 的源码产物将是 "minimal/src/source/overlay/hello.c"。
cp $SRC_DIR/hello.c \
  $OVERLAY_SOURCE_DIR

# 下一步是准备上一步下载的源码。通常这意味着解压。按约定，每个 overlay
# bundle 都有自己的根文件夹，所有构建工作都在其中完成。在我们的简单
# 用例中，我们通过把源码从 source 文件夹复制到 bundle 主文件夹来
# 进行"解压"。
#
# 主要的 overlay 文件夹是 "minimal/src/work/overlay"，本 bundle 的 overlay
# 文件夹将是 "minimal/src/work/overlay/mll_hello"。
mkdir $OVERLAY_WORK_DIR/$BUNDLE_NAME
cp $OVERLAY_SOURCE_DIR/hello.c \
  $OVERLAY_WORK_DIR/$BUNDLE_NAME

# 每个 overlay bundle 还有一个特殊目录，所有构建产物都按最终 OS 的文件
# 目录结构放在其中。这个文件夹是
# "minimal/src/work/overlay/mll_hello/mll_hello_installed"。

# 首先创建 "destination"（目标）文件夹。
mkdir $DEST_DIR

# 我们希望 "hello" 可执行文件位于 "/bin" 文件夹，因此在 "$DEST_DIR" 中
# 创建子文件夹 "bin"。
mkdir $DEST_DIR/bin

# 我们希望 "autorun" 脚本文件 "90_hello.sh" 位于 "/etc/autorun"，
# 因此在 "$DEST_DIR" 中创建相应的文件夹。
mkdir -p $DEST_DIR/etc/autorun

# 现在把 "autorun" 脚本文件 "90_hello.sh" 复制到 "$DEST_DIR/etc/autorun"
# 并确保该脚本可执行。
cp $SRC_DIR/90_hello.sh $DEST_DIR/etc/autorun
chmod +x $DEST_DIR/etc/autorun/90_hello.sh

# 现在编译 "$OVERLAY_WORK_DIR/$BUNDLE_NAME/hello.c"，并把可执行文件
# "hello" 放到 "$DEST_DIR/bin" 中。
gcc -o $DEST_DIR/bin/hello $OVERLAY_WORK_DIR/$BUNDLE_NAME/hello.c

# 可选：我们可以缩减生成的 overlay bundle 产物的体积。
# 我们使用特殊函数 "reduce_size"，并把生成的产物所在文件或文件夹
# 作为参数传入。
reduce_size $DEST_DIR/bin/hello

# 无论你对 bundle 做了什么，无论你如何编译和/或准备它们，
# 最终所有 bundle 产物都必须存在于 "$OVERLAY_ROOTFS" 文件夹中。
# 这个特殊文件夹代表最终目录结构，所有 overlay bundle 都把它们的
# 最终产物放在这里。在我们的简单用例中，我们已经在 "$DEST_DIR" 中
# 准备好了相应的目录结构，因此只需把它复制到 "$OVERLAY_ROOTFS"。
#
# overlay 根文件系统文件夹是 "minimal/src/work/overlay_rootfs"。

# 我们使用特殊函数 "install_to_overlay"，它有三种工作模式：
#
# 模式 1 - 把 "$DEST_DIR" 中的全部内容安装到 "OVERLAY_ROOTFS"：
#
#  install_to_overlay （不提供参数）
#
# 模式 2 - 把 "$DEST_DIR" 中的特定文件/文件夹（例如 "$DEST_DIR/bin"）
# 直接安装到 "$OVERLAY_ROOTFS"：
#
#  install_to_overlay bin
#
# 模式 3 - 把 "$DEST_DIR" 中的特定文件/文件夹（例如 "$DEST_DIR/bin"）
# 作为 "$OVERLAY_ROOTFS" 中的特定文件/文件夹（例如 "$OVERLAY_ROOTFS/bin"）
# 安装：
#
#  install_to_overlay bin bin
#
# 以上所有示例的最终效果相同。在我们的简单用例中我们使用第一种模式
# （即不提供参数）。
install_to_overlay

# 最后我们打印 bundle 已安装的消息，并返回 overlay 源码文件夹。
echo "Bundle '$BUNDLE_NAME' 已安装。"

cd $SRC_DIR

# 就这样。把 overlay bundle 加入主 ".config" 文件中，重新构建
# FasterEdgeOS（即运行 "repackage.sh"），OS 启动后输入 "hello"。