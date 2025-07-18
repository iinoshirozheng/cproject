#!/usr/bin/env bash

# === 路徑設定 ===
# 取得腳本自身所在目錄（不管從哪裡呼叫都正確）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
CMAKE_FILE="${PROJECT_DIR}/CMakeLists.txt"

# 目錄變數
BUILD_DIR="${PROJECT_DIR}/build"
BIN_DIR="${PROJECT_DIR}/bin"
LIB_DIR="${PROJECT_DIR}/lib"

# === 新增：定義清理函數 ===
cleanup() {
    echo "🧹 執行清理程序..."
    if [ -d "${BUILD_DIR}" ]; then
        echo "🗑️ 正在移除 build 目錄: ${BUILD_DIR}"
        rm -rf "${BUILD_DIR}"
    fi
}

# === 新增：定義 Containerfile 生成函數 ===
generate_containerfile() {
  local containerfile_path="${PROJECT_DIR}/Containerfile"
  echo "📝 Generating Containerfile at ${containerfile_path}..."

  if [ -z "${PROJECT_NAME}" ]; then
    echo "❌ PROJECT_NAME is not set. Cannot generate Containerfile."
    exit 1 # This will trigger EXIT trap
  fi

  cat > "${containerfile_path}" <<EOL
# Containerfile (for ${PROJECT_NAME})

# --- Stage 1: Builder ---
# 使用您上面定義的、已包含預編譯第三方函式庫和設定好環境變數的 Builder Image
# 假設您將上面的 Containerfile.builder 建置成了名為 my_builder_with_env:latest 的映像檔
FROM raylab.io/cpp-builder:latest AS builder

WORKDIR /app

# 複製您的 ${PROJECT_NAME} 原始碼
COPY . .

# 賦予 run.sh 執行權限
RUN chmod +x ./run.sh

# 執行 run.sh 來編譯您的 ${PROJECT_NAME}
# 您的 run.sh 中的 CMake 現在會透過環境變數 THIRD_PARTY_DIR_ENV
# (或者直接使用 CMakeLists.txt 中讀取環境變數的邏輯)
# 來找到函式庫。
# --third-party-dir /opt/third_party 告訴 run.sh 在 builder 內部何處尋找函式庫
RUN ./run.sh --build-only --third-party-dir /opt/third_party

# --- Stage 2: Runner ---
FROM registry.access.redhat.com/ubi9/ubi:latest

WORKDIR /app

# 從 Builder 的 /app/bin/ 目錄複製編譯好的執行檔
COPY --from=builder /app/bin/${PROJECT_NAME} ./${PROJECT_NAME}

# 確保執行檔有執行權限
RUN chmod +x ./${PROJECT_NAME}

# (選用) 安裝執行時期依賴，例如 libstdc++。通常 ubi 映像檔已包含或您的專案靜態連結。
# RUN microdnf update -y && microdnf install -y libstdc++ && microdnf clean all && rm -rf /var/cache/yum

# 定義執行您應用程式的命令
CMD ["./${PROJECT_NAME}"]
EOL

  echo "✅ Containerfile generated successfully at ${containerfile_path}"
}


# === 新增：設定陷阱 (trap) ===
# 當腳本因錯誤退出 (EXIT)，或收到中斷 (INT)，終止 (TERM) 信號時，執行 cleanup 函數
trap cleanup EXIT INT TERM

# === Exit on error ===
# 將 set -e 移到 trap 之後，確保 trap 能被正確設定
set -e

# 確認 CMakeLists.txt 存在
if [ ! -f "${CMAKE_FILE}" ]; then
    echo "❌ 無法找到 ${CMAKE_FILE}，請確認專案根目錄下有 CMakeLists.txt"
    exit 1 # 這裡的 exit 會觸發上面設定的 trap
fi

# 從 CMakeLists.txt 裡解析 project 名稱 (第一個參數)
PROJECT_NAME="$(grep -E '^[[:space:]]*project\(' "${CMAKE_FILE}" \
               | head -n1 \
               | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"

# === 預設值 ===
RUN_TESTS=false
BUILD_ONLY=false
DEPLOY_MODE=false # 新增 deploy 模式旗標

# === 新增：接收第三方函式庫路徑參數 ===
CUSTOM_THIRD_PARTY_DIR="/Users/ray/cppackage/third_party"

# === 參數解析 (已修正語法) ===
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --test)
            RUN_TESTS=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --third-party-dir)
            CUSTOM_THIRD_PARTY_DIR="$2"
            shift 2
            ;;
        --deploy)
            DEPLOY_MODE=true
            shift
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done

# === 新增：處理 --deploy 模式 ===
if [ "${DEPLOY_MODE}" = true ]; then
  if [ -z "${PROJECT_NAME}" ]; then
    echo "❌ PROJECT_NAME could not be determined from CMakeLists.txt. Cannot generate Containerfile."
    exit 1 # Triggers EXIT trap
  fi
  generate_containerfile
  echo "✅ --deploy mode finished."
  exit 0
fi

# === 建置步驟 ===
echo "📦 建立新的 build 目錄: ${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" || {
  echo "❌ 無法建立 build 目錄！"
  exit 1 # 這裡的 exit 會觸發 trap
}
cd "${BUILD_DIR}" || {
  echo "❌ 無法進入 build 目錄！"
  exit 1 # 這裡的 exit 會觸發 trap
}

echo "⚙️ 準備 CMake 配置參數…"
CMAKE_ARGS=() # 初始化 CMake 參數陣列

