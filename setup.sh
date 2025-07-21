#!/bin/bash

# 取得此腳本所在的目錄 (即 cppackage 的根目錄)
# 這確保無論您從哪裡 source 此腳本，路徑都是正確的
CPPROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 設定 VCPKG_ROOT 環境變數，指向此工具庫內的 vcpkg
export VCPKG_ROOT="${CPPROJECT_DIR}/vcpkg"
export PATH="${VCPKG_ROOT}:${PATH}"

# --- [新增] 設定 cproject 別名 ---
# 使用絕對路徑，確保別名在任何地方都有效
# 明確使用 bash 來執行，避免 shell 相容性問題
SHELL_PROFILE=""
if [[ "$SHELL" == *"/zsh" ]]; then
    alias cproject="zsh ${CPPROJECT_DIR}/cproject.sh"
else
    alias cproject="bash ${CPPROJECT_DIR}/cproject.sh"
fi