add_executable(cropdx-cli main.cpp)
target_link_libraries(cropdx-cli PRIVATE cropdx_core)
install(TARGETS cropdx-cli RUNTIME DESTINATION bin)
