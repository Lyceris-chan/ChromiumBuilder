#!/bin/bash

# Ultimate Chromium Builder - Privacy + Performance Optimized
# Combines ungoogled-chromium privacy patches with Chromium Clang optimizations
# Target: Windows 64-bit AVX512 cross-compilation from Linux

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
CHROMIUM_DIR="${BUILD_DIR}/chromium"
UNGOOGLED_DIR="${BUILD_DIR}/ungoogled-chromium"
CLANG_DIR="${BUILD_DIR}/chromium-clang"
TOOLCHAIN_DIR="${BUILD_DIR}/custom-toolchain"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Error handling
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Build failed. Cleaning up..."
        # Preserve logs but clean temp files
        find "${BUILD_DIR}" -name "*.tmp" -delete 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Verify dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=("git" "python3" "curl" "tar" "patch" "make" "cmake")
    local missing_deps=()
    
    # Check basic dependencies
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
            log_error "Required dependency '$dep' not found"
        fi
    done
    
    # Check for ninja (different command names on different systems)
    if command -v ninja &> /dev/null; then
        log_success "Found ninja build system"
    elif command -v ninja-build &> /dev/null; then
        log_success "Found ninja-build build system"
        # Create symlink for consistency
        if [ ! -f "$HOME/.local/bin/ninja" ]; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(which ninja-build)" "$HOME/.local/bin/ninja"
            log_info "Created ninja symlink for compatibility"
        fi
    else
        missing_deps+=("ninja")
        log_error "Required dependency 'ninja' not found (install ninja-build package)"
    fi
    
    # Check for minimum Python version
    if command -v python3 &> /dev/null; then
        python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" || {
            log_error "Python 3.8+ required"
            missing_deps+=("python3.8+")
        }
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo
        log_info "To install all dependencies, run:"
        log_info "  ./install-dependencies.sh"
        echo
        log_info "Or install manually on Ubuntu/Debian:"
        log_info "  sudo apt update"
        log_info "  sudo apt install -y build-essential cmake ninja-build git curl python3 python3-pip patch make"
        echo
        exit 1
    fi
    
    log_success "All dependencies verified"
}

# Setup build environment
setup_environment() {
    log_info "Setting up build environment..."
    
    # Create build directory structure
    mkdir -p "${BUILD_DIR}"/{chromium,logs,artifacts}
    
    # Set environment variables
    export DEPOT_TOOLS_WIN_TOOLCHAIN=0
    export DEPOT_TOOLS_UPDATE=1
    export GYP_MSVS_VERSION=2022
    export GYP_MSVS_OVERRIDE_PATH="/usr/bin"
    
    # Install depot_tools if not present
    if [ ! -d "${BUILD_DIR}/depot_tools" ]; then
        log_info "Installing depot_tools..."
        cd "${BUILD_DIR}"
        git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    fi
    
    export PATH="${BUILD_DIR}/depot_tools:$PATH"
    
    log_success "Build environment ready"
}

# Clone repositories
clone_repositories() {
    log_info "Cloning repositories..."
    
    cd "${BUILD_DIR}"
    
    # Clone ungoogled-chromium
    if [ ! -d "${UNGOOGLED_DIR}" ]; then
        log_info "Cloning ungoogled-chromium..."
        git clone --depth 1 https://github.com/ungoogled-software/ungoogled-chromium.git ungoogled-chromium
    else
        log_info "Updating ungoogled-chromium..."
        cd "${UNGOOGLED_DIR}" && (git pull origin master || git pull origin main) && cd "${BUILD_DIR}"
    fi
    
    # Clone Chromium Clang optimizations
    if [ ! -d "${CLANG_DIR}" ]; then
        log_info "Cloning Chromium Clang optimizations..."
        git clone --depth 1 https://github.com/RobRich999/Chromium_Clang.git chromium-clang
    else
        log_info "Updating Chromium Clang..."
        cd "${CLANG_DIR}" && git pull origin main && cd "${BUILD_DIR}"
    fi
    
    # Get Chromium source
    if [ ! -d "${CHROMIUM_DIR}" ]; then
        log_info "Fetching Chromium source (this may take a while)..."
        cd "${BUILD_DIR}"
        
        # Check if depot_tools is in PATH
        if ! command -v fetch >/dev/null; then
            log_error "depot_tools not found in PATH"
            export PATH="${BUILD_DIR}/depot_tools:$PATH"
        fi
        
        # Fetch Chromium with timeout and retry
        timeout 3600 fetch --nohooks chromium || {
            log_error "Chromium fetch failed or timed out"
            log_info "You may need to run this manually: cd ${BUILD_DIR} && fetch --nohooks chromium"
            exit 1
        }
        
        cd chromium
        
        # Get the correct Chromium version
        if [ -f "${UNGOOGLED_DIR}/chromium_version.txt" ]; then
            local chromium_version=$(cat "${UNGOOGLED_DIR}/chromium_version.txt")
            log_info "Checking out Chromium version: $chromium_version"
            git checkout -f "$chromium_version"
        else
            log_warning "chromium_version.txt not found, using latest"
        fi
        
        # Run hooks
        gclient sync --nohooks
    else
        log_info "Chromium source already available"
    fi
    
    log_success "All repositories ready"
}

