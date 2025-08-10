cmake_minimum_required(VERSION 3.21)
project({{name}} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(${CMAKE_SOURCE_DIR}/cmake/dependencies.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/gtest.cmake)

file(GLOB_RECURSE ALL_SRC_FILES CONFIGURE_DEPENDS "src/*.cpp")
set(EXAMPLE_SRC_FILES src/main.cpp)

list(REMOVE_ITEM ALL_SRC_FILES ${EXAMPLE_SRC_FILES})
set(LIB_SRC_FILES ${ALL_SRC_FILES})

add_library(${PROJECT_NAME}
  ${LIB_SRC_FILES}
)

target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME} PUBLIC ${THIRD_PARTY_LIBS})

add_executable(${PROJECT_NAME}_example src/main.cpp)
target_link_libraries(${PROJECT_NAME}_example PRIVATE ${PROJECT_NAME})

