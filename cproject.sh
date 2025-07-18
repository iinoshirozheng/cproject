#!/usr/bin/env bash

# === helper: 顯示用法 ===
usage() {
  cat <<EOF
📘 cproject 使用說明

用法:
  cproject create [--library] <ProjectName>
      ➤ 建立一個新的 C++ 專案。
      ➤ 加上 --library 旗標，會建立一個靜態函式庫專案 (.a)。
      ➤ 若無旗標，則預設建立一個可執行檔專案。

  cproject build [--test]
      ➤ 建置當前資料夾的專案。

  cproject run [--test]
      ➤ 在當前資料夾執行 run.sh 腳本 (建置並執行)。

範例:
  cproject create MyApp
  cproject create --library MyLib
  cproject build
  cproject run
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
    CREATE_TYPE="executable" # 預設為執行檔
    if [ "$1" == "--library" ]; then
      CREATE_TYPE="library"
      shift # 移除 --library 旗標
    fi

    if [ $# -ne 1 ]; then
      echo ""
      echo "❌ create 需要一個專案名稱！"
      echo ""
      usage
    fi
    NEW_PROJ="$1"
    
    if [ ! -x "${SCRIPT_DIR}/create_project.sh" ]; then
      echo "❌ 找不到或無執行權限：${SCRIPT_DIR}/create_project.sh"
      exit 1
    fi
    
    echo "📁 透過 create_project.sh 建立新專案：${NEW_PROJ} (類型: ${CREATE_TYPE})"
    # 將專案類型作為第二個參數傳遞
    exec bash "${SCRIPT_DIR}/create_project.sh" "${NEW_PROJ}" "${CREATE_TYPE}"
    ;;
    
  # ... build 和 run 的部分保持不變 ...
  build)
    BUILD_ARGS="--build-only"
    if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--test" ]; }; then
      echo ""
      echo "❌ build 只能接受 --test（或不帶參數）"
      echo ""
      usage
    elif [ $# -eq 1 ] && [ "$1" == "--test" ]; then
      BUILD_ARGS="--build-only --test"
      shift
    fi

    if [ ! -x "./run.sh" ]; then
      echo ""
      echo "❌ 找不到可執行的 run.sh，請確認檔案存在並加上執行權限"
      echo ""
      exit 1
    fi
    echo "🛠️  執行建置 (透過 run.sh ${BUILD_ARGS})"
    exec bash ./run.sh ${BUILD_ARGS}
    ;;
  run)
    RUN_ARGS=()
    if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--test" ]; }; then
      echo ""
      echo "❌ run 只能接受 --test（或不帶參數）"
      echo ""
      usage
    elif [ $# -eq 1 ] && [ "$1" == "--test" ]; then
      RUN_ARGS+=("--test")
      shift
    fi

    if [ ! -x "./run.sh" ]; then
      echo ""
      echo "❌ 找不到可執行的 run.sh，請確認檔案存在並加上執行權限"
      echo ""
      exit 1
    fi
    echo "🚀 執行 run.sh ${RUN_ARGS[*]}"
    exec bash ./run.sh "${RUN_ARGS[@]}"
    ;;
  *)
    echo "❌ 未知子命令: $SUBCMD"
    usage
    ;;
esac