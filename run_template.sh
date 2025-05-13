#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# === 預設參數與路徑 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_CMAKE_SCRIPT="${SCRIPT_DIR}/generate_cmake.sh"

# === 輸入參數檢查 ===
if [ $# -lt 1 ]; then
    echo "❌ 錯誤：請提供專案名稱，例如："
    echo "    $0 MyApp"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/${PROJECT_NAME}"

# === 關鍵資訊輸出 ===
echo "🛠 正在生成專案：${PROJECT_NAME}"
echo "📂 專案目錄：${PROJECT_DIR}"
echo "📜 generate_cmake.sh 路徑：${GENERATE_CMAKE_SCRIPT}"

# === 建立專案目錄結構 ===
echo "📂 正在創建目錄結構..."
mkdir -p "${PROJECT_DIR}/src"    # Source code
mkdir -p "${PROJECT_DIR}/tests"   # Test code
mkdir -p "${PROJECT_DIR}/bin"    # Binary output

# === 在 src 資料夾中創建 main.cpp ===
echo "📝 創建 src/main.cpp..."
cat > "${PROJECT_DIR}/src/main.cpp" <<EOF
#include <iostream>

int main() {
    std::cout << "Hello, ${PROJECT_NAME}! 🌟" << std::endl;
    return 0;
}
EOF

# === 在 test 資料夾中創建 basic_test.cpp ===
echo "📝 創建 test/basic_test.cpp..."
cat > "${PROJECT_DIR}/tests/basic_test.cpp" <<EOF
#include <gtest/gtest.h>
#include <optional>
#include <variant>
#include <string>

// Basic test case
TEST(BasicTest, AssertTrue)
{
    EXPECT_TRUE(true);
}

TEST(BasicTest, AssertEqual)
{
    EXPECT_EQ(2 + 2, 4);
}

// Test C++17 features
TEST(BasicTest, StdOptional)
{
    std::optional<int> opt = 42;
    EXPECT_TRUE(opt.has_value());
    EXPECT_EQ(*opt, 42);
}

TEST(BasicTest, StdVariant)
{
    std::variant<int, std::string> var = 123;
    EXPECT_TRUE(std::holds_alternative<int>(var));
    EXPECT_EQ(std::get<int>(var), 123);

    var = "test";
    EXPECT_TRUE(std::holds_alternative<std::string>(var));
    EXPECT_EQ(std::get<std::string>(var), "test");
}

EOF

# === 檢查 generate_cmake.sh 是否存在 ===
if [ ! -f "${GENERATE_CMAKE_SCRIPT}" ]; then
    echo "❌ 錯誤：找不到 ${GENERATE_CMAKE_SCRIPT}"
    exit 1
fi

# === 執行 generate_cmake.sh ===
echo "📜 執行 generate_cmake.sh..."
cd ${PROJECT_DIR}
chmod +x "${GENERATE_CMAKE_SCRIPT}"
sh "${GENERATE_CMAKE_SCRIPT}"

# === 完成提示 ===
echo "🎉 專案 ${PROJECT_NAME} 已成功生成完成！"
echo "💡 下一步操作："
echo "   1. run.sh"
echo "   1. run.sh --test"