# Casanova Deposition Model (CDM)

## Build on Windows with vcpkg

Make sure Visual Studio is installed with C++ development tools. Open an x64 Native Tools Command Prompt and install vcpkg as follows, assuming it will be installed in your home directory (%USERPROFILE%):

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

The model library (libcdm.dll) and command-line executable (cdmcli.exe) will be located in the ./cdm/bin directory. libcdm.dll must be copied to inst/libs/x64 in the R package.

## Build on Linux with vcpkg

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
cmake -B ./cdm/build -S ./cdm -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=On -DCMAKE_TOOLCHAIN_FILE=~/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-linux
cmake --build ./cdm/build
cmake --install ./cdm/build
```

The header file (CDM.h), library (libcdm.so), and executable (cdmcli) are copied to /usr/local/include, /usr/local/lib and /usr/local/bin respectively.
