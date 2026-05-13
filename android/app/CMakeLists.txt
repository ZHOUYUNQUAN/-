cmake_minimum_required(VERSION 3.10)
project(paddle_ocr_native)

set(CMAKE_CXX_STANDARD 14)

# Paddle Lite include path
set(PADDLE_LITE_DIR ${CMAKE_SOURCE_DIR}/src/main/cpp/PaddleLite)
include_directories(${PADDLE_LITE_DIR}/include)

# JNI bridge source
add_library(paddle_ocr_native SHARED
    src/main/cpp/paddle_ocr_native.cpp
)

# Link Paddle Lite shared library
add_library(paddle_light_api_shared SHARED IMPORTED)
set_target_properties(paddle_light_api_shared PROPERTIES
    IMPORTED_LOCATION ${PADDLE_LITE_DIR}/libs/${ANDROID_ABI}/libpaddle_light_api_shared.so
)

# Link against OpenCL for GPU acceleration (optional)
find_library(OPENCL_LIB OpenCL)

target_link_libraries(paddle_ocr_native
    paddle_light_api_shared
    ${OPENCL_LIB}
    jnigraphics
    log
)
