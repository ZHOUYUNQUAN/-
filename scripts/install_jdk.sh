#!/bin/bash
set -e

# JDK 17 安装脚本 (macOS ARM64)
# 用于 Android SDK 和 Flutter APK 构建

INSTALL_DIR="$HOME/development/jdk-17"
JDK_TARBALL="/tmp/jdk17.tar.gz"

echo "=========================================="
echo "  JDK 17 (Eclipse Temurin) 安装"
echo "  macOS ARM64"
echo "=========================================="
echo ""

# 检查是否已安装
if [ -d "$INSTALL_DIR/Contents/Home/bin" ] && [ -f "$INSTALL_DIR/Contents/Home/bin/java" ]; then
  echo "✅ JDK 已存在: $INSTALL_DIR"
  "$INSTALL_DIR/Contents/Home/bin/java" -version 2>&1
  exit 0
fi

echo "⬇️  下载 JDK 17 (~180MB)..."

# 多个下载源
URLS=(
  "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.14%2B7/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.14_7.tar.gz"
  "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/aarch64/"
)

DOWNLOADED=false
for url in "${URLS[@]}"; do
  echo "尝试: $url"
  if curl -L --connect-timeout 30 --max-time 600 -o "$JDK_TARBALL" "$url" 2>&1; then
    if [ -f "$JDK_TARBALL" ] && [ "$(stat -f%z "$JDK_TARBALL" 2>/dev/null || echo 0)" -gt 1000000 ]; then
      DOWNLOADED=true
      echo "✅ 下载成功"
      break
    fi
  fi
  echo "❌ 此源失败，尝试下一个..."
  rm -f "$JDK_TARBALL"
done

if [ "$DOWNLOADED" != "true" ]; then
  echo ""
  echo "❌ 所有下载源失败"
  echo "请手动安装 JDK 17: https://adoptium.net/download/"
  exit 1
fi

echo "📂 解压中..."
mkdir -p "$INSTALL_DIR"
tar -xzf "$JDK_TARBALL" -C "$INSTALL_DIR" --strip-components=1 2>/dev/null || \
  tar -xzf "$JDK_TARBALL" -C /tmp && mv /tmp/jdk-17*/* "$INSTALL_DIR/"
rm -f "$JDK_TARBALL"

echo "✅ 解压完成"

# 验证
echo ""
echo "🔍 验证 JDK..."
"$INSTALL_DIR/Contents/Home/bin/java" -version 2>&1 || "$INSTALL_DIR/bin/java" -version 2>&1

# 配置 JAVA_HOME
JAVA_HOME_PATH="$INSTALL_DIR/Contents/Home"
if ! grep -q 'JAVA_HOME' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" << EOF

# Java / JDK
export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
  echo "✅ 已添加 JAVA_HOME 到 ~/.zshrc"
fi

echo ""
echo "🎉 JDK 17 安装完成！"