# 處理第三方函式庫路徑
if [[ "$CUSTOM_THIRD_PARTY_DIR" != /* ]]; then
    # 如果不是絕對路徑，假設它是相對於 PROJECT_DIR
    resolved_third_party_dir="${PROJECT_DIR}/${CUSTOM_THIRD_PARTY_DIR}"
else
    resolved_third_party_dir="${CUSTOM_THIRD_PARTY_DIR}"
fi

if [ -n "$CUSTOM_THIRD_PARTY_DIR" ]; then # 檢查原始的 CUSTOM_THIRD_PARTY_DIR 是否有被設定
  echo "🛠️ 使用第三方函式庫路徑: ${resolved_third_party_dir}"
  CMAKE_ARGS+=("-DTHIRD_PARTY_DIR=${resolved_third_party_dir}")
else
  echo "ℹ️ 使用 CMakeLists.txt 中預設的 THIRD_PARTY_DIR"
fi


CMAKE_ARGS+=("-DCMAKE_MODULE_PATH=${PROJECT_DIR}/cmake")

if [ "${RUN_TESTS}" = false ]; then
  CMAKE_ARGS+=("-DBUILD_TESTS=OFF" "-DLINK_GTEST=OFF")
else
  echo "✅ 啟用測試模式…"
  CMAKE_ARGS+=("-DBUILD_TESTS=ON" "-DLINK_GTEST=ON")
fi

echo "⚙️ 執行 CMake 配置…"
cmake "${CMAKE_ARGS[@]}" .. # 如果這裡失敗，set -e 會導致腳本退出，觸發 trap

echo "🔨 編譯中…"
cmake --build . # 如果這裡失敗，set -e 會導致腳本退出，觸發 trap

echo "✅ 建置完成！"

if [ "${RUN_TESTS}" = true ]; then
  echo "🧪 執行單元測試…"
  
  TEST_EXECUTABLE_PATH=""
  POSSIBLE_TEST_PATHS=(
      "${BUILD_DIR}/cmake/run_tests" # <--- 新增這個最關鍵的路徑
      "${BUILD_DIR}/run_tests"
      "${BUILD_DIR}/bin/run_tests"
  )

  for path in "${POSSIBLE_TEST_PATHS[@]}"; do
      if [ -f "$path" ]; then
          TEST_EXECUTABLE_PATH="$path"
          break
      fi
  done

  if [ -n "${TEST_EXECUTABLE_PATH}" ]; then
    echo "✅ 在 ${TEST_EXECUTABLE_PATH} 找到測試程式，準備執行..."
    # 進入該檔案所在目錄再執行，避免路徑問題
    cd "$(dirname "${TEST_EXECUTABLE_PATH}")"
    "./$(basename "${TEST_EXECUTABLE_PATH}")"
    cd "${PROJECT_DIR}" # 執行完畢後回到專案根目錄
  else
    echo "⚠️ 找不到測試執行檔 run_tests。"
  fi
fi

# 返回專案根目錄，以便路徑解析一致
cd "${PROJECT_DIR}"

# 確保 PROJECT_NAME 有值
if [ -z "${PROJECT_NAME}" ]; then
  echo "❌ PROJECT_NAME 未定義，無法複製執行檔。"
  exit 1 # Triggers EXIT trap
fi

# 尋找編譯產出
EXECUTABLE_PATH_IN_BUILD=""
POSSIBLE_PATHS=(
    "${BUILD_DIR}/cmake/${PROJECT_NAME}"
    "${BUILD_DIR}/${PROJECT_NAME}"
    "${BUILD_DIR}/bin/${PROJECT_NAME}"
)
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        EXECUTABLE_PATH_IN_BUILD="$path"
        break
    fi
done

# 檢查是否為函式庫
IS_LIBRARY=false
if [ -z "${EXECUTABLE_PATH_IN_BUILD}" ] && [ -f "${BUILD_DIR}/lib${PROJECT_NAME}.a" ]; then
    IS_LIBRARY=true
fi

# 複製或提示
if [ -n "${EXECUTABLE_PATH_IN_BUILD}" ]; then
    echo "🚀 將 ${PROJECT_NAME} 從 ${EXECUTABLE_PATH_IN_BUILD} 複製到 ${BIN_DIR}..."
    mkdir -p "${BIN_DIR}"
    cp "${EXECUTABLE_PATH_IN_BUILD}" "${BIN_DIR}/${PROJECT_NAME}"
    echo "✅ 執行檔已複製到 ${BIN_DIR}"
elif [ "$IS_LIBRARY" = true ]; then
    echo "✅ 函式庫 lib${PROJECT_NAME}.a 已成功建置在 ${BUILD_DIR} 目錄下。"
    mkdir -p "${LIB_DIR}" 
    cp "${BUILD_DIR}/lib${PROJECT_NAME}.a" "${LIB_DIR}/lib${PROJECT_NAME}.a"
    echo "✅ 函式庫已複製到 ${LIB_DIR}"
else
    echo "❌ 找不到任何編譯後的執行檔或函式庫！"
    exit 1
fi

# 執行或結束
if [ "${BUILD_ONLY}" = true ]; then
  echo "✅ 建置完成 (--build-only 模式)！"
  trap - EXIT
  exit 0
fi

if [ "$IS_LIBRARY" = true ]; then
    echo "ℹ️ 專案 '${PROJECT_NAME}' 是一個函式庫，沒有主程式可以執行。"
    trap - EXIT
    exit 0
fi

echo "🚀 執行主程式..."
cd "${BIN_DIR}"
"./${PROJECT_NAME}"

echo "✅ 完成 run.sh ！"
trap - EXIT # 成功執行完畢，取消 EXIT trap，避免刪除 build 目錄
exit 0