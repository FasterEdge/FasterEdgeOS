# 贡献指南

欢迎为 FasterEdgeOS 提交改进建议。请在提交 Pull Request 之前务必完成以下完整测试流程，确保改动可用。

## 完整测试流程

* 使用 ``make src`` 生成干净的 FasterEdgeOS 源码树。该命令会生成包含完整源码树的压缩归档文件。
* 在空目录中复制或移动该源码归档文件，然后解压。
* 使用 ``./build_fasteredgeos.sh`` 构建 FasterEdgeOS。构建完成后，应能通过 ``./qemu-bios.sh`` 和/或 ``./qemu-uefi.sh`` 运行系统并验证你的改动。
* 使用 ``./repackage.sh`` 重新打包 FasterEdgeOS 的 ISO 镜像。打包后同样应能通过 ``./qemu-bios.sh`` 和/或 ``./qemu-uefi.sh`` 运行验证。
* 使用 ``./test_docker_image.sh`` 测试生成的 Docker 功能，应看到测试通过的提示信息。
* 使用 ``./run_docker_console.sh`` 在 Docker 中打开 shell 控制台，应能在该控制台中调用 FasterEdgeOS 的所有二进制程序与脚本。

## 提交规范

* 本项目优先使用中文编写提交信息、文档与注释。
* 提交信息应简洁明确，说明本次改动的目的与内容。
* 涉及行为变更或新增功能时，请在 Pull Request 描述中说明改动的测试方式与结果。

感谢你的贡献！