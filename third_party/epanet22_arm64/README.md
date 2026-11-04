# EPANET 2.2 native Apple-Silicon library

This directory contains a local `arm64` build of the official EPANET 2.2
solver library needed by MATLAB R2026a on Apple Silicon.

- Source: `https://github.com/OpenWaterAnalytics/EPANET`, tag `v2.2`
- Commit: `4d8d82ddc260fce216af9321fc3d9a4646ac6827`
- Build system: CMake, Release configuration, `CMAKE_OSX_ARCHITECTURES=arm64`
- License: MIT; see `LICENSE`.

The header is named `libepanet2.h` because the existing EPANET-MATLAB Toolkit
derives the header name from the dynamic-library basename.

