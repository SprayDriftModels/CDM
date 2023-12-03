# Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

cmake_minimum_required(VERSION 3.15)

# Enable CMAKE_MSVC_RUNTIME_LIBRARY
cmake_policy(SET CMP0091 NEW)

if(DEFINED ENV{VCPKG_DEFAULT_TRIPLET} AND NOT DEFINED VCPKG_TARGET_TRIPLET)
  set(VCPKG_TARGET_TRIPLET "$ENV{VCPKG_DEFAULT_TRIPLET}" CACHE STRING "")
endif()

if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
  set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

if(NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)
endif()
if(NOT DEFINED CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)
endif()
if(NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)
endif()

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Workaround for "-isystem" issue in MinGW build.
set(CMAKE_NO_SYSTEM_FROM_IMPORTED ON)

project(cdm LANGUAGES CXX DESCRIPTION "Casanova Drift Model")

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(JoinPaths)

# Options
option(BUILD_SHARED_LIBS "Build using shared libraries" OFF)

# Version
file(READ include/cdm/CDM.h CDM_H)
if(NOT CDM_H MATCHES "CDM_VERSION ([0-9]+)([0-9][0-9])([0-9][0-9])")
  message(FATAL_ERROR "Cannot read CDM_VERSION from CDM.h.")
endif()
math(EXPR CPACK_PACKAGE_VERSION_MAJOR ${CMAKE_MATCH_1})
math(EXPR CPACK_PACKAGE_VERSION_MINOR ${CMAKE_MATCH_2})
math(EXPR CPACK_PACKAGE_VERSION_PATCH ${CMAKE_MATCH_3})
set(CDM_VERSION ${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH})
message(STATUS "CDM version: ${CDM_VERSION}")

# Always use full RPATH.
# See: https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/RPATH-handling
set(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
list(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}" isSystemDir)
if("${isSystemDir}" STREQUAL "-1")
  set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
endif()

#-------------------------------------------------------------------------------
# Dependencies
#-------------------------------------------------------------------------------

find_package(Boost) # Boost.Math
find_package(blaze CONFIG REQUIRED)
find_package(Ceres CONFIG REQUIRED) # Requires Eigen, gflags, glog
find_package(fmt CONFIG REQUIRED)
find_package(SUNDIALS CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

#-------------------------------------------------------------------------------
# CDM Library
#-------------------------------------------------------------------------------

add_library(cdm
  ${CMAKE_CURRENT_SOURCE_DIR}/src/CDM.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/AtmosphericProperties.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Deposition.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletSizeModel.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletTransport.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/NozzleVelocity.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Serialization.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/WindVelocityProfile.cpp)

add_library(cdm::cdm ALIAS cdm)

set_property(TARGET cdm PROPERTY CXX_STANDARD 17)
set_property(TARGET cdm PROPERTY CXX_STANDARD_REQUIRED ON)
set_property(TARGET cdm PROPERTY OUTPUT_NAME libcdm)
set_property(TARGET cdm PROPERTY PREFIX "")
set_property(TARGET cdm PROPERTY VERSION ${CDM_VERSION})
set_property(TARGET cdm PROPERTY SOVERSION ${CPACK_PACKAGE_VERSION_MAJOR})

target_compile_definitions(cdm PRIVATE BOOST_MATH_STANDALONE=1)

if(BUILD_SHARED_LIBS)
  target_compile_definitions(cdm PRIVATE CDM_EXPORTS)
else()
  target_compile_definitions(cdm PUBLIC CDM_STATIC_DEFINE)
endif()

if(MSVC)
  target_compile_options(cdm PUBLIC "/utf-8")
  target_compile_definitions(cdm PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

target_include_directories(cdm PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_include_directories(cdm PUBLIC
  $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include/cdm>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

target_link_libraries(cdm PRIVATE
  blaze::blaze
  Ceres::ceres
  fmt::fmt
  SUNDIALS::cvode
  SUNDIALS::nvecserial
  nlohmann_json::nlohmann_json
)

#-------------------------------------------------------------------------------
# CLI
#-------------------------------------------------------------------------------

add_executable(cdmcli ${CMAKE_CURRENT_SOURCE_DIR}/src/CDMCLI.cpp)
set_property(TARGET cdmcli PROPERTY CXX_STANDARD 17)
set_property(TARGET cdmcli PROPERTY CXX_STANDARD_REQUIRED ON)
target_link_libraries(cdmcli PRIVATE cdm::cdm fmt::fmt)

#-------------------------------------------------------------------------------
# Install
#-------------------------------------------------------------------------------

set(CDM_CMAKE_DIR ${CMAKE_INSTALL_LIBDIR}/cmake/cdm)

configure_package_config_file(
  ${PROJECT_SOURCE_DIR}/cmake/cdm-config.cmake.in
  ${PROJECT_BINARY_DIR}/cdm-config.cmake
  INSTALL_DESTINATION ${CDM_CMAKE_DIR})

install(TARGETS cdm EXPORT cdm-targets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(TARGETS cdmcli)

export(TARGETS cdm NAMESPACE cdm:: FILE ${PROJECT_BINARY_DIR}/cdm-targets.cmake)

install(FILES ${PROJECT_BINARY_DIR}/cdm-config.cmake DESTINATION ${CDM_CMAKE_DIR})
install(FILES ${PROJECT_SOURCE_DIR}/include/cdm/CDM.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/cdm)
install(EXPORT cdm-targets DESTINATION ${CDM_CMAKE_DIR} NAMESPACE cdm::)

# Generate cdm.pc for pkg-config.
join_paths(CDM_PKGCONFIG_LIBDIR "\${exec_prefix}" "${CMAKE_INSTALL_LIBDIR}")
join_paths(CDM_PKGCONFIG_INCLUDEDIR "\${prefix}" "${CMAKE_INSTALL_INCLUDEDIR}")
configure_file("${PROJECT_SOURCE_DIR}/cmake/cdm.pc.in" "${PROJECT_BINARY_DIR}/cdm.pc" @ONLY)
install(FILES "${PROJECT_BINARY_DIR}/cdm.pc" DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")

#-------------------------------------------------------------------------------
# Packaging
#-------------------------------------------------------------------------------

set(CPACK_PACKAGE_NAME cdm)
set(CPACK_PACKAGE_VENDOR "Bayer")
set(CPACK_RESOURCE_FILE_README ${PROJECT_SOURCE_DIR}/README.md)
set(CPACK_SOURCE_PACKAGE_FILE_NAME cdm-${CDM_VERSION})
set(CPACK_SOURCE_GENERATOR ZIP)
set(CPACK_SOURCE_IGNORE_FILES
  "\\\\.DS_Store"
  "/\\\\.git/"
  "/\\\\.github/"
  "/\\\\.gitlab/"
  "/\\\\.vscode/"
  "/\\\\.clang-format"
  "/\\\\.gitattributes"
  "/\\\\.gitignore"
  ".gitlab-ci.yml"
  "/bin/"
  "/build/"
  "/R/cdm/inst/libs/i386/.*.dll$"
  "/R/cdm/inst/libs/x64/.*.dll$"
  "/R/cdm/src/Makevars$"
  "/R/cdm/src/.*.o$"
  "/R/cdm/src/.*.so$"
  "/R/cdm/src/.*.dll$"
  "/R/cdm/src/.*.dylib$")

include(CPack)
