---
title: Getting Started
---

# Getting Started

This guide covers how to build CDM from source, and how to install the R package.

## Build on Windows with vcpkg

### Prerequisites

Download and install [Visual Studio](https://visualstudio.microsoft.com/). In the Visual Studio installer:
- **Workloads** tab: select **Desktop development with C++**
- **Individual components** tab: select **Git for Windows**

### Install vcpkg

Open an **x64 Native Tools Command Prompt** and install [vcpkg](https://github.com/microsoft/vcpkg):

```
cd %USERPROFILE%
git clone https://github.com/microsoft/vcpkg
.\vcpkg\bootstrap-vcpkg.bat
```

### Build CDM

Clone the repository and build. Required dependencies will be automatically installed to the build directory.

```
git clone https://github.com/SprayDriftModels/CDM.git ./cdm
cmake -B ./cdm/build -S ./cdm -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=On -DCMAKE_TOOLCHAIN_FILE="%USERPROFILE%\vcpkg\scripts\buildsystems\vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows-static
cmake --build ./cdm/build
```

The model library (`libcdm.dll`) and command-line executable (`cdmcli.exe`) will be located in `./cdm/bin`.

### Copy DLL for R package (optional)

If you are using the R package, copy the DLL:

```
copy ./cdm/bin/libcdm.dll ./cdm/R/cdm/inst/libs/x64
```

## Build on Linux with vcpkg

### Prerequisites

Install C++ development tools and Git. On Debian/Ubuntu:

```
sudo apt update
sudo apt install build-essential git-all ninja-build pkg-config
```

Install the latest version of CMake from [apt.kitware.com](https://apt.kitware.com/) or [cmake.org/download](https://cmake.org/download/).

### Install vcpkg

```
cd ~
git clone https://github.com/microsoft/vcpkg
./vcpkg/bootstrap-vcpkg.sh
```

### Build and Install CDM

```
git clone https://github.com/SprayDriftModels/CDM.git ./cdm
cmake -B ./cdm/build -S ./cdm -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=On -DCMAKE_TOOLCHAIN_FILE="~/vcpkg/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-linux
cmake --build ./cdm/build
cmake --install ./cdm/build
```

Installed locations:

| Artifact | Path |
|----------|------|
| Header file (`CDM.h`) | `/usr/local/include/cdm` |
| Library (`libcdm.so`) | `/usr/local/lib` |
| Executable (`cdmcli`) | `/usr/local/bin` |

## Install the R Package

### Prerequisites (Windows)

Install [Rtools](https://cran.r-project.org/bin/windows/Rtools/).

### Install

From an R (64-bit) session, install the `cdm` package from the local repository:

```r
install.packages("~/cdm/R/cdm", repos = NULL, type = "source", INSTALL_opts = "--no-multiarch")
```

### Run Test Cases

```r
demo("caseB", package = "cdm")
demo("caseG", package = "cdm")
demo("caseI", package = "cdm")
```

## Using the CLI

Run the model with a JSON input file:

```bash
# Run model and print report to console
cdmcli tests/Case_B.json

# Save JSON output to a file
cdmcli tests/Case_B.json -o results.json

# Quiet mode (suppress console output)
cdmcli tests/Case_B.json -o results.json -q
```

## Docker

A `Dockerfile` is included for containerized builds. See the [repository root](https://github.com/SprayDriftModels/CDM) for details.
