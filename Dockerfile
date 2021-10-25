FROM alpine:latest as build

LABEL description="CDM Build Container"

RUN apk update && apk add --no-cache binutils cmake make libgcc musl-dev gcc g++ ninja git

RUN git clone --branch v3.8 https://bitbucket.org/blaze-lib/blaze.git /tmp/blaze \
    && cmake -S /tmp/blaze -B /tmp/blaze-build -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_BUILD_TYPE=Release -DUSE_LAPACK=Off \
    && cmake --install /tmp/blaze-build

RUN git clone --branch v1.77-standalone https://github.com/boostorg/math.git /tmp/boost-math \
    && cp -R /tmp/boost-math/include/* /usr/local/include

RUN git clone --branch 8.0.1 https://github.com/fmtlib/fmt.git /tmp/fmt \
    && cmake -S /tmp/fmt -B /tmp/fmt-build -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=Off \
	&& cmake --build /tmp/fmt-build \
    && cmake --install /tmp/fmt-build

RUN git clone --branch v3.10.4 https://github.com/nlohmann/json.git /tmp/nlohmann-json \
    && cmake -S /tmp/nlohmann-json -B /tmp/nlohmann-json-build -G Ninja -DCMAKE_BUILD_TYPE=Release -DJSON_MultipleHeaders=On \
    && cmake --install /tmp/nlohmann-json-build

RUN git clone --branch v2.2.2 https://github.com/gflags/gflags.git /tmp/gflags \
    && cmake -S /tmp/gflags -B /tmp/gflags-build -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=Off \
    && cmake --build /tmp/gflags-build \
	&& cmake --install /tmp/gflags-build

RUN git clone --branch v0.5.0 https://github.com/google/glog.git /tmp/glog \
    && cmake -S /tmp/glog -B /tmp/glog-build -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=Off \
    && cmake --build /tmp/glog-build \
    && cmake --install /tmp/glog-build

RUN git clone --branch 3.4.0 https://gitlab.com/libeigen/eigen.git /tmp/eigen \
    && cmake -S /tmp/eigen -B /tmp/eigen-build -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_BUILD_TYPE=Release \
    && cmake --install /tmp/eigen-build

RUN git clone --branch 2.0.0 https://github.com/ceres-solver/ceres-solver.git /tmp/ceres \
    && cmake -S /tmp/ceres -B /tmp/ceres-build -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=Off \
	   -DBUILD_BENCHMARKS=Off -DBUILD_DOCUMENTATION=Off -DBUILD_EXAMPLES=Off -DBUILD_TESTING=Off \
    && cmake --build /tmp/ceres-build \
    && cmake --install /tmp/ceres-build

RUN git clone --branch v5.8.0 https://github.com/LLNL/sundials.git /tmp/sundials \
    && cmake -S /tmp/sundials -B /tmp/sundials-build -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=Off \
	   -DEXAMPLES_ENABLE_C=Off -DEXAMPLES_ENABLE_CXX=Off -DEXAMPLES_INSTALL=Off \
       -DBUILD_ARKODE=Off -DBUILD_CVODE=On -DBUILD_CVODES=Off -DBUILD_IDA=Off -DBUILD_IDAS=Off -DBUILD_KINSOL=Off \
    && cmake --build /tmp/sundials-build \
    && cmake --install /tmp/sundials-build
