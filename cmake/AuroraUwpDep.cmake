include_guard(GLOBAL)

if (NOT AURORA_WINDOWS_STORE)
  return()
endif ()

if (NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "aurora: uwp-dep ships x64 binaries only.")
endif ()

option(AURORA_FETCH_UWP_DEP "Fetch uwp-dep (UWP SDL / Dawn / nod / libuwp)" ON)

if (NOT AURORA_FETCH_UWP_DEP)
  return()
endif ()

set(AURORA_UWP_DEP_SOURCE_DIR "" CACHE PATH
  "Path to a local uwp-dep checkout")

if (AURORA_UWP_DEP_SOURCE_DIR)
  get_filename_component(_aurora_uwp_dep_root "${AURORA_UWP_DEP_SOURCE_DIR}" REALPATH)
  if (NOT EXISTS "${_aurora_uwp_dep_root}/CMakeLists.txt")
    message(FATAL_ERROR "AURORA_UWP_DEP_SOURCE_DIR must be the uwp-dep repository root.")
  endif ()
  add_subdirectory("${_aurora_uwp_dep_root}" "${CMAKE_BINARY_DIR}/_aurora_uwp_dep" EXCLUDE_FROM_ALL)
  set(AURORA_UWP_DEP_ROOT "${_aurora_uwp_dep_root}" CACHE INTERNAL "SternXD/uwp-dep root")
else ()
  include(FetchContent)
  set(AURORA_UWP_DEP_REPOSITORY "https://github.com/SternXD/uwp-dep.git"
    CACHE STRING "Git repository for SternXD/uwp-dep")
  set(AURORA_UWP_DEP_TAG "dawnlight" CACHE STRING "Git tag or branch for SternXD/uwp-dep")
  FetchContent_Declare(aurora_uwp_dep
    GIT_REPOSITORY "${AURORA_UWP_DEP_REPOSITORY}"
    GIT_TAG "${AURORA_UWP_DEP_TAG}"
    GIT_SHALLOW TRUE
  )
  message(STATUS "aurora: Fetching uwp-dep (${AURORA_UWP_DEP_TAG})")
  FetchContent_MakeAvailable(aurora_uwp_dep)
  set(AURORA_UWP_DEP_ROOT "${aurora_uwp_dep_SOURCE_DIR}" CACHE INTERNAL "SternXD/uwp-dep root")
endif ()

set(_aurora_uwp_x64 "${AURORA_UWP_DEP_ROOT}/x64")
set(_aurora_uwp_dep_skip "")
if (EXISTS "${_aurora_uwp_x64}/lib/SDL3.lib"
    AND (AURORA_SDL3_PROVIDER STREQUAL "auto"
      OR AURORA_SDL3_PROVIDER STREQUAL "vendor"
      OR AURORA_SDL3_PROVIDER STREQUAL "package"))
  set(AURORA_SDL3_PROVIDER "uwp_dep" CACHE STRING "" FORCE)
  set(AURORA_SDL3_LINKAGE "shared" CACHE STRING "" FORCE)
elseif (EXISTS "${_aurora_uwp_x64}/lib/SDL3.lib" AND NOT AURORA_SDL3_PROVIDER STREQUAL "uwp_dep")
  list(APPEND _aurora_uwp_dep_skip "SDL3(${AURORA_SDL3_PROVIDER})")
endif ()
if (AURORA_ENABLE_GX AND EXISTS "${_aurora_uwp_x64}/lib/webgpu_dawn.lib"
    AND (AURORA_DAWN_PROVIDER STREQUAL "auto"
      OR AURORA_DAWN_PROVIDER STREQUAL "vendor"
      OR AURORA_DAWN_PROVIDER STREQUAL "package"))
  set(AURORA_DAWN_PROVIDER "uwp_dep" CACHE STRING "" FORCE)
  set(AURORA_DAWN_LINKAGE "shared" CACHE STRING "" FORCE)
elseif (AURORA_ENABLE_GX AND EXISTS "${_aurora_uwp_x64}/lib/webgpu_dawn.lib" AND NOT AURORA_DAWN_PROVIDER STREQUAL "uwp_dep")
  list(APPEND _aurora_uwp_dep_skip "Dawn(${AURORA_DAWN_PROVIDER})")
endif ()
if (AURORA_ENABLE_DVD AND EXISTS "${_aurora_uwp_x64}/lib/nod.lib"
    AND (AURORA_NOD_PROVIDER STREQUAL "auto"
      OR AURORA_NOD_PROVIDER STREQUAL "vendor"
      OR AURORA_NOD_PROVIDER STREQUAL "package"))
  set(AURORA_NOD_PROVIDER "uwp_dep" CACHE STRING "" FORCE)
  set(AURORA_NOD_LINKAGE "shared" CACHE STRING "" FORCE)
elseif (AURORA_ENABLE_DVD AND EXISTS "${_aurora_uwp_x64}/lib/nod.lib" AND NOT AURORA_NOD_PROVIDER STREQUAL "uwp_dep")
  list(APPEND _aurora_uwp_dep_skip "nod(${AURORA_NOD_PROVIDER})")
endif ()
if (_aurora_uwp_dep_skip)
  list(JOIN _aurora_uwp_dep_skip ", " _aurora_uwp_dep_skip_join)
  message(STATUS "aurora: uwp-dep prebuilts present; non-uwp_dep providers unchanged: ${_aurora_uwp_dep_skip_join} (set to auto to select uwp_dep)")
  unset(_aurora_uwp_dep_skip_join)
endif ()
unset(_aurora_uwp_dep_skip)
unset(_aurora_uwp_x64)

if (NOT TARGET LIBUWP)
  message(FATAL_ERROR "aurora: uwp-dep did not define imported target LIBUWP.")
endif ()

if (NOT TARGET aurora::uwp_dep)
  add_library(aurora::uwp_dep ALIAS LIBUWP)
endif ()
