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
    find "${TEMPLATE_DIR}" -type f ! -name "BuildMainExecutable.cmake" -exec cp {} "${TARGET_CMAKE_DIR}/" \;
else
    echo "📑 複製執行檔專用的 CMake 模組..."
    cp -v "${TEMPLATE_DIR}"/* "${TARGET_CMAKE_DIR}/"
fi

# === 複製並設定 run.sh (所有專案都需要) ===
echo "📜 正在複製並設定 run.sh..."
cp "${SCRIPT_DIR}/run_template.sh" "${PROJECT_DIR}/run.sh"
# 根據作業系統使用不同的 sed -i 語法
if [[ "$(uname)" == "Darwin" ]]; then # macOS
    sed -i '' "s|CUSTOM_THIRD_PARTY_DIR=.*|CUSTOM_THIRD_PARTY_DIR=\"${THIRD_PARTY_DIR}\"|" "${PROJECT_DIR}/run.sh"
else # Linux
    sed -i "s|CUSTOM_THIRD_PARTY_DIR=.*|CUSTOM_THIRD_PARTY_DIR=\"${THIRD_PARTY_DIR}\"|" "${PROJECT_DIR}/run.sh"
fi
chmod +x "${PROJECT_DIR}/run.sh"

# === 根據專案類型產生主 CMakeLists.txt ===
echo "📝 正在產生主 CMakeLists.txt for a ${PROJECT_TYPE} project..."

if [ "${PROJECT_TYPE}" == "library" ]; then
# --- 函式庫版本的 CMakeLists.txt (支援動態與靜態) ---
cat > "${MAIN_CMAKELISTS}" <<EOF
cmake_minimum_required(VERSION 3.15)
project(${PROJECT_NAME} VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- 步驟 1: 建立一個 OBJECT 函式庫 ---
# 這一步只會編譯原始碼成 .o 檔案，但不連結。這是最高效的方式。
file(GLOB_RECURSE LIB_SOURCES "src/*.cpp")
add_library(${PROJECT_NAME}_obj OBJECT \${LIB_SOURCES})

# 設定這個物件函式庫需要公開的標頭檔路徑
target_include_directories(${PROJECT_NAME}_obj
    PUBLIC 
        \${CMAKE_CURRENT_SOURCE_DIR}/include
)

# --- 步驟 2: 從 OBJECT 函式庫建立靜態與動態函式庫 ---
# 建立靜態函式庫 (.a)
add_library(${PROJECT_NAME}_static STATIC \$<TARGET_OBJECTS:${PROJECT_NAME}_obj>)
set_target_properties(${PROJECT_NAME}_static PROPERTIES OUTPUT_NAME ${PROJECT_NAME})

# 建立動態函式庫 (.so / .dylib)
add_library(${PROJECT_NAME}_shared SHARED \$<TARGET_OBJECTS:${PROJECT_NAME}_obj>)
set_target_properties(${PROJECT_NAME}_shared PROPERTIES OUTPUT_NAME ${PROJECT_NAME})

# --- 步驟 3: 設定測試 ---
set(CMAKE_MODULE_PATH "${TARGET_CMAKE_DIR}" \${CMAKE_MODULE_PATH})
include(GlobalOptions)
include(ConfigureTests)

DefineGlobalOptions()
ConfigureTests() # 建立 'run_tests' 執行檔

# --- 步驟 4: 將函式庫連結到測試程式上 ---
# 為了方便，我們預設將靜態函式庫連結到測試程式
if(TARGET run_tests)
    target_link_libraries(run_tests PRIVATE ${PROJECT_NAME}_static)
    message(STATUS "已將靜態函式庫 '${PROJECT_NAME}_static' 連結到測試執行檔 'run_tests'")
endif()

# --- 步驟 5: 安裝規則 (安裝兩種函式庫) ---
install(TARGETS ${PROJECT_NAME}_static ${PROJECT_NAME}_shared
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
install(DIRECTORY include/ DESTINATION include)

EOF

else
# --- 執行檔版本的 CMakeLists.txt (保持不變) ---
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