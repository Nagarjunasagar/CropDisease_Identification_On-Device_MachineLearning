find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Multimedia)
qt_standard_project_setup()

qt_add_executable(cropdx-app
  main.cpp
  LeafAnalyzer.cpp LeafAnalyzer.hpp
  InferenceWorker.cpp InferenceWorker.hpp)

qt_add_qml_module(cropdx-app
  URI CropDx
  VERSION 1.0
  NO_RESOURCE_TARGET_PATH
  RESOURCE_PREFIX /CropDx
  QML_FILES
    qml/Main.qml
    qml/ScoreBar.qml
    qml/GuideSection.qml
    qml/StatTile.qml
    qml/PillButton.qml)

target_link_libraries(cropdx-app PRIVATE
  cropdx_core Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Multimedia)

# Keep a copy of the shared model artefacts next to the binary. A separate
# always-run target, so re-exported models are picked up without relinking.
set(_models ${PROJECT_SOURCE_DIR}/../models)
add_custom_target(cropdx_models ALL
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${_models} $<TARGET_FILE_DIR:cropdx-app>/models
  COMMENT "Syncing models/ next to cropdx-app")
add_dependencies(cropdx-app cropdx_models)

install(TARGETS cropdx-app RUNTIME DESTINATION bin)
install(DIRECTORY ${_models}/ DESTINATION share/cropdx/models)
