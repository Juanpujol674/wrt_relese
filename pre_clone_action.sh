#!/bin/bash
# pre_clone_action.sh 修改后内容

DEVICE_NAME=$1
BUILD_DIR=${2:-"action_build"}  # 接收第二个参数作为构建目录

INI_FILE="./compilecfg/${DEVICE_NAME}.ini"
REPO_URL=$(awk -F"=" '/REPO_URL/ {print $2}' "$INI_FILE" | tr -d '[:space:]')
REPO_BRANCH=$(awk -F"=" '/REPO_BRANCH/ {print $2}' "$INI_FILE" | tr -d '[:space:]')

echo "▼▼▼▼▼ 克隆参数验证 ▼▼▼▼▼"
echo "设备名称: $DEVICE_NAME"
echo "仓库地址: $REPO_URL"
echo "分支名称: $REPO_BRANCH"
echo "构建目录: $BUILD_DIR"

# 清理旧目录
rm -rf "$BUILD_DIR"

# 执行克隆（关键修正点）
git clone "$REPO_URL" -b "$REPO_BRANCH" "$BUILD_DIR" || {
    echo "::error::源码克隆失败！"
    exit 1
}

# 标记仓库状态
touch "$BUILD_DIR/repo_flag"
