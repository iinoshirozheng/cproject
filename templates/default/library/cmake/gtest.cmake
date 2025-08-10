option(BUILD_TESTS "Build unit tests" OFF)

if(BUILD_TESTS)
  include(CTest)
  find_package(GTest CONFIG QUIET)
  enable_testing()

  if(GTest_FOUND)
    add_executable(run_tests tests/basic_test.cpp)
    target_link_libraries(run_tests PRIVATE
      ${PROJECT_NAME}
      ${THIRD_PARTY_LIBS}
      GTest::gtest
      GTest::gtest_main
      GTest::gmock
      GTest::gmock_main
    )
    add_test(NAME all-tests COMMAND run_tests)
  else()
    message(STATUS "GTest not found; tests will be skipped unless provided")
    add_executable(${PROJECT_NAME}_example src/main.cpp)
    target_link_libraries(${PROJECT_NAME}_example PRIVATE ${PROJECT_NAME})
    add_test(NAME smoke COMMAND ${PROJECT_NAME}_example)
  endif()
endif()


