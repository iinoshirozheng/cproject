#!/usr/bin/env bash

# === 路徑設定 ===
# 取得腳本自身所在目錄（不管從哪裡呼叫都正確）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
CMAKE_FILE="${PROJECT_DIR}/CMakeLists.txt"

# 確認 CMakeLists.txt 存在
if [ ! -f "${CMAKE_FILE}" ]; then
    echo "❌ 無法找到 ${CMAKE_FILE}，請確認專案根目錄下有 CMakeLists.txt"
    exit 1
fi

# 從 CMakeLists.txt 裡解析 project 名稱 (第一個參數)
PROJECT_NAME="$(grep -E '^[[:space:]]*project\(' "${CMAKE_FILE}" \
               | head -n1 \
               | sed -E 's/^[[:space:]]*project\(\s*([A-Za-z0-9_]+).*/\1/')"

# 目錄變數
BUILD_DIR="${PROJECT_DIR}/build"
BIN_DIR="${PROJECT_DIR}/bin"

# === 預設值 ===
RUN_TESTS=false
BUILD_ONLY=false

# === 新增：接收第三方函式庫路徑參數 ===
CUSTOM_THIRD_PARTY_DIR=""

# === 參數解析 ===
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --test) RUN_TESTS=true; shift ;;
        --build-only) BUILD_ONLY=true; shift ;;
        --third-party-dir) CUSTOM_THIRD_PARTY_DIR="$2"; shift 2 ;; # 接收路徑參數
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

# === 清理舊的 build 目錄 ===
if [ -d "${BUILD_DIR}" ]; then
  echo "🗑️ 發現已存在的 build 目錄，正在移除..."
  rm -rf "${BUILD_DIR}" || {
    echo "❌ 無法移除 build 目錄！請檢查權限。"
    exit 1
  }
fi

# === 建立 bin 目錄 if needed ===
if [ ! -d "${BIN_DIR}" ]; then
  echo "📁 找不到 bin 目錄，正在建立..."
  mkdir -p "${BIN_DIR}" || {
    echo "❌ 無法建立 bin 目錄！"
    exit 1
  }
else
  echo "📁 已存在 bin 目錄，繼續…"
fi

# === 建置步驟 ===
echo "📦 建立新的 build 目錄: ${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" || {
  echo "❌ 無法建立 build 目錄！"
  exit 1
}
cd "${BUILD_DIR}" || {
  echo "❌ 無法進入 build 目錄！"
  exit 1
}

echo "⚙️ 準備 CMake 配置參數…"
CMAKE_ARGS=() # 初始化 CMake 參數陣列

if [ -n "$CUSTOM_THIRD_PARTY_DIR" ]; then
  echo "🛠️ 使用自訂的第三方函式庫路徑: ${CUSTOM_THIRD_PARTY_DIR}"
  CMAKE_ARGS+=("-DTHIRD_PARTY_DIR=${CUSTOM_THIRD_PARTY_DIR}")
else
  # 如果沒有提供參數，則CMake會使用CMakeLists.txt中的預設值
  echo "ℹ️ 使用 CMakeLists.txt 中預設的 THIRD_PARTY_DIR"
fi

# 將 CMAKE_MODULE_PATH 也設定為相對於專案的路徑，以便在容器中工作
# PROJECT_DIR 是腳本開頭定義的專案根目錄的絕對路徑
CMAKE_ARGS+=("-DCMAKE_MODULE_PATH=${PROJECT_DIR}/cmake")


if [ "${RUN_TESTS}" = false ]; then
  CMAKE_ARGS+=("-DBUILD_TESTS=OFF" "-DLINK_GTEST=OFF")
else
  echo "✅ 啟用測試模式…"
  CMAKE_ARGS+=("-DBUILD_TESTS=ON" "-DLINK_GTEST=ON")
fi

echo "⚙️ 執行 CMake 配置…"
# 使用組裝好的 CMAKE_ARGS 執行 cmake
cmake "${CMAKE_ARGS[@]}" .. || {
  echo "❌ CMake 配置失敗！"
  exit 1
}

echo "🔨 編譯中…"
cmake --build . || {
  echo "❌ 編譯失敗！"
  exit 1
}

echo "✅ 建置完成！"

# === 執行測試 or 主程式 ===
if [ "${RUN_TESTS}" = true ]; then
  echo "🧪 執行單元測試…"
  # 進入存放測試執行檔的目錄 (假設是 build/cmake)
  # 注意：測試執行檔的確切位置和名稱取決於您的 CMake 設定
  # 您的 CMakeLists.txt 中，測試目標 run_tests 是在 cmake 子目錄中定義的
  cd "${PROJECT_DIR}/build/cmake" # 確保路徑正確
  ./run_tests || { # 假設測試執行檔名為 run_tests
    echo "❌ 測試失敗！"
    exit 1
  }
fi

echo "🚀 將 ${PROJECT_NAME} 複製到 ${BIN_DIR}..."
# BUILD_DIR/cmake/${PROJECT_NAME} 是根據您的 CMakeLists.txt 推斷的執行檔輸出位置
cp "${PROJECT_DIR}/build/cmake/${PROJECT_NAME}" "${BIN_DIR}/${PROJECT_NAME}" || {
    echo "❌ 無法複製執行檔！"
    exit 1
}
# 在 Dockerfile 中，CMD 會負責啟動，所以這裡不需要再執行
# cd "${BIN_DIR}"
# "./${PROJECT_NAME}"
echo "✅ 執行檔已複製到 ${BIN_DIR}"

# 移除 build 目錄
echo "🗑️ 移除 build 目錄..."
rm -rf "${BUILD_DIR}"

if [ "${BUILD_ONLY}" = true ]; then
  echo "✅ 建置完成！"
  exit 0
fi

# 執行主程式
echo "🚀 執行主程式..."
cd "${BIN_DIR}"
"./${PROJECT_NAME}"

echo "✅ 完成 run.sh ！" && exit 0