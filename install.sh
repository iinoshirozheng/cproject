#!/bin/bash

# 當任何指令出錯時，立即退出
set -e

# --- 路徑設定 ---
# 取得此腳本所在的目錄，也就是 cppackage 的根目錄
CPPROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_VCPKG_SCRIPT="${CPPROJECT_DIR}/setup_vcpkg.sh"
SETUP_SCRIPT_PATH="${CPPROJECT_DIR}/setup.sh"


# --- [新增] 步驟一：確保 vcpkg 環境已就緒 ---
echo "--- 正在執行 vcpkg 環境安裝與設定... ---"
bash "${SETUP_VCPKG_SCRIPT}"
echo "--- vcpkg 環境設定完成 ---"
echo "" # 增加空行，讓輸出更美觀


# --- 步驟二：偵測 Shell 設定檔 ---
SHELL_PROFILE=""
# $SHELL 環境變數通常會指向使用者預設 shell 的路徑 (例如 /bin/zsh)
if [[ "$SHELL" == *"/zsh" ]]; then
    SHELL_PROFILE="$HOME/.zprofile"
elif [[ "$SHELL" == *"/bash" ]]; then
    SHELL_PROFILE="$HOME/.bash_profile"
else
    # 對於其他 shell 或無法確定的情況，使用通用的 .profile
    SHELL_PROFILE="$HOME/.profile"
fi

echo "🔎 正在檢查您的 Shell 設定檔: ${SHELL_PROFILE}"

# --- 步驟三：準備要加入的指令 ---
# 使用雙引號確保路徑中的空格等被正確處理
SOURCE_COMMAND="source \"${SETUP_SCRIPT_PATH}\""

# --- 步驟四：檢查是否已設定，若無才加入 ---
# grep -q: 安靜模式，不輸出結果
# grep -F: 將搜尋內容視為固定字串，而不是正則表達式
# grep -x: 精確匹配整行
if grep -qFx -- "${SOURCE_COMMAND}" "${SHELL_PROFILE}" &> /dev/null; then
    echo "✅ 設定指令已存在於 ${SHELL_PROFILE} 中，無需任何操作。"
else
    echo "🔧 正在將 cproject 環境設定指令加入到 ${SHELL_PROFILE}..."
    # 為了美觀，先加入一個空行和註解
    echo "" >> "${SHELL_PROFILE}"
    echo "# Added by cproject installer to setup environment" >> "${SHELL_PROFILE}"
    echo "${SOURCE_COMMAND}" >> "${SHELL_PROFILE}"
    
    echo "✅ 成功加入設定！"
    echo ""
    echo "💡 請執行以下指令，或重開您的終端機，來讓設定立即生效："
    echo "   source ${SHELL_PROFILE}"

    # 顯示成功訊息，讓使用者知道環境已設定
    echo "   VCPKG_ROOT: ${VCPKG_ROOT}"
    echo "   PATH:       cproject 工具路徑已加入"
    echo "   Alias:      現在您可以在任何地方使用 'cproject' 指令了。"
fi