function(ConfigureTests)
    if(NOT BUILD_TESTS OR NOT LINK_GTEST)
        return()
    endif()

    enable_testing()
    file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/tests/*.cpp)

    if(TEST_SOURCES)
        message(STATUS "找到的測試源文件:")
        foreach(file IN LISTS TEST_SOURCES)
            message(STATUS "  ${file}")
        endforeach()

        add_executable(run_tests ${TEST_SOURCES})

        # 為 run_tests 目標加入必要的 include 路徑
        # 這樣它才能找到函式庫的 .h 檔案
        target_include_directories(run_tests PRIVATE
            ${CMAKE_SOURCE_DIR}/include
            ${CMAKE_SOURCE_DIR}/src
        )

        # 第三方靜態連結
        LinkThirdparty(run_tests)

        # 自動註冊 Google Test 測試案例
        include(GoogleTest)
        gtest_discover_tests(run_tests)

        # 為了相容性，也加入一個簡單的 add_test
        add_test(NAME AllTests COMMAND run_tests)
        
        message(STATUS "已建立測試目標: run_tests")
    else()
        message(STATUS "未找到測試源文件，測試目標未建立")
    endif()
endfunction()