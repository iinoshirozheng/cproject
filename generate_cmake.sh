#!/bin/bash

# Exit on error
set -e

# --- 參數處理 ---
PROJECT_DIR="$1"
PROJECT_TYPE="${2:-executable}"
PROJECT_NAME=$(basename "${PROJECT_DIR}")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- vcpkg 路徑設定 ---
VCPKG_DIR="${SCRIPT_DIR}/vcpkg"
VCPKG_EXECUTABLE="${VCPKG_DIR}/vcpkg"

# --- 函式：設定 vcpkg (如果不存在則自動 clone 並 bootstrap) ---
setup_vcpkg() {
    if [ ! -d "${VCPKG_DIR}" ]; then
        echo "🔧 vcpkg 不存在，正在從 GitHub clone..."
        git clone https://github.com/microsoft/vcpkg.git "${VCPKG_DIR}"
    else
        echo "✅ vcpkg 目錄已存在。"
    fi

    if [ ! -x "${VCPKG_EXECUTABLE}" ]; then
        echo "🚀 正在進行 vcpkg 的首次設定 (bootstrap)..."
        (cd "${VCPKG_DIR}" && ./bootstrap-vcpkg.sh -disableMetrics)
    else
        echo "✅ vcpkg 已完成首次設定。"
    fi
}

# --- 主要邏輯開始 ---

# 1. 設定 vcpkg
setup_vcpkg

# 2. 複製 run.sh 範本
echo "📜 正在複製 run.sh..."
cp "${SCRIPT_DIR}/run_template.sh" "${PROJECT_DIR}/run.sh"
chmod +x "${PROJECT_DIR}/run.sh"

# 3. 產生 vcpkg.json 來管理依賴
echo "📝 正在產生 vcpkg.json..."

# 使用 tr 建立一個相容性高的小寫版本名稱
LOWERCASE_PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')

cat > "${PROJECT_DIR}/vcpkg.json" <<EOF
{
  "name": "${LOWERCASE_PROJECT_NAME}",
  "version-string": "1.0.0",
  "dependencies": [
    "curl",
    "libxml2",
    "gtest"
  ]
}
EOF

# 4. 產生主 CMakeLists.txt (vcpkg 版本)
echo "📝 正在產生主 CMakeLists.txt (for vcpkg)..."

# [修正] 將 find_package 邏輯加到通用內容中
COMMON_CMAKE_CONTENT=$(cat <<'EOF'
# --- 尋找 vcpkg 安裝的函式庫 ---
find_package(CURL REQUIRED)
find_package(LibXml2 REQUIRED)
find_package(Threads REQUIRED)

# --- 測試相關設定 ---
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    find_package(GTest CONFIG REQUIRED)
    enable_testing()
endif()
EOF
)

if [ "${PROJECT_TYPE}" == "library" ]; then
# --- 函式庫版本的 CMakeLists.txt ---
cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

${COMMON_CMAKE_CONTENT}

# --- 建立函式庫 ---
# [建議] 明確列出原始碼檔案，避免使用 file(GLOB)
add_library(${PROJECT_NAME} STATIC
    src/${PROJECT_NAME}.cpp
)
target_include_directories(${PROJECT_NAME} PUBLIC \${CMAKE_CURRENT_SOURCE_DIR}/include)

# 將依賴性連結到函式庫 (名稱由 vcpkg 提供)
target_link_libraries(${PROJECT_NAME}
    PRIVATE
        CURL::libcurl
        LibXml2::LibXml2
        Threads::Threads
)

# --- 測試設定 ---
if(BUILD_TESTS)
    # [建議] 明確列出測試檔案
    add_executable(run_tests
        tests/basic_test.cpp
    )
    target_link_libraries(run_tests PRIVATE ${PROJECT_NAME} GTest::GTest GTest::Main)
    include(GoogleTest)
    gtest_discover_tests(run_tests)
endif()
EOF

else
# --- 執行檔版本的 CMakeLists.txt ---
cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

${COMMON_CMAKE_CONTENT}

# --- 建立執行檔 ---
# [建議] 明確列出原始碼檔案，避免使用 file(GLOB)
add_executable(${PROJECT_NAME}
    src/main.cpp
)

# 連結所有需要的函式庫 (名稱由 vcpkg 提供)
target_link_libraries(${PROJECT_NAME}
    PRIVATE
        CURL::libcurl
        LibXml2::LibXml2
        Threads::Threads
)

# --- 測試設定 ---
if(BUILD_TESTS)
    # [建議] 明確列出測試檔案
    add_executable(run_tests
        tests/basic_test.cpp
    )
    # [核心修正] 將主目標 ${PROJECT_NAME} 連結到測試程式
    target_link_libraries(run_tests
        PRIVATE
            ${PROJECT_NAME}
            GTest::GTest
            GTest::Main
    )
    include(GoogleTest)
    gtest_discover_tests(run_tests)
endif()
EOF
fi

echo "✅ vcpkg 專案設定已成功產生！"