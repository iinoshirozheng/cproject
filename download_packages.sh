#!/bin/bash

# Exit on error
set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_PREFIX="${SCRIPT_DIR}/third_party"
BUILD_DIR="${SCRIPT_DIR}/third_party_tmp"

# --- 函式：初始化目錄與 LinkThirdparty.cmake ---
setup_directories() {
    echo "🧹 清理並建立建置目錄..."
    rm -rf "${BUILD_DIR}" "${INSTALL_PREFIX}"
    mkdir -p "${BUILD_DIR}" "${INSTALL_PREFIX}"
    cd "${BUILD_DIR}"

    # 初始化 CMake 檔案
    cat > "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'
function(LinkThirdparty target_name)
    message(STATUS "LinkThirdparty module invoked for target '${target_name}'")
    if(NOT EXISTS "${THIRD_PARTY_DIR}")
        message(FATAL_ERROR "Thirdparty directory '${THIRD_PARTY_DIR}' does not exist!")
    endif()
EOL
}

# --- 函式：完成 LinkThirdparty.cmake ---
finalize_cmake_file() {
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'
endfunction()
EOL
    echo "✅ LinkThirdparty.cmake 已成功產生。"
    cd "${SCRIPT_DIR}"
    rm -rf "${BUILD_DIR}"
    echo "🗑️  臨時建置目錄已清理。"
}

# --- 函式：更新並清理 repo ---
update_repo() {
    local repo_dir=$1
    if [ -d "$repo_dir" ]; then
        echo "Updating $repo_dir..."
        cd "$repo_dir"
        git pull
        if [ -d "build" ]; then
            echo "Cleaning build directory..."
            rm -rf build
        fi
        cd ..
    fi
}

