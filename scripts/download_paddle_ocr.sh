#!/bin/bash
# Download Paddle Lite SDK and PP-OCRv5 models for PaddleOCR branch
# Run from project root: bash scripts/download_paddle_ocr.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CPP_DIR="$PROJECT_DIR/android/app/src/main/cpp"
JNILIBS_DIR="$PROJECT_DIR/android/app/src/main/jniLibs"
ASSETS_DIR="$PROJECT_DIR/android/app/src/main/assets/models"
TMP_DIR="/tmp/paddle_ocr_dl"

# Paddle Lite version
PADDLELITE_VER="2.13"

# URLs (Baidu BOS - fast in China, GitHub as fallback)
BOS_BASE="https://paddle-inference-lib.bj.bcebos.com/${PADDLELITE_VER}/android"
GITHUB_BASE="https://github.com/PaddlePaddle/Paddle-Lite/releases/download/v${PADDLELITE_VER}"
MODEL_BASE="https://paddleocr.bj.bcebos.com/PP-OCRv5/mobile"

ABIS=("armeabi-v7a" "arm64-v8a")
MODELS=(
  "ch_PP-OCRv5_det.nb"
  "ch_PP-OCRv5_rec.nb"
  "ch_ppocr_mobile_v2.0_cls.nb"
)
DICT_FILES=(
  "ppocr_keys_v1.txt"
)

echo "=== PaddleOCR Download Script ==="
echo "Project: $PROJECT_DIR"
echo "Paddle Lite version: $PADDLELITE_VER"
echo ""

# Create directories
mkdir -p "$CPP_DIR/PaddleLite/include"
mkdir -p "$ASSETS_DIR"
mkdir -p "$TMP_DIR"

# ------------------------------------------------------------
# Step 1: Download Paddle Lite headers (same for all ABIs)
# ------------------------------------------------------------
echo "[1/3] Downloading Paddle Lite C++ headers..."

HEADER_ZIP="$TMP_DIR/paddle_lite_headers.zip"
HEADER_URL="${GITHUB_BASE}/PaddleLite-android-headers.zip"

curl -L --connect-timeout 30 --retry 3 \
  -o "$HEADER_ZIP" "$HEADER_URL" 2>/dev/null || {
  echo "  GitHub failed, trying alternative..."
  curl -L --connect-timeout 30 --retry 3 \
    -o "$HEADER_ZIP" \
    "${BOS_BASE}/include.zip" 2>/dev/null
}

if [ -f "$HEADER_ZIP" ]; then
  unzip -o -q "$HEADER_ZIP" -d "$TMP_DIR/headers"
  cp -r "$TMP_DIR/headers"/include/* "$CPP_DIR/PaddleLite/include/" 2>/dev/null || true
  # If the zip extracts directly to current dir
  if [ -d "$TMP_DIR/headers/paddle" ]; then
    mkdir -p "$CPP_DIR/PaddleLite/include"
    cp -r "$TMP_DIR/headers/paddle" "$CPP_DIR/PaddleLite/include/"
  fi
  echo "  Headers installed to $CPP_DIR/PaddleLite/include/"
else
  echo "  WARNING: Failed to download headers."
  echo "  Manual download: $HEADER_URL"
fi

# ------------------------------------------------------------
# Step 2: Download Paddle Lite .so for each ABI
# ------------------------------------------------------------
echo "[2/3] Downloading Paddle Lite native libraries..."

for ABI in "${ABIS[@]}"; do
  echo "  Downloading for $ABI..."

  SO_DIR="$JNILIBS_DIR/$ABI"
  mkdir -p "$SO_DIR"

  SO_URL="${GITHUB_BASE}/PaddleLite-android-${ABI}.tar.gz"

  curl -L --connect-timeout 60 --retry 3 \
    -o "$TMP_DIR/paddle_lite_${ABI}.tar.gz" "$SO_URL" 2>/dev/null || {
    echo "    GitHub failed, use manual download"
    continue
  }

  tar -xzf "$TMP_DIR/paddle_lite_${ABI}.tar.gz" -C "$TMP_DIR/"

  # Find and copy .so files
  find "$TMP_DIR" -name "*.so" -exec cp {} "$SO_DIR/" \; 2>/dev/null || true

  if ls "$SO_DIR"/*.so 1>/dev/null 2>&1; then
    echo "    -> $SO_DIR/"
    ls -la "$SO_DIR"/*.so 2>/dev/null
  else
    echo "    WARNING: No .so files found for $ABI"
  fi
done

# ------------------------------------------------------------
# Step 3: Download PP-OCRv5 models
# ------------------------------------------------------------
echo "[3/3] Downloading PP-OCRv5 models..."

for MODEL in "${MODELS[@]}"; do
  echo "  Downloading $MODEL..."

  # Try multiple sources
  curl -L --connect-timeout 60 --retry 3 \
    -o "$ASSETS_DIR/$MODEL" "${MODEL_BASE}/${MODEL}" 2>/dev/null || \
  curl -L --connect-timeout 60 --retry 3 \
    -o "$ASSETS_DIR/$MODEL" \
    "https://huggingface.co/PaddlePaddle/PaddleOCR/resolve/main/ppocr_v5_mobile/${MODEL}" 2>/dev/null || \
  {
    echo "    WARNING: Failed to download $MODEL"
    echo "    Manual: ${MODEL_BASE}/${MODEL}"
  }

  if [ -f "$ASSETS_DIR/$MODEL" ]; then
    SIZE=$(ls -lh "$ASSETS_DIR/$MODEL" | awk '{print $5}')
    echo "    -> $ASSETS_DIR/$MODEL ($SIZE)"
  fi
done

# Download dictionary file
echo "  Downloading dictionary..."
for DICT in "${DICT_FILES[@]}"; do
  curl -L --connect-timeout 30 --retry 3 \
    -o "$ASSETS_DIR/$DICT" "${MODEL_BASE}/${DICT}" 2>/dev/null || \
  curl -L --connect-timeout 30 --retry 3 \
    -o "$ASSETS_DIR/$DICT" \
    "https://huggingface.co/PaddlePaddle/PaddleOCR/resolve/main/ppocr_v5_mobile/${DICT}" 2>/dev/null || \
  echo "    WARNING: Failed to download $DICT (optional)"
done

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
echo ""
echo "=== Download Complete ==="
echo ""
echo "Expected directory structure:"
echo "  $JNILIBS_DIR/"
echo "    ├── armeabi-v7a/"
echo "    │   └── libpaddle_light_api_shared.so"
echo "    └── arm64-v8a/"
echo "        └── libpaddle_light_api_shared.so"
echo "  $CPP_DIR/PaddleLite/"
echo "    └── include/"
echo "        └── paddle_api.h, paddle_use_kernels.h, ..."
echo "  $ASSETS_DIR/"
echo "    ├── ch_PP-OCRv5_det.nb"
echo "    ├── ch_PP-OCRv5_rec.nb"
echo "    └── ch_ppocr_mobile_v2.0_cls.nb"
echo ""
echo "Next: Build APK with 'flutter build apk'"

# Clean up
rm -rf "$TMP_DIR"
