cmake_minimum_required(VERSION 3.21)
project({{name}} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(${CMAKE_SOURCE_DIR}/cmake/dependencies.cmake)

add_library({{name}}
  src/{{name}}.cpp
)
target_include_directories({{name}} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries({{name}} PUBLIC ${THIRD_PARTY_LIBS})

add_executable({{name}}_example src/main.cpp)
target_link_libraries({{name}}_example PRIVATE {{name}})

enable_testing()
add_test(NAME smoke COMMAND {{name}}_example)
