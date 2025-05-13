#!/usr/bin/env bash

# === helper: 顯示用法 ===
usage() {
  cat <<EOF
用法:
  cproject create <ProjectName>
    透過 create_project.sh scaffold 一個新的 CMake 專案結構

  cproject run [--test]
    執行當前資料夾下的 run.sh，可加 --test 開啟測試模式
EOF
  exit 1
}

# === 取得本脚本所在目錄 ===
SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# === 確認至少有一個參數 ===
[ $# -ge 1 ] || { echo "❌ 未指定子命令"; usage; }

SUBCMD="$1"; shift

case "$SUBCMD" in

  create)
    # create 必須且只能帶一個專案名稱
    if [ $# -ne 1 ]; then
      echo "❌ create 需要且只能有一個參數！"
      usage
    fi
    NEW_PROJ="$1"

    # 確認 create_project.sh 存在並可執行
    if [ ! -x "${SCRIPT_DIR}/create_project.sh" ]; then
      echo "❌ 找不到或無執行權限：${SCRIPT_DIR}/create_project.sh"
      exit 1
    fi

    echo "📁 透過 create_project.sh scaffold 新專案：${NEW_PROJ}"
    exec bash "${SCRIPT_DIR}/create_project.sh" "${NEW_PROJ}"
    ;;

  run)
    # run 只能帶零或一個 --test
    if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--test" ]; }; then
      echo "❌ run 只能接受 --test（或不帶參數）"
      usage
    fi

    # 確認 run.sh 存在並可執行
    if [ ! -x "./run.sh" ]; then
      echo "❌ 找不到可執行的 run.sh，請確認檔案存在並加上執行權限"
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

# alias cproject='bash cproject.sh'