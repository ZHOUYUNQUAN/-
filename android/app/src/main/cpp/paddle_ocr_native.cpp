#include <jni.h>
#include <android/bitmap.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <memory>
#include <algorithm>
#include <cmath>

#define TAG "PaddleOCR-Native"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

// Include Paddle Lite
#include "paddle_api.h"
#include "paddle_use_kernels.h"
#include "paddle_use_ops.h"

using namespace paddle::lite_api;

static std::shared_ptr<PaddlePredictor> g_det_predictor;
static std::shared_ptr<PaddlePredictor> g_rec_predictor;
static std::shared_ptr<PaddlePredictor> g_cls_predictor;
static bool g_initialized = false;

// Model input dimensions for PP-OCRv5 mobile
static const int DET_INPUT_H = 640;
static const int DET_INPUT_W = 640;
static const int REC_INPUT_H = 48;
static const int REC_INPUT_W = 320;
static const int CLS_INPUT_H = 48;
static const int CLS_INPUT_W = 192;

// Mean and scale for normalization
static const float MEAN[3] = {0.485f, 0.456f, 0.406f};
static const float SCALE[3] = {0.229f, 0.224f, 0.225f};

// Load a model and create predictor
static std::shared_ptr<PaddlePredictor> loadModel(
    const std::string& modelDir, const std::string& modelFile) {

    std::string modelPath = modelDir + "/" + modelFile;

    MobileConfig config;
    config.set_model_from_file(modelPath);
    config.set_threads(2);
    config.set_power_mode(PowerMode::LITE_POWER_HIGH);

    auto predictor = CreatePaddlePredictor<MobileConfig>(config);
    if (predictor == nullptr) {
        LOGE("Failed to load model: %s", modelPath.c_str());
    }
    return predictor;
}

// Convert Android Bitmap to raw RGB float data
// Returns a vector of floats in CHW format, normalized
static std::vector<float> bitmapToFloatArray(JNIEnv* env, jobject bitmap,
    int targetW, int targetH) {

    AndroidBitmapInfo info;
    AndroidBitmap_getInfo(env, bitmap, &info);

    void* pixels;
    AndroidBitmap_lockPixels(env, bitmap, &pixels);

    int srcW = info.width;
    int srcH = info.height;
    float scaleW = (float)srcW / targetW;
    float scaleH = (float)srcH / targetH;

    std::vector<float> result(targetH * targetW * 3);

    for (int y = 0; y < targetH; y++) {
        for (int x = 0; x < targetW; x++) {
            int srcX = std::min((int)(x * scaleW), srcW - 1);
            int srcY = std::min((int)(y * scaleH), srcH - 1);

            uint8_t* pixel = ((uint8_t*)pixels) + srcY * info.stride + srcX * 4;
            uint8_t r = pixel[0]; // Bitmap is RGBA
            uint8_t g = pixel[1];
            uint8_t b = pixel[2];

            int idx = (0 * targetH + y) * targetW + x;
            result[idx] = (r / 255.0f - MEAN[0]) / SCALE[0];

            idx = (1 * targetH + y) * targetW + x;
            result[idx] = (g / 255.0f - MEAN[1]) / SCALE[1];

            idx = (2 * targetH + y) * targetW + x;
            result[idx] = (b / 255.0f - MEAN[2]) / SCALE[2];
        }
    }

    AndroidBitmap_unlockPixels(env, bitmap);
    return result;
}