# --- 函式：clone and build hiredis ---
build_hiredis() {
    cd "${BUILD_DIR}"
    if [ ! -d "hiredis" ]; then
        echo "Cloning hiredis..."
        git clone https://github.com/redis/hiredis.git
    else
        update_repo "hiredis"
    fi
    
    cd hiredis
    make -j$(sysctl -n hw.ncpu)
    make PREFIX="${INSTALL_PREFIX}/hiredis" install
    cd ..

    # Add hiredis CMake configuration
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === Hiredis ===
    if(LINK_HIREDIS)
        message(STATUS "Linking hiredis (static)...")
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/hiredis/include)
        
        set(lib_file "libhiredis.a")
        if(EXISTS "${THIRD_PARTY_DIR}/hiredis/lib/${lib_file}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/hiredis/lib/${lib_file})
        elseif(EXISTS "${THIRD_PARTY_DIR}/hiredis/lib64/${lib_file}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/hiredis/lib64/${lib_file})
        else()
            message(FATAL_ERROR "hiredis library not found in lib/ or lib64/ directories")
        endif()
    endif()
EOL
}

# --- 函式：clone and build spdlog (header-only) ---
build_spdlog() {
    cd "${BUILD_DIR}"
    if [ ! -d "spdlog" ]; then
        echo "Cloning spdlog..."
        git clone https://github.com/gabime/spdlog.git
    else
        update_repo "spdlog"
    fi

    cd spdlog
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/spdlog" \
          -DSPDLOG_BUILD_SHARED=OFF \
          -DSPDLOG_BUILD_EXAMPLE=OFF \
          -DSPDLOG_BUILD_TESTS=OFF \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          -DCMAKE_BUILD_TYPE=Release \
          ..
    make -j$(sysctl -n hw.ncpu)
    make install
    cd ../../
    rm -rf spdlog

    # Add spdlog CMake configuration
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === spdlog ===
    if(LINK_SPDLOG)
        message(STATUS "Linking spdlog (static)...")
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/spdlog/include)
        
        set(lib_file "libspdlog.a")
        if(EXISTS "${THIRD_PARTY_DIR}/spdlog/lib/${lib_file}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/spdlog/lib/${lib_file})
        elseif(EXISTS "${THIRD_PARTY_DIR}/spdlog/lib64/${lib_file}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/spdlog/lib64/${lib_file})
        else()
            message(FATAL_ERROR "spdlog library not found in lib/ or lib64/ directories")
        endif()
    endif()
EOL
}

# --- 函式：clone and build gtest ---
build_gtest() {
    cd "${BUILD_DIR}"
    if [ ! -d "googletest" ]; then
        echo "Cloning googletest..."
        git clone https://github.com/google/googletest.git
    else
        update_repo "googletest"
    fi

    cd googletest
    mkdir -p build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/googletest" \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          -DBUILD_GMOCK=ON \
          -DBUILD_GTEST=ON \
          -DCMAKE_BUILD_TYPE=Release \
          ..
    make -j$(sysctl -n hw.ncpu)
    make install
    cd ../../
    rm -rf googletest

    # Add gtest CMake configuration
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === GoogleTest ===
    if(LINK_GTEST)
        message(STATUS "Linking GoogleTest...")
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/googletest/include)
        
        set(gtest_lib "libgtest.a")
        set(gtest_main_lib "libgtest_main.a")
        
        # Check for gtest library
        if(EXISTS "${THIRD_PARTY_DIR}/googletest/lib/${gtest_lib}")
            set(gtest_lib_path "${THIRD_PARTY_DIR}/googletest/lib/${gtest_lib}")
        elseif(EXISTS "${THIRD_PARTY_DIR}/googletest/lib64/${gtest_lib}")
            set(gtest_lib_path "${THIRD_PARTY_DIR}/googletest/lib64/${gtest_lib}")
        else()
            message(FATAL_ERROR "Google Test library not found in lib/ or lib64/ directories")
        endif()
        
        # Check for gtest_main library
        if(EXISTS "${THIRD_PARTY_DIR}/googletest/lib/${gtest_main_lib}")
            set(gtest_main_lib_path "${THIRD_PARTY_DIR}/googletest/lib/${gtest_main_lib}")
        elseif(EXISTS "${THIRD_PARTY_DIR}/googletest/lib64/${gtest_main_lib}")
            set(gtest_main_lib_path "${THIRD_PARTY_DIR}/googletest/lib64/${gtest_main_lib}")
        else()
            message(FATAL_ERROR "Google Test Main library not found in lib/ or lib64/ directories")
        endif()
        
        target_link_libraries(${target_name} PRIVATE
            ${gtest_lib_path}
            ${gtest_main_lib_path}
            pthread)
    endif()
EOL
}

# --- 函式：clone and build nlohmann json (header-only) ---
build_nlohmann_json() {
    cd "${BUILD_DIR}"
    if [ ! -d "nlohmann_json" ]; then
        echo "Cloning nlohmann/json..."
        git clone https://github.com/nlohmann/json.git nlohmann_json
    else
        update_repo "nlohmann_json"
    fi
    
    mkdir -p "${INSTALL_PREFIX}/nlohmann"
    cp -r nlohmann_json/single_include/nlohmann "${INSTALL_PREFIX}/"

    # Add nlohmann/json CMake configuration
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === nlohmann/json (Header-only) ===
    if(LINK_NLOHMANN_JSON)
        message(STATUS "Adding nlohmann/json support...")
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR})
    endif()
EOL
}

