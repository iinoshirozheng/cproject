#!/usr/bin/env bash

# === helper: 顯示用法 ===
usage() {
  cat <<EOF
📘 cproject 使用說明

用法:
  cproject create <ProjectName>
      ➤ 建立一個新的 C++ 專案，內含 CMake 結構與範例程式

  cproject run [--test]
      ➤ 在當前資料夾執行 run.sh 腳本
      ➤ 加上 --test 則會執行單元測試

範例:
  cproject create MyApp
  cproject run
  cproject run --test
EOF
  exit 1
}

# === 取得本腳本所在目錄 ===
SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# === 若無參數，顯示使用說明 ===
if [ $# -lt 1 ]; then
  echo ""
  echo "⚠️  請帶入參數："
  echo ""
  usage
fi

SUBCMD="$1"; shift

case "$SUBCMD" in
  create)
    if [ $# -ne 1 ]; then
      echo ""
      echo "❌ create 需要且只能有一個參數（專案名稱）！"
      echo ""
      usage
    fi
    NEW_PROJ="$1"
    if [ ! -x "${SCRIPT_DIR}/create_project.sh" ]; then
      echo "❌ 找不到或無執行權限：${SCRIPT_DIR}/create_project.sh"
      exit 1
    fi
    echo "📁 透過 create_project.sh scaffold 新專案：${NEW_PROJ}"
    exec bash "${SCRIPT_DIR}/create_project.sh" "${NEW_PROJ}"
    ;;
  run)
    if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--test" ]; }; then
      echo ""
      echo "❌ run 只能接受 --test（或不帶參數）"
      echo ""
      usage
    fi
    if [ ! -x "./run.sh" ]; then
      echo ""
      echo "❌ 找不到可執行的 run.sh，請確認檔案存在並加上執行權限"
      echo ""
      exit 1
    fi
    echo "🚀 執行 run.sh $*"
    exec bash ./run.sh "$@"
    ;;
  *)
    echo "❌ 未知子命令: $SUBCMD"
    usage
    ;;
esac