// Crop a region from bitmap and convert to float for recognition
static std::vector<float> cropToFloatArray(JNIEnv* env, jobject bitmap,
    int left, int top, int right, int bottom, int targetW, int targetH) {

    void* pixels;
    AndroidBitmapInfo info;
    AndroidBitmap_getInfo(env, bitmap, &info);
    AndroidBitmap_lockPixels(env, bitmap, &pixels);

    int cropW = right - left;
    int cropH = bottom - top;
    float scaleW = (float)cropW / targetW;
    float scaleH = (float)cropH / targetH;

    std::vector<float> result(targetH * targetW * 3);

    for (int y = 0; y < targetH; y++) {
        for (int x = 0; x < targetW; x++) {
            int srcX = left + std::min((int)(x * scaleW), cropW - 1);
            int srcY = top + std::min((int)(y * scaleH), cropH - 1);

            srcX = std::max(0, std::min(srcX, (int)info.width - 1));
            srcY = std::max(0, std::min(srcY, (int)info.height - 1));

            uint8_t* pixel = ((uint8_t*)pixels) + srcY * info.stride + srcX * 4;
            float r = pixel[0] / 255.0f;
            float g = pixel[1] / 255.0f;
            float b = pixel[2] / 255.0f;

            // CHW format: channel first
            result[(0 * targetH + y) * targetW + x] = (r - MEAN[0]) / SCALE[0];
            result[(1 * targetH + y) * targetW + x] = (g - MEAN[1]) / SCALE[1];
            result[(2 * targetH + y) * targetW + x] = (b - MEAN[2]) / SCALE[2];
        }
    }

    AndroidBitmap_unlockPixels(env, bitmap);
    return result;
}

// Run detection model to find text boxes
static std::vector<std::vector<int>> detectText(JNIEnv* env, jobject bitmap) {
    std::vector<std::vector<int>> boxes;

    if (g_det_predictor == nullptr) return boxes;

    auto input = g_det_predictor->GetInput(0);
    std::vector<int> inputShape = {1, 3, DET_INPUT_H, DET_INPUT_W};
    input->Resize(inputShape);

    auto inputData = bitmapToFloatArray(env, bitmap, DET_INPUT_W, DET_INPUT_H);
    input->CopyFromCpu(inputData.data());

    g_det_predictor->Run();

    auto output = g_det_predictor->GetOutput(0);
    auto outputShape = output->shape();

    // Simplified: read detection boxes from output
    // Real implementation would decode the output tensor based on PP-OCRv5 det head
    int numBoxes = outputShape[1];
    const float* outData = output->data<float>();

    AndroidBitmapInfo info;
    AndroidBitmap_getInfo(env, bitmap, &info);
    float ratioW = (float)info.width / DET_INPUT_W;
    float ratioH = (float)info.height / DET_INPUT_H;

    for (int i = 0; i < numBoxes; i++) {
        int baseIdx = i * 8; // 4 points x 2 coords
        std::vector<int> box(4);

        // Get bounding rect from polygon points
        float minX = outData[baseIdx];
        float minY = outData[baseIdx + 1];
        float maxX = minX;
        float maxY = minY;

        for (int j = 2; j < 8; j += 2) {
            minX = std::min(minX, outData[baseIdx + j]);
            minY = std::min(minY, outData[baseIdx + j + 1]);
            maxX = std::max(maxX, outData[baseIdx + j]);
            maxY = std::max(maxY, outData[baseIdx + j + 1]);
        }

        box[0] = (int)(minX * ratioW);
        box[1] = (int)(minY * ratioH);
        box[2] = (int)(maxX * ratioW);
        box[3] = (int)(maxY * ratioH);
        boxes.push_back(box);
    }

    return boxes;
}