# --- 函式：clone and build loguru ---
build_loguru() {
    cd "${BUILD_DIR}"
    if [ ! -d "loguru" ]; then
        echo "Cloning loguru..."
        if ! git clone https://github.com/emilk/loguru.git; then
            echo "Error: Failed to clone loguru repository."
            return 1
        fi
    else
        echo "Updating loguru repository..."
        if ! (cd loguru && git pull); then
            echo "Warning: Failed to update loguru repository. Using existing version."
        fi
    fi
    
    # Define paths
    LOGURU_CLONE_DIR="loguru"
    LOGURU_DEST_DIR="${INSTALL_PREFIX}/loguru"
    LOGURU_CPP_FILE_NAME="loguru.cpp"
    LOGURU_HPP_FILE_NAME="loguru.hpp"
    LOGURU_CPP_DEST_PATH="${LOGURU_DEST_DIR}/${LOGURU_CPP_FILE_NAME}"

    mkdir -p "${LOGURU_DEST_DIR}"
    
    # Copy files
    echo "Copying loguru files to ${LOGURU_DEST_DIR}..."
    if ! cp -f "${LOGURU_CLONE_DIR}/${LOGURU_HPP_FILE_NAME}" "${LOGURU_DEST_DIR}/"; then
        echo "Error: Failed to copy ${LOGURU_HPP_FILE_NAME}."
        return 1
    fi
    if ! cp -f "${LOGURU_CLONE_DIR}/${LOGURU_CPP_FILE_NAME}" "${LOGURU_DEST_DIR}/"; then
        echo "Error: Failed to copy ${LOGURU_CPP_FILE_NAME}."
        return 1
    fi

    echo "Attempting to patch ${LOGURU_CPP_DEST_PATH} to increase level_buff size..."

    # --- SED PATCHING ---
    # 模式1: 查找 'char level_buff[<數字>];' 並將 <數字> 替換為 10
    # 我們假設 level_buff 的定義就在 snprintf 使用它的附近，或者是一個可識別的模式。
    # 並且假設原始大小是個位數或兩位數。
    # `\s*` 匹配零個或多個空格/制表符。 `\+` 匹配一個或多個。
    # `[0-9]\{1,2\}` 匹配 1 到 2 位數字。如果原始大小可能是3位數，則改為 \{1,3\}

    # 備份原始檔案
    cp "${LOGURU_CPP_DEST_PATH}" "${LOGURU_CPP_DEST_PATH}.orig_before_patch"

    # 這是 sed 命令。注意：sed 的語法在不同平台 (GNU vs BSD/macOS) 可能有差異。
    # 這個版本嘗試使用擴展正規表示式 (-E for GNU sed, -r for some older seds, macOS sed supports -E)
    # 並且直接修改檔案，創建 .bak 備份。
    # 模式解釋:
    # \(char\s\+level_buff\[\)   : 捕獲 "char " (一個以上空格) "level_buff[" 到 \1
    # [0-9]\{1,2\}              : 匹配 1 或 2 位數字 (原始大小)
    # \(\];\)                    : 捕獲 "];" 到 \2
    # 替換為: \1 (第一捕獲組) 10 \2 (第二捕獲組)
    
    # 為了更好的可移植性和清晰度，我們可以嘗試一個稍微不同的方法，或者使用 awk。
    # 以下是一個 sed 嘗試，如果失敗，我們會嘗試 awk。

    PATCH_SUCCEEDED=false
    # 嘗試 sed (macOS/BSD sed 通常需要 -E 選項用於擴展正則，且 -i 後面直接跟備份副檔名)
    # GNU sed -i 和 -E 選項可能略有不同
    echo "Trying sed to patch 'char level_buff[<size>];'..."
    if sed -E -i'.bak' 's/(char\s+level_buff\[)[0-9]+(\];)/\110\2/g' "${LOGURU_CPP_DEST_PATH}"; then
        if grep -q 'char\s*level_buff\[10\];' "${LOGURU_CPP_DEST_PATH}"; then
            echo "SED PATCH SUCCEEDED: 'char level_buff[10];' found."
            rm -f "${LOGURU_CPP_DEST_PATH}.bak" # 刪除 sed 創建的備份
            PATCH_SUCCEEDED=true
        else
            echo "SED command executed, but verification failed. 'char level_buff[10];' not found."
            echo "Original line might be different. Restoring from .bak (if exists) or .orig_before_patch."
            if [ -f "${LOGURU_CPP_DEST_PATH}.bak" ]; then
                mv "${LOGURU_CPP_DEST_PATH}.bak" "${LOGURU_CPP_DEST_PATH}"
            elif [ -f "${LOGURU_CPP_DEST_PATH}.orig_before_patch" ]; then # Fallback to original copy
                 mv "${LOGURU_CPP_DEST_PATH}.orig_before_patch" "${LOGURU_CPP_DEST_PATH}"
            fi
        fi
    else
        echo "SED command itself failed to execute."
        if [ -f "${LOGURU_CPP_DEST_PATH}.bak" ]; then # 如果 sed 失敗但創建了 .bak
            mv "${LOGURU_CPP_DEST_PATH}.bak" "${LOGURU_CPP_DEST_PATH}"
        elif [ -f "${LOGURU_CPP_DEST_PATH}.orig_before_patch" ]; then
             mv "${LOGURU_CPP_DEST_PATH}.orig_before_patch" "${LOGURU_CPP_DEST_PATH}"
        fi
    fi

    # 如果 sed 失敗，可以嘗試 awk 作為備選方案 (更複雜，但更強大)
    if [ "$PATCH_SUCCEEDED" = false ]; then
        echo "SED patch failed or verification failed. Attempting AWK patch..."
        # 將原始檔案複製回來，以便 awk 在乾淨的檔案上操作
        cp "${LOGURU_CPP_DEST_PATH}.orig_before_patch" "${LOGURU_CPP_DEST_PATH}"

        # awk 命令：如果一行包含 "char" 和 "level_buff[" 並且包含 "];"，則替換中間的數字
        # gsub(\[[0-9]+\];, "[10];", current_line)
        # 這個 awk 命令會創建一個新檔案，然後替換原檔案
        awk '
        /char/ && /level_buff\[/ && /\];/ {
            # 找到包含 "char" "level_buff[" 和 "];" 的行
            # 嘗試替換 level_buff[數字] 為 level_buff[10]
            # $0 代表整行
            if (sub(/level_buff\[[0-9]+\];/, "level_buff[10];", $0)) {
                print "AWK: Patched line: " $0 > "/dev/stderr" # 打印到 stderr 進行調試
            }
        }
        { print $0 } # 打印每一行（修改過的或未修改的）
        ' "${LOGURU_CPP_DEST_PATH}" > "${LOGURU_CPP_DEST_PATH}.awk_tmp"

        if [ $? -eq 0 ] && [ -s "${LOGURU_CPP_DEST_PATH}.awk_tmp" ]; then
            if grep -q 'char\s*level_buff\[10\];' "${LOGURU_CPP_DEST_PATH}.awk_tmp"; then
                mv "${LOGURU_CPP_DEST_PATH}.awk_tmp" "${LOGURU_CPP_DEST_PATH}"
                echo "AWK PATCH SUCCEEDED."
                PATCH_SUCCEEDED=true
            else
                echo "AWK command executed, but verification failed. 'char level_buff[10];' not found in awk output."
                rm -f "${LOGURU_CPP_DEST_PATH}.awk_tmp"
                # 保留 .orig_before_patch, 不還原，以便用戶檢查
            fi
        else
            echo "AWK command failed or produced an empty file."
            rm -f "${LOGURU_CPP_DEST_PATH}.awk_tmp"
            # 保留 .orig_before_patch
        fi
    fi
    
    # 清理原始備份
    if [ "$PATCH_SUCCEEDED" = true ]; then
        rm -f "${LOGURU_CPP_DEST_PATH}.orig_before_patch"
    else
        echo "------------------------------------------------------------------"
        echo "PATCHING FAILED for ${LOGURU_CPP_DEST_PATH}."
        echo "The original unpatched file is: ${LOGURU_CPP_DEST_PATH}.orig_before_patch"
        echo "Please manually inspect and modify the definition of 'level_buff' in:"
        echo "${LOGURU_CPP_DEST_PATH}"
        echo "You need to find a line like 'char level_buff[<size>];' and change <size> to 10 or more."
        echo "The problematic snprintf call is near line 1328."
        echo "------------------------------------------------------------------"
        # return 1 # 取決於你是否希望在補丁失敗時停止整個腳本
    fi


    # Add loguru CMake configuration (保持不變)
    if ! grep -q "Using Loguru for logging..." "${INSTALL_PREFIX}/LinkThirdparty.cmake"; then
        echo "Adding Loguru configuration to LinkThirdparty.cmake..."
        cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === Loguru (Header-only, but we compile .cpp too) ===
    if(LINK_LOGURU)
        message(STATUS "Using Loguru for logging...")
        target_sources(${target_name} PRIVATE ${THIRD_PARTY_DIR}/loguru/loguru.cpp)
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/loguru)
    endif()
