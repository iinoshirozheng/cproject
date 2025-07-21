function(ConfigureTests)
    # --- 修正開始 ---
    # 現在只檢查 BUILD_TESTS 這一個開關
    if(NOT BUILD_TESTS)
        message(STATUS "未啟用 BUILD_TESTS，跳過測試設定。")
        return()
    endif()
    # --- 修正結束 ---

    # 檢查 Google Test 是否能被找到
    find_package(GTest CONFIG REQUIRED)
    if(NOT GTest_FOUND)
        message(WARNING "找不到 GoogleTest (請用 brew install googletest 或確認安裝路徑)，測試目標未建立。")
        return()
    endif()

    enable_testing()
    file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/tests/*.cpp")

    if(TEST_SOURCES)
        message(STATUS "找到的測試源文件:")
        foreach(file IN LISTS TEST_SOURCES)
            message(STATUS "  ${file}")
        endforeach()

        add_executable(run_tests ${TEST_SOURCES})

        target_include_directories(run_tests PRIVATE
            ${CMAKE_SOURCE_DIR}/include
        )

        # 自動註冊 Google Test 測試案例
        include(GoogleTest)
        gtest_discover_tests(run_tests)
        
        message(STATUS "已建立測試目標: run_tests")
    else()
        message(STATUS "未找到測試源文件，測試目標未建立")
    endif()
endfunction()