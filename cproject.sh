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
    if [[ ! -f "vcpkg.json" || ! -d "cmake" ]]; then
        echo "❌ 錯誤：找不到 vcpkg.json 或 cmake 目錄。" >&2
        echo "   請確認您位於 cproject 專案的根目錄下。" >&2
        exit 1
    fi

    # 1. 更新 vcpkg.json
    echo "📝 正在將 '${lib_name}' 加入到 vcpkg.json..."
    jq --arg lib "$lib_name" '.dependencies |= . + [$lib] | .dependencies |= unique' vcpkg.json > vcpkg.json.tmp && mv vcpkg.json.tmp vcpkg.json

    # 2. 提示使用者更新 cmake/dependencies.cmake
    echo "✅ 成功將依賴加入 vcpkg.json！"
    echo ""
    echo "--- 👉下一步：手動設定 CMake ---"
    echo "請編輯 'cmake/dependencies.cmake' 檔案，加入以下兩行："
    echo ""
    echo "   # 範例 (請根據函式庫文檔調整)"
    echo "   find_package(${lib_name^} CONFIG REQUIRED) # 將 ${lib_name} 首字母大寫"
    echo "   list(APPEND THIRD_PARTY_LIBS ${lib_name^}::${lib_name}) # 使用 vcpkg 提供的 target"
    echo ""
    echo "💡 提示：vcpkg 提供的 CMake target 名稱通常是 'PackageName::target' 格式。"
    echo "   完成後，執行 'cproject build' 來安裝並連結新的函式庫。"
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
        # create 命令邏輯不變，它呼叫外部腳本
        exec bash "${TOOL_SCRIPT_DIR}/create_project.sh" "$@"
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