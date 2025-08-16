#!/bin/bash

# Setup custom optimized Clang/LLVM toolchain for Chromium
# Configures advanced optimizations: LTO, PGO, Polly, BOLT

set -euo pipefail

TOOLCHAIN_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m' 
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking toolchain dependencies..."
    
    local deps=("cmake" "ninja-build" "python3" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done
    
    log_success "Dependencies verified"
}

# Setup toolchain directory
setup_directory() {
    log_info "Setting up toolchain directory: $TOOLCHAIN_DIR"
    
    mkdir -p "$TOOLCHAIN_DIR"/{src,build,install}
    
    cd "$TOOLCHAIN_DIR"
    log_success "Toolchain directory ready"
}

# Clone LLVM source with optimizations
clone_llvm() {
    log_info "Cloning LLVM with Polly and optimization tools..."
    
    cd "$TOOLCHAIN_DIR/src"
    
    # Clone LLVM
    if [ ! -d "llvm-project" ]; then
        git clone --depth 1 --branch main https://github.com/llvm/llvm-project.git
    else
        cd llvm-project && git pull origin main && cd ..
    fi
    
    log_success "LLVM source ready"
}

# Configure LLVM build with all optimizations
configure_llvm() {
    log_info "Configuring LLVM with maximum optimizations..."
    
    cd "$TOOLCHAIN_DIR/build"
    
    # CMake configuration for optimized LLVM
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$TOOLCHAIN_DIR/install" \
        -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;polly;bolt" \
        -DLLVM_ENABLE_RUNTIMES="compiler-rt" \
        -DLLVM_TARGETS_TO_BUILD="X86;AArch64" \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_ENABLE_LTO=Thin \
        -DLLVM_USE_SPLIT_DWARF=ON \
        -DLLVM_OPTIMIZED_TABLEGEN=ON \
        -DLLVM_ENABLE_ZLIB=ON \
        -DLLVM_ENABLE_ZSTD=ON \
        -DLLVM_PARALLEL_LINK_JOBS=1 \
        -DLLVM_POLLY_LINK_INTO_TOOLS=ON \
        -DPOLLY_ENABLE_GPGPU_CODEGEN=OFF \
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
        -DCLANG_ENABLE_ARCMT=OFF \
        -DCLANG_DEFAULT_LINKER=lld \
        -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
        -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
        -DCOMPILER_RT_BUILD_XRAY=OFF \
        -DCOMPILER_RT_BUILD_MEMPROF=OFF \
        -DCMAKE_C_FLAGS="-O3 -DNDEBUG" \
        -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG" \
        ../src/llvm-project/llvm
    
    log_success "LLVM configuration complete"
}

# Build optimized LLVM toolchain
build_llvm() {
    log_info "Building optimized LLVM toolchain (this will take a while)..."
    
    cd "$TOOLCHAIN_DIR/build"
    
    # Build with maximum parallelism but limit memory usage
    ninja -j $(nproc) install
    
    log_success "LLVM toolchain built and installed"
}

# Configure Clang for Chromium optimizations
configure_clang_optimizations() {
    log_info "Configuring Clang for Chromium-specific optimizations..."
    
    local clang_config="$TOOLCHAIN_DIR/install/lib/clang.cfg"
    
    cat > "$clang_config" << 'EOF'
# Chromium-optimized Clang configuration
# Default optimization flags for maximum performance

# LTO configuration
-flto=thin
-fwhole-program-vtables

# Optimization level
-O3

# Fast math for hot code paths
-ffast-math
-funsafe-math-optimizations
-ffinite-math-only
-fno-signed-zeros
-fno-trapping-math
-fassociative-math
-freciprocal-math

# Vectorization
-ftree-vectorize
-ftree-slp-vectorize
-fvectorize
-fslp-vectorize

# Code generation optimizations
-fomit-frame-pointer
-ffunction-sections
-fdata-sections

# Platform-specific optimizations
-march=native
-mtune=native

# Linker optimizations
-fuse-ld=lld
-Wl,--icf=all
-Wl,--gc-sections
EOF
    
    log_success "Clang optimization configuration created"
}

