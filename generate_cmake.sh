#!/bin/bash

# Exit on error
set -e

# --- 參數處理 ---
PROJECT_DIR="$1"
PROJECT_TYPE="${2:-executable}"
PROJECT_NAME=$(basename "${PROJECT_DIR}")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 產生 vcpkg.json (維持不變)
echo "📝 正在產生 vcpkg.json (僅含 gtest)..."
LOWERCASE_PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
cat > "${PROJECT_DIR}/vcpkg.json" <<EOF
{
  "name": "${LOWERCASE_PROJECT_NAME}",
  "version-string": "1.0.0",
  "dependencies": [
    "gtest"
  ]
}
EOF

# 2. 產生 cmake/dependencies.cmake (維持不變)
echo "📝 正在產生 cmake/dependencies.cmake..."
mkdir -p "${PROJECT_DIR}/cmake"
cat > "${PROJECT_DIR}/cmake/dependencies.cmake" <<EOF
# --- Cmake Dependency Management ---
find_package(GTest CONFIG REQUIRED)
find_package(Threads REQUIRED)

set(THIRD_PARTY_LIBS
    Threads::Threads
)
EOF

# 3. 【新增】產生 CMakePresets.json
echo "📝 正在產生 CMakePresets.json..."
cat > "${PROJECT_DIR}/CMakePresets.json" <<EOF
{
  "version": 3,
  "configurePresets": [
    {
      "name": "default",
      "displayName": "Default Config",
      "description": "Default build with tests disabled.",
      "generator": "Ninja",
      "binaryDir": "\${sourceDir}/build/default",
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "\$env{CPROJECT_VCPKG_TOOLCHAIN}",
        "BUILD_TESTS": "OFF"
      }
    },
    {
      "name": "test",
      "displayName": "Test Config",
      "description": "Build with tests enabled.",
      "inherits": "default",
      "binaryDir": "\${sourceDir}/build/test",
      "cacheVariables": {
        "BUILD_TESTS": "ON"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "default",
      "configurePreset": "default"
    },
    {
      "name": "test",
      "configurePreset": "test"
    }
  ],
  "testPresets": [
    {
      "name": "default",
      "configurePreset": "test",
      "output": { "outputOnFailure": true }
    }
  ]
}
EOF


# 4. 產生主 CMakeLists.txt (明確列出檔案，無 GLOB)
echo "📝 正在產生主 CMakeLists.txt (明確列出檔案)..."

if [ "${PROJECT_TYPE}" == "library" ]; then
# --- 函式庫版本的 CMakeLists.txt ---
cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(cmake/dependencies.cmake)

option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    enable_testing()
    include(GoogleTest)
endif()

# --- 建立函式庫 (明確列出檔案) ---
add_library(${PROJECT_NAME} STATIC
    src/${PROJECT_NAME}.cpp
)
target_include_directories(${PROJECT_NAME} PUBLIC 
    \${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    \${THIRD_PARTY_LIBS}
)

# --- 建置測試 (明確列出檔案) ---
if(BUILD_TESTS)
    add_executable(run_tests
        tests/basic_test.cpp
    )
    target_link_libraries(run_tests PRIVATE 
        ${PROJECT_NAME} 
        GTest::GTest GTest::Main
    )
    gtest_discover_tests(run_tests)
endif()
EOF

else
# --- 執行檔版本的 CMakeLists.txt ---
cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(cmake/dependencies.cmake)

option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    enable_testing()
    include(GoogleTest)
endif()

# --- 建立執行檔 (明確列出檔案) ---
add_executable(${PROJECT_NAME}
    src/main.cpp
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    \${THIRD_PARTY_LIBS}
)

# --- 建置測試 (明確列出檔案) ---
if(BUILD_TESTS)
    add_executable(run_tests
        tests/basic_test.cpp
    )
    target_link_libraries(run_tests PRIVATE 
        ${PROJECT_NAME} 
        GTest::GTest GTest::Main
    )
    gtest_discover_tests(run_tests)
endif()
EOF
fi

echo "✅ 現代化 CMake 專案設定已成功產生！"