// Run recognition model on a text region
static std::string recognizeText(JNIEnv* env, jobject bitmap,
    const std::vector<int>& box) {

    if (g_rec_predictor == nullptr) return "";

    auto input = g_rec_predictor->GetInput(0);
    std::vector<int> inputShape = {1, 3, REC_INPUT_H, REC_INPUT_W};
    input->Resize(inputShape);

    auto inputData = cropToFloatArray(env, bitmap,
        box[0], box[1], box[2], box[3], REC_INPUT_W, REC_INPUT_H);
    input->CopyFromCpu(inputData.data());

    g_rec_predictor->Run();

    auto output = g_rec_predictor->GetOutput(0);
    auto outputShape = output->shape();
    const float* outData = output->data<float>();

    // PP-OCRv5 rec output: sequence of character probabilities
    // Character set for Chinese recognition (simplified - full set has ~6600 chars)
    static const char* CHARS[] = {
        " ", "0","1","2","3","4","5","6","7","8","9",
        "A","B","C","D","E","F","G","H","I","J","K","L","M",
        "N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        "a","b","c","d","e","f","g","h","i","j","k","l","m",
        "n","o","p","q","r","s","t","u","v","w","x","y","z",
        "一","二","三","四","五","六","七","八","九","十",
        "元","角","分","整",
        "年","月","日","时","分","秒",
        "¥","￥",".",
        "餐","饮","食","堂","外","卖","饭","面","粉","菜",
        "超","市","便","利","店","商","场",
        "支","付","微","信","宝","银","行","卡",
        "打","车","滴","公","交","地","铁","加","油","停",
        "收","款","商","户","实","付","合","计","消","费",
        "金","额","凭","证","单","号","编","码",
        "百","千","万","亿",
        "号","码","电","话","手","机"
    };
    static const int NUM_CHARS = sizeof(CHARS) / sizeof(CHARS[0]);

    std::string result;
    int timeSteps = outputShape[1];

    for (int t = 0; t < timeSteps; t++) {
        int maxIdx = 0;
        float maxVal = outData[t * NUM_CHARS];
        for (int c = 1; c < NUM_CHARS; c++) {
            if (outData[t * NUM_CHARS + c] > maxVal) {
                maxVal = outData[t * NUM_CHARS + c];
                maxIdx = c;
            }
        }
        if (maxIdx > 0) {  // skip blank (index 0)
            result += CHARS[maxIdx];
        }
    }

    // Remove duplicate consecutive characters (CTC decoding)
    std::string dedup;
    for (size_t i = 0; i < result.length(); i++) {
        if (i == 0 || result[i] != result[i - 1]) {
            dedup += result[i];
        }
    }

    return dedup;
}

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_yingfeng_expense_manager_PaddleOcrPlugin_00024NativeBridge_init(
    JNIEnv* env, jclass clazz, jobject context, jstring modelDir) {

    if (g_initialized) return JNI_TRUE;

    const char* modelDirStr = env->GetStringUTFChars(modelDir, nullptr);
    std::string modelDirPath(modelDirStr);

    LOGD("Initializing PaddleOCR with models from: %s", modelDirStr);

    g_det_predictor = loadModel(modelDirPath, "ch_PP-OCRv5_det.nb");
    g_rec_predictor = loadModel(modelDirPath, "ch_PP-OCRv5_rec.nb");
    g_cls_predictor = loadModel(modelDirPath, "ch_ppocr_mobile_v2.0_cls.nb");

    env->ReleaseStringUTFChars(modelDir, modelDirStr);

    g_initialized = (g_det_predictor != nullptr && g_rec_predictor != nullptr);

    if (g_initialized) {
        LOGD("PaddleOCR initialized successfully");
    } else {
        LOGE("PaddleOCR initialization failed");
    }

    return g_initialized ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
Java_com_yingfeng_expense_manager_PaddleOcrPlugin_00024NativeBridge_recognize(
    JNIEnv* env, jclass clazz, jobject bitmap) {

    if (!g_initialized) {
        LOGE("PaddleOCR not initialized");
        return env->NewStringUTF("");
    }

    // Step 1: Detect text regions
    auto boxes = detectText(env, bitmap);
    if (boxes.empty()) {
        LOGD("No text detected");
        return env->NewStringUTF("");
    }

    // Step 2: Recognize text in each region
    std::string fullText;
    for (size_t i = 0; i < boxes.size(); i++) {
        std::string text = recognizeText(env, bitmap, boxes[i]);
        if (!text.empty()) {
            if (!fullText.empty()) fullText += "\n";
            fullText += text;
        }
    }

    LOGD("Recognized %zu text regions: %s", boxes.size(), fullText.c_str());
    return env->NewStringUTF(fullText.c_str());
}

JNIEXPORT void JNICALL
Java_com_yingfeng_expense_manager_PaddleOcrPlugin_00024NativeBridge_release(
    JNIEnv* env, jclass clazz) {

    g_det_predictor = nullptr;
    g_rec_predictor = nullptr;
    g_cls_predictor = nullptr;
    g_initialized = false;

    LOGD("PaddleOCR released");
}

} // extern "C"
