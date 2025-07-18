#!/bin/bash

# Exit on error
set -e

# === 參數處理 ===
PROJECT_DIR="$1"
PROJECT_TYPE="${2:-executable}"

PROJECT_NAME=$(basename "${PROJECT_DIR}")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/cmake_template"
THIRD_PARTY_DIR="${SCRIPT_DIR}/third_party"
TARGET_CMAKE_DIR="${PROJECT_DIR}/cmake"
MAIN_CMAKELISTS="${PROJECT_DIR}/CMakeLists.txt"

echo "🛠 正在產生 CMake 設定檔..."
echo "🔩 專案類型: ${PROJECT_TYPE}"

# === 建立 cmake 目錄 ===
mkdir -p "${TARGET_CMAKE_DIR}"

# === 根據專案類型複製不同的模板檔案 ===
if [ "${PROJECT_TYPE}" == "library" ]; then
    echo "📑 複製函式庫專用的 CMake 模組..."
    # 複製所有模板，但排除 BuildMainExecutable.cmake
    find "${TEMPLATE_DIR}" -type f ! -name "BuildMainExecutable.cmake" -exec cp {} "${TARGET_CMAKE_DIR}/" \;
else
    echo "📑 複製執行檔專用的 CMake 模組..."
    # 執行檔專案需要所有模板
    cp -v "${TEMPLATE_DIR}"/* "${TARGET_CMAKE_DIR}/"
fi

# === 複製並設定 run.sh (所有專案都需要) ===
echo "📜 正在複製並設定 run.sh..."
cp "${SCRIPT_DIR}/run_template.sh" "${PROJECT_DIR}/run.sh"
# ... (sed 和 chmod 的邏輯保持不變) ...
chmod +x "${PROJECT_DIR}/run.sh"

# === 根據專案類型產生主 CMakeLists.txt ===
echo "📝 正在產生主 CMakeLists.txt for a ${PROJECT_TYPE} project..."

if [ "${PROJECT_TYPE}" == "library" ]; then
# --- 函式庫版本的 CMakeLists.txt ---
cat > "${MAIN_CMAKELISTS}" <<EOF
cmake_minimum_required(VERSION 3.15)
project(${PROJECT_NAME} VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- 步驟 1: 建立函式庫目標 ---
file(GLOB_RECURSE LIB_SOURCES "src/*.cpp")
add_library(${PROJECT_NAME} STATIC \${LIB_SOURCES})

target_include_directories(${PROJECT_NAME}
    PUBLIC 
        \${CMAKE_CURRENT_SOURCE_DIR}/include
)

# --- 步驟 2: 設定測試 ---
set(CMAKE_MODULE_PATH "${TARGET_CMAKE_DIR}" \${CMAKE_MODULE_PATH})
# 引入必要的模組 (注意：不包含 BuildMainExecutable)
include(GlobalOptions)
include(ConfigureTests)

# 執行設定
DefineGlobalOptions()
ConfigureTests() # 這個模組會建立 'run_tests' 執行檔

# --- 步驟 3: 將函式庫連結到測試程式上 ---
if(TARGET run_tests)
    target_link_libraries(run_tests PRIVATE ${PROJECT_NAME})
    message(STATUS "已將函式庫 '${PROJECT_NAME}' 連結到測試執行檔 'run_tests'")
endif()

# --- 步驟 4: 安裝規則 ---
install(TARGETS ${PROJECT_NAME}
    ARCHIVE DESTINATION lib
)
install(DIRECTORY include/ DESTINATION include)

EOF

else
# --- 執行檔版本的 CMakeLists.txt (原始邏輯) ---
cat > "${MAIN_CMAKELISTS}" <<EOF
cmake_minimum_required(VERSION 3.15)
project(${PROJECT_NAME} VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(MAIN_SOURCE_FILE \${PROJECT_SOURCE_DIR}/src/main.cpp)
set(THIRD_PARTY_DIR "${THIRD_PARTY_DIR}")
include(\${THIRD_PARTY_DIR}/LinkThirdparty.cmake OPTIONAL)

set(CMAKE_MODULE_PATH "${TARGET_CMAKE_DIR}" \${CMAKE_MODULE_PATH})
add_subdirectory(cmake)
EOF
fi

echo "✅ CMakeLists.txt 已成功產生！"