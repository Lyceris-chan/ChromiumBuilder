# Ultimate Chromium Builder

A comprehensive bash script that applies **ALL** ungoogled-chromium privacy patches **AND** **ALL** Chromium Clang optimizations to build the ultimate optimized privacy-focused Chromium for Windows 64-bit AVX512.

## Features

### Privacy (ungoogled-chromium)
- **Complete Google dependency removal** - All patches from patches/core/, patches/extra/, and patches/inox-patchset/
- **Domain substitution** - Replace Google domains with privacy-respecting alternatives  
- **Pruning list application** - Remove telemetry and tracking components
- **Privacy build flags** - Disable all Google services and telemetry
- **Extension support** - Keep useful features while removing privacy violations

### Performance (Chromium Clang)
- **Link Time Optimization (LTO)** - Both ThinLTO and Full LTO support for cross-module optimization
- **Profile Guided Optimization (PGO)** - Complete integration with profile data for maximum performance
- **Polly Optimization** - High-level loop and data-locality optimizer from LLVM
- **BOLT Optimization** - Binary optimization and layout tool for post-link optimization
- **Fast-math optimizations** - Aggressive floating-point optimizations for hot code paths
- **AVX512 instruction set** - Complete 512-bit vector operations support + FMA
- **V8 engine optimizations** - Enhanced JavaScript engine performance patches
- **Custom Clang/LLVM build** - Optimized compiler toolchain with all performance patches
- **Windows cross-compilation** - Complete Windows 64-bit target optimization

## Quick Start

```bash
# Clone this repository
git clone <repository-url>
cd ultimate-chromium-builder

# Make the main script executable
chmod +x build-ultimate-chromium.sh

# Run the complete build process
./build-ultimate-chromium.sh
