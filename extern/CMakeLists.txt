include(FetchContent)

# Don't build tests for third party dependencies
set(BUILD_TESTING OFF CACHE INTERNAL "Build tests")
set(SKIP_INSTALL_ALL ON)
if (NOT DEFINED BUILD_SHARED_LIBS)
  set(_USE_SHARED ON)
else ()
  set(_USE_SHARED OFF)
endif ()

function(aurora_find_package_global)
  set(_PREV_FIND_PACKAGE_TARGETS_GLOBAL ${CMAKE_FIND_PACKAGE_TARGETS_GLOBAL})
  set(CMAKE_FIND_PACKAGE_TARGETS_GLOBAL ON)
  find_package(${ARGV})
  set(CMAKE_FIND_PACKAGE_TARGETS_GLOBAL ${_PREV_FIND_PACKAGE_TARGETS_GLOBAL})
endfunction()

if (AURORA_WINDOWS_STORE)
  include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/AuroraUwpDep.cmake)
endif ()

if (AURORA_ENABLE_GX)
  include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/AuroraDawnProvider.cmake)
endif ()

# Abseil is needed for core libraries. It normally comes via Dawn's vendor build.
# Otherwise prefer a system package and only fetch it as a last resort.
if (NOT TARGET absl::flat_hash_map OR NOT TARGET absl::btree)
  aurora_find_package_global(absl CONFIG QUIET GLOBAL)
endif ()

if (TARGET absl::flat_hash_map AND TARGET absl::btree)
  message(STATUS "aurora: Using system/existing abseil")
else ()
  message(STATUS "aurora: Fetching abseil-cpp (standalone)")
  if(NOT DEFINED CMAKE_MSVC_RUNTIME_LIBRARY OR CMAKE_MSVC_RUNTIME_LIBRARY MATCHES "DLL$")
    set(ABSL_MSVC_STATIC_RUNTIME OFF CACHE INTERNAL "Link static runtime libraries")
  else()
    set(ABSL_MSVC_STATIC_RUNTIME ON CACHE INTERNAL "Link static runtime libraries")
  endif()
  set(ABSL_PROPAGATE_CXX_STD ON)
  FetchContent_Declare(abseil-cpp
    URL https://github.com/abseil/abseil-cpp/archive/refs/tags/20240722.0.tar.gz
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    EXCLUDE_FROM_ALL
  )
  FetchContent_MakeAvailable(abseil-cpp)
  if (NOT TARGET absl::flat_hash_map OR NOT TARGET absl::btree)
    message(FATAL_ERROR "Failed to make abseil-cpp available")
  endif ()
endif ()

include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/AuroraSDL3Provider.cmake)

if (NOT TARGET xxhash)
  message(STATUS "aurora: Fetching xxhash")
  FetchContent_Declare(xxhash
    URL https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.3.tar.gz
    URL_HASH SHA256=aae608dfe8213dfd05d909a57718ef82f30722c392344583d3f39050c7f29a80
    SOURCE_SUBDIR cmake_unofficial
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    EXCLUDE_FROM_ALL
  )
  set(XXHASH_BUILD_XXHSUM OFF CACHE INTERNAL "Build the xxhsum binary")
  # xxhash uses CMAKE_DEPENDENT_OPTION(BUILD_SHARED_LIBS ...) which writes
  # a sticky CACHE INTERNAL entry on reconfigure. Undo it afterward.
  set(_aurora_xxhash_saved_bsl "${BUILD_SHARED_LIBS}")
  FetchContent_MakeAvailable(xxhash)
  unset(BUILD_SHARED_LIBS CACHE)
  set(BUILD_SHARED_LIBS "${_aurora_xxhash_saved_bsl}")
  unset(_aurora_xxhash_saved_bsl)
  if (NOT TARGET xxhash)
    message(FATAL_ERROR "Failed to make xxhash available")
  endif ()
else ()
  message(STATUS "aurora: Using existing xxhash")
endif ()

if (NOT TARGET fmt)
  message(STATUS "aurora: Fetching fmt")
  FetchContent_Declare(fmt
    URL https://github.com/fmtlib/fmt/archive/refs/tags/11.1.4.tar.gz
    URL_HASH SHA256=ac366b7b4c2e9f0dde63a59b3feb5ee59b67974b14ee5dc9ea8ad78aa2c1ee1e
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    EXCLUDE_FROM_ALL
  )
  FetchContent_MakeAvailable(fmt)
  if (NOT TARGET fmt)
    message(FATAL_ERROR "Failed to make fmt available")
  endif ()
else ()
  message(STATUS "aurora: Using existing fmt")
endif ()