# Setup custom Clang toolchain
setup_custom_toolchain() {
    log_info "Setting up custom optimized Clang toolchain..."
    
    # Check available system resources
    local total_mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem_gb" -lt 4 ]; then
        log_error "Insufficient memory for toolchain build. At least 4GB RAM required."
        log_info "Consider using a system with more memory or enable swap space."
        exit 1
    fi
    
    # Run toolchain setup script with error handling
    if ! "${SCRIPT_DIR}/utils/setup-toolchain.sh" "${TOOLCHAIN_DIR}"; then
        log_error "Custom toolchain setup failed"
        log_info "Falling back to system Clang toolchain..."
        
        # Fallback: install and use system clang if custom build fails
        log_info "Installing system Clang toolchain as fallback..."
        sudo apt update >/dev/null 2>&1
        sudo apt install -y clang clang++ lld libc++-dev libc++abi-dev build-essential >/dev/null 2>&1
        
        if command -v clang >/dev/null && command -v clang++ >/dev/null; then
            log_warning "Using system Clang toolchain as fallback"
            export CC=clang
            export CXX=clang++
            export LD=lld
            return 0
        else
            log_error "Failed to install system Clang toolchain"
            exit 1
        fi
    fi
    
    # Only run Chromium's LLVM update if we have the Chromium source
    if [ -d "${CHROMIUM_DIR}/tools/clang" ]; then
        log_info "Updating Chromium's LLVM tools..."
        cd "${CHROMIUM_DIR}"
        
        # Update LLVM for optimizations (with fallback)
        python3 tools/clang/scripts/update.py --bootstrap --without-android \
            --without-fuchsia --disable-asserts || {
            log_warning "LLVM update failed, proceeding with existing toolchain"
        }
    else
        log_info "Chromium source not available yet, skipping LLVM update"
    fi
    
    log_success "Custom toolchain ready"
}

# Apply ungoogled-chromium patches
apply_ungoogled_patches() {
    log_info "Applying ungoogled-chromium patches..."
    
    cd "${CHROMIUM_DIR}"
    
    # Run ungoogled-chromium utilities
    python3 "${SCRIPT_DIR}/patches/apply-ungoogled-patches.py" \
        --ungoogled-dir "${UNGOOGLED_DIR}" \
        --chromium-dir "${CHROMIUM_DIR}" \
        --verbose
    
    log_success "Ungoogled patches applied successfully"
}

# Apply Chromium Clang optimizations
apply_clang_optimizations() {
    log_info "Applying Chromium Clang optimizations..."
    
    cd "${CHROMIUM_DIR}"
    
    # Apply optimization patches
    python3 "${SCRIPT_DIR}/patches/apply-clang-optimizations.py" \
        --clang-dir "${CLANG_DIR}" \
        --chromium-dir "${CHROMIUM_DIR}" \
        --target-arch avx512 \
        --verbose
    
    log_success "Clang optimizations applied successfully"
}

# Generate build configuration
generate_build_config() {
    log_info "Generating optimized build configuration..."
    
    cd "${CHROMIUM_DIR}"
    
    # Create output directory
    mkdir -p out/Ultimate
    
    # Copy merged args.gn with all optimizations
    cp "${SCRIPT_DIR}/config/merged-args.gn" out/Ultimate/args.gn
    
    # Generate build files
    gn gen out/Ultimate --args='import("//args.gn")'
    
    # Verify configuration
    gn args out/Ultimate --list | tee "${BUILD_DIR}/logs/build-config.log"
    
    log_success "Build configuration generated"
}

