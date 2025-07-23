#!/bin/bash
# 當任何指令出錯時，立即退出
set -e

# --- 腳本設定 ---
VCPKG_REPO_URL="https://github.com/microsoft/vcpkg.git"

# --- 路徑與變數設定 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VCPKG_DIR="${SCRIPT_DIR}/vcpkg"
VCPKG_EXECUTABLE="${VCPKG_DIR}/vcpkg"
PERFORM_UPDATE=false

# --- 函式：顯示用法 ---
usage() {
    echo "用法: $0 [--update]"
    echo "  --update   更新 vcpkg 到其遠端分支的最新版本。"
    exit 1
}

# --- 函式：主邏輯 ---
main() {
    if ! command -v git &> /dev/null; then
        echo "❌ 錯誤: 此腳本需要 git，請先安裝 git。"
        exit 1
    fi

    if [ -f "${SCRIPT_DIR}/.gitmodules" ] && grep -q "path = vcpkg" "${SCRIPT_DIR}/.gitmodules"; then
        echo "✅ vcpkg 已作為 git submodule 存在。"
        if [ "$PERFORM_UPDATE" = true ]; then
            echo "🔄 收到 --update 參數，正在更新 submodule 至遠端最新版本..."
            git submodule update --init --recursive --remote "${VCPKG_DIR}"
        else
            echo "🔄 正在根據父專案紀錄的版本來初始化/更新 submodule..."
            git submodule update --init --recursive "${VCPKG_DIR}"
        fi
    elif [ ! -d "${VCPKG_DIR}" ]; then
        echo "🔧 vcpkg 不存在 (且非 submodule)，正在從 GitHub clone 最新版本..."
        git clone "${VCPKG_REPO_URL}" "${VCPKG_DIR}"
    else
        if [ "$PERFORM_UPDATE" = true ]; then
            echo "🔄 vcpkg 目錄已存在，收到 --update 參數，正在拉取最新版本..."
            (cd "${VCPKG_DIR}" && git pull)
        else
            echo "✅ vcpkg 目錄已存在，跳過更新。(可使用 --update 參數來拉取最新版)"
        fi
    fi

    if [ ! -x "${VCPKG_EXECUTABLE}" ]; then
        echo "🚀 vcpkg 尚未設定，正在進行首次設定 (bootstrap)..."
        (cd "${VCPKG_DIR}" && ./bootstrap-vcpkg.sh -disableMetrics)
    else
        echo "✅ vcpkg 已完成首次設定。"
    fi

    echo "🎉 vcpkg 環境已準備就緒！"

}


# --- 參數解析 ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --update)
            PERFORM_UPDATE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "❌ 未知參數: $1"
            usage
            ;;
    esac
done

# --- 執行主函式 ---
main