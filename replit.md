# replit.md

## Overview

Ultimate Chromium Builder is a comprehensive automation system that combines privacy patches from ungoogled-chromium with performance optimizations from Chromium Clang to build an optimized, privacy-focused Chromium browser for Windows 64-bit. The project uses Python scripts to systematically apply patches from two major sources: ungoogled-chromium for privacy enhancements (removing Google dependencies, telemetry, and tracking) and Chromium Clang for performance optimizations (LTO, PGO, Polly, BOLT, AVX512 instructions, and V8 engine improvements).

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Build System Architecture
The project follows a modular patch application architecture with three main components:
- **Main Build Script**: `build-ultimate-chromium.sh` serves as the orchestration layer that coordinates the entire build process
- **Privacy Patcher**: `apply-ungoogled-patches.py` handles systematic application of all ungoogled-chromium privacy patches
- **Performance Optimizer**: `apply-clang-optimizations.py` applies Chromium Clang performance optimizations

### Patch Management Strategy
The system uses a two-phase patching approach:
1. **Privacy Phase**: Applies ungoogled-chromium patches including core patches, extra patches, inox patchset, domain substitution, and component pruning
2. **Performance Phase**: Applies Chromium Clang optimizations including LTO, PGO, Polly, BOLT, fast-math, AVX512 instructions, and V8 engine enhancements

### Directory Structure Design
The architecture assumes three primary directories:
- Source Chromium directory for the base browser code
- ungoogled-chromium directory containing privacy patches and utilities
- Chromium Clang directory containing performance optimization patches

### Error Handling and Validation
Both Python scripts implement comprehensive validation systems that verify directory existence, import required utilities, and provide detailed logging for debugging build failures.

### Cross-Platform Build Target
The system is specifically architected for Windows 64-bit cross-compilation with AVX512 instruction set support, indicating a focus on high-performance desktop systems.

## External Dependencies

### Core Dependencies
- **ungoogled-chromium**: Privacy patch source providing core patches, extra patches, inox patchset, domain substitution rules, and pruning lists
- **Chromium Clang**: Performance optimization patch source for LTO, PGO, Polly, BOLT, and compiler optimizations
- **LLVM/Clang Toolchain**: Custom optimized compiler toolchain required for advanced optimizations
- **Python 3**: Runtime environment for patch application scripts with support for pathlib, subprocess, and logging modules

### Build Tools
- **Bash**: Primary build orchestration environment
- **Git**: Source code management for cloning and managing multiple repositories
- **Cross-compilation Tools**: Windows 64-bit target compilation support

### Optimization Frameworks
- **Profile Guided Optimization (PGO)**: Performance profiling data integration
- **Link Time Optimization (LTO)**: Cross-module optimization support
- **BOLT**: Post-link binary optimization tool
- **Polly**: LLVM-based high-level loop optimizer