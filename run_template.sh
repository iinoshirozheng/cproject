#!/usr/bin/env bash

# === 路徑設定 ===
# 取得腳本自身所在目錄（即專案根目錄）
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VCPKG_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"

CMAKE_FILE="${PROJECT_DIR}/CMakeLists.txt"

# 目錄變數
BUILD_DIR="${PROJECT_DIR}/build"
BIN_DIR="${PROJECT_DIR}/bin"
LIB_DIR="${PROJECT_DIR}/lib"

# === 定義清理函數 ===
cleanup() {
    echo "🧹 執行清理程序..."
    if [ -d "${BUILD_DIR}" ]; then
        echo "🗑️ 正在移除 build 目錄: ${BUILD_DIR}"
        rm -rf "${BUILD_DIR}"
    fi
}

# === 定義 Containerfile 生成函數 ===
# generate_containerfile() {
#   local containerfile_path="${PROJECT_DIR}/Containerfile"
#   echo "📝 Generating Containerfile at ${containerfile_path}..."

#   if [ -z "${PROJECT_NAME}" ]; then
#     echo "❌ PROJECT_NAME is not set. Cannot generate Containerfile."
#     exit 1 # This will trigger EXIT trap
#   fi

#   cat > "${containerfile_path}" <<EOL
# # Containerfile (for ${PROJECT_NAME})

# # --- Stage 1: Builder ---
# # 使用您上面定義的、已包含預編譯第三方函式庫和設定好環境變數的 Builder Image
# # 假設您將上面的 Containerfile.builder 建置成了名為 my_builder_with_env:latest 的映像檔
# FROM raylab.io/cpp-builder:latest AS builder

# WORKDIR /app

# # 複製您的 ${PROJECT_NAME} 原始碼
# COPY . .

# # 賦予 run.sh 執行權限
# RUN chmod +x ./run.sh

# # 執行 run.sh 來編譯您的 ${PROJECT_NAME}
# # 您的 run.sh 中的 CMake 現在會透過 vcpkg 自動處理依賴
# RUN ./run.sh --build-only

# # --- Stage 2: Runner ---
# FROM registry.access.redhat.com/ubi9/ubi:latest

# WORKDIR /app

# # 從 Builder 的 /app/bin/ 目錄複製編譯好的執行檔
# COPY --from=builder /app/bin/${PROJECT_NAME} ./${PROJECT_NAME}

# # 確保執行檔有執行權限
# RUN chmod +x ./${PROJECT_NAME}

# # (選用) 安裝執行時期依賴，例如 libstdc++。通常 ubi 映像檔已包含或您的專案靜態連結。
# # RUN microdnf update -y && microdnf install -y libstdc++ && microdnf clean all && rm -rf /var/cache/yum

# # 定義執行您應用程式的命令
# CMD ["./${PROJECT_NAME}"]
# EOL

#   echo "✅ Containerfile generated successfully at ${containerfile_path}"
# }


# === 設定陷阱 (trap) ===
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

# --- vcpkg 整合：確認 vcpkg toolchain 檔案存在 ---
if [ ! -f "${VCPKG_TOOLCHAIN_FILE}" ]; then
    echo "❌ 找不到 vcpkg 的 CMake toolchain 檔案！"
    echo "    預期路徑: ${VCPKG_TOOLCHAIN_FILE}"
    echo "💡 請確認 vcpkg 已被 clone 到您的工具 repo 目錄下。"
    exit 1
fi

# 從 CMakeLists.txt 裡解析 project 名稱 (第一個參數)
PROJECT_NAME="$(grep -E '^[[:space:]]*project\(' "${CMAKE_FILE}" \
               | head -n1 \
               | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"

# === 預設值 ===
RUN_TESTS=false
BUILD_ONLY=false
DEPLOY_MODE=false # deploy 模式旗標

# === 參數解析 ===
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

# === 處理 --deploy 模式 ===
if [ "${DEPLOY_MODE}" = true ]; then
  if [ -z "${PROJECT_NAME}" ]; then
    echo "❌ PROJECT_NAME could not be determined from CMakeLists.txt. Cannot generate Containerfile."
    exit 1 # Triggers EXIT trap
  fi
  # generate_containerfile
  echo "✅ --deploy mode finished."
  exit 0
fi

# === 建置步驟 ===
echo "📦 建立新的 build 目錄: ${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "⚙️ 準備 CMake 配置參數…"
CMAKE_ARGS=() # 初始化 CMake 參數陣列

