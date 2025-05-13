#!/bin/bash

# Exit on error
set -e

# === 參數處理 ===
if [ $# -ge 1 ]; then
    PROJECT_DIR="$1"
else
    PROJECT_DIR="$(pwd)"
fi

PROJECT_NAME=$(basename "${PROJECT_DIR}")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/cmake_template"
THIRD_PARTY_DIR="${SCRIPT_DIR}/third_party"
TARGET_CMAKE_DIR="${PROJECT_DIR}/cmake"
MAIN_CMAKELISTS="${PROJECT_DIR}/CMakeLists.txt"

echo "📁 目標專案目錄: ${PROJECT_DIR}"
echo "📁 CMake 模板來源: ${TEMPLATE_DIR}"
echo "📁 目標 cmake 資料夾: ${TARGET_CMAKE_DIR}"

# === 檢查 third_party 資料夾 ===
if [ ! -d "${THIRD_PARTY_DIR}" ]; then
    echo "⚠️ 找不到 third_party 資料夾，正在嘗試下載依賴..."
    DOWNLOAD_SCRIPT="${SCRIPT_DIR}/download_packages.sh"
    if [ -f "${DOWNLOAD_SCRIPT}" ]; then
        echo "⬇️ 執行 ${DOWNLOAD_SCRIPT}..."
        bash "${DOWNLOAD_SCRIPT}" || {
            echo "❌ 無法下載依賴，請檢查 ${DOWNLOAD_SCRIPT} 是否正常執行。"
            exit 1
        }
        echo "✅ 第三方依賴下載完成。"
    else
        echo "❌ 找不到下載腳本 ${DOWNLOAD_SCRIPT}，無法繼續。"
        exit 1
    fi
else
    echo "✅ 找到 third_party 資料夾：${THIRD_PARTY_DIR}"
fi

# === 建立目錄與複製模板 ===
mkdir -p "${TARGET_CMAKE_DIR}"
cp -v "${TEMPLATE_DIR}"/* "${TARGET_CMAKE_DIR}/"
cp ${SCRIPT_DIR}/run_template.sh ${PROJECT_DIR}/run.sh
chmod +x ${PROJECT_DIR}/run.sh

# === 產生主 CMakeLists.txt ===
echo "🛠 正在產生 CMakeLists.txt..."
cat > "${MAIN_CMAKELISTS}" <<EOF
cmake_minimum_required(VERSION 3.15)
project(${PROJECT_NAME} VERSION 1.0.0)

message(STATUS "CMake 版本: \${CMAKE_VERSION}")
message(STATUS "專案名稱: \${PROJECT_NAME}")

# C++17 設定
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)

# 第三方庫位置
set(THIRD_PARTY_DIR ${THIRD_PARTY_DIR})
message(STATUS "第三方庫目錄: \${THIRD_PARTY_DIR}")

# 引入外部函數
include(\${THIRD_PARTY_DIR}/LinkThirdparty.cmake OPTIONAL)
message(STATUS "已引入 \${THIRD_PARTY_DIR}/LinkThirdparty.cmake")

# 建立模組化目錄結構
set(CMAKE_MODULE_PATH "${TARGET_CMAKE_DIR}" \${CMAKE_MODULE_PATH})
add_subdirectory(cmake)
EOF

echo "✅ 已完成："
echo "  - 複製模板到 ${TARGET_CMAKE_DIR}"
echo "  - 建立主 CMakeLists.txt at ${MAIN_CMAKELISTS}"
