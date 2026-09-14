cmake_minimum_required(VERSION 3.22.1)
project(get_native_error)

add_library(get_native_error SHARED
    gne_signal.c
    jni_bridge.c)

find_library(log-lib log)
target_link_libraries(get_native_error ${log-lib})
