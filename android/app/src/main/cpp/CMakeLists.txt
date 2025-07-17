cmake_minimum_required(VERSION 3.22.1)

project("sing_box_jni")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_library(log-lib log)
find_library(android-lib android)

# Add the sing-box JNI library
add_library(
    sing_box_jni
    SHARED
    sing_box_jni.c
    sing_box_logging.c
)

# Link libraries (removed sing-box dependency since we use process management)
target_link_libraries(
    sing_box_jni
    ${log-lib}
    ${android-lib}
)

# Set compiler flags
target_compile_options(sing_box_jni PRIVATE
    -Wall
    -Wextra
    -O2
    -fvisibility=hidden
)

# Add include directories
target_include_directories(sing_box_jni PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Export symbols for JNI
set_target_properties(sing_box_jni PROPERTIES
    LINK_FLAGS "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/exports.map"
)

# Create exports map file if it doesn't exist
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/exports.map")
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/exports.map" 
         "{\n  global:\n    Java_*;\n    JNI_*;\n  local:\n    *;\n};\n")
endif()