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

project(cdm LANGUAGES CXX)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

option(BUILD_SHARED_LIBS "Build using shared libraries" OFF)

#-------------------------------------------------------------------------------
# Dependencies
#-------------------------------------------------------------------------------

find_package(Boost) # Boost.Math
find_package(blaze CONFIG REQUIRED)
find_package(Ceres CONFIG REQUIRED) # Requires Eigen, glog
find_package(fmt CONFIG REQUIRED)
find_package(SUNDIALS CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

#-------------------------------------------------------------------------------
# CDM Library
#-------------------------------------------------------------------------------

add_library(cdm
  ${CMAKE_CURRENT_SOURCE_DIR}/src/CDM.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Deposition.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletSizeModel.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletTransport.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/NozzleVelocity.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Serialization.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/WetBulbTemperature.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/WindVelocityProfile.cpp)

add_library(cdm::cdm ALIAS cdm)

set_property(TARGET cdm PROPERTY CXX_STANDARD 17)
set_property(TARGET cdm PROPERTY CXX_STANDARD_REQUIRED ON)
set_property(TARGET cdm PROPERTY OUTPUT_NAME libcdm)
set_property(TARGET cdm PROPERTY PREFIX "")

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
  $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
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
install(FILES ${PROJECT_SOURCE_DIR}/include/CDM.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(EXPORT cdm-targets DESTINATION ${CDM_CMAKE_DIR} NAMESPACE cdm::)
