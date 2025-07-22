#!/bin/bash

# 當任何指令出錯時，立即退出
set -e

# --- 路徑設定 ---
# 取得此腳本所在的目錄，也就是 cproject 工具的根目錄
CPPROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_VCPKG_SCRIPT="${CPPROJECT_DIR}/setup_vcpkg.sh"
CPROJECT_EXECUTABLE="${CPPROJECT_DIR}/cproject.sh"

echo "--- cproject 安裝程序 ---"

# 步驟一：確保主腳本有執行權限
echo "1. 正在設定 cproject 主腳本權限..."
chmod +x "${CPROJECT_EXECUTABLE}"
echo "✅ 主腳本權限設定完成。"
echo ""

# 步驟二：執行 vcpkg 環境安裝與設定
echo "2. 正在執行 vcpkg 環境安裝與設定..."
# 根據 shell 類型執行 setup_vcpkg.sh
if [[ "$SHELL" == *"/zsh" ]]; then
    zsh "${SETUP_VCPKG_SCRIPT}"
else
    bash "${SETUP_VCPKG_SCRIPT}"
fi
echo "✅ vcpkg 環境設定完成。"
echo ""


# 步驟三：顯示手動設定 PATH 的指引
echo "--- 👉 最後一步：手動設定環境變數 ---"
echo "為了能在任何地方使用 'cproject' 指令，請將下列指令"
echo "複製並貼到您的 shell 設定檔中 (例如 ~/.zshrc, ~/.bash_profile 或 ~/.profile)："
echo ""
echo -e "\033[0;32m# --- cproject Environment ---"
echo -e "export CPROJECT_HOME=\"${CPPROJECT_DIR}\""
echo -e "export PATH=\"\$CPROJECT_HOME:\$PATH\"\033[0m"
echo ""
echo "加入後，請執行 'source <您的設定檔>' 或重開一個新的終端機來讓設定生效。"
echo ""
echo "🎉 安裝完成！"