EOL
    else
        echo "Loguru configuration already exists in LinkThirdparty.cmake."
    fi
}

# --- 函式：clone and build poco ---
build_poco() {
    cd "${BUILD_DIR}"
    if [ ! -d "poco" ]; then
        echo "Cloning Poco..."
        git clone https://github.com/pocoproject/poco.git
    else
        update_repo "poco"
    fi
    
    cd poco
    mkdir cmake-build && cd cmake-build
    cmake -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/poco" \
          -DENABLE_TESTS=OFF \
          -DENABLE_SAMPLES=OFF \
          -DBUILD_SHARED_LIBS=OFF \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          ..
    make -j1
    make install
    cd ../../..

    # Add Poco CMake configuration
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === Poco ===
    if(LINK_POCO)
        message(STATUS "Linking Poco libraries (static)...")

        # 注意依賴順序由上往下
        set(PocoModules
            Net
            JSON
            Util
            XML
            Crypto
            Data
            Encodings
            Foundation
        )

        set(DETECTED_POCO_MODULES "")
        foreach(module ${PocoModules})
            set(lib_file "libPoco${module}.a")
            if(EXISTS "${THIRD_PARTY_DIR}/poco/lib/${lib_file}")
                list(APPEND DETECTED_POCO_MODULES ${module})
                set(POCO_${module}_LIB_PATH "${THIRD_PARTY_DIR}/poco/lib/${lib_file}")
            elseif(EXISTS "${THIRD_PARTY_DIR}/poco/lib64/${lib_file}")
                list(APPEND DETECTED_POCO_MODULES ${module})
                set(POCO_${module}_LIB_PATH "${THIRD_PARTY_DIR}/poco/lib64/${lib_file}")
            endif()
        endforeach()

        message(STATUS "Detected Poco Modules (ordered): ${DETECTED_POCO_MODULES}")
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/poco/include)

        foreach(module ${DETECTED_POCO_MODULES})
            target_link_libraries(${target_name} PRIVATE "${POCO_${module}_LIB_PATH}")
            message(STATUS "Linked Poco${module} (static)")
        endforeach()

        target_link_libraries(${target_name} PRIVATE pthread dl)
    endif()
