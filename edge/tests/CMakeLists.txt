add_executable(test_core test_core.cpp)
target_link_libraries(test_core PRIVATE cropdx_core)

add_test(NAME core_unit COMMAND test_core)

set(_models ${PROJECT_SOURCE_DIR}/../models)
if(EXISTS ${_models}/crop_disease_int8.tflite AND EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/data/golden_int8.txt)
  add_test(NAME core_parity_int8
    COMMAND test_core ${_models}/crop_disease_int8.tflite ${_models}/labels.txt
            ${CMAKE_CURRENT_SOURCE_DIR}/data/golden_int8.txt
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data)
endif()