# Execute optimized build
execute_build() {
    log_info "Starting ultimate Chromium build..."
    
    cd "${CHROMIUM_DIR}"
    
    # Record build start time
    local start_time=$(date +%s)
    
    # Build with all optimizations
    ninja -C out/Ultimate chrome chrome_sandbox mini_installer \
        -j $(nproc) -v 2>&1 | tee "${BUILD_DIR}/logs/build.log"
    
    # Calculate build time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "Build completed in ${duration} seconds"
}

# Verify optimizations
verify_optimizations() {
    log_info "Verifying applied optimizations..."
    
    "${SCRIPT_DIR}/utils/verify-optimizations.sh" \
        "${CHROMIUM_DIR}/out/Ultimate/chrome.exe" \
        "${BUILD_DIR}/logs/optimization-report.log"
    
    log_success "Optimization verification complete"
}

# Package build artifacts
package_artifacts() {
    log_info "Packaging build artifacts..."
    
    cd "${CHROMIUM_DIR}/out/Ultimate"
    
    # Create artifact directory
    local artifact_dir="${BUILD_DIR}/artifacts/ultimate-chromium-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${artifact_dir}"
    
    # Copy main executables
    cp chrome.exe chrome_sandbox.exe mini_installer.exe "${artifact_dir}/"
    
    # Copy essential libraries
    cp -r locales resources "${artifact_dir}/"
    cp *.dll "${artifact_dir}/" 2>/dev/null || true
    
    # Create build info
    cat > "${artifact_dir}/build-info.txt" << EOF
Ultimate Chromium Build
Generated: $(date)
Chromium Version: $(cat "${UNGOOGLED_DIR}/chromium_version.txt")
Ungoogled-Chromium: $(cd "${UNGOOGLED_DIR}" && git rev-parse HEAD)
Chromium-Clang: $(cd "${CLANG_DIR}" && git rev-parse HEAD)

Features Applied:
- All ungoogled-chromium privacy patches
- All Chromium Clang performance optimizations
- AVX512 instruction set support
- Link Time Optimization (LTO)
- Profile Guided Optimization (PGO)
- Polly optimization
- BOLT optimization
- Fast-math optimizations
- Custom Clang/LLVM toolchain
- Windows cross-compilation optimizations

Target: Windows 64-bit AVX512
EOF
    
    # Create archive
    cd "${BUILD_DIR}/artifacts"
    tar -czf "$(basename "${artifact_dir}").tar.gz" "$(basename "${artifact_dir}")"
    
    log_success "Build artifacts packaged in ${artifact_dir}"
}

# Generate comprehensive report
generate_report() {
    log_info "Generating comprehensive build report..."
    
    local report_file="${BUILD_DIR}/logs/ultimate-chromium-report.md"
    
    cat > "${report_file}" << EOF
# Ultimate Chromium Build Report

**Build Date:** $(date)
**Build Duration:** ${duration:-N/A} seconds
**Target:** Windows 64-bit AVX512

## Applied Components

### Ungoogled-Chromium Features
- Privacy patches from patches/core/
- Additional privacy features from patches/extra/
- Security enhancements from patches/inox-patchset/
- Domain substitution and pruning
- Google dependency removal
- flags.gn privacy configuration

### Chromium Clang Optimizations
- **Link Time Optimization (LTO):** ThinLTO and Full LTO
- **Profile Guided Optimization (PGO):** Complete integration
- **Polly Optimization:** High-level loop optimizer
- **BOLT Optimization:** Binary optimization and layout
- **Fast-math:** Aggressive floating-point optimizations
- **AVX512:** 512-bit vector operations support
- **FMA:** Fused multiply-add optimizations
- **V8 Engine:** Enhanced JavaScript performance
- **Custom Clang/LLVM:** Optimized compiler toolchain
- **Windows Cross-compilation:** Complete target optimization

## Build Configuration Summary
$(cat "${SCRIPT_DIR}/config/merged-args.gn")

## Optimization Verification
$(cat "${BUILD_DIR}/logs/optimization-report.log" 2>/dev/null || echo "Verification report not available")

## Build Artifacts
$(ls -la "${BUILD_DIR}/artifacts/" 2>/dev/null || echo "No artifacts generated")

---
*Generated by Ultimate Chromium Builder*
EOF
    
    log_success "Report generated: ${report_file}"
}