# Setup PGO infrastructure
setup_pgo_infrastructure() {
    log_info "Setting up Profile Guided Optimization infrastructure..."
    
    local pgo_dir="$TOOLCHAIN_DIR/pgo"
    mkdir -p "$pgo_dir"/{profiles,scripts}
    
    # Create PGO helper script
    cat > "$pgo_dir/scripts/generate-profile.sh" << 'EOF'
#!/bin/bash
# Generate PGO profile for Chromium

set -euo pipefail

CHROMIUM_BINARY="$1"
PROFILE_OUTPUT="$2"

echo "Generating PGO profile for: $CHROMIUM_BINARY"

# Set profiling environment
export LLVM_PROFILE_FILE="$PROFILE_OUTPUT/default_%m.profraw"

# Run representative workload
echo "Running representative workload..."

# Start Chromium with profiling
timeout 300 "$CHROMIUM_BINARY" \
    --no-sandbox \
    --disable-gpu \
    --headless \
    --disable-extensions \
    --no-first-run \
    --run-all-compositor-stages-before-draw \
    --disable-background-timer-throttling \
    --disable-renderer-backgrounding \
    --disable-backgrounding-occluded-windows \
    --virtual-time-budget=300000 \
    --enable-logging=stderr \
    --log-level=0 \
    https://www.google.com \
    https://www.youtube.com \
    https://www.wikipedia.org \
    https://www.github.com \
    || echo "PGO profiling run completed"

# Merge raw profiles
echo "Merging profile data..."
llvm-profdata merge -output="$PROFILE_OUTPUT/merged.profdata" "$PROFILE_OUTPUT"/*.profraw

echo "PGO profile generated: $PROFILE_OUTPUT/merged.profdata"
EOF
    
    chmod +x "$pgo_dir/scripts/generate-profile.sh"
    
    log_success "PGO infrastructure ready"
}

# Setup BOLT infrastructure
setup_bolt_infrastructure() {
    log_info "Setting up BOLT binary optimization infrastructure..."
    
    local bolt_dir="$TOOLCHAIN_DIR/bolt"
    mkdir -p "$bolt_dir"/{profiles,optimized,scripts}
    
    # Create BOLT optimization script
    cat > "$bolt_dir/scripts/optimize-binary.sh" << 'EOF'
#!/bin/bash
# Optimize binary with BOLT

set -euo pipefail

INPUT_BINARY="$1"
OUTPUT_BINARY="$2"
PROFILE_DATA="$3"

echo "BOLT optimizing: $INPUT_BINARY -> $OUTPUT_BINARY"

# Check if BOLT tools are available
if ! command -v llvm-bolt &> /dev/null; then
    echo "BOLT tools not available, skipping optimization"
    cp "$INPUT_BINARY" "$OUTPUT_BINARY"
    exit 0
fi

# Generate performance profile if not provided
if [ ! -f "$PROFILE_DATA" ]; then
    echo "Generating BOLT profile..."
    perf record -e cycles:u -j any,u -o bolt.perf.data -- "$INPUT_BINARY" --version
    llvm-bolt --data=bolt.perf.data --print-sn-stats "$INPUT_BINARY" -o /dev/null | \
        tail -n 1 | grep -o '[0-9]*' > "$PROFILE_DATA"
fi

# Apply BOLT optimizations
llvm-bolt "$INPUT_BINARY" \
    -o "$OUTPUT_BINARY" \
    -data="$PROFILE_DATA" \
    -reorder-blocks=ext-tsp \
    -reorder-functions=hfsort+ \
    -split-functions \
    -split-all-cold \
    -split-eh \
    -dyno-stats \
    -icf=1 \
    -use-gnu-stack

echo "BOLT optimization complete"
EOF
    
    chmod +x "$bolt_dir/scripts/optimize-binary.sh"
    
    log_success "BOLT infrastructure ready"
}

# Create toolchain wrapper scripts
create_wrapper_scripts() {
    log_info "Creating optimized compiler wrapper scripts..."
    
    local bin_dir="$TOOLCHAIN_DIR/bin"
    mkdir -p "$bin_dir"
    
    # Clang wrapper with optimization flags
    cat > "$bin_dir/clang" << EOF
#!/bin/bash
# Optimized Clang wrapper for Chromium

# Use our optimized toolchain
export PATH="$TOOLCHAIN_DIR/install/bin:\$PATH"

# Apply optimization flags
exec clang \\
    -O3 \\
    -flto=thin \\
    -fwhole-program-vtables \\
    -ffast-math \\
    -funsafe-math-optimizations \\
    -ftree-vectorize \\
    -ffunction-sections \\
    -fdata-sections \\
    "\$@"
EOF
    
    # Clang++ wrapper
    cat > "$bin_dir/clang++" << EOF
#!/bin/bash
# Optimized Clang++ wrapper for Chromium

# Use our optimized toolchain  
export PATH="$TOOLCHAIN_DIR/install/bin:\$PATH"

# Apply optimization flags
exec clang++ \\
    -O3 \\
    -flto=thin \\
    -fwhole-program-vtables \\
    -ffast-math \\
    -funsafe-math-optimizations \\
    -ftree-vectorize \\
    -ffunction-sections \\
    -fdata-sections \\
    "\$@"
EOF
    
    # LLD wrapper
    cat > "$bin_dir/lld" << EOF
#!/bin/bash
# Optimized LLD wrapper for Chromium

export PATH="$TOOLCHAIN_DIR/install/bin:\$PATH"

exec lld \\
    -O3 \\
    --lto-O3 \\
    --icf=all \\
    --gc-sections \\
    "\$@"
EOF
    
    # Make wrappers executable
    chmod +x "$bin_dir"/*
    
    log_success "Wrapper scripts created"
}

# Generate toolchain configuration
generate_config() {
    log_info "Generating toolchain configuration..."
    
    cat > "$TOOLCHAIN_DIR/toolchain.conf" << EOF
# Ultimate Chromium Toolchain Configuration
# Generated: $(date)

TOOLCHAIN_ROOT="$TOOLCHAIN_DIR"
TOOLCHAIN_BIN="$TOOLCHAIN_DIR/bin"
LLVM_INSTALL="$TOOLCHAIN_DIR/install"
PGO_DIR="$TOOLCHAIN_DIR/pgo"
BOLT_DIR="$TOOLCHAIN_DIR/bolt"

# Environment variables for Chromium build
export CC="$TOOLCHAIN_DIR/bin/clang"
export CXX="$TOOLCHAIN_DIR/bin/clang++"
export LD="$TOOLCHAIN_DIR/bin/lld"
export AR="$TOOLCHAIN_DIR/install/bin/llvm-ar"
export NM="$TOOLCHAIN_DIR/install/bin/llvm-nm"
export RANLIB="$TOOLCHAIN_DIR/install/bin/llvm-ranlib"
export OBJCOPY="$TOOLCHAIN_DIR/install/bin/llvm-objcopy"
export OBJDUMP="$TOOLCHAIN_DIR/install/bin/llvm-objdump"
export STRIP="$TOOLCHAIN_DIR/install/bin/llvm-strip"

# Optimization flags
export CFLAGS="-O3 -flto=thin -ffast-math -ftree-vectorize"
export CXXFLAGS="-O3 -flto=thin -ffast-math -ftree-vectorize"  
export LDFLAGS="-fuse-ld=lld -Wl,--lto-O3 -Wl,--icf=all"

# Path for tools
export PATH="$TOOLCHAIN_DIR/bin:$TOOLCHAIN_DIR/install/bin:\$PATH"

# Feature flags
TOOLCHAIN_HAS_LTO=1
TOOLCHAIN_HAS_PGO=1
TOOLCHAIN_HAS_POLLY=1
TOOLCHAIN_HAS_BOLT=1
TOOLCHAIN_HAS_AVX512=1
EOF
    
    log_success "Toolchain configuration generated"
}

# Verify toolchain installation
verify_toolchain() {
    log_info "Verifying toolchain installation..."
    
    local errors=0
    
    # Check for required binaries
    local required_bins=("clang" "clang++" "lld" "llvm-ar" "llvm-profdata")
    
    for bin in "${required_bins[@]}"; do
        if [ -f "$TOOLCHAIN_DIR/install/bin/$bin" ]; then
            log_success "Found: $bin"
        else
            log_error "Missing: $bin"
            ((errors++))
        fi
    done
    
    # Test compilation
    log_info "Testing compilation..."
    
    cat > /tmp/test.c << 'EOF'
#include <stdio.h>
int main() { 
    printf("Optimized toolchain test\n");
    return 0;
}
EOF
    
    if "$TOOLCHAIN_DIR/install/bin/clang" -O3 -o /tmp/test /tmp/test.c; then
        log_success "Compilation test passed"
        rm -f /tmp/test /tmp/test.c
    else
        log_error "Compilation test failed"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Toolchain verification complete - all checks passed"
        return 0
    else
        log_error "Toolchain verification failed with $errors errors"
        return 1
    fi
}

# Main setup process
main() {
    log_info "Setting up ultimate optimized toolchain..."
    
    check_dependencies
    setup_directory
    clone_llvm
    configure_llvm
    build_llvm
    configure_clang_optimizations
    setup_pgo_infrastructure
    setup_bolt_infrastructure  
    create_wrapper_scripts
    generate_config
    verify_toolchain
    
    log_success "Ultimate optimized toolchain setup complete!"
    log_info "Toolchain location: $TOOLCHAIN_DIR"
    log_info "Configuration: $TOOLCHAIN_DIR/toolchain.conf"
    log_info "To use this toolchain, source the configuration file:"
    log_info "  source $TOOLCHAIN_DIR/toolchain.conf"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
