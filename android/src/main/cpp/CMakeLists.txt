cmake_minimum_required(VERSION 3.22.1)
project(get_native_error)

set(GNE_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../native")

add_library(get_native_error SHARED
    "${GNE_SRC_DIR}/gne_signal.c"
    jni_bridge.c)

target_include_directories(get_native_error PRIVATE "${GNE_SRC_DIR}")
target_compile_options(get_native_error PRIVATE -fno-omit-frame-pointer)

find_library(log-lib log)
find_library(dl-lib dl)
target_link_libraries(get_native_error ${log-lib} ${dl-lib})
