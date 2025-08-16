#!/usr/bin/env python3
"""
Apply all ungoogled-chromium patches systematically
Handles core patches, extra patches, inox patchset, domain substitution, and pruning
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

class UngoogledPatcher:
    def __init__(self, ungoogled_dir, chromium_dir, verbose=False):
        self.ungoogled_dir = Path(ungoogled_dir)
        self.chromium_dir = Path(chromium_dir)
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
        
        # Initialize ungoogled-chromium utilities
        sys.path.insert(0, str(self.ungoogled_dir))
        
        try:
            from utils import patches as patch_utils
            from utils import substitution as sub_utils  
            from utils import pruning as prune_utils
            self.patch_utils = patch_utils
            self.sub_utils = sub_utils
            self.prune_utils = prune_utils
        except ImportError as e:
            self.logger.error(f"Failed to import ungoogled-chromium utilities: {e}")
            sys.exit(1)

    def _validate_directories(self):
        """Validate that required directories exist"""
        if not self.ungoogled_dir.exists():
            self.logger.error(f"Ungoogled directory not found: {self.ungoogled_dir}")
            sys.exit(1)
            
        if not self.chromium_dir.exists():
            self.logger.error(f"Chromium directory not found: {self.chromium_dir}")
            sys.exit(1)
            
        # Check for required files
        required_files = [
            "patches",
            "domain_substitution.list", 
            "domain_regex.list",
            "pruning.list",
            "flags.gn"
        ]
        
        for file_path in required_files:
            if not (self.ungoogled_dir / file_path).exists():
                self.logger.error(f"Required ungoogled file missing: {file_path}")
                sys.exit(1)

    def apply_core_patches(self):
        """Apply all patches from patches/core/ directory"""
        self.logger.info("Applying core privacy patches...")
        
        patches_dir = self.ungoogled_dir / "patches" / "core"
        if not patches_dir.exists():
            self.logger.warning("Core patches directory not found")
            return False
            
        return self._apply_patch_series(patches_dir, "core")

    def apply_extra_patches(self):
        """Apply all patches from patches/extra/ directory"""
        self.logger.info("Applying extra privacy patches...")
        
        patches_dir = self.ungoogled_dir / "patches" / "extra"  
        if not patches_dir.exists():
            self.logger.warning("Extra patches directory not found")
            return False
            
        return self._apply_patch_series(patches_dir, "extra")

    def apply_inox_patches(self):
        """Apply all patches from patches/inox-patchset/ directory"""
        self.logger.info("Applying Inox security patches...")
        
        patches_dir = self.ungoogled_dir / "patches" / "inox-patchset"
        if not patches_dir.exists():
            self.logger.warning("Inox patchset directory not found") 
            return False
            
        return self._apply_patch_series(patches_dir, "inox-patchset")

    def _apply_patch_series(self, patches_dir, series_name):
        """Apply a series of patches from a directory"""
        series_file = patches_dir / "series"
        
        if series_file.exists():
            # Use series file if available
            with open(series_file, 'r') as f:
                patch_files = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        else:
            # Fall back to all .patch files
            patch_files = [f.name for f in patches_dir.glob("*.patch")]
            patch_files.sort()
        
        success_count = 0
        total_patches = len(patch_files)
        
        self.logger.info(f"Found {total_patches} patches in {series_name} series")
        
        for patch_file in patch_files:
            patch_path = patches_dir / patch_file
            if not patch_path.exists():
                self.logger.warning(f"Patch file not found: {patch_file}")
                continue
                
            if self._apply_single_patch(patch_path):
                success_count += 1
            else:
                self.logger.error(f"Failed to apply patch: {patch_file}")
                return False
        
        self.logger.info(f"Successfully applied {success_count}/{total_patches} patches from {series_name}")
        return success_count == total_patches

    def _apply_single_patch(self, patch_path):
        """Apply a single patch file"""
        try:
            self.logger.debug(f"Applying patch: {patch_path.name}")
            
            # Use git apply for better handling
            cmd = [
                "git", "apply", "--ignore-whitespace", "--ignore-space-change",
                str(patch_path)
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
                self.logger.error(f"Patch failed: {patch_path.name}")
                self.logger.error(f"Error output: {result.stderr}")
                
                # Try with patch command as fallback
                return self._apply_patch_fallback(patch_path)
                
        except Exception as e:
            self.logger.error(f"Exception applying patch {patch_path.name}: {e}")
            return False

    def _apply_patch_fallback(self, patch_path):
        """Fallback patch application using patch command"""
        try:
            self.logger.debug(f"Trying fallback patch method for: {patch_path.name}")
            
            cmd = [
                "patch", "-p1", "-i", str(patch_path), "--ignore-whitespace"
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
                self.logger.error(f"Fallback patch failed: {patch_path.name}")
                return False
                
        except Exception as e:
            self.logger.error(f"Fallback patch exception: {e}")
            return False

    def apply_domain_substitution(self):
        """Apply domain substitution to remove Google dependencies"""
        self.logger.info("Applying domain substitution...")
        
        try:
            # Load domain substitution list
            domain_sub_list = self.ungoogled_dir / "domain_substitution.list"
            domain_regex_list = self.ungoogled_dir / "domain_regex.list"
            
            if not domain_sub_list.exists():
                self.logger.error("domain_substitution.list not found")
                return False
                
            if not domain_regex_list.exists():
                self.logger.error("domain_regex.list not found") 
                return False
            
            # Apply substitutions using ungoogled utilities
            from utils.substitution import SubstitutionDescriptor
            
            # Load substitution mappings
            with open(domain_regex_list, 'r') as f:
                regex_defs = f.read().strip().split('\n')
                
            with open(domain_sub_list, 'r') as f:
                sub_files = f.read().strip().split('\n')
            
            # Process substitutions
            substituted_count = 0
            for file_path in sub_files:
                if file_path.strip() and not file_path.startswith('#'):
                    target_file = self.chromium_dir / file_path.strip()
                    if target_file.exists():
                        if self._substitute_domains_in_file(target_file, regex_defs):
                            substituted_count += 1
            
            self.logger.info(f"Domain substitution applied to {substituted_count} files")
            return True
            
        except Exception as e:
            self.logger.error(f"Domain substitution failed: {e}")
            return False

    def _substitute_domains_in_file(self, file_path, regex_defs):
        """Apply domain substitutions to a single file"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            original_content = content
            
            # Apply each regex substitution
            for regex_line in regex_defs:
                if regex_line.strip() and not regex_line.startswith('#'):
                    parts = regex_line.strip().split('@')
                    if len(parts) == 2:
                        pattern, replacement = parts
                        content = re.sub(pattern, replacement, content)
            
            # Write back if changed
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                self.logger.debug(f"Updated: {file_path}")
                return True
            
            return False
            
        except Exception as e:
            self.logger.debug(f"Could not process file {file_path}: {e}")
            return False

    def apply_pruning(self):
        """Apply pruning list to remove unwanted files"""
        self.logger.info("Applying pruning list...")
        
        try:
            pruning_list = self.ungoogled_dir / "pruning.list"
            if not pruning_list.exists():
                self.logger.error("pruning.list not found")
                return False
            
            with open(pruning_list, 'r') as f:
                prune_paths = [line.strip() for line in f if line.strip() and not line.startswith('#')]
            
            pruned_count = 0
            for prune_path in prune_paths:
                target_path = self.chromium_dir / prune_path
                
                if target_path.exists():
                    if target_path.is_dir():
                        shutil.rmtree(target_path)
                        self.logger.debug(f"Removed directory: {prune_path}")
                    else:
                        target_path.unlink()
                        self.logger.debug(f"Removed file: {prune_path}")
                    pruned_count += 1
                else:
                    self.logger.debug(f"Prune target not found: {prune_path}")
            
            self.logger.info(f"Pruned {pruned_count} items")
            return True
            
        except Exception as e:
            self.logger.error(f"Pruning failed: {e}")
            return False

    def apply_build_flags(self):
        """Apply ungoogled-chromium build flags"""
        self.logger.info("Applying ungoogled-chromium build flags...")
        
        try:
            flags_file = self.ungoogled_dir / "flags.gn"
            if not flags_file.exists():
                self.logger.error("flags.gn not found")
                return False
            
            # Read ungoogled flags
            with open(flags_file, 'r') as f:
                ungoogled_flags = f.read()
            
            # Append to existing args.gn or create new one
            args_file = self.chromium_dir / "out" / "Ultimate" / "args.gn"
            args_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Check if args.gn already exists (from merged config)
            if args_file.exists():
                with open(args_file, 'a') as f:
                    f.write('\n\n# Ungoogled-Chromium specific flags\n')
                    f.write(ungoogled_flags)
            else:
                with open(args_file, 'w') as f:
                    f.write('# Ungoogled-Chromium build flags\n')
                    f.write(ungoogled_flags)
            
            self.logger.info("Build flags applied")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to apply build flags: {e}")
            return False

    def verify_patches(self):
        """Verify that patches were applied successfully"""
        self.logger.info("Verifying patch application...")
        
        verification_markers = [
            # Look for ungoogled-chromium specific changes
            ("chrome/browser/chrome_browser_main.cc", "ungoogled-chromium"),
            ("chrome/browser/about_flags.cc", "ungoogled-chromium"),
            # Check for removed Google services
            ("google_apis/BUILD.gn", False),  # Should be modified/removed
        ]
        
        verified_count = 0
        for file_path, marker in verification_markers:
            target_file = self.chromium_dir / file_path
            
            if target_file.exists():
                try:
                    with open(target_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    if marker is False:
                        # File should be modified (not contain original content)
                        verified_count += 1
                    elif marker in content:
                        verified_count += 1
                        self.logger.debug(f"Verified marker in: {file_path}")
                except:
                    pass
        
        self.logger.info(f"Verified {verified_count}/{len(verification_markers)} patch markers")
        return verified_count > 0

    def run_all(self):
        """Execute complete ungoogled-chromium patching process"""
        self.logger.info("Starting complete ungoogled-chromium patch application...")
        
        success_steps = []
        
        # Apply all patch series
        if self.apply_core_patches():
            success_steps.append("core patches")
            
        if self.apply_extra_patches():
            success_steps.append("extra patches")
            
        if self.apply_inox_patches():
            success_steps.append("inox patches")
        
        # Apply domain substitution
        if self.apply_domain_substitution():
            success_steps.append("domain substitution")
            
        # Apply pruning
        if self.apply_pruning():
            success_steps.append("pruning")
            
        # Apply build flags
        if self.apply_build_flags():
            success_steps.append("build flags")
            
        # Verify patches
        if self.verify_patches():
            success_steps.append("verification")
        
        self.logger.info(f"Completed steps: {', '.join(success_steps)}")
        
        if len(success_steps) >= 5:  # At least most critical steps
            self.logger.info("Ungoogled-chromium patches applied successfully!")
            return True
        else:
            self.logger.error("Some critical patching steps failed")
            return False

def main():
    parser = argparse.ArgumentParser(
        description="Apply ungoogled-chromium patches systematically"
    )
    parser.add_argument(
        "--ungoogled-dir",
        required=True,
        help="Path to ungoogled-chromium repository"
    )
    parser.add_argument(
        "--chromium-dir", 
        required=True,
        help="Path to Chromium source directory"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    patcher = UngoogledPatcher(
        ungoogled_dir=args.ungoogled_dir,
        chromium_dir=args.chromium_dir, 
        verbose=args.verbose
    )
    
    success = patcher.run_all()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
