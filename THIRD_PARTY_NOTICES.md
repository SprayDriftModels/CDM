# Third-Party Notices

CDM is licensed under the GNU Affero General Public License version 3. Third-party components used by CDM are licensed separately by their respective copyright holders.

When distributing CDM source archives, binary bundles, installers, or R package builds, include this file together with the CDM `LICENSE` file. Keep notices embedded in vendored source files intact. If a binary bundle includes third-party library binaries, also include the license or copyright files provided by the package manager or upstream project for those bundled binaries and their transitive dependencies.

## Direct Dependencies

| Component | Purpose | License |
| --- | --- | --- |
| Blaze | C++ math library for dense and sparse arithmetic | BSD-3-Clause |
| Boost.Math | Mathematical functions and numerical utilities | Boost Software License 1.0 |
| Ceres Solver | Nonlinear least-squares optimization | BSD-3-Clause |
| fmt | Formatting library | MIT |
| nlohmann/json | JSON parser and serializer | MIT |
| SUNDIALS CVODE | ODE solver and serial vector support | BSD-3-Clause |

The exact transitive dependency set may vary by platform and vcpkg triplet. For binary distributions, include notices for all dependency binaries that are shipped with CDM.

## Bundled Source

### CLI11

Project: https://github.com/CLIUtils/CLI11
Version: 2.4.0
License: BSD-3-Clause
Location: `src/CLI11.hpp`

CLI11 2.4.0 Copyright (c) 2017-2024 University of Cincinnati, developed by Henry Schreiner under NSF AWARD 1414736. All rights reserved.

Redistribution and use in source and binary forms of CLI11, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
