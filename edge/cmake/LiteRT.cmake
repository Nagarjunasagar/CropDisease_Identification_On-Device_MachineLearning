# LiteRT (TensorFlow Lite) C++ runtime.
#
# Two ways to provide it:
#   1. CROPDX_TF_SOURCE_DIR=<path to a tensorflow checkout>  (default: fetched)
#      The runtime is compiled from source with TFLite's own CMake build, which
#      is the officially supported way to embed LiteRT in a C++ application.
#   2. Leave it unset and the matching TensorFlow release is fetched with git.
#
# Any of TFLite's third-party dependencies can be pointed at a local checkout
# with -DFETCHCONTENT_SOURCE_DIR_<NAME>=<dir> (useful for offline or mirrored
# builds, e.g. EIGEN, FFT2D, NEON2SSE).

set(CROPDX_TF_VERSION "v2.21.0" CACHE STRING "TensorFlow release that provides LiteRT")
set(CROPDX_TF_SOURCE_DIR "" CACHE PATH "Existing TensorFlow source checkout (optional)")

if(NOT CROPDX_TF_SOURCE_DIR)
  include(FetchContent)
  FetchContent_Declare(tensorflow
    GIT_REPOSITORY https://github.com/tensorflow/tensorflow.git
    GIT_TAG        ${CROPDX_TF_VERSION}
    GIT_SHALLOW    TRUE
    GIT_PROGRESS   TRUE
    SOURCE_SUBDIR  tensorflow/lite/__no_auto_add__)
  FetchContent_MakeAvailable(tensorflow)
  set(CROPDX_TF_SOURCE_DIR ${tensorflow_SOURCE_DIR})
endif()

# Tell TFLite's CMake where the source tree is; otherwise it silently fetches
# its own (older) copy of TensorFlow into the build directory.
set(TENSORFLOW_SOURCE_DIR ${CROPDX_TF_SOURCE_DIR} CACHE PATH "" FORCE)

# Keep the runtime lean: CPU only, XNNPACK on (fast float + int8 kernels).
set(TFLITE_ENABLE_XNNPACK ON  CACHE BOOL "" FORCE)
set(TFLITE_ENABLE_GPU     OFF CACHE BOOL "" FORCE)
set(TFLITE_ENABLE_RUY     ON  CACHE BOOL "" FORCE)
set(TFLITE_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)

add_subdirectory(
  ${CROPDX_TF_SOURCE_DIR}/tensorflow/lite
  ${CMAKE_BINARY_DIR}/litert
  EXCLUDE_FROM_ALL)

# Treat LiteRT/TensorFlow headers as system headers so our -Wall -Wextra
# warnings only report on this project's code.
get_target_property(_litert_inc tensorflow-lite INTERFACE_INCLUDE_DIRECTORIES)
set_target_properties(tensorflow-lite PROPERTIES INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${_litert_inc}")
