#!/usr/bin/env bash

set -e

# 输出调试信息，查看当前环境变量
echo "==============================================="
echo "设备名称: $1"
echo "==============================================="

# 读取传入的设备名称
Dev=$1

# 定义配置文件路径
BASE_PATH=$(cd $(dirname $0) && pwd)
CONFIG_FILE="$BASE_PATH/deconfig/$Dev.config"
INI_FILE="$BASE_PATH/compilecfg/$Dev.ini"

# 检查配置文件是否存在
if [[ ! -f $CONFIG_FILE ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

if [[ ! -f $INI_FILE ]]; then
    echo "INI file not found: $INI_FILE"
    exit 1
fi

# 读取 .ini 文件中的值
read_ini_by_key() {
    local key=$1
    awk -F"=" -v key="$key" '$1 == key {print $2}' "$INI_FILE"
}

# 获取仓库 URL 和分支
REPO_URL=$(read_ini_by_key "REPO_URL")
REPO_BRANCH=$(read_ini_by_key "REPO_BRANCH")
REPO_BRANCH=${REPO_BRANCH:-main}  # 默认使用 main 分支
BUILD_DIR="$BASE_PATH/action_build"

# 输出调试信息，查看 REPO_URL 和 REPO_BRANCH
echo "仓库地址: $REPO_URL"
echo "分支名称: $REPO_BRANCH"
echo "构建目录: $BUILD_DIR"

# 清理 REPO_BRANCH，去掉注释和尾部空格
REPO_BRANCH=$(echo "$REPO_BRANCH" | sed 's/#.*//' | sed 's/[[:space:]]*$//')

# 检查分支名称是否为空或无效
if [[ -z "$REPO_BRANCH" || "$REPO_BRANCH" =~ [[:space:]] ]]; then
    echo "Invalid branch name: '$REPO_BRANCH'"
    exit 1
fi

# 输出调试信息，查看清理后的 REPO_BRANCH
echo "使用的分支名称: '$REPO_BRANCH'"

# 写入 repo_flag 文件，用于后续步骤
echo "$REPO_URL/$REPO_BRANCH" > "$BASE_PATH/repo_flag"

# 克隆仓库
echo "Cloning repository: $REPO_URL, Branch: $REPO_BRANCH"
git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR" || { echo "源码克隆失败！"; exit 1; }

# 移除国内下载源的配置
PROJECT_MIRRORS_FILE="$BUILD_DIR/scripts/projectsmirrors.json"
if [ -f "$PROJECT_MIRRORS_FILE" ]; then
    sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
fi

echo "仓库克隆完成，准备下一步..."
