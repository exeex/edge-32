cmake_minimum_required(VERSION 3.20)
project(edge_32 LANGUAGES NONE)

# edge-32 owns synthesizable RTL and public instruction headers. Simulation,
# software-image construction, and verification targets are owned by test-32.
set(EDGE32_RTL_ROOT "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL
    "Edge32 synthesizable RTL package root")

file(GLOB_RECURSE EDGE32_RTL_SOURCES CONFIGURE_DEPENDS
  "${EDGE32_RTL_ROOT}/rtl/*.v")
add_custom_target(edge32_rtl_sources SOURCES ${EDGE32_RTL_SOURCES})
