#!/usr/bin/env bash

set -e

source /etc/profile
BASE_PATH=$(cd $(dirname $0) && pwd)

Dev=$1

CONFIG_FILE="$BASE_PATH/deconfig/$Dev.config"
INI_FILE="$BASE_PATH/compilecfg/$Dev.ini"

# 检查配置文件是否存在
if [[ ! -f $CONFIG_FILE ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

# 检查 INI 文件是否存在
if [[ ! -f $INI_FILE ]]; then
    echo "INI file not found: $INI_FILE"
    exit 1
fi

# 从 INI 文件中读取指定键的值
read_ini_by_key() {
    local key=$1
    awk -F"=" -v key="$key" '$1 == key {print $2}' "$INI_FILE"
}

# 获取 REPO_URL 和 REPO_BRANCH
REPO_URL=$(read_ini_by_key "REPO_URL")
REPO_BRANCH=$(read_ini_by_key "REPO_BRANCH")
REPO_BRANCH=${REPO_BRANCH:-main}  # 如果没有设置分支，默认为 main
BUILD_DIR="$BASE_PATH/action_build"

# 清理分支名称，去掉可能的注释
REPO_BRANCH=$(echo "$REPO_BRANCH" | sed 's/\s*#.*//g' | xargs)

# 输出仓库信息，帮助调试
echo "Cloning repository: $REPO_URL, Branch: $REPO_BRANCH"
echo "$REPO_URL/$REPO_BRANCH" > "$BASE_PATH/repo_flag"

# 输出实际的 git clone 命令，帮助调试
echo "git clone --depth 1 -b $REPO_BRANCH $REPO_URL $BUILD_DIR"

# 克隆指定的 Git 仓库，使用 --depth 1 来优化下载速度
git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR"

# 移除国内下载源
PROJECT_MIRRORS_FILE="$BUILD_DIR/scripts/projectsmirrors.json"

if [ -f "$PROJECT_MIRRORS_FILE" ]; then
    # 删除所有包含 .cn、腾讯、阿里云的镜像源
    sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
fi
