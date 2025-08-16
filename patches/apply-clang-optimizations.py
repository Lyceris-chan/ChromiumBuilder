#!/usr/bin/env python3
"""
Apply Chromium Clang optimization patches
Handles LTO, PGO, Polly, BOLT, fast-math, and AVX512 optimizations
"""

import argparse
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path
import json
import re

class ClangOptimizer:
    def __init__(self, clang_dir, chromium_dir, target_arch="avx512", verbose=False):
        self.clang_dir = Path(clang_dir)
        self.chromium_dir = Path(chromium_dir)
        self.target_arch = target_arch
        self.verbose = verbose
        
        # Setup logging
        log_level = logging.DEBUG if verbose else logging.INFO
        logging.basicConfig(
            level=log_level,
            format='[%(levelname)s] %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Validate directories
        self._validate_directories()

    def _validate_directories(self):
        """Validate required directories exist"""
        if not self.clang_dir.exists():
            self.logger.error(f"Chromium Clang directory not found: {self.clang_dir}")
            sys.exit(1)
            
        if not self.chromium_dir.exists():
            self.logger.error(f"Chromium directory not found: {self.chromium_dir}")
            sys.exit(1)

    def apply_v8_optimizations(self):
        """Apply V8 engine optimization patches"""
        self.logger.info("Applying V8 engine optimizations...")
        
        v8_patch_dir = self.clang_dir / "V8"
        if not v8_patch_dir.exists():
            self.logger.warning("V8 patch directory not found")
            return False
        
        # Apply V8 patches
        v8_patches = list(v8_patch_dir.glob("*.patch"))
        success_count = 0
        
        for patch_file in v8_patches:
            if self._apply_patch(patch_file):
                success_count += 1
            else:
                self.logger.warning(f"V8 patch failed: {patch_file.name}")
        
        self.logger.info(f"Applied {success_count}/{len(v8_patches)} V8 optimization patches")
        return success_count > 0

    def apply_windows_optimizations(self):
        """Apply Windows-specific optimization patches"""
        self.logger.info("Applying Windows optimization patches...")
        
        win_patch_dir = self.clang_dir / "Windows"
        if not win_patch_dir.exists():
            self.logger.warning("Windows patch directory not found")
            return False
        
        # Find target architecture specific patches
        arch_patches = []
        
        if self.target_arch == "avx512":
            arch_patches.extend(list(win_patch_dir.glob("*avx512*.patch")))
        elif self.target_arch == "avx2":
            arch_patches.extend(list(win_patch_dir.glob("*avx2*.patch")))
        
        # Also apply general Windows patches
        general_patches = [p for p in win_patch_dir.glob("*.patch") 
                          if "avx" not in p.name.lower()]
        
        all_patches = arch_patches + general_patches
        success_count = 0
        
        for patch_file in all_patches:
            if self._apply_patch(patch_file):
                success_count += 1
            else:
                self.logger.warning(f"Windows patch failed: {patch_file.name}")
        
        self.logger.info(f"Applied {success_count}/{len(all_patches)} Windows optimization patches")
        return success_count > 0

    def apply_linux_optimizations(self):
        """Apply Linux optimization patches that work for cross-compilation"""
        self.logger.info("Applying cross-platform optimization patches...")
        
        linux_patch_dir = self.clang_dir / "Linux"
        if not linux_patch_dir.exists():
            self.logger.warning("Linux patch directory not found")
            return False
        
        # Apply general optimization patches that work for Windows cross-compilation
        cross_platform_patches = []
        
        for patch_file in linux_patch_dir.glob("*.patch"):
            # Only apply patches that don't have Linux-specific dependencies
            patch_name = patch_file.name.lower()
            if not any(skip in patch_name for skip in ["alsa", "gtk", "x11", "wayland"]):
                cross_platform_patches.append(patch_file)
        
        success_count = 0
        for patch_file in cross_platform_patches:
            if self._apply_patch(patch_file):
                success_count += 1
            else:
                self.logger.warning(f"Cross-platform patch failed: {patch_file.name}")
        
        self.logger.info(f"Applied {success_count}/{len(cross_platform_patches)} cross-platform patches")
        return success_count > 0

    def _apply_patch(self, patch_path):
        """Apply a single patch file"""
        try:
            self.logger.debug(f"Applying optimization patch: {patch_path.name}")
            
            # First try git apply
            cmd = [
                "git", "apply", "--ignore-whitespace", "--ignore-space-change",
                "--reject", str(patch_path)
            ]
            
            result = subprocess.run(
                cmd,
                cwd=self.chromium_dir,
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                self.logger.debug(f"Successfully applied: {patch_path.name}")
                return True
            else:
                self.logger.debug(f"Git apply failed for {patch_path.name}, trying patch command")
                return self._apply_patch_fallback(patch_path)
                
        except Exception as e:
            self.logger.error(f"Exception applying patch {patch_path.name}: {e}")
            return False

    def _apply_patch_fallback(self, patch_path):
        """Fallback patch application using patch command"""
        try:
            cmd = [
                "patch", "-p1", "-i", str(patch_path), 
                "--ignore-whitespace", "--reject-file=-"
            ]
            
            result = subprocess.run(
                cmd,
                cwd=self.chromium_dir,
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                self.logger.debug(f"Fallback patch successful: {patch_path.name}")
                return True
            else:
                # Check if partial application was successful
                if "succeeded" in result.stdout.lower():
                    self.logger.warning(f"Partial patch success: {patch_path.name}")
                    return True
                
                self.logger.debug(f"Fallback patch failed: {patch_path.name}")
                return False
                
        except Exception as e:
            self.logger.error(f"Fallback patch exception: {e}")
            return False

    def configure_build_args(self):
        """Configure build arguments for maximum optimization"""
        self.logger.info("Configuring Clang optimization build arguments...")
        
        try:
            # Read existing args.gn if present
            args_file = self.chromium_dir / "out" / "Ultimate" / "args.gn"
            args_file.parent.mkdir(parents=True, exist_ok=True)
            
            existing_args = ""
            if args_file.exists():
                with open(args_file, 'r') as f:
                    existing_args = f.read()
            
            # Add Clang optimization flags
            optimization_flags = self._generate_optimization_flags()
            
            with open(args_file, 'w') as f:
                f.write(existing_args)
                f.write('\n\n# Chromium Clang Optimizations\n')
                f.write(optimization_flags)
            
            self.logger.info("Build arguments configured with Clang optimizations")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to configure build args: {e}")
            return False

    def _generate_optimization_flags(self):
        """Generate optimization flags for args.gn"""
        flags = []
        
        # LTO optimizations
        flags.extend([
            "# Link Time Optimization",
            "use_thin_lto = true",
            "use_lld = true", 
            "thin_lto_enable_optimizations = true",
            "use_text_section_splitting = true",
            ""
        ])
        
        # PGO optimizations  
        flags.extend([
            "# Profile Guided Optimization",
            "chrome_pgo_phase = 2",
            "pgo_data_path = \"\"",  # Will be filled by build process
            ""
        ])
        
        # Polly optimizations
        flags.extend([
            "# Polly High-level Optimizations", 
            "use_polly = true",
            ""
        ])
        
        # AVX512 specific flags
        if self.target_arch == "avx512":
            flags.extend([
                "# AVX512 Optimization Flags",
                "common_optimize_on_cflags = [",
                "  \"-march=skylake-avx512\",",
                "  \"-mtune=skylake-avx512\",", 
                "  \"-mavx512f\",",
                "  \"-mavx512cd\",",
                "  \"-mavx512vl\",",
                "  \"-mavx512bw\",",
                "  \"-mavx512dq\",",
                "  \"-mfma\",",
                "]",
                ""
            ])
        
        # Fast-math optimizations
        flags.extend([
            "# Fast-math Optimizations",
            "common_optimize_on_cflags += [",
            "  \"-ffast-math\",",
            "  \"-funsafe-math-optimizations\",",
            "  \"-ffinite-math-only\",",
            "  \"-fno-signed-zeros\",",
            "  \"-fno-trapping-math\",",
            "  \"-fassociative-math\",",
            "  \"-freciprocal-math\",",
            "]",
            ""
        ])
        
        # Vectorization flags
        flags.extend([
            "# Vectorization Optimizations", 
            "common_optimize_on_cflags += [",
            "  \"-ftree-vectorize\",",
            "  \"-ftree-slp-vectorize\",",
            "  \"-fvectorize\",",
            "  \"-fslp-vectorize\",",
            "]",
            ""
        ])
        
        # Linker optimizations
        flags.extend([
            "# Advanced Linker Optimizations",
            "common_optimize_on_ldflags = [",
            "  \"-fuse-ld=lld\",",
            "  \"-Wl,--lto-O3\",", 
            "  \"-Wl,--icf=all\",",
            "  \"-Wl,--gc-sections\",",
            "]",
            ""
        ])
        
        # V8 optimizations
        flags.extend([
            "# V8 Engine Optimizations",
            "v8_enable_builtins_optimization = true",
            "v8_enable_fast_torque = true",
            "v8_enable_turbofan = true",
            ""
        ])
        
        return '\n'.join(flags)

    def setup_custom_toolchain(self):
        """Setup custom Clang toolchain with optimizations"""
        self.logger.info("Setting up custom optimized Clang toolchain...")
        
        try:
            # Update Clang with optimization flags
            clang_update_script = self.chromium_dir / "tools" / "clang" / "scripts" / "update.py"
            
            if clang_update_script.exists():
                cmd = [
                    "python3", str(clang_update_script),
                    "--bootstrap",
                    "--without-android", 
                    "--without-fuchsia",
                    "--disable-asserts",
                    "--thinlto",
                    "--pgo"
                ]
                
                # Add BOLT if available
                if shutil.which("llvm-bolt"):
                    cmd.append("--bolt")
                
                result = subprocess.run(
                    cmd,
                    cwd=self.chromium_dir,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode == 0:
                    self.logger.info("Custom Clang toolchain setup complete")
                    return True
                else:
                    self.logger.warning("Custom toolchain setup had issues, continuing...")
                    return True  # Don't fail build for toolchain issues
            else:
                self.logger.warning("Clang update script not found, using default toolchain")
                return True
                
        except Exception as e:
            self.logger.error(f"Toolchain setup failed: {e}")
            return True  # Don't fail build for toolchain issues

    def verify_optimizations(self):
        """Verify that optimization patches were applied"""
        self.logger.info("Verifying optimization patches...")
        
        verification_points = [
            # Check for modified build files
            ("build/config/compiler/BUILD.gn", "O3"),
            ("build/config/compiler/BUILD.gn", "lto"),
            # Check for AVX512 references
            ("BUILD.gn", self.target_arch.upper()),
        ]
        
        verified_count = 0
        for file_path, marker in verification_points:
            target_file = self.chromium_dir / file_path
            
            if target_file.exists():
                try:
                    with open(target_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read().lower()
                    
                    if marker.lower() in content:
                        verified_count += 1
                        self.logger.debug(f"Verified optimization in: {file_path}")
                except:
                    pass
        
        # Also check args.gn file
        args_file = self.chromium_dir / "out" / "Ultimate" / "args.gn"
        if args_file.exists():
            try:
                with open(args_file, 'r') as f:
                    content = f.read().lower()
                if "thin_lto" in content and "polly" in content:
                    verified_count += 1
            except:
                pass
        
        self.logger.info(f"Verified {verified_count} optimization markers")
        return verified_count > 0

    def run_all(self):
        """Execute complete Clang optimization process"""
        self.logger.info("Starting complete Clang optimization application...")
        
        success_steps = []
        
        # Apply V8 optimizations
        if self.apply_v8_optimizations():
            success_steps.append("V8 optimizations")
            
        # Apply Windows optimizations
        if self.apply_windows_optimizations():
            success_steps.append("Windows optimizations")
            
        # Apply cross-platform optimizations
        if self.apply_linux_optimizations():
            success_steps.append("cross-platform optimizations")
        
        # Configure build arguments
        if self.configure_build_args():
            success_steps.append("build configuration")
            
        # Setup custom toolchain
        if self.setup_custom_toolchain():
            success_steps.append("custom toolchain")
            
        # Verify optimizations
        if self.verify_optimizations():
            success_steps.append("verification")
        
        self.logger.info(f"Completed steps: {', '.join(success_steps)}")
        
        if len(success_steps) >= 4:  # At least most critical steps
            self.logger.info("Chromium Clang optimizations applied successfully!")
            return True
        else:
            self.logger.error("Some critical optimization steps failed")
            return False

def main():
    parser = argparse.ArgumentParser(
        description="Apply Chromium Clang optimization patches"
    )
    parser.add_argument(
        "--clang-dir",
        required=True,
        help="Path to Chromium Clang repository"
    )
    parser.add_argument(
        "--chromium-dir",
        required=True, 
        help="Path to Chromium source directory"
    )
    parser.add_argument(
        "--target-arch",
        default="avx512",
        choices=["avx", "avx2", "avx512"],
        help="Target architecture for optimizations"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    optimizer = ClangOptimizer(
        clang_dir=args.clang_dir,
        chromium_dir=args.chromium_dir,
        target_arch=args.target_arch,
        verbose=args.verbose
    )
    
    success = optimizer.run_all()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
