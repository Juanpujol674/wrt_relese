#!/usr/bin/env bash

set -e

source /etc/profile
BASE_PATH=$(cd $(dirname $0) && pwd)

Dev=$1

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

REPO_URL=$(read_ini_by_key "REPO_URL")
REPO_BRANCH=$(read_ini_by_key "REPO_BRANCH")
REPO_BRANCH=${REPO_BRANCH:-main}
BUILD_DIR="$BASE_PATH/action_build"

echo "Cloning repository: $REPO_URL, Branch: $REPO_BRANCH"  # 打印出调试信息

# 清理 REPO_BRANCH，去掉注释部分
REPO_BRANCH=$(echo "$REPO_BRANCH" | sed 's/#.*//')

# 检查 REPO_BRANCH 是否为空或包含空格
echo "Using REPO_BRANCH: '$REPO_BRANCH'"  # 调试信息，检查分支名称
if [[ -z "$REPO_BRANCH" || "$REPO_BRANCH" =~ [[:space:]] ]]; then
    echo "Invalid branch name: $REPO_BRANCH"
    exit 1
fi

echo "$REPO_URL $REPO_BRANCH"
echo "$REPO_URL/$REPO_BRANCH" >"$BASE_PATH/repo_flag"

# 克隆 Git 仓库
git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR"

# GitHub Action 移除国内下载源
PROJECT_MIRRORS_FILE="$BUILD_DIR/scripts/projectsmirrors.json"

if [ -f "$PROJECT_MIRRORS_FILE" ]; then
    sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
fi

# 执行 git reset 时，确保 REPO_BRANCH 是合法的
echo "Resetting repository to branch: $REPO_BRANCH"
git fetch origin "$REPO_BRANCH"
git reset --hard "origin/$REPO_BRANCH"
