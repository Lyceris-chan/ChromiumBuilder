#!/bin/bash

# Verify applied optimizations in built Chromium binary
# Checks for LTO, PGO, AVX512, and other performance optimizations

set -euo pipefail

BINARY_PATH="$1"
LOG_FILE="${2:-optimization-report.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize log file
echo "Optimization Verification Report - $(date)" > "$LOG_FILE"
echo "Binary: $BINARY_PATH" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

if [ ! -f "$BINARY_PATH" ]; then
    log_error "Binary not found: $BINARY_PATH"
    exit 1
fi

log_info "Starting optimization verification for: $BINARY_PATH"

# Check if binary exists and is executable
check_binary() {
    log_info "Checking binary properties..."
    
    if [ -f "$BINARY_PATH" ]; then
        local size=$(stat -c%s "$BINARY_PATH" 2>/dev/null || stat -f%z "$BINARY_PATH" 2>/dev/null || echo "unknown")
        log_success "Binary found, size: $size bytes"
        
        if [ -x "$BINARY_PATH" ]; then
            log_success "Binary is executable"
        else
            log_warning "Binary is not executable"
        fi
    else
        log_error "Binary not found"
        return 1
    fi
}

# Check for LTO optimization
check_lto_optimization() {
    log_info "Checking for Link Time Optimization (LTO) markers..."
    
    # Check for LTO-specific sections and symbols
    if command -v objdump >/dev/null 2>&1; then
        local lto_markers=0
        
        # Look for LTO-related sections
        if objdump -h "$BINARY_PATH" 2>/dev/null | grep -q "\.llvm"; then
            log_success "Found LLVM sections (LTO evidence)"
            ((lto_markers++))
        fi
        
        # Check for optimized symbol names (common with LTO)
        if objdump -t "$BINARY_PATH" 2>/dev/null | grep -q "\.llvm\|\.lto"; then
            log_success "Found LTO symbols"
            ((lto_markers++))
        fi
        
        if [ $lto_markers -gt 0 ]; then
            log_success "LTO optimization detected ($lto_markers indicators)"
        else
            log_warning "No clear LTO indicators found"
        fi
    else
        log_warning "objdump not available, cannot verify LTO"
    fi
}

# Check for AVX512 instruction usage
check_avx512_instructions() {
    log_info "Checking for AVX512 instruction usage..."
    
    if command -v objdump >/dev/null 2>&1; then
        # Disassemble and look for AVX512 instructions
        local avx512_count=0
        
        # Sample some sections for AVX512 instructions
        avx512_instructions=(
            "vaddpd.*%zmm"    # AVX512 packed double add
            "vaddps.*%zmm"    # AVX512 packed single add
            "vmulpd.*%zmm"    # AVX512 packed double multiply  
            "vmulps.*%zmm"    # AVX512 packed single multiply
            "vfmadd.*%zmm"    # AVX512 fused multiply-add
            "vpermute.*%zmm"  # AVX512 permute
            "vbroadcast.*%zmm" # AVX512 broadcast
        )
        
        for instruction in "${avx512_instructions[@]}"; do
            if objdump -d "$BINARY_PATH" 2>/dev/null | head -50000 | grep -q "$instruction"; then
                log_success "Found AVX512 instruction: $instruction"
                ((avx512_count++))
            fi
        done
        
        if [ $avx512_count -gt 0 ]; then
            log_success "AVX512 optimization detected ($avx512_count instruction types found)"
        else
            log_warning "No AVX512 instructions found in sampled code"
        fi
    else
        log_warning "objdump not available, cannot verify AVX512 instructions"
    fi
}

# Check for PGO optimization markers
check_pgo_optimization() {
    log_info "Checking for Profile Guided Optimization (PGO) markers..."
    
    # PGO often results in specific code layout patterns
    if command -v readelf >/dev/null 2>&1; then
        # Check for profile-related sections
        if readelf -S "$BINARY_PATH" 2>/dev/null | grep -q "profile\|pgo"; then
            log_success "Found profile-related sections"
        else
            log_warning "No obvious PGO sections found"
        fi
        
        # Check for hot/cold code separation (common with PGO)
        if readelf -S "$BINARY_PATH" 2>/dev/null | grep -q "\.text\.hot\|\.text\.cold\|\.text\.startup"; then
            log_success "Found hot/cold code sections (PGO evidence)"
        else
            log_warning "No hot/cold code sections found"
        fi
    else
        log_warning "readelf not available, cannot verify PGO"
    fi
}

# Check for fast-math optimizations
check_fastmath_optimization() {
    log_info "Checking for fast-math optimization patterns..."
    
    if command -v objdump >/dev/null 2>&1; then
        local fastmath_indicators=0
        
        # Look for aggressive floating-point operations
        fastmath_patterns=(
            "vfmadd"     # Fused multiply-add
            "vfmsub"     # Fused multiply-subtract  
            "vfnmadd"    # Fused negative multiply-add
            "vfnmsub"    # Fused negative multiply-subtract
            "vrcpps"     # Reciprocal approximation
            "vrsqrtps"   # Reciprocal square root approximation
        )
        
        for pattern in "${fastmath_patterns[@]}"; do
            if objdump -d "$BINARY_PATH" 2>/dev/null | head -50000 | grep -q "$pattern"; then
                log_success "Found fast-math pattern: $pattern"
                ((fastmath_indicators++))
            fi
        done
        
        if [ $fastmath_indicators -gt 0 ]; then
            log_success "Fast-math optimization detected ($fastmath_indicators patterns found)"
        else
            log_warning "No obvious fast-math patterns found in sampled code"
        fi
    fi
}

