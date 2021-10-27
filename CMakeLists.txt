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

project(cdm LANGUAGES CXX)

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

target_compile_definitions(cdm PUBLIC BOOST_MATH_STANDALONE=1)

if(MSVC)
  target_compile_options(cdm PUBLIC "/utf-8")
  target_compile_definitions(cdm PUBLIC _CRT_SECURE_NO_WARNINGS)
endif()

target_include_directories(cdm PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)

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

add_executable(cdmcli ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp)
set_property(TARGET cdmcli PROPERTY CXX_STANDARD 17)
set_property(TARGET cdmcli PROPERTY CXX_STANDARD_REQUIRED ON)
target_link_libraries(cdmcli PRIVATE
  cdm::cdm
  fmt::fmt
  nlohmann_json::nlohmann_json
)

#-------------------------------------------------------------------------------
# Testing
#-------------------------------------------------------------------------------

#add_executable(cdm_case1_test ${CMAKE_CURRENT_SOURCE_DIR}/test/cdm_case1_test.cpp)
#set_property(TARGET cdm_case1_test PROPERTY CXX_STANDARD 17)
#set_property(TARGET cdm_case1_test PROPERTY CXX_STANDARD_REQUIRED ON)
#target_link_libraries(cdm_case1_test PRIVATE cdm::cdm)

#include(CTest)
#add_subdirectory(test)
