cmake_minimum_required(VERSION 3.28)

set(TARGET_NAME "SwitchboardCLIDemo")

project(${TARGET_NAME})
if (APPLE)
    set(CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "" CACHE STRING "Apple Development Team ID")
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "" CACHE STRING "Apple Code Sign Identity")
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO" CACHE STRING "")
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO" CACHE STRING "")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/CMake")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

include(SwitchboardSDK)

# Install JSON files to executable destination directory
include(GNUInstallDirs)

add_subdirectory(demos)