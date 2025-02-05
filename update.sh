#!/usr/bin/env bash

set -e
set -o errexit
set -o errtrace

# 定义错误处理函数
error_handler() {
    echo "Error occurred in script at line: ${BASH_LINENO[0]}, command: '${BASH_COMMAND}'"
    exit 1
}

# 设置 trap 捕获 ERR 信号
trap 'error_handler' ERR

# 加载环境变量
source /etc/profile

# 定义全局变量
BASE_PATH=$(cd "$(dirname "$0")" && pwd)
REPO_URL=$1
REPO_BRANCH=$2
BUILD_DIR=$3
COMMIT_HASH=$4
FEEDS_CONF="feeds.conf.default"
GOLANG_REPO="https://github.com/sbwml/packages_lang_golang"
GOLANG_BRANCH="23.x"
THEME_SET="argon"
LAN_ADDR="192.168.1.1"

# 克隆仓库
clone_repo() {
    if [[ ! -d $BUILD_DIR ]]; then
        echo "Cloning repository from $REPO_URL, branch $REPO_BRANCH..."
        git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR"
    fi
}

# 清理构建目录
clean_up() {
    cd "$BUILD_DIR"
    echo "Cleaning up build directory..."
    [[ -f .config ]] && rm -f .config
    [[ -d tmp ]] && rm -rf tmp
    [[ -d logs ]] && rm -rf logs/*
    mkdir -p tmp
    echo "1" > tmp/.build
}

# 重置 feeds 配置
reset_feeds_conf() {
    cd "$BUILD_DIR"
    echo "Resetting feeds configuration..."
    git reset --hard "origin/$REPO_BRANCH"
    git clean -f -d
    git pull
    if [[ $COMMIT_HASH != "none" ]]; then
        git checkout "$COMMIT_HASH"
    fi
}

# install_feeds
install_feeds() {
    cd "$BUILD_DIR"
    echo "Installing feeds..."
    ./scripts/feeds update -i
    for dir in feeds/*; do
        if [[ -d "$dir" && ! "$dir" == *.tmp && ! -L "$dir" ]]; then
            if [[ $(basename "$dir") == "small8" ]]; then
                install_small8
            else
                ./scripts/feeds install -f -ap "$(basename "$dir")"
            fi
        fi
    done
}

# 移除不需要的包
remove_unwanted_packages() {
    cd "$BUILD_DIR"
    echo "Removing unwanted packages..."

    local luci_packages=(
        "luci-app-passwall"
        "luci-app-smartdns"
        "luci-app-ddns-go"
        "luci-app-rclone"
        "luci-app-ssr-plus"
        "luci-app-vssr"
        "luci-theme-argon"
        "luci-app-daed"
        "luci-app-dae"
        "luci-app-alist"
        "luci-app-argon-config"
        "luci-app-homeproxy"
        "luci-app-haproxy-tcp"
        "luci-app-openclash"
        "luci-app-mihomo"
    )

    local packages_net=(
        "haproxy"
        "xray-core"
        "xray-plugin"
        "dns2socks"
        "alist"
        "hysteria"
        "smartdns"
        "mosdns"
        "adguardhome"
        "ddns-go"
        "naiveproxy"
        "shadowsocks-rust"
        "sing-box"
        "v2ray-core"
        "v2ray-geodata"
        "v2ray-plugin"
        "tuic-client"
        "chinadns-ng"
        "ipt2socks"
        "tcping"
        "trojan-plus"
        "simple-obfs"
        "shadowsocksr-libev"
        "dae"
        "daed"
        "mihomo"
        "geoview"
    )

    for pkg in "${luci_packages[@]}"; do
        rm -rf "./feeds/luci/applications/$pkg"
        rm -rf "./feeds/luci/themes/$pkg"
    done

    for pkg in "${packages_net[@]}"; do
        rm -rf "./feeds/packages/net/$pkg"
    done

    # 清理临时文件
    find "$BUILD_DIR/package/base-files/files/etc/uci-defaults/" -type f -name "9*.sh" -exec rm -f {} +
}

# 更新 Golang
update_golang() {
    cd "$BUILD_DIR"
    echo "Updating Golang..."
    if [[ -d ./feeds/packages/lang/golang ]]; then
        rm -rf ./feeds/packages/lang/golang
    fi
    git clone "$GOLANG_REPO" -b "$GOLANG_BRANCH" ./feeds/packages/lang/golang
}

# 安装 small8 包
install_small8() {
    cd "$BUILD_DIR"
    echo "Installing small8 packages..."
    ./scripts/feeds install -p small8 -f \
        xray-core xray-plugin dns2tcp haproxy hysteria \
        naiveproxy shadowsocks-rust sing-box v2ray-core v2ray-geodata v2ray-plugin \
        luci-app-passwall alist smartdns mosdns adguardhome ddns-go \
        luci-theme-argon netdata lucky luci-app-openclash mihomo luci-app-homeproxy
}

# 主流程
main() {
    clone_repo
    clean_up
    reset_feeds_conf
    install_feeds
    remove_unwanted_packages
    update_golang
    install_small8
}

# 执行主流程
main
