#!/bin/bash
set -e

# Android SDK 命令行工具安装脚本
# 仅安装 Flutter APK 构建所需的最小 SDK 组件

ANDROID_SDK_ROOT="$HOME/Android/sdk"
CMDLINE_VERSION="11076708"
INSTALL_DIR="$ANDROID_SDK_ROOT/cmdline-tools"

echo "=========================================="
echo "  Android SDK 命令行工具安装"
echo "=========================================="
echo ""

# 1. 创建目录
mkdir -p "$INSTALL_DIR"

# 2. 下载命令行工具 (Mac ARM64)
cd "$INSTALL_DIR"
if [ -f "latest/bin/sdkmanager" ]; then
  echo "✅ sdkmanager 已存在，跳过下载"
else
  echo "⬇️  正在下载 Android SDK 命令行工具（约 150MB）..."
  echo ""

  # Google CDN（中国节点）
  URL="https://dl.google.com/android/repository/commandlinetools-mac-${CMDLINE_VERSION}_latest.zip"

  # 尝试直接下载，带重试
  if curl -L --retry 3 --connect-timeout 30 -o cmdline-tools.zip "$URL"; then
    echo "✅ 下载成功"
  else
    echo ""
    echo "❌ 下载失败，请尝试："
    echo "   1. 手动下载: $URL"
    echo "   2. 解压到: $INSTALL_DIR/latest/"
    exit 1
  fi

  echo "📂 解压中..."
  unzip -qo cmdline-tools.zip
  rm cmdline-tools.zip

  # 版本布局需要放到 latest/ 目录下
  echo "✅ 解压完成"
fi

# 3. 设置环境变量
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# 4. 安装 SDK 组件
echo ""
echo "📦 安装 Android SDK 组件（Platform 35, Build Tools）..."
yes | sdkmanager --licenses 2>/dev/null || true

sdkmanager \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "platform-tools" \
  "cmdline-tools;latest" \
  2>&1

echo ""
echo "🔧 配置环境变量..."
if ! grep -q 'ANDROID_SDK_ROOT' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" << 'EOF'

# Android SDK
export ANDROID_SDK_ROOT="$HOME/Android/sdk"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
EOF
  echo "✅ 已添加 Android SDK 到 ~/.zshrc"
else
  echo "环境变量已存在，跳过"
fi

echo ""
echo "🎉 Android SDK 安装完成！"
echo ""
echo "📋 验证:"
echo "  source ~/.zshrc"
echo "  sdkmanager --list"
echo "  flutter doctor"
