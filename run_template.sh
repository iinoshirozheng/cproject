#!/bin/bash

# === 路徑設定 ===
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
BIN_DIR="${PROJECT_DIR}/bin"
PROJECT_NAME="$(basename "${PROJECT_DIR}")"

# === 預設值 ===
RUN_TESTS=false

# === 參數解析 ===
for arg in "$@"; do
case $arg in
--test)
RUN_TESTS=true
shift
;;
*)
;;
esac
done

# === 檢查是否存在舊的 build 目錄 ===
if [ -d "${BUILD_DIR}" ]; then
    echo "🗑️ 發現已存在的 build 目錄，正在移除..."
    rm -rf "${BUILD_DIR}" || {
        echo "❌ 無法移除 build 目錄！請檢查檔案權限。"
        exit 1
    }
fi

# === 檢查是否存在 bin 目錄 ===
if [ ! -d "${BIN_DIR}" ]; then
    echo "📁 找不到 bin 目錄，正在建立..."
    mkdir -p "${BIN_DIR}" || {
        echo "❌ 無法建立 bin 目錄！"
        exit 1
    }
else
    echo "📁 已存在 bin 目錄，同步繼續進行。"
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

echo "⚙️ 執行 CMake 配置..."

# 檢查是否禁用測試 (RUN_TESTS 為 false)
if [ "$RUN_TESTS" = false ]; then
    cmake .. -DBUILD_TESTS=OFF -DLINK_GTEST=OFF || {
        echo "❌ CMake 配置失敗！"
        exit 1
    }
else
    echo "✅ 啟用測試 (Tests enabled)..."
    cmake .. || {
        echo "❌ CMake 配置失敗！"
        exit 1
    }
fi

echo "🔨 編譯中..."
cmake --build . || {
    echo "❌ 編譯失敗！"
    exit 1
}

echo "✅ 建置完成！"

# === 執行測試（如有需要） ===
if [ "$RUN_TESTS" = true ]; then
    cd cmake
    echo "🧪 執行單元測試..."
    ./run_tests || {
        echo "❌ 測試執行失敗！"
        exit 1
    }
else

    echo "🚀 執行專案主程序..."
    cp cmake/${PROJECT_NAME} ${BIN_DIR}/${PROJECT_NAME}
    cd ${BIN_DIR}
    "./${PROJECT_NAME}"
fi