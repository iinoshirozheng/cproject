#!/usr/bin/env bash

# 當任何指令出錯時，立即退出
set -e

# === 取得工具鏈自身的目錄 ===
TOOL_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

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
#include <gmock/gmock.h>
#include "${PROJECT_NAME}/${PROJECT_NAME}.h"
TEST(LibraryTest, GetName) { EXPECT_EQ(get_lib_name(), "${PROJECT_NAME}"); }
TEST(MockTest, BasicMock) { EXPECT_TRUE(true); }
EOF
    else # executable
        echo "📝 創建主程式 (src/main.cpp)..."
        cat > "${PROJECT_DIR}/src/main.cpp" <<EOF
#include <iostream>
int main() { std::cout << "Hello, ${PROJECT_NAME}! 🌟" << std::endl; return 0; }
EOF
        cat > "${PROJECT_DIR}/tests/basic_test.cpp" <<EOF
#include <gtest/gtest.h>
#include <gmock/gmock.h>
TEST(BasicTest, AssertTrue) { EXPECT_TRUE(true); }
TEST(MockTest, BasicMock) { EXPECT_TRUE(true); }
EOF
    fi

    # 3. 產生所有 CMake 設定檔
    echo "📝 正在產生 cmake/dependencies.cmake..."
    cat > "${PROJECT_DIR}/cmake/dependencies.cmake" <<EOF
# --- Cmake Dependency Management ---
# Add your project-specific, non-test dependencies here.

find_package(Threads REQUIRED)
set(THIRD_PARTY_LIBS
  Threads::Threads
)
EOF

    echo "📝 正在產生 cmake/gtest.cmake..."
    cat > "${PROJECT_DIR}/cmake/gtest.cmake" <<EOF
# --- Google Test & Mock Framework Setup ---
find_package(GTest CONFIG REQUIRED)
enable_testing()
include(GoogleTest)
set(TEST_LIBS GTest::gtest GTest::gtest_main GTest::gmock GTest::gmock_main)
EOF

    echo "📝 正在產生主 CMakeLists.txt..."
    if [ "${PROJECT_TYPE}" == "library" ]; then
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(cmake/dependencies.cmake)
option(BUILD_TESTS "Build unit tests" ON)

