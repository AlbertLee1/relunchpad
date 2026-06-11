#!/bin/bash
# ReLaunchpad 一键安装:
#   curl -fsSL https://raw.githubusercontent.com/AlbertLee1/relunchpad/main/Scripts/install.sh | bash
# 下载最新 Release、安装到 /Applications、移除隔离属性并启动。
set -euo pipefail

REPO="AlbertLee1/relunchpad"

echo "▸ 正在获取 ReLaunchpad 最新版本信息…"
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | cut -d'"' -f4)
if [ -z "$URL" ]; then
    echo "✗ 未找到可下载的版本,请到 https://github.com/$REPO/releases 手动下载" >&2
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "▸ 正在下载 $URL"
curl -fL --progress-bar "$URL" -o "$TMP/ReLaunchpad.zip"
ditto -x -k "$TMP/ReLaunchpad.zip" "$TMP"

APP_SRC=$(find "$TMP" -maxdepth 2 -name "ReLaunchpad.app" | head -1)
if [ -z "$APP_SRC" ]; then
    echo "✗ 压缩包内未找到 ReLaunchpad.app" >&2
    exit 1
fi

echo "▸ 正在安装到 /Applications…"
pkill -x ReLaunchpad 2>/dev/null || true
rm -rf /Applications/ReLaunchpad.app
ditto "$APP_SRC" /Applications/ReLaunchpad.app

# 本项目未经 Apple 公证;移除隔离属性以免 Gatekeeper 拦截。
xattr -dr com.apple.quarantine /Applications/ReLaunchpad.app 2>/dev/null || true

open /Applications/ReLaunchpad.app
echo "✅ ReLaunchpad 已安装并启动。点击 Dock 图标或按 ⌥空格 唤起。"
echo "   触控板五指抓拢手势需在 系统设置 > 隐私与安全性 > 输入监控 中授权。"
