#!/bin/bash
# Download Paddle Lite SDK and prepare PP-OCRv5 models for PaddleOCR branch
# Run from project root: bash scripts/download_paddle_ocr.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CPP_DIR="$PROJECT_DIR/android/app/src/main/cpp"
JNILIBS_DIR="$PROJECT_DIR/android/app/src/main/jniLibs"
ASSETS_DIR="$PROJECT_DIR/android/app/src/main/assets/models"
TMP_DIR="/tmp/paddle_ocr_dl"

# Paddle Lite version
PADDLELITE_VER="2.14-rc"

echo "=== PaddleOCR 依赖下载脚本 ==="
echo ""

# Create directories
mkdir -p "$CPP_DIR/PaddleLite/include"
mkdir -p "$ASSETS_DIR"
mkdir -p "$TMP_DIR"

# ------------------------------------------------------------
# Step 1: Download Paddle Lite libraries and headers
# ------------------------------------------------------------
echo "[1/2] 下载 Paddle Lite 推理库..."

# Requires gh CLI (GitHub CLI) - install: brew install gh
if ! command -v gh &> /dev/null; then
    echo "  错误: 需要安装 GitHub CLI"
    echo "  macOS: brew install gh"
    echo "  然后: gh auth login"
    exit 1
fi

cd "$TMP_DIR"

echo "  下载 arm64-v8a 库..."
gh release download "$PADDLELITE_VER" \
    --repo PaddlePaddle/Paddle-Lite \
    --pattern "inference_lite_lib.android.armv8.clang.c++_shared.tar.gz" \
    --dir "$TMP_DIR" 2>&1

echo "  下载 armeabi-v7a 库..."
gh release download "$PADDLELITE_VER" \
    --repo PaddlePaddle/Paddle-Lite \
    --pattern "inference_lite_lib.android.armv7.clang.c++_shared.tar.gz" \
    --dir "$TMP_DIR" 2>&1

# Extract and copy
echo "  解压和复制文件..."
tar -xzf "inference_lite_lib.android.armv8.clang.c++_shared.tar.gz"
tar -xzf "inference_lite_lib.android.armv7.clang.c++_shared.tar.gz"

# Copy .so files
cp "inference_lite_lib.android.armv8.clang.c++_shared/cxx/lib/libpaddle_light_api_shared.so" \
   "$JNILIBS_DIR/arm64-v8a/"
cp "inference_lite_lib.android.armv7.clang.c++_shared/cxx/lib/libpaddle_light_api_shared.so" \
   "$JNILIBS_DIR/armeabi-v7a/"

# Copy headers
cp "inference_lite_lib.android.armv8.clang.c++_shared/cxx/include/"*.h \
   "$CPP_DIR/PaddleLite/include/"

echo "  Paddle Lite 安装完成"
echo ""

# ------------------------------------------------------------
# Step 2: PP-OCRv5 models
# ------------------------------------------------------------
echo "[2/2] PP-OCRv5 模型说明"
echo ""
echo "  PP-OCRv5 的 .nb 模型文件需要手动转换，没有官方直接下载。"
echo "  模型文件需放置在: $ASSETS_DIR"
echo ""
echo "  所需文件:"
echo "    - ch_PP-OCRv5_det.nb  (检测模型, ~4MB)"
echo "    - ch_PP-OCRv5_rec.nb  (识别模型, ~12MB)"
echo "    - ch_ppocr_mobile_v2.0_cls.nb  (方向分类, ~2MB)"
echo ""
echo "  转换步骤:"
echo "    1. pip install paddlepaddle paddleocr paddlelite"
echo "    2. 下载推理模型:"
echo "       paddlex --download PP-OCRv5_mobile_det"
echo "       paddlex --download PP-OCRv5_mobile_rec"
echo "    3. 转换为 ONNX:"
echo "       paddlex --paddle2onnx --paddle_model_dir PP-OCRv5_mobile_det"
echo "    4. 转换为 .nb:"
echo "       paddle_lite_opt --model_dir=./model --valid_targets=arm --optimize_out=ch_PP-OCRv5_det"
echo ""
echo "  或使用 RapidOCR 替代: https://github.com/RapidAI/RapidOCR"
echo ""

# Clean up
rm -rf "$TMP_DIR"

echo "=== 完成 ==="
