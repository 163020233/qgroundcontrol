# src/PayloadControls/Shouting/CMakeLists.txt

# 1. 显式查找模块
find_package(Qt6 REQUIRED COMPONENTS Core Network Multimedia)


qt_add_library(ShoutingModule STATIC)

target_sources(ShoutingModule PRIVATE
        ShoutingController.cc
        ShoutingController.h
        ShoutingManager.cc
        ShoutingManager.h
)

# 只链接 Qt 的功能模块
target_link_libraries(ShoutingModule
        PUBLIC
        Qt6::Core
        Qt6::Network
        Qt6::Multimedia
)

# 确保头文件路径正确导出
target_include_directories(ShoutingModule PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
