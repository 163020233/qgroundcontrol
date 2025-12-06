# src/Comms/BoyingLink/CMakeLists.txt

# 1. 定义静态库
add_library(BoyingLinkLib STATIC
        BoyingLink.cc
        BoyingLink.h
        BoyingLinkConfiguration.cc
        BoyingLinkConfiguration.h
)

# 2. 配置头文件搜索路径
target_include_directories(BoyingLinkLib PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/src/Comms

        # --- ★★★ 暴力修复 MAVLink 路径 ★★★ ---
        # 1. 尝试 c_library_v2 (最常见)
        ${CMAKE_SOURCE_DIR}/libs/c_library_v2
        ${CMAKE_SOURCE_DIR}/libs/c_library_v2/common
        ${CMAKE_SOURCE_DIR}/libs/c_library_v2/all

        # 2. 尝试 libs/mavlink (备选)
        ${CMAKE_SOURCE_DIR}/libs/mavlink/include/mavlink/v2.0
        ${CMAKE_SOURCE_DIR}/libs/mavlink/include/mavlink/v2.0/common
        ${CMAKE_SOURCE_DIR}/libs/mavlink/include/mavlink/v2.0/all

        # 3. 尝试构建目录 (有时是动态生成的)
        ${CMAKE_BINARY_DIR}/libs/c_library_v2
)

# 3. 链接 Qt 库 (Windows 和 Android 通用)
target_link_libraries(BoyingLinkLib PRIVATE
        Qt6::Core
        Qt6::Network
        Qt6::SerialPort  # ★★★ 必须加上这个！否则串口无法使用 ★★★
)

# 4. Android 特有配置
if(ANDROID)
    target_link_libraries(BoyingLinkLib PRIVATE
            android  # 链接安卓系统库，用于日志或底层操作
    )

    # 再次强调：这里不需要链接 libBoyingSdk.so
    # 因为那是通过 JNI 动态加载的，只要打包进 APK 即可
endif()