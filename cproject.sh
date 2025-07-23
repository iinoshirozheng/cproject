#!/bin/bash
# 當任何指令出錯時，立即退出
set -e

# === 取得工具鏈自身的目錄 ===
# 這確保無論從哪裡執行 cproject，都能找到 vcpkg 等工具資源
# 解析符號連結，找到腳本的真實目錄
TOOL_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# ==============================================================================
# === 核心功能函數 ===
# ==============================================================================

# 執行建置
# 參數:
# $1: Enable Tests ("true" or "false")
do_create() {
    local PROJECT_NAME=""
    local PROJECT_TYPE="executable"

    # 1. 解析參數
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

    local PROJECT_DIR="$(pwd)/${PROJECT_NAME}"

    if [ -d "${PROJECT_DIR}" ]; then
        echo "❌ 錯誤：目標資料夾 '${PROJECT_DIR}' 已經存在。" >&2
        exit 1
    fi

    echo "🛠  正在生成專案：${PROJECT_NAME}"
    echo "🔩 專案類型：${PROJECT_TYPE}"
    echo "📂 專案目錄：${PROJECT_DIR}"

    # 2. 建立目錄與原始碼檔案
    mkdir -p "${PROJECT_DIR}/src" "${PROJECT_DIR}/tests" "${PROJECT_DIR}/cmake"

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
TEST(LibraryTest, GetName) { EXPECT_EQ(get_lib_name(), "${PROJECT_NAME}"); }
EOF
    else
        echo "📝 創建主程式 (src/main.cpp)..."
        cat > "${PROJECT_DIR}/src/main.cpp" <<EOF
#include <iostream>
int main() { std::cout << "Hello, ${PROJECT_NAME}! 🌟" << std::endl; return 0; }
EOF
        cat > "${PROJECT_DIR}/tests/basic_test.cpp" <<EOF
#include <gtest/gtest.h>
TEST(BasicTest, AssertTrue) { EXPECT_TRUE(true); }
EOF
    fi

    # 3. 產生所有 CMake 與 vcpkg 設定檔
    echo "📝 正在產生 vcpkg.json..."
    local LOWERCASE_PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
    cat > "${PROJECT_DIR}/vcpkg.json" <<EOF
{
  "name": "${LOWERCASE_PROJECT_NAME}",
  "version-string": "1.0.0",
  "dependencies": [
    "gtest"
  ]
}
EOF

    echo "📝 正在產生 cmake/dependencies.cmake..."
    cat > "${PROJECT_DIR}/cmake/dependencies.cmake" <<EOF
# --- Cmake Dependency Management ---
find_package(GTest CONFIG REQUIRED)
find_package(Threads REQUIRED)
set(THIRD_PARTY_LIBS
  Threads::Threads
)
EOF

    echo "📝 正在產生 CMakePresets.json..."
    cat > "${PROJECT_DIR}/CMakePresets.json" <<EOF
{
  "version": 3,
  "configurePresets": [
    {
      "name": "default", "displayName": "Default Config", "description": "Default build with tests disabled.",
      "binaryDir": "\${sourceDir}/build/default",
      "cacheVariables": { "CMAKE_TOOLCHAIN_FILE": "\$env{CPROJECT_VCPKG_TOOLCHAIN}", "BUILD_TESTS": "OFF" }
    },
    {
      "name": "test", "displayName": "Test Config", "description": "Build with tests enabled.", "inherits": "default",
      "binaryDir": "\${sourceDir}/build/test",
      "cacheVariables": { "BUILD_TESTS": "ON" }
    }
  ],
  "buildPresets": [
    { "name": "default", "configurePreset": "default" }, { "name": "test", "configurePreset": "test" }
  ],
  "testPresets": [
    { "name": "default", "configurePreset": "test", "output": { "outputOnFailure": true } }
  ]
}
EOF

    echo "📝 正在產生主 CMakeLists.txt..."
    if [ "${PROJECT_TYPE}" == "library" ]; then
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
# 【已修正】移除 PROJECT_NAME 前的 '\'，讓 shell 替換變數
project(${PROJECT_NAME}
        VERSION 1.0.0
        LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(cmake/dependencies.cmake)
option(BUILD_TESTS "Build unit tests" ON)

if(BUILD_TESTS)
  enable_testing()
  include(GoogleTest)
endif()

# 【已修正】移除 PROJECT_NAME 和其他變數前的 '\'
add_library(${PROJECT_NAME} STATIC src/${PROJECT_NAME}.cpp)
target_include_directories(${PROJECT_NAME} PUBLIC \${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

if(BUILD_TESTS)
  add_executable(run_tests tests/basic_test.cpp)
  target_link_libraries(run_tests PRIVATE ${PROJECT_NAME} GTest::GTest GTest::Main)
  gtest_discover_tests(run_tests)
endif()
EOF
    else # executable
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
# 【已修正】移除 PROJECT_NAME 前的 '\'，讓 shell 替換變數
project(${PROJECT_NAME}
        VERSION 1.0.0
        LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(cmake/dependencies.cmake)
option(BUILD_TESTS "Build unit tests" ON)

if(BUILD_TESTS)
  enable_testing()
  include(GoogleTest)
endif()

# 【已修正】移除 PROJECT_NAME 和其他變數前的 '\'
add_executable(${PROJECT_NAME} src/main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

if(BUILD_TESTS)
  add_executable(run_tests tests/basic_test.cpp)
  target_link_libraries(run_tests PRIVATE GTest::GTest GTest::Main)
  gtest_discover_tests(run_tests)
endif()
EOF
    fi

    echo "🎉 專案 ${PROJECT_NAME} 已成功生成！"
    echo ""
    echo "下一步:"
    echo " cd ${PROJECT_NAME}"
    echo " cproject build"
}


do_build() {
    local enable_tests="$1"
    local preset_name="default"
    if [[ "${enable_tests}" == "true" ]]; then
        preset_name="test"
    fi

    local project_dir; project_dir="$(pwd)"
    local build_dir="${project_dir}/build/${preset_name}" # Build dir is defined by preset
    local cmake_file="${project_dir}/CMakeLists.txt"
    local vcpkg_toolchain_file="${TOOL_SCRIPT_DIR}/vcpkg/scripts/buildsystems/vcpkg.cmake"

    if [[ ! -f "${cmake_file}" || ! -f "${project_dir}/CMakePresets.json" ]]; then
        echo "❌ 錯誤：找不到 CMakeLists.txt 或 CMakePresets.json。" >&2
        exit 1
    fi

    # --- 透過環境變數傳遞工具鏈路徑給 Preset ---
    export CPROJECT_VCPKG_TOOLCHAIN="${vcpkg_toolchain_file}"

    if [ -d "${build_dir}" ]; then
        echo "🧹 正在移除舊的 build 目錄: ${build_dir}"
        rm -rf "${build_dir}"
    fi

    echo "⚙️  執行 CMake 配置 (Preset: ${preset_name})..."
    cmake --preset "${preset_name}"

    echo "🔨 編譯中 (Preset: ${preset_name})..."
    cmake --build --preset "${preset_name}"

    echo "✅ 建置完成！"

    local project_name
    project_name="$(grep -E '^[[:space:]]*project\(' "${cmake_file}" | head -n1 | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"
    copy_artifacts "${project_name}" "${project_dir}" "${build_dir}" "${project_dir}/bin" "${project_dir}/lib"
}

# 執行測試
do_test() {
    do_build "true"
    echo "🏃‍♂️ 執行 CTest (Preset: default)..."
    ctest --preset default
    echo "✅ 測試完成。"
}

# 執行主程式
do_run() {
    local project_dir
    project_dir="$(pwd)"
    local bin_dir="${project_dir}/bin"

    # --- 解析專案名稱 (重複解析以確保獨立性) ---
    local cmake_file="${project_dir}/CMakeLists.txt"
    if [[ ! -f "${cmake_file}" ]]; then
        echo "❌ 錯誤：找不到 CMakeLists.txt。" >&2
        exit 1
    fi
    local project_name
    project_name="$(grep -E '^[[:space:]]*project\(' "${cmake_file}" | head -n1 | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"

    # 首先，確保專案已建置
    do_build "false"

    local executable_path="${bin_dir}/${project_name}"

    if [[ ! -x "${executable_path}" ]]; then
        echo "❌ 錯誤：找不到可執行的檔案或專案是函式庫。" >&2
        echo "   預期路徑: ${executable_path}" >&2
        # 檢查是否為函式庫
        if [[ -d "${project_dir}/lib" ]]; then
            echo "ℹ️  偵測到 lib 目錄，專案 '${project_name}' 可能是一個函式庫，沒有主程式可執行。"
        fi
        exit 1
    fi

    echo "🚀 執行主程式..."
    echo "------------------------------------------"
    "${executable_path}"
    echo "------------------------------------------"
    echo "✅ 程式執行完畢。"
}


# 複製產出物 (函式庫或執行檔)
copy_artifacts() {
    local project_name="$1"
    local project_dir="$2"
    local build_dir="$3"
    local bin_dir="$4"
    local lib_dir="$5"

    echo "📦 正在處理建置產出..."

    # 清理舊的產出目錄
    rm -rf "${bin_dir}" "${lib_dir}"

    # 尋找執行檔
    local executable_path
    executable_path=$(find "${build_dir}" -maxdepth 2 -type f -name "${project_name}")

    # 尋找函式庫
    local lib_path
    lib_path=$(find "${build_dir}" -maxdepth 2 -type f \( -name "lib${project_name}.a" -o -name "lib${project_name}.so" -o -name "lib${project_name}.dylib" \))


    if [[ -n "${executable_path}" ]]; then
        echo " -> 找到執行檔，正在複製到 ${bin_dir}..."
        mkdir -p "${bin_dir}"
        cp "${executable_path}" "${bin_dir}/"
    elif [[ -n "${lib_path}" ]]; then
        echo " -> 找到函式庫，正在複製到 ${lib_dir}..."
        mkdir -p "${lib_dir}"
        find "${build_dir}" -maxdepth 2 -type f \( -name "lib${project_name}.a" -o -name "lib${project_name}.so" -o -name "lib${project_name}.dylib" \) -exec cp {} "${lib_dir}/" \;
        if [ -d "${project_dir}/include" ]; then
            echo " -> 正在複製公開標頭檔..."
            mkdir -p "${lib_dir}/include"
            rsync -a --delete "${project_dir}/include/" "${lib_dir}/include/"
        fi
    else
        echo "⚠️  警告：在 ${build_dir} 中找不到任何預期的執行檔或函式庫。"
        return 1
    fi

    echo "✅ 產出複製完成。"
}


# 新增依賴函數
do_add() {
    local lib_name="$1"

    # --- 前置檢查 ---
    if ! command -v jq &> /dev/null; then
        echo "❌ 錯誤：此功能需要 'jq' (一個命令列 JSON 處理器)。" >&2
        echo "   請先安裝 jq (例如: sudo apt-get install jq 或 brew install jq)。" >&2
        exit 1
    fi
    if [[ -z "$lib_name" ]]; then
        echo "❌ 錯誤：請提供要新增的函式庫名稱。" >&2
        echo "   用法: cproject add <lib-name>" >&2
        exit 1
    fi
    local vcpkg_file="vcpkg.json"
    local cmake_deps_file="cmake/dependencies.cmake"
    if [[ ! -f "${vcpkg_file}" || ! -f "${cmake_deps_file}" ]]; then
        echo "❌ 錯誤：找不到 vcpkg.json 或 cmake/dependencies.cmake。" >&2
        echo "   請確認您位於 cproject 專案的根目錄下。" >&2
        exit 1
    fi

    # --- 步驟 1: 更新 vcpkg.json (加入冪等性檢查) ---
    if jq -e ".dependencies[] | select(. == \"$lib_name\")" "${vcpkg_file}" > /dev/null; then
        echo "ℹ️  依賴 '${lib_name}' 已經存在於 ${vcpkg_file} 中，跳過。"
    else
        echo "📝 正在將 '${lib_name}' 加入到 ${vcpkg_file}..."
        jq --arg lib "$lib_name" '.dependencies |= . + [$lib] | .dependencies |= unique' "${vcpkg_file}" > "${vcpkg_file}.tmp" && mv "${vcpkg_file}.tmp" "${vcpkg_file}"
    fi

    # --- 步驟 2: 自動更新 cmake/dependencies.cmake (加入冪等性檢查) ---
    # 建立一個通用的 PackageName (例如 fmt -> Fmt, spdlog -> Spdlog)
    local capitalized_lib_name="$(tr '[:lower:]' '[:upper:]' <<< ${lib_name:0:1})${lib_name:1}"

    if grep -q "find_package(${capitalized_lib_name} " "${cmake_deps_file}"; then
        echo "ℹ️  '${capitalized_lib_name}' 看起來已經設定在 ${cmake_deps_file} 中，跳過。"
    else
        echo "📝 正在自動更新 ${cmake_deps_file}..."
        # 在檔案末尾追加設定
        echo "" >> "${cmake_deps_file}"
        echo "# Added by 'cproject add' for ${lib_name}" >> "${cmake_deps_file}"
        echo "find_package(${capitalized_lib_name} CONFIG REQUIRED)" >> "${cmake_deps_file}"
        # 這是基於 vcpkg 常見慣例的猜測，對於大多數函式庫有效
        echo "list(APPEND THIRD_PARTY_LIBS ${capitalized_lib_name}::${lib_name})" >> "${cmake_deps_file}"
    fi

    # --- 步驟 3: 顯示最終結果 ---
    echo ""
    echo "✅ 成功將依賴 '${lib_name}' 加入專案！"
    echo "   現在您可以執行 'cproject build' 來下載並連結該函式庫。"
    echo "💡 提示：自動產生的 CMake target 名稱為 '${capitalized_lib_name}::${lib_name}'。"
    echo "   如果此名稱不正確，請手動修改 '${cmake_deps_file}'。"
}


# ==============================================================================
# === 命令分派器 ===
# ==============================================================================

# --- 使用說明 ---
usage() {
    cat <<EOF
📘 cproject - 現代化的 C++ 專案管理器

用法:
  cproject <command> [options]

命令:
  create [--library] <ProjectName>
    ➤ 建立一個新的 C++ 專案。

  add <lib-name>
    ➤ 為當前專案新增一個 vcpkg 依賴。

  build
    ➤ 建置當前專案。

  run
    ➤ 建置並執行當前專案的主程式。

  test
    ➤ 為當前專案建置並執行所有測試。

範例:
  cproject create MyApp
  cproject add fmt
  cproject build
EOF
    exit 1
}

# --- 主邏輯 ---
if [[ $# -lt 1 ]]; then
    echo "⚠️  請提供一個命令。" >&2
    usage
fi

SUBCMD="$1"; shift

case "$SUBCMD" in
    create)
        do_create "$@"
        ;;
    add)
        do_add "$@"
        ;;
    build)
        do_build "false"
        ;;
    run)
        do_run
        ;;
    test)
        do_test
        ;;
    *)
        echo "❌ 未知命令: $SUBCMD" >&2
        usage
        ;;
esac