#!/bin/sh

# 本脚本由 GitHub 工作流调用。

set -e

sudo apt-get -qq -y install wget make gawk gcc bc xz-utils bison flex xorriso libelf-dev libssl-dev

cd ../src
./build_fasteredgeos.sh

set +e
