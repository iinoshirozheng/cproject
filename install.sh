#!/bin/bash
# 當任何指令出錯時，立即退出
set -e

# --- 路徑設定 ---
# 取得此腳本所在的目錄，也就是 cproject 工具的根目錄
CPPROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_VCPKG_SCRIPT="${CPPROJECT_DIR}/setup_vcpkg.sh"
CPROJECT_EXECUTABLE="${CPPROJECT_DIR}/cproject.sh"

# 【新增】定義 bin 目錄和最終的指令路徑
BIN_DIR="${CPPROJECT_DIR}/bin"
PUBLIC_CPROJECT_CMD="${BIN_DIR}/cproject"

echo "--- cproject 安裝程序 ---"

# 步驟一：確保主腳本有執行權限
echo "1. 正在設定 cproject 主腳本權限..."
chmod +x "${CPROJECT_EXECUTABLE}"
echo "✅ 主腳本權限設定完成。"
echo ""

# 【新增】步驟二：建立 bin 目錄並設定符號連結
echo "2. 正在建立公開指令..."
mkdir -p "${BIN_DIR}"
# 建立一個從 bin/cproject 指向 cproject.sh 的符號連結
# -s: symbolic, -f: force (如果已存在則覆蓋)
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

# 【修改】步驟四：顯示手動設定 PATH 的指引 (只加入 bin 目錄)
echo "--- 👉 最後一步：手動設定環境變數 ---"
echo "為了能在任何地方使用 'cproject' 指令，請將下列指令"
echo "複製並貼到您的 shell 設定檔中 (例如 ~/.zshrc, ~/.bash_profile 或 ~/.profile)："
echo ""
echo -e "\033[0;32m# --- cproject Environment ---"
echo -e "export CPROJECT_HOME=\"${CPPROJECT_DIR}\""
echo -e "export PATH=\"\$CPROJECT_HOME/bin:\$PATH\"\033[0m" # 只將 bin 目錄加入 PATH
echo ""
echo "加入後，請執行 'source <your-shell-config-file>' 或重開一個新的終端機來讓設定生效。"
echo ""
echo "🎉 安裝完成！"