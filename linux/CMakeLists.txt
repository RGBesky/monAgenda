cmake_minimum_required(VERSION 3.13)
project(unified_calendar LANGUAGES CXX)

set(BINARY_NAME "unified_calendar")
cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

if(FLUTTER_TARGET_PLATFORM_OVERRIDE)
  set(FLUTTER_TARGET_PLATFORM "${FLUTTER_TARGET_PLATFORM_OVERRIDE}")
endif()

set(CMAKE_BUILD_TYPE Release)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

add_subdirectory(${FLUTTER_MANAGED_DIR} managed_flutter)

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  ${FLUTTER_TOOL_ENVIRONMENT}
)

apply_standard_settings(${BINARY_NAME})
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Plugins
set(PLUGIN_BUNDLED_LIBRARIES)
include(flutter/generated_plugins.cmake)
foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)
install(FILES "${PROJECT_BUILD_DIR}/app.so" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

# Desktop entry (gestionnaire calendrier Linux)
install(FILES "com.example.unified_calendar.desktop"
  DESTINATION "share/applications"
  COMPONENT Runtime)
