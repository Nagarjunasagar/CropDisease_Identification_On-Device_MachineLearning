add_library(cropdx_core STATIC
  src/image.cpp
  src/classifier.cpp)

target_include_directories(cropdx_core
  PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include
  PRIVATE ${PROJECT_SOURCE_DIR}/third_party/stb)

target_link_libraries(cropdx_core PUBLIC tensorflow-lite)
target_compile_features(cropdx_core PUBLIC cxx_std_17)
set_target_properties(cropdx_core PROPERTIES POSITION_INDEPENDENT_CODE ON)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  # third_party/stb is header-only and noisy; keep our own code strict
  set_source_files_properties(src/classifier.cpp PROPERTIES
    COMPILE_OPTIONS "-Wall;-Wextra;-Wpedantic")
endif()