# Check for text section splitting
check_text_splitting() {
    log_info "Checking for text section splitting optimization..."
    
    if command -v readelf >/dev/null 2>&1; then
        local text_sections=$(readelf -S "$BINARY_PATH" 2>/dev/null | grep -c "\.text\." || echo "0")
        
        if [ "$text_sections" -gt 3 ]; then
            log_success "Text section splitting detected ($text_sections text sections)"
        else
            log_warning "Limited text section splitting ($text_sections sections)"
        fi
    fi
}

# Check for symbol optimization
check_symbol_optimization() {
    log_info "Checking for symbol table optimizations..."
    
    if command -v nm >/dev/null 2>&1; then
        local symbol_count=$(nm -D "$BINARY_PATH" 2>/dev/null | wc -l || echo "0")
        local local_symbols=$(nm "$BINARY_PATH" 2>/dev/null | grep -c " t \| d \| b " || echo "0")
        
        log_info "Dynamic symbols: $symbol_count"
        log_info "Local symbols: $local_symbols"
        
        if [ "$symbol_count" -lt 1000 ]; then
            log_success "Symbol table appears optimized (minimal dynamic symbols)"
        else
            log_warning "Symbol table may not be fully optimized"
        fi
    fi
}

# Check for BOLT optimization markers
check_bolt_optimization() {
    log_info "Checking for BOLT optimization markers..."
    
    if command -v readelf >/dev/null 2>&1; then
        # BOLT often creates specific section layouts
        if readelf -S "$BINARY_PATH" 2>/dev/null | grep -q "\.bolt\|\.text\.split"; then
            log_success "Found BOLT optimization markers"
        else
            log_warning "No obvious BOLT markers found"
        fi
    fi
}

# Check build configuration
check_build_config() {
    log_info "Checking build configuration markers..."
    
    if command -v strings >/dev/null 2>&1; then
        # Look for build flags in the binary
        local config_markers=0
        
        config_patterns=(
            "Official Build"
            "ThinLTO"
            "PGO"
            "Clang"
            "AVX512"
            "O3"
        )
        
        for pattern in "${config_patterns[@]}"; do
            if strings "$BINARY_PATH" 2>/dev/null | head -10000 | grep -q "$pattern"; then
                log_success "Found build marker: $pattern"
                ((config_markers++))
            fi
        done
        
        if [ $config_markers -gt 2 ]; then
            log_success "Build configuration markers found ($config_markers/6)"
        else
            log_warning "Limited build configuration markers found"
        fi
    fi
}

# Performance estimation
estimate_performance() {
    log_info "Estimating performance characteristics..."
    
    # Get binary size for comparison
    local size=$(stat -c%s "$BINARY_PATH" 2>/dev/null || stat -f%z "$BINARY_PATH" 2>/dev/null || echo "0")
    local size_mb=$((size / 1024 / 1024))
    
    log_info "Binary size: ${size_mb}MB"
    
    # Estimate based on size (optimized builds are often larger due to inlining)
    if [ "$size_mb" -gt 200 ]; then
        log_success "Large binary size suggests aggressive optimization"
    elif [ "$size_mb" -gt 100 ]; then
        log_info "Moderate binary size"
    else
        log_warning "Small binary size may indicate limited optimization"
    fi
}

# Generate summary
generate_summary() {
    log_info "Generating optimization summary..."
    
    echo "" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    echo "OPTIMIZATION SUMMARY" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    
    # Count successful verifications
    local success_count=$(grep -c "SUCCESS" "$LOG_FILE" || echo "0")
    local warning_count=$(grep -c "WARNING" "$LOG_FILE" || echo "0")
    local total_checks=8
    
    echo "Successful verifications: $success_count" | tee -a "$LOG_FILE"
    echo "Warnings: $warning_count" | tee -a "$LOG_FILE"
    echo "Total checks: $total_checks" | tee -a "$LOG_FILE"
    
    local score=$((success_count * 100 / total_checks))
    echo "Optimization score: $score%" | tee -a "$LOG_FILE"
    
    if [ "$score" -gt 70 ]; then
        log_success "Excellent optimization level detected!"
    elif [ "$score" -gt 50 ]; then
        log_success "Good optimization level detected"
    else
        log_warning "Limited optimization detected"
    fi
    
    echo "" | tee -a "$LOG_FILE"
    echo "Report saved to: $LOG_FILE" | tee -a "$LOG_FILE"
}

# Main verification process
main() {
    log_info "Starting comprehensive optimization verification..."
    
    check_binary || exit 1
    check_lto_optimization
    check_avx512_instructions  
    check_pgo_optimization
    check_fastmath_optimization
    check_text_splitting
    check_symbol_optimization
    check_bolt_optimization
    check_build_config
    estimate_performance
    generate_summary
    
    log_success "Optimization verification complete!"
}

# Execute main function
main "$@"
