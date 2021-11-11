# Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

cmake_minimum_required(VERSION 3.15)

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

add_library(libcdm
  ${CMAKE_CURRENT_SOURCE_DIR}/src/CDM.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Deposition.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletSizeModel.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletTransport.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/NozzleVelocity.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Serialization.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/WetBulbTemperature.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/WindVelocityProfile.cpp)

add_library(libcdm::libcdm ALIAS libcdm)

set_property(TARGET libcdm PROPERTY CXX_STANDARD 17)
set_property(TARGET libcdm PROPERTY CXX_STANDARD_REQUIRED ON)
set_property(TARGET libcdm PROPERTY LIBRARY_OUTPUT_NAME libcdm)
set_property(TARGET libcdm PROPERTY PREFIX "")

target_compile_definitions(libcdm PRIVATE BOOST_MATH_STANDALONE=1)

if(BUILD_SHARED_LIBS)
  target_compile_definitions(libcdm PRIVATE CDM_EXPORTS)
else()
  target_compile_definitions(libcdm PUBLIC CDM_STATIC_DEFINE)
endif()

if(MSVC)
  target_compile_options(libcdm PUBLIC "/utf-8")
  target_compile_definitions(libcdm PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

target_include_directories(libcdm PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_include_directories(libcdm PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_link_libraries(libcdm PRIVATE
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
target_link_libraries(cdmcli PRIVATE libcdm::libcdm fmt::fmt)

#-------------------------------------------------------------------------------
# Testing
#-------------------------------------------------------------------------------

#add_executable(crtdbg ${CMAKE_CURRENT_SOURCE_DIR}/test/crtdbg.cpp)
#target_link_libraries(crtdbg PRIVATE cdm::cdm fmt::fmt)

#include(CTest)
#add_subdirectory(test)
