cmake_minimum_required(VERSION 3.21)
project({{name}} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Control building tests from the outside (-DBUILD_TESTS=ON)
include(${CMAKE_SOURCE_DIR}/cmake/dependencies.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/gtest.cmake)

file(GLOB_RECURSE SOURCE_FILES CONFIGURE_DEPENDS "src/*.cpp")

add_executable(${PROJECT_NAME}
  ${SOURCE_FILES}
)

target_compile_definitions(${PROJECT_NAME} PRIVATE PROJECT_NAME="${PROJECT_NAME}")

target_link_libraries(${PROJECT_NAME} PRIVATE ${THIRD_PARTY_LIBS})

