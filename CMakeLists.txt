# Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

cmake_minimum_required(VERSION 3.15)

if(DEFINED ENV{VCPKG_DEFAULT_TRIPLET} AND NOT DEFINED VCPKG_TARGET_TRIPLET)
  set(VCPKG_TARGET_TRIPLET "$ENV{VCPKG_DEFAULT_TRIPLET}" CACHE STRING "")
endif()

if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
  set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

project(cdm LANGUAGES CXX)

find_package(Boost) # Boost.Math
find_package(blaze CONFIG REQUIRED)
find_package(Ceres CONFIG REQUIRED) # Requires Eigen, glog
find_package(fmt CONFIG REQUIRED)
find_package(SUNDIALS CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

#-------------------------------------------------------------------------------
# Main Executable
#-------------------------------------------------------------------------------

add_executable(cdm
  ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Deposition.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletSizeModel.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/DropletTransport.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/NozzleVelocity.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Serialization.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/WetBulbTemperature.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/WVProfile.cpp
)

set_property(TARGET cdm PROPERTY CXX_STANDARD 17)
set_property(TARGET cdm PROPERTY CXX_STANDARD_REQUIRED ON)
set_property(TARGET cdm PROPERTY RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)

if(MSVC)
  target_compile_options(cdm PRIVATE "/utf-8")
  target_compile_definitions(cdm PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# Boost.Math Standalone Mode (Beta)
target_compile_definitions(cdm PRIVATE BOOST_MATH_STANDALONE=1)

target_link_libraries(cdm PRIVATE
  blaze::blaze
  Ceres::ceres
  fmt::fmt
  SUNDIALS::cvode
  SUNDIALS::nvecserial
  nlohmann_json::nlohmann_json
)
