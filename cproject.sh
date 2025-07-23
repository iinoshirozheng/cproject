#!/bin/bash
# 當任何指令出錯時，立即退出
set -e

# === 取得工具鏈自身的目錄 ===
# 這確保無論從哪裡執行 cproject，都能找到 vcpkg 等工具資源
# 解析符號連結，找到腳本的真實目錄
TOOL_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# --- 自動讀取專案本地的 .env 檔案 ---
if [ -f ".env" ]; then
    echo "ℹ 正在從 .env 檔案載入專案環境變數..."
    cat .env
    # set -a 讓後續 source 的所有變數都自動被 export
    set -a
    source .env
    set +a # 恢復預設行為
fi

# ==============================================================================
# === 核心功能函數 ===
# ==============================================================================

# 執行建置
# 參數:
# $1: Enable Tests ("true" or "false")
#【最終修正版 v2】專案建立函式
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

add_library(${PROJECT_NAME} STATIC src/${PROJECT_NAME}.cpp)
target_include_directories(${PROJECT_NAME} PUBLIC \${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

if(BUILD_TESTS)
  add_executable(run_tests tests/basic_test.cpp)
  # 【已修正】使用 vcpkg 提供的小寫 target 名稱
  target_link_libraries(run_tests PRIVATE ${PROJECT_NAME} GTest::gtest GTest::gtest_main)
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

if(BUILD_TESTS)
  enable_testing()
  include(GoogleTest)
endif()

add_executable(${PROJECT_NAME} src/main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE \${THIRD_PARTY_LIBS})

if(BUILD_TESTS)
  add_executable(run_tests tests/basic_test.cpp)
  # 【已修正】使用 vcpkg 提供的小寫 target 名稱
  target_link_libraries(run_tests PRIVATE GTest::gtest GTest::gtest_main)
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
#【整合版】執行測試函式，根據參數決定模式
do_test() {
    local is_ci_mode=false
    # 步驟 1: 解析傳入 do_test 的參數
    if [[ "$1" == "--detail" ]]; then
        is_ci_mode=true
    fi

    # 步驟 2: 無論何種模式，都先建置測試
    do_build "true"

    # 步驟 3: 根據模式執行不同的測試方法
    if [[ "$is_ci_mode" == "true" ]]; then
        # --- CI/CD 模式 ---
        echo "🤖 執行 CI/CD 測試 (Preset: default)..."
        
        # --output-on-failure: 只有在測試失敗時才顯示詳細日誌
        # --output-junit: 產生 Jenkins, GitHub Actions 等工具相容的報告
        ctest --preset default --output-on-failure --output-junit "ctest_results.xml"

        echo "✅ CI/CD 測試完成，報告已儲存至 ctest_results.xml"
    else
        # --- 開發者互動模式 ---
        local test_executable_path="./build/test/run_tests"

        if [ -f "${test_executable_path}" ]; then
            echo "🏃‍♂️ 直接執行 Google Test (${test_executable_path})..."
            echo "------------------------------------------"
            # 直接執行，此時 Google Test 會偵測到 TTY 並輸出顏色
            "${test_executable_path}"
            echo "------------------------------------------"
            echo "✅ 測試完成。"
        else
            echo "❌ 錯誤：找不到測試執行檔於 ${test_executable_path}" >&2
            exit 1
        fi
    fi
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

# --- pkg add ---
do_pkg_add() {
    local lib_name="$1"

    # --- 前置檢查 ---
    if ! command -v jq &> /dev/null; then echo "❌ 錯誤：此功能需要 'jq'。" >&2; exit 1; fi
    if ! command -v vcpkg &> /dev/null; then echo "❌ 錯誤：找不到 'vcpkg' 指令。" >&2; exit 1; fi
    if [[ -z "$lib_name" ]]; then echo "❌ 錯誤：請提供函式庫名稱。" >&2; echo "   用法: cproject pkg add <lib-name>" >&2; exit 1; fi
    local vcpkg_file="vcpkg.json"
    local cmake_deps_file="cmake/dependencies.cmake"
    if [[ ! -f "${vcpkg_file}" || ! -f "${cmake_deps_file}" ]]; then echo "❌ 錯誤：找不到設定檔，請確認位於專案根目錄下。" >&2; exit 1; fi

    # --- vcpkg search 驗證 ---
    echo "🔎 正在透過 vcpkg search 驗證函式庫 '${lib_name}'..."
    local search_result; search_result=$(vcpkg search "$lib_name")
    local exact_match; exact_match=$(echo "${search_result}" | grep -E "^${lib_name}[[:space:]]" | head -n 1)
    if [[ -z "$exact_match" ]]; then
        echo "❌ 錯誤：在 vcpkg 中找不到名為 '${lib_name}' 的函式庫。" >&2
        echo "   最接近的搜尋結果如下：" >&2; echo "${search_result}" >&2; exit 1;
    fi
    echo "✅ 找到相符的函式庫: ${exact_match}"

    # --- 更新 vcpkg.json ---
    if ! jq -e ".dependencies[] | select(. == \"$lib_name\")" "${vcpkg_file}" > /dev/null; then
        echo "📝 正在將 '${lib_name}' 加入到 ${vcpkg_file}..."
        jq --arg lib "$lib_name" '.dependencies |= . + [$lib] | .dependencies |= unique' "${vcpkg_file}" > "${vcpkg_file}.tmp" && mv "${vcpkg_file}.tmp" "${vcpkg_file}"
    fi

    # --- 執行 vcpkg install 並捕獲輸出 ---
    echo "📦 正在安裝依賴... (vcpkg install)"
    local install_output; install_output=$(vcpkg install | tee /dev/tty)

    # --- 解析 vcpkg 輸出以取得 CMake 用法 ---
    echo "⚙️  正在解析 CMake 用法..."
    local usage_block; usage_block=$(echo "${install_output}" | awk -v lib="${lib_name}" '/The package/ && $3==lib {p=1} p && /^$/ {p=0} p')
    local package_name; package_name=$(echo "${usage_block}" | grep "find_package" | sed -E 's/.*find_package\(([^ ]+).*/\1/')
    local link_targets; link_targets=$(echo "${usage_block}" | grep "target_link_libraries" | sed -E 's/.*(PRIVATE|PUBLIC|INTERFACE) //; s/\).*//')

    # --- 使用解析到的資訊更新 cmake/dependencies.cmake ---
    if [[ -n "$package_name" && -n "$link_targets" ]]; then
        if grep -q "find_package(${package_name} " "${cmake_deps_file}"; then
            echo "ℹ️  '${package_name}' 看起來已經設定在 ${cmake_deps_file} 中，跳過。"
        else
            echo "📝 正在使用精確的 target 自動更新 ${cmake_deps_file}..."
            echo "" >> "${cmake_deps_file}"
            echo "# Added by 'cproject pkg add' for ${lib_name}" >> "${cmake_deps_file}"
            echo "find_package(${package_name} CONFIG REQUIRED)" >> "${cmake_deps_file}"
            echo "list(APPEND THIRD_PARTY_LIBS ${link_targets})" >> "${cmake_deps_file}"
        fi
    else
        echo "⚠️ 警告：無法自動解析 '${lib_name}' 的 CMake 用法，您可能需要手動修改 ${cmake_deps_file}。"
    fi

    echo ""
    echo "✅ 成功新增並安裝依賴 '${lib_name}'！"
}

# --- pkg rm ---
do_pkg_rm() {
    local lib_name="$1"

    # --- 前置檢查 ---
    if ! command -v jq &> /dev/null; then echo "❌ 錯誤：此功能需要 'jq'。" >&2; exit 1; fi
    if [[ -z "$lib_name" ]]; then echo "❌ 錯誤：請提供函式庫名稱。" >&2; echo "   用法: cproject pkg rm <lib-name>" >&2; exit 1; fi
    local vcpkg_file="vcpkg.json"
    local cmake_deps_file="cmake/dependencies.cmake"
    if [[ ! -f "${vcpkg_file}" || ! -f "${cmake_deps_file}" ]]; then echo "❌ 錯誤：找不到設定檔，請確認位於專案根目錄下。" >&2; exit 1; fi

    # --- 步驟 1: 從 vcpkg.json 移除 ---
    if jq -e ".dependencies[] | select(. == \"$lib_name\")" "${vcpkg_file}" > /dev/null; then
        echo "📝 正在從 ${vcpkg_file} 中移除 '${lib_name}'..."
        jq "del(.dependencies[] | select(. == \"$lib_name\"))" "${vcpkg_file}" > "${vcpkg_file}.tmp" && mv "${vcpkg_file}.tmp" "${vcpkg_file}"
    else
        echo "ℹ️  依賴 '${lib_name}' 不存在於 ${vcpkg_file} 中，無需移除。"
    fi

    # --- 步驟 2: 從 cmake/dependencies.cmake 移除 ---
    # 這個邏輯的核心是尋找當初 add 指令留下的註解標記
    local anchor_comment="# Added by 'cproject pkg add' for ${lib_name}"
    
    # 先檢查標記是否存在
    if grep -qF "${anchor_comment}" "${cmake_deps_file}"; then
        echo "📝 正在從 ${cmake_deps_file} 中移除 '${lib_name}' 的 CMake 設定..."
        
        # 使用 sed 找到標記行(anchor)，並將其及後續兩行一併刪除
        # sed -i 在不同系統行為有差異，使用臨時檔案更為可靠安全
        sed "/${anchor_comment}/{N;N;d;}" "${cmake_deps_file}" > "${cmake_deps_file}.tmp" && mv "${cmake_deps_file}.tmp" "${cmake_deps_file}"
        
        # 移除可能留下的多餘空行，讓檔案更整潔
        sed -i.bak '/^$/N;/^\n$/D' "${cmake_deps_file}" && rm -f "${cmake_deps_file}.bak"

    else
        echo "ℹ️  在 ${cmake_deps_file} 中找不到 '${lib_name}' 對應的設定區塊，無需移除。"
    fi

    # --- 步驟 3: 提示使用者 ---
    echo ""
    echo "✅ 成功從設定檔中移除依賴 '${lib_name}'！"
    echo "   vcpkg 會在下次建置時自動清理不再需要的套件。"
    echo "   您可以執行 'cproject build' 來更新專案狀態。"
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
    # --- 專案生命週期指令 ---
    create)
        do_create "$@"
        ;;
    build)
        do_build "false"
        ;;
    run)
        do_run
        ;;
    test)
        do_test "$@"
        ;;

    # --- 【新增】套件管理的快捷指令 (Aliases) ---
    add)
        do_pkg_add "$@"
        ;;
    remove)
        do_pkg_rm "$@"
        ;;
    search)
        do_pkg_search "$@"
        ;;

    # --- 套件管理的完整指令 ---
    pkg)
        PKG_SUBCMD="$1"; shift
        case "$PKG_SUBCMD" in
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
                echo "❌ 未知的 pkg 子命令: '$PKG_SUBCMD'" >&2
                usage
                ;;
        esac
        ;;
        
    *)
        echo "❌ 未知命令: $SUBCMD" >&2
        usage
        ;;
esac