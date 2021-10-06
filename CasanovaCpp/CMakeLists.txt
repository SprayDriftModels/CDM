# Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

cmake_minimum_required(VERSION 3.15)

if(DEFINED ENV{VCPKG_DEFAULT_TRIPLET} AND NOT DEFINED VCPKG_TARGET_TRIPLET)
  set(VCPKG_TARGET_TRIPLET "$ENV{VCPKG_DEFAULT_TRIPLET}" CACHE STRING "")
endif()

if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
  set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

project(cdm LANGUAGES CXX)

find_package(Boost REQUIRED)
find_package(blaze CONFIG REQUIRED)
find_package(Ceres CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(SUNDIALS CONFIG REQUIRED)
find_package(units CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

find_package(imgui CONFIG REQUIRED)
find_package(implot CONFIG REQUIRED)
find_package(freetype CONFIG REQUIRED)

#-------------------------------------------------------------------------------
# Plot GUI
#-------------------------------------------------------------------------------

add_library(libplot STATIC
  ${CMAKE_CURRENT_SOURCE_DIR}/src/gui/PlotWindow.cpp
)

set_property(TARGET libplot PROPERTY CXX_STANDARD 17)
set_property(TARGET libplot PROPERTY CXX_STANDARD_REQUIRED ON)

if(MSVC)
  target_compile_definitions(libplot PRIVATE -D_UNICODE -DUNICODE)
endif()

target_link_libraries(libplot PRIVATE
  d3d11.lib
  d3dcompiler.lib
  imgui::imgui
  implot::implot
)

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

add_dependencies(cdm libplot)

set_property(TARGET cdm PROPERTY CXX_STANDARD 17)
set_property(TARGET cdm PROPERTY CXX_STANDARD_REQUIRED ON)
set_property(TARGET cdm PROPERTY RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)

if(MSVC)
  target_compile_definitions(cdm PRIVATE -D_CRT_SECURE_NO_WARNINGS)
endif()

#target_compile_definitions(cdm PRIVATE -DCDM_USE_IMGUI)

target_link_libraries(cdm PRIVATE
  libplot
  Boost::headers
  blaze::blaze
  Ceres::ceres
  fmt::fmt
  SUNDIALS::cvode
  SUNDIALS::nvecserial
  units::units
  nlohmann_json::nlohmann_json
)
