function(DefineGlobalOptions)
    # --- 步驟 1: 設定 C++ 標準 ---
    set(CMAKE_CXX_STANDARD 17 PARENT_SCOPE)
    set(CMAKE_CXX_STANDARD_REQUIRED ON PARENT_SCOPE)
    set(CMAKE_CXX_EXTENSIONS OFF PARENT_SCOPE)

    # --- 步驟 2: 設定全域編譯旗標 ---
    message(STATUS "正在設定全域編譯旗標...")
    add_compile_options(
        -Wall
        -Wextra
        -Wpedantic
        -Wformat=2
        -Wunused-parameter
        -Wno-missing-field-initializers
        -fPIC
    )
    add_compile_options($<$<CONFIG:Debug>:-g -O0>)
    add_compile_options($<$<CONFIG:Release>:-O3 -DNDEBUG>)
    
    # --- 步驟 3: 專案選項 ---
    option(BUILD_TESTS "Build unit tests" OFF)

    message(STATUS "C++ 標準: ${CMAKE_CXX_STANDARD}")
    message(STATUS "建置測試: ${BUILD_TESTS}")
endfunction()