EOL
}

# --- 函式：clone and build redis-plus-plus ---
build_redis_plus_plus() {
    cd "${BUILD_DIR}"
    if [ ! -d "redis-plus-plus" ]; then
        echo "Cloning redis-plus-plus..."
        git clone https://github.com/sewenew/redis-plus-plus.git
    else
        update_repo "redis-plus-plus"
    fi
    
    cd redis-plus-plus
    mkdir -p build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/redis-plus-plus" \
          -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}/hiredis" \
          -DREDIS_PLUS_PLUS_CXX_STANDARD=17 \
          -DREDIS_PLUS_PLUS_BUILD_TEST=OFF \
          -DREDIS_PLUS_PLUS_BUILD_SHARED=OFF \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          -DCMAKE_BUILD_TYPE=Release \
          ..
    make -j$(sysctl -n hw.ncpu)
    make install
    cd ../../
    rm -rf redis-plus-plus

    # Add redis-plus-plus CMake configuration
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === redis-plus-plus ===
    if(LINK_REDIS_PLUS_PLUS)

        message(STATUS "Linking hiredis (static)...")
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/hiredis/include)
        
        set(hiredis_lib "libhiredis.a")
        if(EXISTS "${THIRD_PARTY_DIR}/hiredis/lib/${hiredis_lib}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/hiredis/lib/${hiredis_lib})
        elseif(EXISTS "${THIRD_PARTY_DIR}/hiredis/lib64/${hiredis_lib}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/hiredis/lib64/${hiredis_lib})
        else()
            message(FATAL_ERROR "hiredis library not found in lib/ or lib64/ directories")
        endif()

        message(STATUS "Linking redis-plus-plus (static)...")
        # Make sure hiredis is linked first as it's a dependency
        if(NOT LINK_HIREDIS)
            message(FATAL_ERROR "redis-plus-plus requires hiredis, please enable LINK_HIREDIS")
        endif()
        
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/redis-plus-plus/include)
        
        set(redis_lib "libredis++.a")
        if(EXISTS "${THIRD_PARTY_DIR}/redis-plus-plus/lib/${redis_lib}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/redis-plus-plus/lib/${redis_lib})
        elseif(EXISTS "${THIRD_PARTY_DIR}/redis-plus-plus/lib64/${redis_lib}")
            target_link_libraries(${target_name} PRIVATE ${THIRD_PARTY_DIR}/redis-plus-plus/lib64/${redis_lib})
        else()
            message(FATAL_ERROR "redis-plus-plus library not found in lib/ or lib64/ directories")
        endif()
    endif()
EOL
}

# Function to add pthread and dl linking options
add_pthread_and_dl_link() {
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === Pthread & DL (Dynamic Linking Library) ===
    # This section provides an explicit option to link pthread and dl.
    # Note: Other libraries might already link these implicitly.
    # CMake is generally good at handling duplicate link requests for system libraries.

    if(LINK_THREAD)
        message(STATUS "Explicitly linking Pthread...")
        find_package(Threads QUIET)
        if(Threads_FOUND)
            target_link_libraries(${target_name} PRIVATE Threads::Threads)
            message(STATUS "Linked Threads::Threads (via find_package)")
        else()
            message(WARNING "Threads package not found by CMake, linking pthread directly.")
            target_link_libraries(${target_name} PRIVATE pthread)
            message(STATUS "Linked pthread (directly)")
        endif()
    endif()

    # DL Library for dladdr, dlopen, etc.
    # Often needed by logging libraries for stack traces or by plugin systems.
    if(LINK_DL) # 新增一個 LINK_DL 變數來控制是否連結 libdl
        message(STATUS "Explicitly linking DL library...")
        # On most Unix-like systems (Linux, macOS), libdl is just 'dl'
        # CMake doesn't have a standard find_package module for libdl like it does for Threads,
        # as linking 'dl' directly is common and portable enough for these systems.
        target_link_libraries(${target_name} PRIVATE dl)
        message(STATUS "Linked dl library (directly)")
    endif()
EOL
}

# --- 新增：編譯 libxml2 ---
build_libxml2() {
    echo "--- 正在下載與編譯 libxml2 ---"
    cd "${BUILD_DIR}"
    git clone https://gitlab.gnome.org/GNOME/libxml2.git
    cd libxml2
    # autoreconf is needed if autogen.sh is not present or fails
    autoreconf -fiv
    # 設定 CFLAGS=-fPIC 確保產生的函式庫是位置無關碼，這對於後續連結很重要
    ./configure CFLAGS="-fPIC" --prefix="${INSTALL_PREFIX}/libxml2" --without-python --disable-shared
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)
    make install
    cd ..
    
    # 將 libxml2 的連結邏輯加入到 LinkThirdparty.cmake
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === libxml2 ===
    if(LINK_LIBXML2)
        message(STATUS "Linking libxml2 (static)...")
        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/libxml2/include/libxml2)
        find_library(LIBXML2_LIBRARY NAMES libxml2.a PATHS ${THIRD_PARTY_DIR}/libxml2/lib NO_DEFAULT_PATH)
        if(LIBXML2_LIBRARY)
            target_link_libraries(${target_name} PRIVATE ${LIBXML2_LIBRARY})
        else()
            message(FATAL_ERROR "libxml2 library not found in ${THIRD_PARTY_DIR}/libxml2/lib")
        endif()
    endif()
