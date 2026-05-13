#!/bin/bash
set -e

# Flutter SDK 安装脚本 for macOS ARM64
FLUTTER_VERSION="3.29.0"
INSTALL_DIR="$HOME/development"
FLUTTER_DIR="$INSTALL_DIR/flutter"

echo "=========================================="
echo "  Flutter SDK $FLUTTER_VERSION 安装脚本"
echo "  macOS ARM64 (Apple Silicon)"
echo "=========================================="
echo ""

# 1. 创建安装目录
mkdir -p "$INSTALL_DIR"

# 2. 下载 Flutter SDK
cd "$INSTALL_DIR"
if [ -d "$FLUTTER_DIR" ]; then
  echo "✅ Flutter 目录已存在，跳过下载"
else
  echo "⬇️  正在下载 Flutter SDK（约 1.4GB）..."
  echo ""

  # 先用国内镜像，失败则用官方源
  DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.29.0-stable.zip"
  MIRROR_URL="https://storage.flutter-io.cn/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.29.0-stable.zip"

  echo "尝试1: 国内镜像..."
  if curl -L -o flutter.zip "$MIRROR_URL"; then
    echo "✅ 国内镜像下载成功"
  else
    echo "尝试2: 官方源..."
    if curl -L -o flutter.zip "$DOWNLOAD_URL"; then
      echo "✅ 官方源下载成功"
    else
      echo ""
      echo "❌ 下载失败，请手动下载："
      echo "   $DOWNLOAD_URL"
      echo "   下载后解压到 $FLUTTER_DIR"
      exit 1
    fi
  fi

  echo "📂 解压中..."
  unzip -q flutter.zip
  rm flutter.zip
  echo "✅ 解压完成"
fi

# 3. 配置环境变量
echo "🔧 配置环境变量..."
if ! grep -q 'FLUTTER_ROOT' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" << 'EOF'

# Flutter
export FLUTTER_ROOT="$HOME/development/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
EOF
  echo "✅ 已添加 Flutter 到 ~/.zshrc"
else
  echo "环境变量已存在，跳过"
fi

# 4. 加载环境变量并验证
export PATH="$FLUTTER_DIR/bin:$PATH"
echo ""
echo "🔍 验证安装..."
flutter --version || echo "⚠️  请运行 source ~/.zshrc 后再试"

# 5. 配置国内镜像 (可选)
echo ""
echo "📚 预配置完成"
echo ""
echo "🎉 Flutter 安装完成！"
echo ""
echo "📋 后续步骤："
echo "  1. 重启终端 或 运行: source ~/.zshrc"
echo "  2. 安装 Android Studio: https://developer.android.com/studio"
echo "  3. 打开 Android Studio → 安装 Android SDK"
echo "  4. 运行: flutter doctor 检查环境"
echo ""