if (AURORA_ENABLE_GX)
  set(_u "")
  if (AURORA_WINDOWS_STORE AND DEFINED AURORA_UWP_DEP_ROOT)
    set(_u "${AURORA_UWP_DEP_ROOT}/x64")
  endif ()
  if (_u AND EXISTS "${_u}/lib/z.lib" AND EXISTS "${_u}/lib/libpng16.lib" AND NOT TARGET zlib_uwp_depot)
    message(STATUS "aurora: zlib and libpng from uwp-dep (${AURORA_UWP_DEP_ROOT})")
    add_library(zlib_uwp_depot SHARED IMPORTED GLOBAL)
    set_target_properties(zlib_uwp_depot PROPERTIES
      IMPORTED_LOCATION "${_u}/bin/z.dll"
      IMPORTED_IMPLIB "${_u}/lib/z.lib"
      INTERFACE_INCLUDE_DIRECTORIES "${_u}/include")
    add_library(ZLIB::ZLIB ALIAS zlib_uwp_depot)
    add_library(libpng16_uwp_depot SHARED IMPORTED GLOBAL)
    set_target_properties(libpng16_uwp_depot PROPERTIES
      IMPORTED_LOCATION "${_u}/bin/libpng16.dll"
      IMPORTED_IMPLIB "${_u}/lib/libpng16.lib"
      INTERFACE_INCLUDE_DIRECTORIES "${_u}/include;${_u}/include/libpng16"
      INTERFACE_LINK_LIBRARIES ZLIB::ZLIB)
    add_library(PNG::PNG ALIAS libpng16_uwp_depot)
  endif ()
  unset(_u)

  if (NOT TARGET ZLIB::ZLIB)
    aurora_find_package_global(ZLIB QUIET)
  endif ()
  if (NOT TARGET ZLIB::ZLIB)
    message(STATUS "aurora: Fetching zlib")
    set(ZLIB_BUILD_SHARED ${_USE_SHARED} CACHE BOOL "Enable building zlib shared library" FORCE)
    set(ZLIB_BUILD_TESTING OFF CACHE BOOL "Enable Zlib Examples as tests" FORCE)
    set(ZLIB_INSTALL OFF CACHE BOOL "Enable installation of zlib" FORCE)
    FetchContent_Declare(
      ZLIB
      URL https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz
      URL_HASH SHA256=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
      DOWNLOAD_EXTRACT_TIMESTAMP TRUE
      EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(ZLIB)
    if (NOT TARGET ZLIB::ZLIB)
      message(FATAL_ERROR "Failed to make zlib available")
    endif ()
    # libpng calls find_package(ZLIB) even when zlib was already provided by FetchContent.
    file(WRITE "${CMAKE_FIND_PACKAGE_REDIRECTS_DIR}/ZLIBConfig.cmake"
      "set(ZLIB_FOUND TRUE)\n"
      "set(ZLIB_INCLUDE_DIR \"${zlib_SOURCE_DIR}\")\n"
      "set(ZLIB_INCLUDE_DIRS \"${zlib_BINARY_DIR};${zlib_SOURCE_DIR}\")\n"
    )
  endif ()

  if (NOT TARGET PNG::PNG)
    if (TARGET png_shared AND _USE_SHARED)
      add_library(PNG::PNG ALIAS png_shared)
    elseif (TARGET png_static)
      add_library(PNG::PNG ALIAS png_static)
    else ()
      aurora_find_package_global(PNG QUIET)
    endif ()
  endif ()
  if (NOT TARGET PNG::PNG)
    message(STATUS "aurora: Fetching libpng")
    set(PNG_SHARED ${_USE_SHARED} CACHE BOOL "Build libpng as a shared library" FORCE)
    set(PNG_TESTS OFF CACHE BOOL "Build the libpng tests" FORCE)
    set(PNG_TOOLS OFF CACHE BOOL "Build the libpng tools" FORCE)
    FetchContent_Declare(
      PNG
      URL https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.58.tar.gz
      URL_HASH SHA256=A9D4DF463D36A6E5F9C29BD6F4967312D17E996C1854F3511F833924EB1993CF
      DOWNLOAD_EXTRACT_TIMESTAMP TRUE
      EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(PNG)
    if (TARGET png_shared AND _USE_SHARED)
      add_library(PNG::PNG ALIAS png_shared)
    elseif (TARGET png_static)
      add_library(PNG::PNG ALIAS png_static)
    else ()
      message(FATAL_ERROR "Failed to make libpng available")
    endif ()
  else ()
    message(STATUS "aurora: Using existing libpng")
  endif ()
  if (AURORA_WINDOWS_STORE AND MSVC)
    foreach (_aurora_png IN ITEMS png_shared png_static)
      if (TARGET ${_aurora_png})
        target_compile_options(${_aurora_png} PRIVATE /wd4146)
      endif ()
    endforeach ()
    unset(_aurora_png)
  endif ()

  aurora_find_package_global(Freetype QUIET)
  if (NOT TARGET Freetype::Freetype)
    message(STATUS "aurora: Fetching Freetype")
    set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
    set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "" FORCE)
    set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
    FetchContent_Declare(Freetype
      URL https://files.twilitrealm.dev/freetype-2.14.3.tar.gz
      URL_HASH SHA256=e61b31ab26358b946e767ed7eb7f4bb2e507da1cfefeb7a8861ace7fd5c899a1
      DOWNLOAD_EXTRACT_TIMESTAMP TRUE
      EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(Freetype)
    add_library(Freetype::Freetype ALIAS freetype)
  else ()
    message(STATUS "aurora: Using existing Freetype")
  endif ()

  if (NOT TARGET imgui)
    message(STATUS "aurora: Fetching imgui")
    FetchContent_Declare(imgui
      URL https://github.com/ocornut/imgui/archive/refs/tags/v1.91.9b-docking.tar.gz
      URL_HASH SHA256=466fdef9b18de15f0bb6e288e3d00ffa3d82200ec458ce5e4f724a161d9528a5
      DOWNLOAD_EXTRACT_TIMESTAMP TRUE
      EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(imgui)

    add_library(imgui STATIC
      ${imgui_SOURCE_DIR}/imgui.cpp
      ${imgui_SOURCE_DIR}/imgui_demo.cpp
      ${imgui_SOURCE_DIR}/imgui_draw.cpp
      ${imgui_SOURCE_DIR}/imgui_tables.cpp
      ${imgui_SOURCE_DIR}/imgui_widgets.cpp
      ${imgui_SOURCE_DIR}/misc/cpp/imgui_stdlib.cpp
    )
    target_include_directories(imgui PUBLIC ${imgui_SOURCE_DIR})

    add_library(imgui_backends STATIC
      ${imgui_SOURCE_DIR}/backends/imgui_impl_sdl3.cpp
      ${imgui_SOURCE_DIR}/backends/imgui_impl_sdlrenderer3.cpp
      ${imgui_SOURCE_DIR}/backends/imgui_impl_wgpu.cpp
    )
    target_compile_definitions(imgui_backends PRIVATE IMGUI_IMPL_WEBGPU_BACKEND_DAWN)
    target_link_libraries(imgui_backends PRIVATE imgui ${AURORA_SDL3_TARGET} dawn::webgpu_dawn)
    target_link_libraries(imgui PUBLIC imgui_backends)

    if (TARGET Freetype::Freetype)
      target_sources(imgui PRIVATE ${imgui_SOURCE_DIR}/misc/freetype/imgui_freetype.cpp)
      target_compile_definitions(imgui PUBLIC IMGUI_ENABLE_FREETYPE)
      target_link_libraries(imgui PRIVATE Freetype::Freetype)
    endif ()
  else ()
    message(STATUS "aurora: Using existing imgui")
  endif ()

  if (TARGET imgui)
    target_include_directories(imgui PUBLIC ${PROJECT_SOURCE_DIR}/include)
    target_compile_definitions(imgui PUBLIC IMGUI_USER_CONFIG="aurora/imgui_config.h")
    target_sources(imgui PRIVATE ${PROJECT_SOURCE_DIR}/lib/imgui_config.cpp)
    target_link_libraries(imgui PRIVATE ${AURORA_SDL3_TARGET})
  endif ()

  if (NOT TARGET sqlite3)
    message(STATUS "aurora: Fetching sqlite3")
    FetchContent_Declare(sqlite3
      URL https://sqlite.org/2026/sqlite-amalgamation-3510300.zip
      URL_HASH SHA256=acb1e6f5d832484bf6d32b681e858c38add8b2acdfd42ac5df24b8afb46552b4
      DOWNLOAD_EXTRACT_TIMESTAMP TRUE
      EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(sqlite3)

    add_library(sqlite3 STATIC ${sqlite3_SOURCE_DIR}/sqlite3.c)
    target_include_directories(sqlite3 PUBLIC ${sqlite3_SOURCE_DIR})
  else ()
    message(STATUS "aurora: Using existing sqlite3")
  endif ()
  if (TARGET sqlite3 AND AURORA_WINDOWS_STORE)
    target_compile_definitions(sqlite3 PRIVATE SQLITE_OS_WINRT=1)
  endif ()

  if (AURORA_CACHE_USE_ZSTD)
    if (NOT TARGET libzstd_static)
      message(STATUS "aurora: Fetching zstd")
      set(ZSTD_BUILD_STATIC ON)
      set(ZSTD_BUILD_SHARED OFF)

      FetchContent_Declare(zstd
        URL https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz
        URL_HASH SHA256=eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        SOURCE_SUBDIR build/cmake
        EXCLUDE_FROM_ALL
      )
      FetchContent_MakeAvailable(zstd)
    else ()
      message(STATUS "aurora: Using existing zstd")
    endif ()
  endif ()

  if (AURORA_ENABLE_RMLUI AND NOT TARGET RmlUi)
    message(STATUS "aurora: Fetching RmlUi")
    FetchContent_Declare(rmlui
      URL https://github.com/mikke89/RmlUi/archive/f9b8c9e2935d5df2c7dff2c190d3968e99b0c3dc.tar.gz
      URL_HASH SHA256=42b830abc2509a8c07cf02ba3313505de3a4642725654f489402022d8fefdd79
      DOWNLOAD_EXTRACT_TIMESTAMP TRUE
      EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(rmlui)

    add_library(rmlui_backends STATIC ${rmlui_SOURCE_DIR}/Backends/RmlUi_Platform_SDL.cpp)
    # TODO: maybe dont hardcode this to SDL3?
    target_compile_definitions(rmlui_backends PUBLIC RMLUI_SDL_VERSION_MAJOR=3)
    target_include_directories(rmlui_backends PUBLIC ${rmlui_SOURCE_DIR}/Backends)
    target_link_libraries(rmlui_backends PRIVATE rmlui ${AURORA_SDL3_TARGET})
  endif ()
endif ()

if (NOT TARGET TracyClient)
  if (AURORA_WINDOWS_STORE)
    set(_aurora_tracy_tgz "${CMAKE_BINARY_DIR}/aurora_deps/tracy-a64b9a20294d59421a2f57aeca3c6383d8c48169.tar.gz")
    set(_aurora_tracy_extract "${CMAKE_BINARY_DIR}/aurora_deps/tracy-src")
    set(_aurora_tracy_marker "${_aurora_tracy_extract}/.aurora_tracy_extracted")
    if (NOT EXISTS "${_aurora_tracy_marker}")
      file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/aurora_deps")
      file(DOWNLOAD
        "https://github.com/wolfpld/tracy/archive/a64b9a20294d59421a2f57aeca3c6383d8c48169.tar.gz"
        "${_aurora_tracy_tgz}"
        EXPECTED_HASH SHA256=24d342b5127d7f659dc3cf94f24347b348cc736f25b17a691fd7f69541937658
      )
      file(MAKE_DIRECTORY "${_aurora_tracy_extract}")
      file(ARCHIVE_EXTRACT INPUT "${_aurora_tracy_tgz}" DESTINATION "${_aurora_tracy_extract}")
      file(WRITE "${_aurora_tracy_marker}" "")
    endif ()
    file(GLOB _aurora_tracy_roots LIST_DIRECTORIES TRUE "${_aurora_tracy_extract}/tracy-*")
    if (NOT _aurora_tracy_roots)
      message(FATAL_ERROR "aurora: Tracy archive layout unexpected under ${_aurora_tracy_extract}")
    endif ()
    list(GET _aurora_tracy_roots 0 _aurora_tracy_root)
    if (NOT EXISTS "${_aurora_tracy_root}/public/tracy/Tracy.hpp")
      message(FATAL_ERROR "aurora: Tracy public headers missing at ${_aurora_tracy_root}/public/tracy")
    endif ()
    message(STATUS "aurora: Tracy headers for UWP (${_aurora_tracy_root}/public)")
    add_library(TracyClient INTERFACE)
    target_include_directories(TracyClient INTERFACE "${_aurora_tracy_root}/public")
    unset(_aurora_tracy_tgz)
    unset(_aurora_tracy_extract)
    unset(_aurora_tracy_marker)
    unset(_aurora_tracy_roots)
    unset(_aurora_tracy_root)
  else ()
    message(STATUS "aurora: Fetching Tracy")

    # Default to off, users can enable the cache variable if they want to use it.
    set(TRACY_ENABLE OFF CACHE BOOL "Enable Tracy profiling")

    FetchContent_Declare(
      tracy
      URL https://github.com/wolfpld/tracy/archive/a64b9a20294d59421a2f57aeca3c6383d8c48169.tar.gz
      URL_HASH SHA256=24d342b5127d7f659dc3cf94f24347b348cc736f25b17a691fd7f69541937658
      DOWNLOAD_EXTRACT_TIMESTAMP TRUE
      EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(tracy)

    if (NOT TARGET TracyClient)
      message(FATAL_ERROR "Failed to make TracyClient available")
    endif ()
  endif ()
endif ()