add_library(${PROJECT_NAME} STATIC src/${PROJECT_NAME}.cpp)
target_include_directories(${PROJECT_NAME} PUBLIC \${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

if(BUILD_TESTS)
  include(cmake/gtest.cmake)
  add_executable(run_tests tests/basic_test.cpp)
  target_link_libraries(run_tests PRIVATE ${PROJECT_NAME} \${TEST_LIBS})
  gtest_discover_tests(run_tests)
endif()
EOF
    else # executable
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.18)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(cmake/dependencies.cmake)
option(BUILD_TESTS "Build unit tests" ON)

add_executable(${PROJECT_NAME} src/main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

if(BUILD_TESTS)
  include(cmake/gtest.cmake)
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
    echo " cproject add gtest  # 安裝 GTest 和 GMock 框架"
    echo " cproject build"
}

do_build() {
    local build_config="$1"
    [[ -z "$build_config" ]] && build_config="release"

    local project_dir; project_dir="$(pwd)"
    local build_dir="${project_dir}/build/${build_config}"
    local cmake_file="${project_dir}/CMakeLists.txt"
    local vcpkg_toolchain_file="${TOOL_SCRIPT_DIR}/vcpkg/scripts/buildsystems/vcpkg.cmake"

    if [[ ! -f "${cmake_file}" ]]; then
        echo "❌ 錯誤：找不到 CMakeLists.txt。" >&2; exit 1
    fi

    local cmake_args=()
    cmake_args+=("-DCMAKE_TOOLCHAIN_FILE=${vcpkg_toolchain_file}")

    if [[ "$build_config" == "test" ]]; then
        cmake_args+=("-DCMAKE_BUILD_TYPE=Debug")
        cmake_args+=("-DBUILD_TESTS=ON")
    elif [[ "$build_config" == "debug" ]]; then
        cmake_args+=("-DCMAKE_BUILD_TYPE=Debug")
        cmake_args+=("-DBUILD_TESTS=OFF")
    else # release
        cmake_args+=("-DCMAKE_BUILD_TYPE=Release")
        cmake_args+=("-DBUILD_TESTS=OFF")
    fi

    if [ ! -d "${build_dir}" ]; then mkdir -p "${build_dir}"; fi

    echo "⚙️  執行 CMake 配置 (組態: ${build_config})..."
    cmake -S . -B "${build_dir}" "${cmake_args[@]}"

    # 【已修改】自動偵測核心數並行建置
    local core_count=2 # Fallback
    if [[ "$(uname)" == "Linux" ]]; then
        core_count=$(nproc)
    elif [[ "$(uname)" == "Darwin" ]]; then
        core_count=$(sysctl -n hw.ncpu)
    fi

    echo "🔨 編譯中 (組態: ${build_config}, 使用 ${core_count} 個核心)..."
    cmake --build "${build_dir}" -- -j"${core_count}"

    echo "✅ 建置完成！"

    local project_name
    project_name="$(grep -E '^[[:space:]]*project\(' "${cmake_file}" | head -n1 | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"
    copy_artifacts "${project_name}" "${project_dir}" "${build_dir}" "${project_dir}/lib"
}

do_test() {
    do_build "test"

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
}

#【已修改】合併 do_run 與 do_run_debug
do_run() {
    local build_config="$1"
    if [[ -z "$build_config" ]]; then
        build_config="release"
    fi

    do_build "$build_config"

    local project_dir
    project_dir="$(pwd)"
    local project_name
    project_name="$(grep -E '^[[:space:]]*project\(' "${project_dir}/CMakeLists.txt" | head -n1 | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"
    
    local executable_path="${project_dir}/build/${build_config}/${project_name}"

    if [[ ! -x "${executable_path}" ]]; then
        echo "❌ 錯誤：找不到可執行的檔案或專案是函式庫。" >&2
        echo "   預期路徑: ${executable_path}" >&2
        exit 1
    fi

    echo "🚀 執行主程式 (${build_config} 組態)..."
    echo "------------------------------------------"
    "${executable_path}"
    echo "------------------------------------------"
    echo "✅ 程式執行完畢。"
}

copy_artifacts() {
    local project_name="$1"
    local project_dir="$2"
    local build_dir="$3"
    local lib_dir="$4"

    local lib_candidates=()
    while IFS= read -r -d '' f; do
        case "$f" in */CMakeFiles/*|*/tests/*|*/test/*) continue ;; esac
        lib_candidates+=("$f")
    done < <(find "${build_dir}" -type f \( -name "lib${project_name}.a" -o -name "lib${project_name}.so" -o -name "lib${project_name}.dylib" -o -name "${project_name}.lib" \) -print0)

    if (( ${#lib_candidates[@]} > 0 )); then
        echo "📦 正在處理函式庫產出..."
        rm -rf "${lib_dir}"
        mkdir -p "${lib_dir}"
        for f in "${lib_candidates[@]}"; do rsync -a "$f" "${lib_dir}/"; done
        if [[ -d "${project_dir}/include" ]]; then
            rsync -a --delete "${project_dir}/include/" "${lib_dir}/include/"
        fi
        echo "✅ 函式庫複製完成。"
    else
        : # Do nothing
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

    if ! command -v vcpkg &> /dev/null; then echo "❌ 錯誤：找不到 'vcpkg' 指令。" >&2; exit 1; fi
    if [[ -z "$lib_name" ]]; then
        echo "❌ 錯誤：請提供函式庫名稱。" >&2
        echo "   用法: cproject pkg add <lib-name>" >&2
        exit 1
    fi
    local cmake_deps_file="cmake/dependencies.cmake"
    if [[ ! -f "$cmake_deps_file" ]]; then echo "❌ 錯誤：找不到 cmake/dependencies.cmake" >&2; exit 1; fi

    if [[ "$lib_name" == "gtest" ]]; then
        echo "📦 正在安裝預設的測試框架 gtest 與 gmock..."
        vcpkg install gtest gmock
        echo "✅ gtest 與 gmock 已安裝。"
        return 0
    fi

    if grep -q "# === ${lib_name} START ===" "${cmake_deps_file}"; then
        echo "ℹ️  套件 '${lib_name}' 的設定已存在於 ${cmake_deps_file} 中。"
        return 0
    fi

    echo "📦 正在安裝 '${lib_name}' 到 vcpkg..."
    vcpkg install "$lib_name"

    echo "⚙️ 正在解析 CMake 用法..."
    local find_package_line=""
    local link_targets=""

    if ! command -v jq &> /dev/null; then echo "⚠️  警告：建議安裝 'jq' 以獲得更精準的 CMake 設定。"; fi
    
    if pkg_info_json="$(vcpkg x-package-info "$lib_name" --x-json 2>/dev/null)"; then
        find_package_line="$(printf "%s" "$pkg_info_json" | jq -r '.usage.cmake.find_package // empty')"
        link_targets="$(printf "%s" "$pkg_info_json" | jq -r '[.usage.cmake.targets[]?] | join(" ")')"
    fi

    if [[ -z "$find_package_line" || -z "$link_targets" ]]; then
        local cmake_pkg; cmake_pkg="$(printf "%s" "$lib_name" | tr '-' '_')"
        find_package_line="find_package(${cmake_pkg} CONFIG REQUIRED)"
        link_targets="${cmake_pkg}::${cmake_pkg}"
        echo "ℹ️ vcpkg x-package-info 不可用或回傳空，已套用 fallback。"
    fi
    
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
    
    if [[ -z "$lib_name" ]]; then echo "❌ 錯誤：請提供函式庫名稱。" >&2; echo "   用法: cproject pkg rm <lib-name>" >&2; exit 1; fi
    local cmake_deps_file="cmake/dependencies.cmake"
    if [[ ! -f "${cmake_deps_file}" ]]; then echo "❌ 錯誤：找不到 cmake/dependencies.cmake" >&2; exit 1; fi
    
    if [[ "$lib_name" == "gtest" || "$lib_name" == "gmock" ]]; then
        echo "⚠️  gtest/gmock 是專案基礎依賴，不建議移除。若要移除，請手動修改 cmake/gtest.cmake。"
        return 1
    fi

    echo "🗑️  正在從 vcpkg 中移除 '${lib_name}'..."
    vcpkg remove --purge "$lib_name"

    if grep -q "# === ${lib_name} START ===" "${cmake_deps_file}"; then
        echo "📝 正在從 ${cmake_deps_file} 中移除 '${lib_name}' 的設定..."
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
#【已修改】更新 usage 說明
usage() {
    cat <<EOF
📘 cproject - 現代化的 C++ 專案管理器

用法:
  cproject <command> [options]

命令:
  專案生命週期
    create [--library] <ProjectName>
      ➤ 建立一個新的 C++ 專案。
    build [-r|--release] [-d|--debug]
      ➤ 建置專案 (預設: release)。
    run [-r|--release] [-d|--debug]
      ➤ 建置並執行專案 (預設: release)。
    test
      ➤ 建置並執行單元測試 (debug 組態)。

  套件管理
    add <lib-name>
      ➤ 新增並安裝一個套件。
    remove <lib-name>
      ➤ 移除一個套件。
    search <lib-name>
      ➤ 搜尋套件。

範例:
  cproject create MyApp
  cd MyApp
  cproject add gtest
  cproject test
  cproject run --debug
EOF
    exit 1
}

#【已修改】重構指令分派器以支援參數
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
    
    build)
        build_config="release" # Default
        while [[ "$#" -gt 0 ]]; do
            case $1 in
                -d|--debug) build_config="debug"; shift ;;
                -r|--release) build_config="release"; shift ;;
                *) echo "❌ build 的未知參數: $1" >&2; usage; exit 1 ;;
            esac
        done
        do_build "$build_config"
        ;;

    run)
        build_config="release" # Default
        while [[ "$#" -gt 0 ]]; do
            case $1 in
                -d|--debug) build_config="debug"; shift ;;
                -r|--release) build_config="release"; shift ;;
                *) echo "❌ run 的未知參數: $1" >&2; usage; exit 1 ;;
            esac
        done
        do_run "$build_config"
        ;;

    test)
        do_test
        ;;
    
    add)
        do_pkg_add "$@"
        ;;
    remove)
        do_pkg_rm "$@"
        ;;
    search)
        do_pkg_search "$@"
        ;;
    
    *)
        echo "❌ 未知命令: $SUBCMD" >&2
        usage
        ;;
esac