#!/usr/bin/env bash

# === 路徑設定 ===
# 取得腳本自身所在目錄（不管從哪裡呼叫都正確）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
CMAKE_FILE="${PROJECT_DIR}/CMakeLists.txt"

# 目錄變數
BUILD_DIR="${PROJECT_DIR}/build"
BIN_DIR="${PROJECT_DIR}/bin"

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
CUSTOM_THIRD_PARTY_DIR="__SCRIPT_DIR__/third_party" # 修正預設路徑變數

# === 參數解析 ===
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --test) RUN_TESTS=true; shift ;;
        --build-only) BUILD_ONLY=true; shift ;;
        --third-party-dir) CUSTOM_THIRD_PARTY_DIR="$2"; shift 2 ;; # 接收路徑參數
        --deploy) DEPLOY_MODE=true; shift ;; # 新增 deploy 參數
        *) echo "Unknown parameter passed: $1"; exit 1 ;; # 這裡的 exit 會觸發 trap
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
  # 正常退出，此時 EXIT trap 會執行 cleanup
  # 如果不希望在生成 Containerfile 後執行 cleanup，可以取消 EXIT trap:
  # trap - EXIT
  exit 0
fi


# === 清理舊的 build 目錄 (這部分可以由 trap 處理，但保留也無妨，trap 會在腳本最終退出時執行) ===
# if [ -d "${BUILD_DIR}" ]; then
#   echo "🗑️ 發現已存在的 build 目錄，正在移除..."
#   rm -rf "${BUILD_DIR}" || {
#     echo "❌ 無法移除 build 目錄！請檢查權限。"
#     exit 1 # 這裡的 exit 會觸發 trap
#   }
# fi

# === 建立 bin 目錄 if needed ===
if [ ! -d "${BIN_DIR}" ]; then
  echo "📁 找不到 bin 目錄，正在建立..."
  mkdir -p "${BIN_DIR}" || {
    echo "❌ 無法建立 bin 目錄！"
    exit 1 # 這裡的 exit 會觸發 trap
  }
else
  echo "📁 已存在 bin 目錄，繼續…"
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
# 確保 CUSTOM_THIRD_PARTY_DIR 是絕對路徑或相對於 PROJECT_DIR 的有效路徑
# CMakeLists.txt 中應該能夠正確處理這個傳入的路徑
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
  # 假設 run_tests 在 ${BUILD_DIR}/cmake/ 目錄下，這取決於您的 CMake 設定
  # 如果 run_tests 位於 ${BUILD_DIR}/bin 或其他位置，請相應修改
  if [ -f "${BUILD_DIR}/cmake/run_tests" ]; then
    cd "${BUILD_DIR}/cmake"
    ./run_tests # 如果這裡失敗，set -e 會導致腳本退出，觸發 trap
  elif [ -f "${BUILD_DIR}/bin/run_tests" ]; then # 檢查是否在 build/bin
    cd "${BUILD_DIR}/bin"
    ./run_tests
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

# 執行檔的路徑取決於 CMake 設定，通常在 build 目錄下
# 您的原始腳本是從 build/cmake/ 複製，這比較不尋常
# 通常執行檔會在 ${BUILD_DIR}/${PROJECT_NAME} 或 ${BUILD_DIR}/bin/${PROJECT_NAME}
EXECUTABLE_PATH_IN_BUILD="${BUILD_DIR}/${PROJECT_NAME}" # 假設執行檔直接在 BUILD_DIR
if [ ! -f "${EXECUTABLE_PATH_IN_BUILD}" ]; then
    # 檢查是否在 build/cmake/ (如原始腳本)
    if [ -f "${BUILD_DIR}/cmake/${PROJECT_NAME}" ]; then
        EXECUTABLE_PATH_IN_BUILD="${BUILD_DIR}/cmake/${PROJECT_NAME}"
    # 檢查是否在 build/bin/ (常見的 CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    elif [ -f "${BUILD_DIR}/bin/${PROJECT_NAME}" ]; then
        EXECUTABLE_PATH_IN_BUILD="${BUILD_DIR}/bin/${PROJECT_NAME}"
    else
        echo "❌ 找不到編譯後的執行檔 ${PROJECT_NAME} 在 ${BUILD_DIR} 或其子目錄 (cmake/, bin/)"
        exit 1 # Triggers EXIT trap
    fi
fi

echo "🚀 將 ${PROJECT_NAME} 從 ${EXECUTABLE_PATH_IN_BUILD} 複製到 ${BIN_DIR}..."
cp "${EXECUTABLE_PATH_IN_BUILD}" "${BIN_DIR}/${PROJECT_NAME}" # 如果這裡失敗，set -e 會導致腳本退出，觸發 trap

echo "✅ 執行檔已複製到 ${BIN_DIR}"

# 腳本成功執行到這裡時，我們不希望 trap 在正常退出時也刪除 build 目錄
# 所以在 --build-only 模式或正常執行完主程式後，明確地移除 trap 或以成功狀態退出
if [ "${BUILD_ONLY}" = true ]; then
  echo "✅ 建置完成 (--build-only 模式)！"
  # 在 build-only 模式下，我們通常希望保留 build 目錄供檢查
  # 如果您希望 build-only 模式下保留 build，則可以在這裡取消 EXIT trap
  # trap - EXIT # 取消 EXIT trap，這樣 build 目錄不會被刪除
  exit 0 # 正常退出
fi

# 執行主程式
echo "🚀 執行主程式..."
cd "${BIN_DIR}"
"./${PROJECT_NAME}" # 如果這裡失敗，set -e 會導致腳本退出，觸發 trap

echo "✅ 完成 run.sh ！"
trap - EXIT # 成功執行完畢，取消 EXIT trap，避免刪除 build 目錄
exit 0