EOL
}

# --- 新增：編譯 libcurl ---
build_curl() {
    echo "--- 正在下載與編譯 libcurl ---"
    cd "${BUILD_DIR}"
    git clone https://github.com/curl/curl.git
    cd curl
    mkdir -p build && cd build
    # 設定 PKG_CONFIG_PATH，讓 curl 的 cmake 腳本可以找到我們剛剛編譯好的 libxml2
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/libxml2/lib/pkgconfig"
    cmake -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/curl" \
          -DBUILD_SHARED_LIBS=OFF \
          -DCURL_USE_OPENSSL=ON \
          -DCURL_DISABLE_LDAP=ON \
          -DCURL_DISABLE_LDAPS=ON \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          ..
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)
    make install
    cd ../..

    # 將 curl 的連結邏輯加入到 LinkThirdparty.cmake
    cat >> "${INSTALL_PREFIX}/LinkThirdparty.cmake" << 'EOL'

    # === cURL ===
    if(LINK_CURL)
        message(STATUS "Linking curl (static)...")
        # 尋找 OpenSSL 和 Zlib，因為 libcurl 依賴它們
        find_package(OpenSSL REQUIRED)
        find_package(ZLIB REQUIRED)

        target_include_directories(${target_name} PRIVATE ${THIRD_PARTY_DIR}/curl/include)
        find_library(LIBCURL_LIBRARY NAMES libcurl.a PATHS ${THIRD_PARTY_DIR}/curl/lib NO_DEFAULT_PATH)
        if(LIBCURL_LIBRARY)
            target_link_libraries(${target_name} PRIVATE 
                ${LIBCURL_LIBRARY}
                OpenSSL::SSL
                OpenSSL::Crypto
                ${ZLIB_LIBRARY}
            )
        else()
            message(FATAL_ERROR "libcurl library not found in ${THIRD_PARTY_DIR}/curl/lib")
        endif()
    endif()
EOL
}


# --- 函式：main function ---
main() {
    setup_directories

    #Clone and build all dependencies
    build_hiredis
    build_nlohmann_json
    build_loguru
    build_poco
    build_redis_plus_plus
    build_spdlog
    build_gtest
    build_libxml2
    build_curl
    
    # Add the explicit pthread linking option to LinkThirdparty.cmake
    add_pthread_and_dl_link

    finalize_cmake_file

    echo "All dependencies successfully built and installed to ${INSTALL_PREFIX}!"
}

# Execute main function
main 