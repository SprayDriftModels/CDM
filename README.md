[![Build](https://github.com/bayer-int/cdmcpp/actions/workflows/hosted-build.yml/badge.svg)](https://github.com/bayer-int/cdmcpp/actions/workflows/hosted-build.yml)

# Casanova Drift Model (CDM)

## Build on Windows with vcpkg

Download and install [Visual Studio](https://visualstudio.microsoft.com/). In the Visual Studio installer, Workloads tab, select the **Desktop development with C++** workload. Under Individual components tab, select **Git for Windows**.

Open an x64 Native Tools Command Prompt and install [vcpkg](https://github.com/microsoft/vcpkg) as follows, assuming it will be installed in your home directory (%USERPROFILE%):

```
cd %USERPROFILE%
git clone https://github.com/microsoft/vcpkg
.\vcpkg\bootstrap-vcpkg.bat
```

Install dependencies:

```
.\vcpkg\vcpkg install blaze:x64-windows-static
.\vcpkg\vcpkg install boost-math:x64-windows-static
.\vcpkg\vcpkg install fmt:x64-windows-static
.\vcpkg\vcpkg install nlohmann-json:x64-windows-static
.\vcpkg\vcpkg install ceres:x64-windows-static
.\vcpkg\vcpkg install sundials:x64-windows-static
```

Clone this repository and build CDM:

```
git clone --branch cpp https://gitlab.bayer.com/GBBFX/mondep.git ./cdm
cmake -B ./cdm/build -S ./cdm -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=On -DCMAKE_TOOLCHAIN_FILE=%USERPROFILE%\vcpkg\scripts\buildsystems\vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-static
cmake --build ./cdm/build
```

The model library (libcdm.dll) and command-line executable (cdmcli.exe) will be located in the ./cdm/bin directory. If you are using the R package, copy libcdm.dll to ./cdm/R/cdm/inst/libs/x64:

```
copy ./cdm/bin/libcdm.dll ./cdm/R/cdm/inst/libs/x64
```

## Build on Linux with vcpkg

Install C++ development tools and Git using the package management tool that comes with your Linux distribution. On a Debian-based distribution, such as Ubuntu, use APT:

```
sudo apt update
sudo apt install build-essential git-all
```

Follow the instructions at [apt.kitware.com](https://apt.kitware.com/) to install the latest version of CMake using APT. For alternative installation options, see [cmake.org/download](https://cmake.org/download/).

Install vcpkg as follows, assuming it will be installed in your home directory (~):

```
cd ~
git clone https://github.com/microsoft/vcpkg
./vcpkg/bootstrap-vcpkg.sh
```

Install dependencies:

```
./vcpkg/vcpkg install blaze:x64-linux
./vcpkg/vcpkg install boost-math:x64-linux
./vcpkg/vcpkg install fmt:x64-linux
./vcpkg/vcpkg install nlohmann-json:x64-linux
./vcpkg/vcpkg install ceres:x64-linux
./vcpkg/vcpkg install sundials:x64-linux
```

Clone this repository, build and install CDM:

```
git clone --branch cpp https://gitlab.bayer.com/GBBFX/mondep.git ./cdm
cmake -B ./cdm/build -S ./cdm -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=On -DCMAKE_TOOLCHAIN_FILE=~/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-linux
cmake --build ./cdm/build
cmake --install ./cdm/build
```

The header file (CDM.h), library (libcdm.so), and executable (cdmcli) are copied to /usr/local/include/cdm, /usr/local/lib64 and /usr/local/bin respectively.

## Install the R package

On Windows, install [Rtools](https://cran.r-project.org/bin/windows/Rtools/). From an R (64-bit) session, install the `cdm` package as follows, assuming this repository is located at "~/cdm":

```
install.packages("~/cdm/R/cdm", repos=NULL, type="source", INSTALL_opts="--no-multiarch")
```

Run the test case as follows:

```
demo("case1", package="cdm")
```