# --- vcpkg 整合：傳入 vcpkg toolchain 檔案 ---
CMAKE_ARGS+=("-DCMAKE_TOOLCHAIN_FILE=${VCPKG_TOOLCHAIN_FILE}")

if [ "${RUN_TESTS}" = false ]; then
  CMAKE_ARGS+=("-DBUILD_TESTS=OFF")
else
  echo "✅ 啟用測試模式…"
  CMAKE_ARGS+=("-DBUILD_TESTS=ON")
fi

echo "⚙️ 執行 CMake 配置 (使用 vcpkg)..."
cmake "${CMAKE_ARGS[@]}" ..

echo "🔨 編譯中 (vcpkg 會自動處理依賴下載)..."
cmake --build .

echo "✅ 建置完成！"

if [ "${RUN_TESTS}" = true ]; then
  echo "🧪 執行單元測試…"
  
  TEST_EXECUTABLE_PATH=""
  POSSIBLE_TEST_PATHS=(
      "${BUILD_DIR}/cmake/run_tests"
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
    cd "$(dirname "${TEST_EXECUTABLE_PATH}")"
    "./$(basename "${TEST_EXECUTABLE_PATH}")"
    cd "${PROJECT_DIR}"
  else
    echo "⚠️ 找不到測試執行檔 run_tests。"
  fi
fi

# 返回專案根目錄
cd "${PROJECT_DIR}"

if [ -z "${PROJECT_NAME}" ]; then
  echo "❌ PROJECT_NAME 未定義。"
  exit 1
fi

# --- 產出處理邏輯 ---
# 尋找執行檔
EXECUTABLE_PATH_IN_BUILD=""
POSSIBLE_EXEC_PATHS=(
    "${BUILD_DIR}/cmake/${PROJECT_NAME}"
    "${BUILD_DIR}/${PROJECT_NAME}"
    "${BUILD_DIR}/bin/${PROJECT_NAME}"
)
for path in "${POSSIBLE_EXEC_PATHS[@]}"; do
    if [ -f "$path" ]; then
        EXECUTABLE_PATH_IN_BUILD="$path"
        break
    fi
done

# 尋找函式庫檔案
STATIC_LIB_PATH="${BUILD_DIR}/lib${PROJECT_NAME}.a"
SHARED_LIB_PATH_SO="${BUILD_DIR}/lib${PROJECT_NAME}.so"
SHARED_LIB_PATH_DYLIB="${BUILD_DIR}/lib${PROJECT_NAME}.dylib"
IS_LIBRARY=false
if [ -f "${STATIC_LIB_PATH}" ] || [ -f "${SHARED_LIB_PATH_SO}" ] || [ -f "${SHARED_LIB_PATH_DYLIB}" ]; then
    IS_LIBRARY=true
fi

# 根據找到的檔案類型進行處理
if [ -n "${EXECUTABLE_PATH_IN_BUILD}" ]; then
    echo "🚀 將 ${PROJECT_NAME} 從 ${EXECUTABLE_PATH_IN_BUILD} 複製到 ${BIN_DIR}..."
    mkdir -p "${BIN_DIR}"
    cp "${EXECUTABLE_PATH_IN_BUILD}" "${BIN_DIR}/${PROJECT_NAME}"
    echo "✅ 執行檔已複製到 ${BIN_DIR}"
elif [ "$IS_LIBRARY" = true ]; then
    echo "📚 處理函式庫產出..."
    mkdir -p "${LIB_DIR}"
    
    # 複製靜態與動態函式庫
    find "${BUILD_DIR}" -name "lib${PROJECT_NAME}.a" -exec cp {} "${LIB_DIR}/" \;
    find "${BUILD_DIR}" -name "lib${PROJECT_NAME}.so" -exec cp {} "${LIB_DIR}/" \;
    find "${BUILD_DIR}" -name "lib${PROJECT_NAME}.dylib" -exec cp {} "${LIB_DIR}/" \;
    
    # 複製公開標頭檔
    if [ -d "${PROJECT_DIR}/include" ]; then
        echo "  -> 正在複製公開標頭檔..."
        mkdir -p "${LIB_DIR}/include"
        # 使用 rsync 更健壯，或用 cp -R
        rsync -a --delete "${PROJECT_DIR}/include/" "${LIB_DIR}/include/"
    fi
    echo "✅ 函式庫及標頭檔已成功複製到 ${LIB_DIR} 目錄"
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
trap - EXIT
exit 0