#!/usr/bin/env python3
"""
build.py - Build WazeOSM dylib on Linux without Theos
Cross-compiler for iOS 6 armv7
"""

import subprocess
import sys
import os
import shutil
import urllib.request
import tarfile
import json

class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    END = '\033[0m'

def log(msg):
    print(f"{Colors.BLUE}[BUILD]{Colors.END} {msg}")

def success(msg):
    print(f"{Colors.GREEN}[OK]{Colors.END} {msg}")

def warn(msg):
    print(f"{Colors.YELLOW}[WARN]{Colors.END} {msg}")

def error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.END} {msg}")
    sys.exit(1)

class Builder:
    def __init__(self):
        self.sdk_path = "/tmp/iPhoneOS6.1.sdk"
        self.cc = "/usr/bin/clang"
        self.cxx = "/usr/bin/clang++"
        self.build_dir = "/tmp/wazeosm-build"
        self.output = "WazeOSM.dylib"
        
    def check_dependencies(self):
        log("Checking dependencies...")
        
        # Check for clang
        if not shutil.which("clang"):
            error("clang not found. Install with: sudo apt-get install clang")
        
        # Check for ldid
        if not shutil.which("ldid"):
            warn("ldid not found. Will try to install...")
            self.install_ldid()
        
        # Check for dpkg-deb
        if not shutil.which("dpkg-deb"):
            warn("dpkg-deb not found. Install with: sudo apt-get install dpkg")
        
        success("Dependencies OK")
    
    def install_ldid(self):
        """Install ldid from source"""
        log("Installing ldid...")
        try:
            subprocess.run(["sudo", "apt-get", "install", "-y", "ldid"], check=True)
        except:
            warn("Could not install ldid via apt. Building from source...")
            # Build from source
            os.makedirs("/tmp/ldid-build", exist_ok=True)
            os.chdir("/tmp/ldid-build")
            subprocess.run(["git", "clone", "https://github.com/ProcursusTeam/ldid.git", "."], check=True)
            subprocess.run(["make"], check=True)
            subprocess.run(["sudo", "make", "install"], check=True)
            os.chdir("/tmp")
    
    def download_sdk(self):
        """Download iOS 6.1 SDK"""
        if os.path.exists(self.sdk_path):
            log("SDK already exists, skipping download")
            return
        
        log("Downloading iOS 6.1 SDK...")
        sdk_url = "https://github.com/xybp888/iOS-SDKs/releases/download/iOS-SDKs/iPhoneOS6.1.sdk.tar.xz"
        sdk_file = "/tmp/iPhoneOS6.1.sdk.tar.xz"
        
        try:
            urllib.request.urlretrieve(sdk_url, sdk_file)
            log("Extracting SDK...")
            with tarfile.open(sdk_file) as tar:
                tar.extractall("/tmp/")
            os.remove(sdk_file)
            success("SDK ready at " + self.sdk_path)
        except Exception as e:
            error(f"Failed to download SDK: {e}")
    
    def compile_tweak(self):
        """Compile the tweak"""
        log("Compiling WazeOSM tweak...")
        
        # Create build directory
        os.makedirs(self.build_dir, exist_ok=True)
        
        # Compile command
        cmd = [
            self.cc,
            "-arch", "armv7",
            "-isysroot", self.sdk_path,
            "-miphoneos-version-min=6.0",
            "-fobjc-arc",
            "-fmodules",
            "-fmodule-name=WazeOSM",
            "-O2",
            "-c",
            "Tweak.xm",
            "-o",
            os.path.join(self.build_dir, "Tweak.o")
        ]
        
        log(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            error(f"Compilation failed:\n{result.stderr}")
        
        success("Compilation successful")
    
    def link_tweak(self):
        """Link the tweak into a dylib"""
        log("Linking WazeOSM.dylib...")
        
        cmd = [
            self.cc,
            "-arch", "armv7",
            "-isysroot", self.sdk_path,
            "-miphoneos-version-min=6.0",
            "-dynamiclib",
            "-install_name", "@executable_path/WazeOSM.dylib",
            "-framework", "Foundation",
            "-framework", "UIKit",
            "-framework", "CoreGraphics",
            "-framework", "CoreLocation",
            "-framework", "MapKit",
            "-o", self.output,
            os.path.join(self.build_dir, "Tweak.o")
        ]
        
        log(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            error(f"Linking failed:\n{result.stderr}")
        
        # Strip the dylib
        subprocess.run(["strip", "-x", self.output], check=True)
        
        success(f"Created {self.output}")
        
        # Show info
        result = subprocess.run(["file", self.output], capture_output=True, text=True)
        log(f"Output: {result.stdout.strip()}")
        
        result = subprocess.run(["du", "-h", self.output], capture_output=True, text=True)
        log(f"Size: {result.stdout.strip()}")
    
    def sign_dylib(self):
        """Sign the dylib with ldid"""
        log("Signing dylib with ldid...")
        
        result = subprocess.run(["ldid", "-S", self.output], capture_output=True, text=True)
        
        if result.returncode != 0:
            warn(f"ldid signing failed: {result.stderr}")
        else:
            success("dylib signed")
    
    def build(self):
        """Full build pipeline"""
        log("=" * 50)
        log("WazeOSM Build System")
        log("=" * 50)
        
        self.check_dependencies()
        self.download_sdk()
        self.compile_tweak()
        self.link_tweak()
        self.sign_dylib()
        
        log("=" * 50)
        success("Build complete!")
        log(f"Output: {os.path.abspath(self.output)}")
        log("=" * 50)

if __name__ == "__main__":
    builder = Builder()
    builder.build()
