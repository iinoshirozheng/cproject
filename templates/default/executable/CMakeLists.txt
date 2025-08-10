cmake_minimum_required(VERSION 3.21)
project({{name}} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Dependencies (vcpkg targets appended to THIRD_PARTY_LIBS)
include(${CMAKE_SOURCE_DIR}/cmake/dependencies.cmake)

add_executable(${PROJECT_NAME}
  src/main.cpp
)

target_compile_definitions(${PROJECT_NAME} PRIVATE PROJECT_NAME="${PROJECT_NAME}")

target_link_libraries(${PROJECT_NAME} PRIVATE ${THIRD_PARTY_LIBS})

enable_testing()
add_test(NAME smoke COMMAND ${PROJECT_NAME})