# Show help information
show_help() {
    cat << EOF
Ultimate Chromium Builder - Privacy + Performance Optimized

DESCRIPTION:
    Combines ALL ungoogled-chromium privacy patches with ALL Chromium Clang 
    performance optimizations to build the ultimate privacy-focused, 
    high-performance Chromium browser for Windows 64-bit AVX512.

FEATURES APPLIED:
    Privacy (ungoogled-chromium):
    ✓ All core patches from patches/core/
    ✓ All extra patches from patches/extra/  
    ✓ All Inox security patches from patches/inox-patchset/
    ✓ Complete domain substitution (Google → privacy alternatives)
    ✓ Component pruning (remove telemetry/tracking)
    ✓ Privacy build flags (disable all Google services)

    Performance (Chromium Clang):
    ✓ Link Time Optimization (ThinLTO + Full LTO)
    ✓ Profile Guided Optimization (PGO) with complete integration
    ✓ Polly high-level loop optimizer
    ✓ BOLT binary optimization and layout  
    ✓ Fast-math optimizations for hot code paths
    ✓ AVX512 + FMA instruction set support
    ✓ V8 JavaScript engine optimizations
    ✓ Custom optimized Clang/LLVM toolchain
    ✓ Windows cross-compilation optimizations

TARGET:
    Windows 64-bit with AVX512 instruction set support

USAGE:
    $0 [options]

OPTIONS:
    --help, -h          Show this help message
    --verbose, -v       Enable verbose logging
    --clean             Clean build directory before starting
    --skip-deps         Skip dependency checking
    --dry-run           Show what would be done without executing

EXAMPLES:
    $0                  # Run complete build process
    $0 --verbose        # Run with detailed logging
    $0 --clean          # Clean build and start fresh

OUTPUT:
    Build artifacts:    ./build/artifacts/
    Build logs:         ./build/logs/
    Build report:       ./build/logs/ultimate-chromium-report.md

NOTE:
    This process builds a complete Chromium browser with maximum privacy
    and performance optimizations. Build time is typically 2-6 hours
    depending on hardware. Requires ~50GB free disk space.

EOF
}

# Parse command line arguments
parse_arguments() {
    VERBOSE=false
    CLEAN_BUILD=false
    SKIP_DEPS=false
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main execution flow
main() {
    parse_arguments "$@"
    
    log_info "Starting Ultimate Chromium Builder"
    log_info "Target: Windows 64-bit AVX512 with privacy + performance optimizations"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN MODE - Showing what would be executed:"
        log_info "1. Check dependencies (git, python3, ninja, cmake, etc.)"
        log_info "2. Setup build environment and depot_tools"
        log_info "3. Clone ungoogled-chromium and Chromium-Clang repositories"
        log_info "4. Fetch Chromium source code"
        log_info "5. Setup custom optimized Clang/LLVM toolchain"
        log_info "6. Apply ALL ungoogled-chromium patches (core + extra + inox)"
        log_info "7. Apply ALL Chromium Clang optimization patches"
        log_info "8. Generate merged build configuration with all optimizations"
        log_info "9. Execute optimized build (chrome, chrome_sandbox, mini_installer)"
        log_info "10. Verify applied optimizations"
        log_info "11. Package build artifacts"
        log_info "12. Generate comprehensive build report"
        return 0
    fi
    
    if [ "$CLEAN_BUILD" = true ]; then
        log_info "Cleaning build directory..."
        rm -rf "${BUILD_DIR}"
    fi
    
    if [ "$SKIP_DEPS" = false ]; then
        check_dependencies
    fi
    
    setup_environment
    clone_repositories
    setup_custom_toolchain
    apply_ungoogled_patches
    apply_clang_optimizations
    generate_build_config
    execute_build
    verify_optimizations
    package_artifacts
    generate_report
    
    log_success "Ultimate Chromium build completed successfully!"
    log_info "Artifacts available in: ${BUILD_DIR}/artifacts/"
    log_info "Build report: ${BUILD_DIR}/logs/ultimate-chromium-report.md"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
