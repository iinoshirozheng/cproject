#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# === 預設參數與路徑 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_CMAKE_SCRIPT="${SCRIPT_DIR}/generate_cmake.sh"

# === 輸入參數檢查 ===
if [ $# -lt 2 ]; then
    echo "❌ 錯誤：此腳本需要 2 個參數：專案名稱和專案類型 (executable/library)"
    echo "    用法: $0 <ProjectName> <Type>"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_TYPE="$2"
PROJECT_DIR="$(pwd)/${PROJECT_NAME}"

# === 關鍵資訊輸出 ===
echo "🛠 正在生成專案：${PROJECT_NAME}"
echo "🔩 專案類型：${PROJECT_TYPE}"
echo "📂 專案目錄：${PROJECT_DIR}"

# === 建立專案目錄結構 ===
echo "📂 正在創建目錄結構..."
mkdir -p "${PROJECT_DIR}/src"
mkdir -p "${PROJECT_DIR}/tests"

# === 根據專案類型建立不同的原始碼檔案與目錄 ===
if [ "${PROJECT_TYPE}" == "library" ]; then
    # --- 函式庫專案 ---
    echo "📝 創建函式庫檔案 (src/ and include/)..."
    mkdir -p "${PROJECT_DIR}/include/${PROJECT_NAME}"
    # 為執行檔專案建立 lib 目錄
    mkdir -p "${PROJECT_DIR}/lib"
    
    # 建立標頭檔 include/MyLib/MyLib.h
    cat > "${PROJECT_DIR}/include/${PROJECT_NAME}/${PROJECT_NAME}.h" <<EOF
#pragma once
#include <string>

// 宣告一個函式，以便在測試中呼叫
std::string get_lib_name();
EOF
    
    # 建立原始碼檔 src/MyLib.cpp
    cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.cpp" <<EOF
#include "${PROJECT_NAME}/${PROJECT_NAME}.h"

std::string get_lib_name() {
    return "${PROJECT_NAME}";
}
EOF

    # 函式庫的測試需要引用標頭檔
    cat > "${PROJECT_DIR}/tests/basic_test.cpp" <<EOF
#include <gtest/gtest.h>
#include "${PROJECT_NAME}/${PROJECT_NAME}.h" // 引入函式庫標頭檔

// 測試函式庫的功能
TEST(LibraryTest, GetName) {
    EXPECT_EQ(get_lib_name(), "${PROJECT_NAME}");
}
EOF

else
    # --- 執行檔專案 ---
    echo "📝 創建主程式 (src/main.cpp)..."
    # 為執行檔專案建立 bin 目錄
    mkdir -p "${PROJECT_DIR}/bin"
    
    cat > "${PROJECT_DIR}/src/main.cpp" <<EOF
#include <iostream>

int main() {
    std::cout << "Hello, ${PROJECT_NAME}! 🌟" << std::endl;
    return 0;
}
EOF

    cat > "${PROJECT_DIR}/tests/basic_test.cpp" <<EOF
#include <gtest/gtest.h>

TEST(BasicTest, AssertTrue) {
    EXPECT_TRUE(true);
}
EOF
fi

# === 執行 generate_cmake.sh ===
echo "📜 執行 generate_cmake.sh..."
cd "${PROJECT_DIR}"
# 將專案類型作為參數傳遞給下一個腳本
bash "${GENERATE_CMAKE_SCRIPT}" "${PROJECT_DIR}" "${PROJECT_TYPE}"

# === 完成提示 ===
echo "🎉 專案 ${PROJECT_NAME} 已成功生成完成！"