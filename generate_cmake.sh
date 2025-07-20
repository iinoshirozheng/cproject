#!/bin/bash

# Exit on error
set -e

# --- 參數處理 ---
PROJECT_DIR="$1"
PROJECT_TYPE="${2:-executable}"
PROJECT_NAME=$(basename "${PROJECT_DIR}")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/cmake_template"
TARGET_CMAKE_DIR="${PROJECT_DIR}/cmake"
MAIN_CMAKELISTS="${PROJECT_DIR}/CMakeLists.txt"

echo "🛠 正在產生 Homebrew 版本的 CMake 設定檔..."
echo "🔩 專案類型: ${PROJECT_TYPE}"

# --- 複製模板與 run.sh ---
mkdir -p "${TARGET_CMAKE_DIR}"
if [ "${PROJECT_TYPE}" == "library" ]; then
    find "${TEMPLATE_DIR}" -type f ! -name "BuildMainExecutable.cmake" -exec cp {} "${TARGET_CMAKE_DIR}/" \;
else
    cp -v "${TEMPLATE_DIR}"/* "${TARGET_CMAKE_DIR}/"
fi
cp "${SCRIPT_DIR}/run_template.sh" "${PROJECT_DIR}/run.sh"
chmod +x "${PROJECT_DIR}/run.sh"

# --- 根據專案類型產生主 CMakeLists.txt ---
echo "📝 正在產生主 CMakeLists.txt for a ${PROJECT_TYPE} project..."

# --- 這是一段所有專案類型都會用到的通用 CMake 內容 ---
COMMON_CMAKE_CONTENT=$(cat <<'EOF'
# --- 尋找外部函式庫 (透過 Homebrew 安裝) ---
find_package(Threads REQUIRED)
find_package(CURL REQUIRED)
find_package(LibXml2 REQUIRED)

# 測試相關設定
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    find_package(GTest REQUIRED)
    enable_testing()
endif()
EOF
)

if [ "${PROJECT_TYPE}" == "library" ]; then
# --- 函式庫版本的 CMakeLists.txt ---
cat > "${MAIN_CMAKELISTS}" <<EOF
cmake_minimum_required(VERSION 3.15)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

${COMMON_CMAKE_CONTENT}

# --- 建立函式庫 ---
file(GLOB_RECURSE LIB_SOURCES "src/*.c" "src/*.cpp")
add_library(${PROJECT_NAME} STATIC \${LIB_SOURCES})
target_include_directories(${PROJECT_NAME} PUBLIC \${CMAKE_CURRENT_SOURCE_DIR}/include)

# 將相依性連結到函式庫
target_link_libraries(${PROJECT_NAME} 
    PRIVATE 
        CURL::libcurl
        LibXml2::LibXml2
        Threads::Threads
)

# --- 測試設定 ---
if(BUILD_TESTS AND TARGET GTest::GTest)
    file(GLOB_RECURSE TEST_SOURCES "tests/*.cpp")
    add_executable(run_tests \${TEST_SOURCES})
    target_link_libraries(run_tests PRIVATE ${PROJECT_NAME} GTest::GTest GTest::Main)
    include(GoogleTest)
    gtest_discover_tests(run_tests)
endif()
EOF

else
# --- 執行檔版本的 CMakeLists.txt ---
cat > "${MAIN_CMAKELISTS}" <<EOF
cmake_minimum_required(VERSION 3.15)
project(${PROJECT_NAME} VERSION 1.0.0 LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

${COMMON_CMAKE_CONTENT}

# --- 建立執行檔 ---
file(GLOB_RECURSE EXEC_SOURCES "src/*.c" "src/*.cpp")
add_executable(${PROJECT_NAME} \${EXEC_SOURCES})

# 連結所有需要的函式庫
target_link_libraries(${PROJECT_NAME}
    PRIVATE
        CURL::libcurl
        LibXml2::LibXml2
        Threads::Threads
)

# --- 測試設定 ---
if(BUILD_TESTS AND TARGET GTest::GTest)
    file(GLOB_RECURSE TEST_SOURCES "tests/*.cpp")
    if(TEST_SOURCES)
        add_executable(run_tests \${TEST_SOURCES})
        target_link_libraries(run_tests PRIVATE GTest::GTest GTest::Main)
        target_include_directories(run_tests PRIVATE \${CMAKE_CURRENT_SOURCE_DIR}/src)
        include(GoogleTest)
        gtest_discover_tests(run_tests)
    endif()
endif()
EOF
fi

echo "✅ CMakeLists.txt 已成功產生！"