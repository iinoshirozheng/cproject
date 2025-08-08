#!/usr/bin/env bash

# 當任何指令出錯時，立即退出
set -e

# === 取得工具鏈自身的目錄 ===
TOOL_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# --- 自動讀取專案本地的 .env 檔案 ---
if [ -f ".env" ]; then
    echo "ℹ 正在從 .env 檔案載入專案環境變數..."
    cat .env
    set -a
    source .env
    set +a
fi

# ==============================================================================
# === 核心功能函數 ===
# ==============================================================================

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
    else # executable
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

    # 3. 產生所有 CMake 與設定檔
    echo "📝 正在產生 cmake/dependencies.cmake..."
    cat > "${PROJECT_DIR}/cmake/dependencies.cmake" <<EOF
# --- Cmake Dependency Management ---

# --- 通用函式庫 ---
find_package(Threads REQUIRED)
set(THIRD_PARTY_LIBS
  Threads::Threads
)

# --- 測試專用函式庫 ---
find_package(GTest CONFIG REQUIRED)
set(TEST_LIBS
  GTest::gtest
  GTest::gtest_main
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
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "\$env{CPROJECT_VCPKG_TOOLCHAIN}",
        "BUILD_TESTS": "OFF"
      }
    },
    {
      "name": "test", "displayName": "Test Config", "description": "Build with tests enabled.", "inherits": "default",
      "binaryDir": "\${sourceDir}/build/test",
      "cacheVariables": { "BUILD_TESTS": "ON" }
    },
    {
      "name": "debug", "displayName": "Debug Config", "description": "Debug build.", "inherits": "default",
      "binaryDir": "\${sourceDir}/build/debug",
      "cacheVariables": { "CMAKE_BUILD_TYPE": "Debug" }
    },
    {
      "name": "release", "displayName": "Release Config", "description": "Release build.", "inherits": "default",
      "binaryDir": "\${sourceDir}/build/release",
      "cacheVariables": { "CMAKE_BUILD_TYPE": "Release" }
    }
  ],
    "buildPresets": [
      { "name": "default", "configurePreset": "default" },
      { "name": "test", "configurePreset": "test" },
      { "name": "debug", "configurePreset": "debug" },
      { "name": "release", "configurePreset": "release" }
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
project(${PROJECT_NAME}
        VERSION 1.0.0
        LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(cmake/dependencies.cmake)
option(BUILD_TESTS "Build unit tests" ON)

# 主函式庫設定
add_library(${PROJECT_NAME} STATIC src/${PROJECT_NAME}.cpp)
target_include_directories(${PROJECT_NAME} PUBLIC \${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

# 測試相關設定
if(BUILD_TESTS)
  enable_testing()
  include(GoogleTest)

  add_executable(run_tests tests/basic_test.cpp)
  target_link_libraries(run_tests PRIVATE ${PROJECT_NAME} \${TEST_LIBS})
  gtest_discover_tests(run_tests)
endif()
EOF
    else # executable
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
project(${PROJECT_NAME}
        VERSION 1.0.0
        LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(cmake/dependencies.cmake)
option(BUILD_TESTS "Build unit tests" ON)

# 主程式設定
add_executable(${PROJECT_NAME} src/main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

# 測試相關設定
if(BUILD_TESTS)
  enable_testing()
  include(GoogleTest)

  add_executable(run_tests tests/basic_test.cpp)
  target_link_libraries(run_tests PRIVATE \${TEST_LIBS})
  gtest_discover_tests(run_tests)
endif()
EOF
    fi

    echo "🎉 專案 ${PROJECT_NAME} 已成功生成！"
    echo ""
    echo "下一步:"
    echo " cd ${PROJECT_NAME}"
    echo " cproject add gtest  # 首次使用需安裝預設的測試框架"
    echo " cproject build"
}


do_build() {
    local enable_tests="$1"
    local preset_name="default"
    if [[ "${enable_tests}" == "true" ]]; then
        preset_name="test"
    fi

    local project_dir; project_dir="$(pwd)"
    local build_dir="${project_dir}/build/${preset_name}"
    local cmake_file="${project_dir}/CMakeLists.txt"
    local vcpkg_toolchain_file="${TOOL_SCRIPT_DIR}/vcpkg/scripts/buildsystems/vcpkg.cmake"

    if [[ ! -f "${cmake_file}" || ! -f "${project_dir}/CMakePresets.json" ]]; then
        echo "❌ 錯誤：找不到 CMakeLists.txt 或 CMakePresets.json。" >&2
        exit 1
    fi

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
    # 【已修改】執行函式庫複製 (執行檔不會被複製)
    copy_artifacts "${project_name}" "${project_dir}" "${build_dir}" "${project_dir}/lib"
}

do_test() {
    local is_ci_mode=false
    if [[ "$1" == "--detail" ]]; then
        is_ci_mode=true
    fi

    do_build "true"

    if [[ "$is_ci_mode" == "true" ]]; then
        echo "🤖 執行 CI/CD 測試 (Preset: test)..."
        ctest --preset test --output-on-failure --output-junit "ctest_results.xml"
        echo "✅ CI/CD 測試完成，報告已儲存至 ctest_results.xml"
    else
        local test_executable_path="./build/test/run_tests"
        if [ -f "${test_executable_path}" ]; then
            echo "🏃‍♂️ 直接執行 Google Test (${test_executable_path})..."
            echo "------------------------------------------"
            "${test_executable_path}"
            echo "------------------------------------------"
            echo "✅ 測試完成。"
        else
            echo "❌ 錯誤：找不到測試執行檔於 ${test_executable_path}" >&2
            exit 1
        fi
    fi
}

#【已修改】直接從 build 目錄執行
do_run() {
    local project_dir
    project_dir="$(pwd)"

    local cmake_file="${project_dir}/CMakeLists.txt"
    if [[ ! -f "${cmake_file}" ]]; then
        echo "❌ 錯誤：找不到 CMakeLists.txt。" >&2
        exit 1
    fi
    local project_name
    project_name="$(grep -E '^[[:space:]]*project\(' "${cmake_file}" | head -n1 | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"

    # 步驟 1: 確保專案已建置
    do_build "false"

    # 步驟 2: 直接從預設的 build 目錄尋找執行檔
    local executable_path="${project_dir}/build/default/${project_name}"

    if [[ ! -x "${executable_path}" ]]; then
        echo "❌ 錯誤：找不到可執行的檔案或專案是函式庫。" >&2
        echo "   預期路徑: ${executable_path}" >&2
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

#【已修改】只複製函式庫，不複製執行檔
copy_artifacts() {
    local project_name="$1"
    local project_dir="$2"
    local build_dir="$3"
    local lib_dir="$4"

    # --- 只處理函式庫 ---
    local lib_candidates=()
    while IFS= read -r -d '' f; do
        case "$f" in
            */CMakeFiles/*|*/tests/*|*/test/*|*/examples/*|*/example/*|*/bench*/*) continue ;;
        esac
        lib_candidates+=("$f")
    done < <(find "${build_dir}" -type f \( -name "lib${project_name}.a" -o -name "lib${project_name}.so" -o -name "lib${project_name}.dylib" -o -name "${project_name}.lib" \) -print0)

    if (( ${#lib_candidates[@]} > 0 )); then
        echo "📦 正在處理函式庫產出..."
        rm -rf "${lib_dir}"
        mkdir -p "${lib_dir}"
        for f in "${lib_candidates[@]}"; do
            rsync -a "$f" "${lib_dir}/"
        done
        # 若有對外頭檔，順手帶上
        if [[ -d "${project_dir}/include" ]]; then
            rsync -a --delete "${project_dir}/include/" "${lib_dir}/include/"
        fi
        echo "✅ 函式庫複製完成。"
    else
        echo "ℹ️ 在 ${build_dir} 中找不到函式庫產出，跳過複製步驟。"
    fi
}


do_pkg_search() {
    local lib_name="$1"
    if [[ -z "$lib_name" ]]; then
        echo "❌ 錯誤：請提供要搜尋的函式庫名稱。" >&2
        echo "   用法: cproject pkg search <lib-name>" >&2
        exit 1
    fi
    echo "🔎 正在透過 vcpkg search 搜尋 '${lib_name}'..."
    vcpkg search "$lib_name"
}

do_pkg_add() {
    local lib_name="$1"

    # --- 前置檢查 ---
    if ! command -v vcpkg &> /dev/null; then echo "❌ 錯誤：找不到 'vcpkg' 指令。" >&2; exit 1; fi
    if [[ -z "$lib_name" ]]; then
        echo "❌ 錯誤：請提供函式庫名稱。" >&2
        echo "   用法: cproject pkg add <lib-name>" >&2
        exit 1
    fi
    local cmake_deps_file="cmake/dependencies.cmake"
    if [[ ! -f "$cmake_deps_file" ]]; then echo "❌ 錯誤：找不到 cmake/dependencies.cmake" >&2; exit 1; fi

    # GTest 是特殊情況，由範本預設管理
    if [[ "$lib_name" == "gtest" ]]; then
        echo "ℹ️  正在安裝預設的測試函式庫 gtest..."
        vcpkg install "gtest" # 確保它被安裝
        echo "✅ gtest 已安裝。"
        return 0
    fi

    # 檢查是否已存在
    if grep -q "# === ${lib_name} START ===" "${cmake_deps_file}"; then
        echo "ℹ️  套件 '${lib_name}' 的設定已存在於 ${cmake_deps_file} 中。"
        return 0
    fi

    # --- 步驟 1: 安裝套件 ---
    echo "📦 正在安裝 '${lib_name}' 到 vcpkg..."
    vcpkg install "$lib_name"

    # --- 步驟 2: 解析 CMake 用法 ---
    echo "⚙️ 正在解析 CMake 用法..."
    local find_package_line=""
    local link_targets=""

    if ! command -v jq &> /dev/null; then echo "⚠️  警告：建議安裝 'jq' 以獲得更精準的 CMake 設定。"; fi
    
    if pkg_info_json="$(vcpkg x-package-info "$lib_name" --x-json 2>/dev/null)"; then
        find_package_line="$(printf "%s" "$pkg_info_json" | jq -r '.usage.cmake.find_package // empty')"
        link_targets="$(printf "%s" "$pkg_info_json" | jq -r '[.usage.cmake.targets[]?] | join(" ")')"
    fi

    # --- Fallback 邏輯 ---
    if [[ -z "$find_package_line" || -z "$link_targets" ]]; then
        local cmake_pkg; cmake_pkg="$(printf "%s" "$lib_name" | tr '-' '_')"
        find_package_line="find_package(${cmake_pkg} CONFIG REQUIRED)"
        link_targets="${cmake_pkg}::${cmake_pkg}"
        echo "ℹ️ vcpkg x-package-info 不可用或回傳空，已套用 fallback。"
    fi
    
    # --- 步驟 3: 將設定區塊附加到檔案末尾 ---
    echo "📝 正在更新 ${cmake_deps_file}..."
    {
        echo ""
        echo "# === ${lib_name} START ==="
        echo "${find_package_line}"
        echo "list(APPEND THIRD_PARTY_LIBS ${link_targets})"
        echo "# === ${lib_name} END ==="
    } >> "${cmake_deps_file}"

    echo "✅ 成功新增套件 '${lib_name}'！"
}

do_pkg_rm() {
    local lib_name="$1"
    
    # --- 前置檢查 ---
    if [[ -z "$lib_name" ]]; then echo "❌ 錯誤：請提供函式庫名稱。" >&2; echo "   用法: cproject pkg rm <lib-name>" >&2; exit 1; fi
    local cmake_deps_file="cmake/dependencies.cmake"
    if [[ ! -f "${cmake_deps_file}" ]]; then echo "❌ 錯誤：找不到 cmake/dependencies.cmake" >&2; exit 1; fi
    
    # GTest 是特殊情況，不建議移除
    if [[ "$lib_name" == "gtest" ]]; then
        echo "⚠️  gtest 是專案基礎依賴，不建議移除。"
        return 1
    fi

    # --- 步驟 1: 從 vcpkg 移除 ---
    echo "🗑️  正在從 vcpkg 中移除 '${lib_name}'..."
    vcpkg remove --purge "$lib_name"

    # --- 步驟 2: 從 cmake/dependencies.cmake 移除設定區塊 ---
    if grep -q "# === ${lib_name} START ===" "${cmake_deps_file}"; then
        echo "📝 正在從 ${cmake_deps_file} 中移除 '${lib_name}' 的設定..."
        # 使用可移植的 sed 語法，刪除 START 和 END 註解之間的所有行 (包含註解本身)
        sed -i.bak "/# === ${lib_name} START ===/,/# === ${lib_name} END ===/d" "${cmake_deps_file}"
        rm -f "${cmake_deps_file}.bak"
    else
        echo "ℹ️ 在 ${cmake_deps_file} 中找不到 '${lib_name}' 的設定區塊。"
    fi

    echo "✅ 成功移除依賴 '${lib_name}'！"
}


# ==============================================================================
# === 命令分派器 ===
# ==============================================================================
usage() {
    cat <<EOF
📘 cproject - 現代化的 C++ 專案管理器 (Classic 模式)

用法:
  cproject <command> [options]

命令:
  常用指令
    create [--library] <ProjectName>
      ➤ 建立一個新的 C++ 專案。
    build
      ➤ 建置當前專案。
    run
      ➤ 建置並執行當前專案的主程式。
    test [--detail]
      ➤ 執行測試 (使用 --detail 以 Ctest 模式執行)。

  套件管理
    add <lib-name>
      ➤ (推薦) 新增並安裝一個套件。
    remove <lib-name>
      ➤ 移除一個套件。
    search <lib-name>
      ➤ 搜尋套件。
    pkg <add|remove|search>
      ➤ (完整指令) 執行套件管理子命令。

範例:
  cproject create MyApp
  cd MyApp
  cproject add gtest
  cproject build
  cproject run
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
    create) do_create "$@";;
    build) do_build "false";;
    run) do_run;;
    test) do_test "$@";;
    add) do_pkg_add "$@";;
    remove) do_pkg_rm "$@";;
    search) do_pkg_search "$@";;
    pkg)
        PKG_SUBCMD="$1"; shift
        case "$PKG_SUBCMD" in
            add) do_pkg_add "$@";;
            remove) do_pkg_rm "$@";;
            search) do_pkg_search "$@";;
            *) echo "❌ 未知的 pkg 子命令: '$PKG_SUBCMD'" >&2; usage;;
        esac
        ;;
    *) echo "❌ 未知命令: $SUBCMD" >&2; usage;;
esac