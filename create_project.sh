#!/bin/bash
set -e

# 解析符號連結，找到腳本的真實目錄
TOOL_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
GENERATE_CMAKE_SCRIPT="${TOOL_SCRIPT_DIR}/generate_cmake.sh"

PROJECT_NAME=""
PROJECT_TYPE="executable"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --library)
            PROJECT_TYPE="library"
            shift
            ;;
        *)
            if [[ -z "$PROJECT_NAME" ]]; then
                PROJECT_NAME="$1"
            else
                echo "❌ 錯誤：無法辨識的參數 $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$PROJECT_NAME" ]]; then
    echo "❌ 錯誤：請提供專案名稱。" >&2
    echo "   用法: cproject create [--library] <ProjectName>" >&2
    exit 1
fi

PROJECT_DIR="$(pwd)/${PROJECT_NAME}"

if [ -d "${PROJECT_DIR}" ]; then
    echo "❌ 錯誤：目標資料夾 '${PROJECT_DIR}' 已經存在。" >&2
    exit 1
fi

echo "🛠  正在生成專案：${PROJECT_NAME}"
echo "🔩 專案類型：${PROJECT_TYPE}"
echo "📂 專案目錄：${PROJECT_DIR}"

mkdir -p "${PROJECT_DIR}/src"
mkdir -p "${PROJECT_DIR}/tests"

if [ "${PROJECT_TYPE}" == "library" ]; then
    echo "📝 創建函式庫檔案 (src/ and include/)..."
    mkdir -p "${PROJECT_DIR}/include/${PROJECT_NAME}"
    cat > "${PROJECT_DIR}/include/${PROJECT_NAME}/${PROJECT_NAME}.h" <<EOF
#pragma once
#include <string>

std::string get_lib_name();
EOF
    cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.cpp" <<EOF
#include "${PROJECT_NAME}/${PROJECT_NAME}.h"

std::string get_lib_name() { return "${PROJECT_NAME}"; }
EOF
    cat > "${PROJECT_DIR}/tests/basic_test.cpp" <<EOF
#include <gtest/gtest.h>
#include "${PROJECT_NAME}/${PROJECT_NAME}.h"

TEST(LibraryTest, GetName) {
    EXPECT_EQ(get_lib_name(), "${PROJECT_NAME}");
}
EOF
else
    echo "📝 創建主程式 (src/main.cpp)..."
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

echo "📜 執行 generate_cmake.sh..."
bash "${GENERATE_CMAKE_SCRIPT}" "${PROJECT_DIR}" "${PROJECT_TYPE}"

echo "🎉 專案 ${PROJECT_NAME} 已成功生成！"
echo ""
echo "下一步:"
echo " cd ${PROJECT_NAME}"
echo " cproject build"