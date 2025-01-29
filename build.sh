#!/usr/bin/env bash

set -e

source /etc/profile
BASE_PATH=$(cd $(dirname $0) && pwd)

Dev=$1
Build_Mod=$2

CONFIG_FILE="$BASE_PATH/deconfig/$Dev.config"
INI_FILE="$BASE_PATH/compilecfg/$Dev.ini"

if [[ ! -f $CONFIG_FILE ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

if [[ ! -f $INI_FILE ]]; then
    echo "INI file not found: $INI_FILE"
    exit 1
fi

read_ini_by_key() {
    local key=$1
    awk -F"=" -v key="$key" '$1 == key {print $2}' "$INI_FILE"
}

# 获取仓库 URL 和分支名，并清除可能的注释
REPO_URL=$(read_ini_by_key "REPO_URL")
REPO_BRANCH=$(read_ini_by_key "REPO_BRANCH" | awk '{print $1}')  # 去掉注释部分
REPO_BRANCH=${REPO_BRANCH:-main}
BUILD_DIR=$(read_ini_by_key "BUILD_DIR")
COMMIT_HASH=$(read_ini_by_key "COMMIT_HASH")
COMMIT_HASH=${COMMIT_HASH:-none}

# 如果存在 action_build 目录，更新构建目录
if [[ -d $BASE_PATH/action_build ]]; then
    BUILD_DIR="action_build"
fi

# 拉取并重置远程分支
echo "Fetching repository from $REPO_URL, branch $REPO_BRANCH"
cd "$BASE_PATH/$BUILD_DIR"
git fetch origin

# 输出当前分支调试信息
echo "Current branch before reset: $(git branch --show-current)"

# 切换到指定分支并重置
git checkout "$REPO_BRANCH" || git checkout -b "$REPO_BRANCH" origin/"$REPO_BRANCH"
git reset --hard origin/"$REPO_BRANCH"

# 如果你使用了 commit hash 来回滚到指定提交，执行以下命令
if [[ "$COMMIT_HASH" != "none" ]]; then
    git reset --hard "$COMMIT_HASH"
fi

# 更新仓库
$BASE_PATH/update.sh "$REPO_URL" "$REPO_BRANCH" "$BASE_PATH/$BUILD_DIR" "$COMMIT_HASH"

# 拷贝配置文件
\cp -f "$CONFIG_FILE" "$BASE_PATH/$BUILD_DIR/.config"

# 进入构建目录并进行 defconfig 配置
cd "$BASE_PATH/$BUILD_DIR"
make defconfig

# 如果是调试模式，则退出
if [[ $Build_Mod == "debug" ]]; then
    exit 0
fi

# 清理目标目录中的固件文件
TARGET_DIR="$BASE_PATH/$BUILD_DIR/bin/targets"
if [[ -d $TARGET_DIR ]]; then
    find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec rm -f {} +
fi

# 下载和编译固件
make download -j$(($(nproc) * 2))
make -j$(($(nproc) + 1)) || make -j1 V=s

# 拷贝生成的固件文件
FIRMWARE_DIR="$BASE_PATH/firmware"
\rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"
find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec cp -f {} "$FIRMWARE_DIR/" \;
\rm -f "$BASE_PATH/firmware/Packages.manifest" 2>/dev/null

# 清理构建目录
if [[ -d $BASE_PATH/action_build ]]; then
    make clean
fi
