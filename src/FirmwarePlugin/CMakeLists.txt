target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        FirmwarePlugin.cc
        FirmwarePlugin.h
        FirmwarePluginFactory.cc
        FirmwarePluginFactory.h
        FirmwarePluginManager.cc
        FirmwarePluginManager.h
)

# 添加自身路径
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})


# 添加子模块
add_subdirectory(APM)
add_subdirectory(PX4)

# 添加子模块返回的 include 路径
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${APM_INCLUDE_DIRS}
)