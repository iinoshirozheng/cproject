cmake_minimum_required(VERSION 3.21)
project({{name}} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Dependencies (vcpkg targets appended to THIRD_PARTY_LIBS)
include(${CMAKE_SOURCE_DIR}/cmake/dependencies.cmake)

add_executable({{name}}
  src/main.cpp
)

target_link_libraries({{name}} PRIVATE ${THIRD_PARTY_LIBS})

enable_testing()
add_test(NAME smoke COMMAND {{name}})
