# Copyright (c) 2023 John Buonagurio <jbuonagurio@exponent.com>

FROM alpine:latest as build

LABEL description="CDM Build Container"

RUN apk update && apk add --no-cache binutils cmake make libgcc musl-dev gcc g++ ninja git

RUN git clone --branch v3.8.2 https://bitbucket.org/blaze-lib/blaze.git /tmp/blaze \
    && cmake -S /tmp/blaze -B /tmp/blaze-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
             -DUSE_LAPACK=Off \
             -DBLAZE_SMP_THREADS="C++11" \
    && cmake --install /tmp/blaze-build \
    && rm -rf /tmp/blaze && rm -rf /tmp/blaze-build

RUN git clone --branch v1.77-standalone https://github.com/boostorg/math.git /tmp/boost-math \
    && cp -R /tmp/boost-math/include/* /usr/local/include \
    && rm -rf /tmp/boost-math

RUN git clone --branch 10.1.1 https://github.com/fmtlib/fmt.git /tmp/fmt \
    && cmake -S /tmp/fmt -B /tmp/fmt-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=Off \
             -DCMAKE_POSITION_INDEPENDENT_CODE=On \
    && cmake --build /tmp/fmt-build \
    && cmake --install /tmp/fmt-build \
    && rm -rf /tmp/fmt && rm -rf /tmp/fmt-build

RUN git clone --branch v3.11.3 https://github.com/nlohmann/json.git /tmp/nlohmann-json \
    && cmake -S /tmp/nlohmann-json -B /tmp/nlohmann-json-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
             -DJSON_MultipleHeaders=On \
    && cmake --install /tmp/nlohmann-json-build \
    && rm -rf /tmp/nlohmann-json && rm -rf /tmp/nlohmann-json-build

RUN git clone --branch v2.2.2 https://github.com/gflags/gflags.git /tmp/gflags \
    && cmake -S /tmp/gflags -B /tmp/gflags-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=Off \
             -DCMAKE_POSITION_INDEPENDENT_CODE=On \
    && cmake --build /tmp/gflags-build \
    && cmake --install /tmp/gflags-build \
    && rm -rf /tmp/gflags && rm -rf /tmp/gflags-build

RUN git clone --branch v0.6.0 https://github.com/google/glog.git /tmp/glog \
    && cmake -S /tmp/glog -B /tmp/glog-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=Off \
             -DCMAKE_POSITION_INDEPENDENT_CODE=On \
    && cmake --build /tmp/glog-build \
    && cmake --install /tmp/glog-build \
    && rm -rf /tmp/glog && rm -rf /tmp/glog-build

RUN git clone --branch 3.4.0 https://gitlab.com/libeigen/eigen.git /tmp/eigen \
    && cmake -S /tmp/eigen -B /tmp/eigen-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
    && cmake --install /tmp/eigen-build \
    && rm -rf /tmp/eigen && rm -rf /tmp/eigen-build

RUN git clone --branch 2.1.0 https://github.com/ceres-solver/ceres-solver.git /tmp/ceres \
    && cmake -S /tmp/ceres -B /tmp/ceres-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=Off \
             -DCMAKE_POSITION_INDEPENDENT_CODE=On \
             -DBUILD_BENCHMARKS=Off \
             -DBUILD_DOCUMENTATION=Off \
             -DBUILD_EXAMPLES=Off \
             -DBUILD_TESTING=Off \
             -DSCHUR_SPECIALIZATIONS=Off \
    && cmake --build /tmp/ceres-build \
    && cmake --install /tmp/ceres-build \
    && rm -rf /tmp/ceres && rm -rf /tmp/ceres-build

RUN git clone --branch v6.6.2 https://github.com/LLNL/sundials.git /tmp/sundials \
    && cmake -S /tmp/sundials -B /tmp/sundials-build -G Ninja \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=Off \
             -DCMAKE_POSITION_INDEPENDENT_CODE=On \
             -DEXAMPLES_ENABLE_C=Off \
             -DEXAMPLES_ENABLE_CXX=Off \
             -DEXAMPLES_INSTALL=Off \
             -DBUILD_ARKODE=Off \
             -DBUILD_CVODE=On \
             -DBUILD_CVODES=Off \
             -DBUILD_IDA=Off \
             -DBUILD_IDAS=Off \
             -DBUILD_KINSOL=Off \
    && cmake --build /tmp/sundials-build \
    && cmake --install /tmp/sundials-build \
    && rm -rf /tmp/sundials && rm -rf /tmp/sundials-build

WORKDIR /src
COPY . .
RUN cmake -B /build -S . -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_SHARED_LIBS=Off \
          -DCMAKE_POSITION_INDEPENDENT_CODE=On \
          -DCMAKE_EXE_LINKER_FLAGS="-static" \
          -DCMAKE_VERBOSE_MAKEFILE=On \
          -DCMAKE_SKIP_RPATH=On \
    && cmake --build /build \
    && cmake --install /build

WORKDIR /build
RUN cpack -G TGZ -C Release
FROM scratch as artifact
COPY --from=build /build/cdm-*-Linux.tar.gz .
