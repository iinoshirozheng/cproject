#!/bin/bash
# 當任何指令出錯時，立即退出
set -e

# --- 路徑設定 ---
CPROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_VCPKG_SCRIPT="${CPROJECT_DIR}/setup_vcpkg.sh"
CPROJECT_EXECUTABLE="${CPROJECT_DIR}/cproject.sh"
BIN_DIR="${CPROJECT_DIR}/bin"
PUBLIC_CPROJECT_CMD="${BIN_DIR}/cproject"

echo "--- cproject 安裝程序 ---"

# 步驟一：確保主腳本有執行權限
echo "1. 正在設定 cproject 主腳本權限..."
chmod +x "${CPROJECT_EXECUTABLE}"
echo "✅ 主腳本權限設定完成。"
echo ""

# 步驟二：建立 bin 目錄並設定符號連結
echo "2. 正在建立公開指令..."
mkdir -p "${BIN_DIR}"
ln -sf "${CPROJECT_EXECUTABLE}" "${PUBLIC_CPROJECT_CMD}"
echo "✅ 指令 'cproject' 已設定於: ${PUBLIC_CPROJECT_CMD}"
echo ""

# 步驟三：執行 vcpkg 環境安裝與設定
echo "3. 正在執行 vcpkg 環境安裝與設定..."
if [[ "$SHELL" == *"/zsh" ]]; then
    zsh "${SETUP_VCPKG_SCRIPT}"
else
    bash "${SETUP_VCPKG_SCRIPT}"
fi
echo "✅ vcpkg 環境設定完成。"
echo ""

# 步驟四：【已修正】自動設定環境變數
echo "--- 👉 最後一步：設定環境變數 ---"
SHELL_PROFILE=""
if [[ "$SHELL" == *"/zsh" ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [[ "$SHELL" == *"/bash" ]]; then
    SHELL_PROFILE="$HOME/.bash_profile" # For macOS default bash
    if [[ ! -f "$SHELL_PROFILE" ]]; then # For Linux bash
        SHELL_PROFILE="$HOME/.bashrc"
    fi
else
    SHELL_PROFILE="$HOME/.profile"
fi

# 【已修正】定義正確的環境變數設定
# 使用單引號和雙引號組合，確保變數只在需要時展開，且路徑正確
CPROJECT_PATH_LINE="export PATH=\"${CPROJECT_DIR}/bin:\$PATH\""
VCPKG_ROOT_LINE="export VCPKG_ROOT=\"${CPROJECT_DIR}/vcpkg\""
VCPKG_PATH_LINE="export PATH=\"\$VCPKG_ROOT:\$PATH\""

if [[ -f "$SHELL_PROFILE" ]]; then
    # 檢查是否已存在 cproject 的設定
    if ! grep -q "# cproject Environment" "$SHELL_PROFILE"; then
        echo "為了能在任何地方使用 'cproject' 和 'vcpkg' 指令，需要將以下設定加入到您的 shell 設定檔中："
        echo ""
        echo "   檔案: ${SHELL_PROFILE}"
        echo "   -------------------------------------------------------"
        echo "   ${CPROJECT_PATH_LINE}"
        echo "   ${VCPKG_ROOT_LINE}"
        echo "   ${VCPKG_PATH_LINE}"
        echo "   -------------------------------------------------------"
        echo ""
        read -p "❓ 是否要自動為您設定? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            echo "✅ 正在為您自動設定..."
            echo "" >> "$SHELL_PROFILE"
            echo "# --- cproject Environment ---" >> "$SHELL_PROFILE"
            echo "${CPROJECT_PATH_LINE}" >> "$SHELL_PROFILE"
            echo "${VCPKG_ROOT_LINE}" >> "$SHELL_PROFILE"
            echo "${VCPKG_PATH_LINE}" >> "$SHELL_PROFILE"
            echo ""
            echo ""
            echo "設定完成！請重開一個新的終端機來讓設定生效。"
        else
            echo "好的，請手動將以上指令加入您的設定檔。"
        fi
    else
        echo "✅ 環境變數看起來已經設定過了。"
        echo "   如果您遇到問題，請手動檢查檔案: ${SHELL_PROFILE}"
    fi
else
    echo "⚠️ 找不到您的 shell 設定檔，請手動設定..."
fi
