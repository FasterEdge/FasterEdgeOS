# 这是一个非常简单的 Makefile，封装了 'FasterEdgeOS' 的构建流程。
# 输入以下命令可获取更多信息：
#
# make help

.DEFAULT_GOAL := help

all: clean
	@{ \
		echo "正在启动主构建脚本。" ; \
		/usr/bin/time -f "\n  消耗时间：%E" ./build_fasteredgeos.sh 2>&1 | tee fasteredgeos.log ; \
		echo "" ; \
	}

clean:
	@{ \
		echo "正在移除生成的 work 产物。" ; \
		rm -rf work ; \
		echo "正在移除生成的构建产物。" ; \
		rm -f fasteredgeos.iso ; \
		rm -f fasteredgeos_image.tgz ; \
		USE_PREDEFINED_KERNEL_CONFIG=`grep -i ^USE_PREDEFINED_KERNEL_CONFIG= .config | cut -f2- -d'=' | xargs` ; \
		if [ ! "$$USE_PREDEFINED_KERNEL_CONFIG" = "true" ] ; then \
			echo "正在移除预定义的 Linux 内核配置文件。" ; \
			rm -rf minimal_overlay/kernel.config ; \
		else \
			echo "保留本地 Linux 内核配置文件。" ; \
		fi ; \
		USE_PREDEFINED_BUSYBOX_CONFIG=`grep -i ^USE_PREDEFINED_BUSYBOX_CONFIG= .config | cut -f2- -d'=' | xargs` ; \
		if [ ! "$$USE_PREDEFINED_BUSYBOX_CONFIG" = "true" ] ; then \
			echo "正在移除预定义的 Busybox 配置文件。" ; \
			rm -rf minimal_overlay/busybox.config ; \
		else \
			echo "保留本地 Busybox 配置文件。" ; \
		fi ; \
		echo "正在移除源码级 overlay 软件。" ; \
		mv -f minimal_overlay/rootfs/README /tmp/fasteredgeos_overlay_readme ; \
		cd minimal_overlay/rootfs ; \
		rm -rf * ; \
		cd ../.. ; \
		mv -f /tmp/fasteredgeos_overlay_readme minimal_overlay/rootfs/README ; \
		echo "正在移除构建日志文件。" ; \
		rm -f fasteredgeos.log ; \
		USE_LOCAL_SOURCE=`grep -i ^USE_LOCAL_SOURCE= .config | cut -f2- -d'=' | xargs` ; \
		if [ ! "$$USE_LOCAL_SOURCE" = "true" ] ; then \
			echo "正在移除本地源码文件。" ; \
			rm -rf source ; \
		else \
			echo "保留本地源码。" ; \
		fi ; \
	}

qemu-bios:
	@{ \
		if [ ! -f ./fasteredgeos.iso ] ; then \
			echo "" ; \
			echo "  错误：未找到 ISO 镜像 'fasteredgeos.iso'。" ; \
			echo "" ; \
			exit 1 ; \
		fi ; \
		echo "正在以 BIOS 模式启动 QEMU。" ; \
		./qemu-bios.sh ; \
	}

qemu-uefi:
	@{ \
		if [ ! -f ./fasteredgeos.iso ] ; then \
			echo "" ; \
			echo "  错误：未找到 ISO 镜像 'fasteredgeos.iso'。" ; \
			echo "" ; \
			exit 1 ; \
		fi ; \
		echo "正在以 UEFI 模式启动 QEMU。" ; \
		./qemu-uefi.sh ; \
	}

src:
	@{ \
		echo "正在生成源码归档。" ; \
		rm -f fasteredgeos_*_src.tar.xz ; \
		cd minimal_overlay ; \
		./overlay_build.sh mll_source 1>/dev/null ; \
		cd .. ; \
		cp work/overlay/mll_source/*.tar.xz . ; \
		echo "源码归档为 '`ls fasteredgeos_*_src.tar.xz`'。" ; \
	}

release: src
	@{ \
		echo "正在移除旧的构建产物。" ; \
		rm -rf /tmp/fasteredgeos_release ; \
		mkdir -p /tmp/fasteredgeos_release ; \
		echo "正在准备 FasterEdgeOS 源码树。" ; \
		cp fasteredgeos_*_src.tar.xz /tmp/fasteredgeos_release ; \
		cd /tmp/fasteredgeos_release ; \
		tar -xf fasteredgeos_*_src.tar.xz ; \
		cd /tmp/fasteredgeos_release/fasteredgeos_*/ ; \
		echo "正在启动主构建脚本。" ; \
		/usr/bin/time -f "\n  消耗时间：%E" ./build_fasteredgeos.sh 2>&1 | tee fasteredgeos.log ; \
		echo "" ; \
		echo "  请检查目录 '/tmp/fasteredgeos_release'。" ; \
		echo "" ; \
	}

release2:
	@{ \
		echo "正在移除旧的构建产物。" ; \
		rm -rf /tmp/fasteredgeos_release2 ; \
		mkdir -p /tmp/fasteredgeos_release2 ; \
		cd /tmp/fasteredgeos_release2 ; \
		echo "正在克隆项目仓库。" ; \
		git clone https://github.com/FasterEdge/FasterEdgeOS.git ; \
		cd FasterEdgeOS/src ; \
		echo "准备生成 release。" ; \
		make release ; \
	}

test:
	@{ \
		echo "" ; \
		echo "  此目标保留用于本地测试。" ; \
		echo "" ; \
	}

help:
	@{ \
		echo "" ; \
		echo "  make all       - 清理工作区并生成 'fasteredgeos.iso'。" ; \
		echo "" ; \
		echo "  make clean     - 移除所有生成的文件。" ; \
		echo "" ; \
		echo "  make help      - 默认目标，显示帮助信息。" ; \
		echo "" ; \
		echo "  make release   - 在 '/tmp/fasteredgeos_release' 生成干净的源码树并构建 FasterEdgeOS。" ; \
		echo "" ; \
		echo "  make release2  - 克隆项目仓库并从中执行 'make release'。" ; \
		echo "" ; \
		echo "  make src       - 生成 'tar.xz' 源码归档。" ; \
		echo "" ; \
		echo "  make qemu-bios - 以传统 BIOS 兼容模式在 QEMU 中运行 FasterEdgeOS。" ; \
		echo "" ; \
		echo "  make qemu-uefi - 以 UEFI 兼容模式在 QEMU 中运行 FasterEdgeOS。" ; \
		echo "" ; \
	}
