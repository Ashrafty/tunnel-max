# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(tunnel_max LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "tunnel_max")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Native library loading configuration
set(SINGBOX_EXECUTABLE "${CMAKE_CURRENT_SOURCE_DIR}/sing-box/sing-box.exe")

# Enhanced function to validate and configure sing-box executable
function(validate_and_configure_singbox_executable EXECUTABLE_PATH)
    # Check multiple potential locations for sing-box executable
    set(SEARCH_PATHS
        "${EXECUTABLE_PATH}"
        "${CMAKE_CURRENT_SOURCE_DIR}/bin/sing-box.exe"
        "${CMAKE_CURRENT_SOURCE_DIR}/native/sing-box.exe"
        "${CMAKE_CURRENT_SOURCE_DIR}/windows/sing-box/sing-box.exe"
    )
    
    set(FOUND_EXECUTABLE "")
    foreach(SEARCH_PATH ${SEARCH_PATHS})
        if(EXISTS "${SEARCH_PATH}")
            file(SIZE "${SEARCH_PATH}" SINGBOX_SIZE)
            if(SINGBOX_SIZE GREATER 1000000)  # At least 1MB
                set(FOUND_EXECUTABLE "${SEARCH_PATH}")
                message(STATUS "Found valid sing-box executable: ${SEARCH_PATH} (${SINGBOX_SIZE} bytes)")
                break()
            else()
                message(WARNING "sing-box executable too small: ${SEARCH_PATH} (${SINGBOX_SIZE} bytes)")
            endif()
        endif()
    endforeach()
    
    if(FOUND_EXECUTABLE)
        set(SINGBOX_VALID TRUE PARENT_SCOPE)
        set(VALIDATED_SINGBOX_PATH "${FOUND_EXECUTABLE}" PARENT_SCOPE)
        
        # Create native library configuration header
        configure_file(
            "${CMAKE_CURRENT_SOURCE_DIR}/runner/native_config.h.in"
            "${CMAKE_CURRENT_BINARY_DIR}/native_config.h"
            @ONLY
        )
    else()
        set(SINGBOX_VALID FALSE PARENT_SCOPE)
        message(WARNING "No valid sing-box executable found in any search location")
        foreach(SEARCH_PATH ${SEARCH_PATHS})
            message(WARNING "  Checked: ${SEARCH_PATH}")
        endforeach()
    endif()
endfunction()

# Create native configuration header template if it doesn't exist
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/runner/native_config.h.in")
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/runner/native_config.h.in"
        "#ifndef NATIVE_CONFIG_H_\n"
        "#define NATIVE_CONFIG_H_\n"
        "\n"
        "// Native library configuration - auto-generated\n"
        "#define SINGBOX_EXECUTABLE_PATH \"@VALIDATED_SINGBOX_PATH@\"\n"
        "#define NATIVE_LIBRARY_CONFIGURED 1\n"
        "\n"
        "#endif // NATIVE_CONFIG_H_\n"
    )
endif()

# Validate and configure sing-box executable
validate_and_configure_singbox_executable("${SINGBOX_EXECUTABLE}")

if(SINGBOX_VALID)
    # Install the validated executable
    install(FILES "${VALIDATED_SINGBOX_PATH}"
            DESTINATION "${CMAKE_INSTALL_PREFIX}"
            COMPONENT Runtime)
    
    # Add post-install validation with enhanced checks
    install(CODE "
        set(INSTALLED_SINGBOX \"\${CMAKE_INSTALL_PREFIX}/sing-box.exe\")
        if(EXISTS \"\${INSTALLED_SINGBOX}\")
            file(SIZE \"\${INSTALLED_SINGBOX}\" INSTALLED_SIZE)
            if(INSTALLED_SIZE GREATER 1000000)
                message(STATUS \"sing-box executable installed and validated: \${INSTALLED_SINGBOX} (\${INSTALLED_SIZE} bytes)\")
            else()
                message(WARNING \"Installed sing-box executable validation failed: size \${INSTALLED_SIZE} bytes\")
            endif()
        else()
            message(FATAL_ERROR \"Failed to install sing-box executable to \${INSTALLED_SINGBOX}\")
        endif()
    " COMPONENT Runtime)
    
    # Create runtime library path configuration
    install(CODE "
        # Create library path configuration file
        set(CONFIG_FILE \"\${CMAKE_INSTALL_PREFIX}/native_library_config.txt\")
        file(WRITE \"\${CONFIG_FILE}\" \"SINGBOX_PATH=\${CMAKE_INSTALL_PREFIX}/sing-box.exe\\n\")
        file(APPEND \"\${CONFIG_FILE}\" \"LIBRARY_VERSION=${CMAKE_PROJECT_VERSION}\\n\")
        file(APPEND \"\${CONFIG_FILE}\" \"BUILD_TYPE=${CMAKE_BUILD_TYPE}\\n\")
        message(STATUS \"Created native library configuration: \${CONFIG_FILE}\")
    " COMPONENT Runtime)
else()
    message(WARNING "sing-box executable validation failed")
    message(WARNING "Native library loading may not work properly")
    message(WARNING "Run 'scripts/setup_singbox_binaries.ps1' to download sing-box binary")
    
    # Create placeholder configuration for development
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/native_config.h"
        "#ifndef NATIVE_CONFIG_H_\n"
        "#define NATIVE_CONFIG_H_\n"
        "\n"
        "// Native library configuration - placeholder\n"
        "#define SINGBOX_EXECUTABLE_PATH \"sing-box.exe\"\n"
        "#define NATIVE_LIBRARY_CONFIGURED 0\n"
        "\n"
        "#endif // NATIVE_CONFIG_H_\n"
    )
endif()

# Add custom target for native library validation
add_custom_target(validate_native_libraries
    COMMAND ${CMAKE_COMMAND} -E echo "=== Native Library Validation ==="
    COMMAND ${CMAKE_COMMAND} -E echo "sing-box executable: ${SINGBOX_EXECUTABLE}"
    COMMAND ${CMAKE_COMMAND} -E echo "Validation status: $<IF:$<BOOL:${SINGBOX_VALID}>,PASSED,FAILED>"
    COMMAND ${CMAKE_COMMAND} -E echo "Build type: ${CMAKE_BUILD_TYPE}"
    COMMAND ${CMAKE_COMMAND} -E echo "Target platform: Windows"
    COMMENT "Validating native library configuration"
)

# Add dependency to ensure validation runs during build
add_dependencies(${BINARY_NAME} validate_native_libraries)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
