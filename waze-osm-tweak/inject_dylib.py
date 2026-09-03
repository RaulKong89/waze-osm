#!/usr/bin/env python3
"""
inject_dylib.py - Inject WazeOSM dylib into Waze 3.9.6 IPA
Uses Mach-O binary manipulation to add LC_LOAD_DYLIB command
"""

import struct
import sys
import os
import shutil
import subprocess
import tempfile
import zipfile
import argparse

class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    END = '\033[0m'

def log(msg):
    print(f"{Colors.BLUE}[INJECT]{Colors.END} {msg}")

def success(msg):
    print(f"{Colors.GREEN}[OK]{Colors.END} {msg}")

def warn(msg):
    print(f"{Colors.YELLOW}[WARN]{Colors.END} {msg}")

def error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.END} {msg}")
    sys.exit(1)

class IPAInjector:
    def __init__(self, ipa_path, dylib_path, output_path):
        self.ipa_path = ipa_path
        self.dylib_path = dylib_path
        self.output_path = output_path
        self.work_dir = tempfile.mkdtemp(prefix="wazeosm_")
        
    def cleanup(self):
        """Remove temporary directory"""
        if os.path.exists(self.work_dir):
            shutil.rmtree(self.work_dir)
    
    def extract_ipa(self):
        """Extract IPA file"""
        log(f"Extracting {self.ipa_path}...")
        
        with zipfile.ZipFile(self.ipa_path, 'r') as zip_ref:
            zip_ref.extractall(self.work_dir)
        
        # Find Payload directory
        payload_dir = os.path.join(self.work_dir, "Payload")
        if not os.path.exists(payload_dir):
            error("Payload directory not found in IPA")
        
        # Find Waze.app
        app_dir = None
        for item in os.listdir(payload_dir):
            if item.endswith(".app"):
                app_dir = os.path.join(payload_dir, item)
                break
        
        if not app_dir:
            error("Could not find .app bundle in IPA")
        
        success(f"Extracted to {self.work_dir}")
        return app_dir
    
    def copy_dylib(self, app_dir):
        """Copy dylib into app bundle"""
        log(f"Copying {self.dylib_path} to app bundle...")
        
        if not os.path.exists(self.dylib_path):
            error(f"dylib not found: {self.dylib_path}")
        
        dest = os.path.join(app_dir, "WazeOSM.dylib")
        shutil.copy2(self.dylib_path, dest)
        
        # Also copy to PlugIns if exists
        plugins_dir = os.path.join(app_dir, "PlugIns")
        if os.path.exists(plugins_dir):
            for plugin in os.listdir(plugins_dir):
                if plugin.endswith(".appex"):
                    plugin_dir = os.path.join(plugins_dir, plugin)
                    shutil.copy2(self.dylib_path, plugin_dir)
        
        success("dylib copied")
    
    def inject_load_command(self, app_dir):
        """Inject LC_LOAD_DYLIB into the main binary"""
        binary_path = os.path.join(app_dir, "Waze")
        
        if not os.path.exists(binary_path):
            error(f"Binary not found: {binary_path}")
        
        log(f"Injecting load command into {binary_path}...")
        
        # Read binary
        with open(binary_path, 'rb') as f:
            data = bytearray(f.read())
        
        # Parse Mach-O header
        magic = struct.unpack('<I', data[:4])[0]
        if magic == 0xfeedface:
            log("Detected 32-bit Mach-O (armv7)")
        elif magic == 0xfeedfacf:
            log("Detected 64-bit Mach-O (arm64)")
        else:
            error(f"Unknown Mach-O magic: {hex(magic)}")
        
        cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = struct.unpack('<IIIIII', data[4:28])
        
        log(f"CPU: {cputype}, filetype: {filetype}, ncmds: {ncmds}, sizeofcmds: {sizeofcmds}")
        
        # Find end of load commands
        offset = 28
        end_of_cmds = 28 + sizeofcmds
        
        # Check if dylib is already injected
        cmd_offset = 28
        for i in range(ncmds):
            if cmd_offset + 8 > len(data):
                break
            cmd, cmdsize = struct.unpack('<II', data[cmd_offset:cmd_offset+8])
            if cmd == 0xC:  # LC_LOAD_DYLIB
                # Read the name
                name_offset = struct.unpack('<I', data[cmd_offset+8:cmd_offset+12])[0]
                name_start = cmd_offset + name_offset
                name_end = data.index(0, name_start) if 0 in data[name_start:cmd_offset+cmdsize] else cmd_offset + cmdsize
                name = data[name_start:name_end].decode('ascii', errors='ignore')
                if "WazeOSM" in name:
                    warn("WazeOSM.dylib already injected, skipping")
                    return
            cmd_offset += cmdsize
        
        # Create LC_LOAD_DYLIB command
        dylib_name = b"@executable_path/WazeOSM.dylib\x00"
        
        # Pad to 8-byte alignment
        while len(dylib_name) % 8 != 0:
            dylib_name += b'\x00'
        
        cmdsize = 24 + len(dylib_name)  # 24 = size of dylib_command struct
        
        # Build the command
        new_cmd = struct.pack('<IIIIIII',
            0xC,                    # LC_LOAD_DYLIB
            cmdsize,                # total size
            24,                     # name offset
            0,                      # timestamp
            0,                      # current_version
            0                       # compatibility_version
        )
        new_cmd += dylib_name
        
        # Insert at end of load commands
        data = data[:end_of_cmds] + new_cmd + data[end_of_cmds:]
        
        # Update header
        ncmds += 1
        sizeofcmds += cmdsize
        struct.pack_into('<I', data, 16, ncmds)
        struct.pack_into('<I', data, 20, sizeofcmds)
        
        # Write back
        with open(binary_path, 'wb') as f:
            f.write(data)
        
        success(f"Injected LC_LOAD_DYLIB (new ncmds: {ncmds}, sizeofcmds: {sizeofcmds})")
    
    def sign_binary(self, app_dir):
        """Sign the binary with ldid"""
        binary_path = os.path.join(app_dir, "Waze")
        
        log("Signing binary with ldid...")
        
        result = subprocess.run(["ldid", "-S", binary_path], capture_output=True, text=True)
        
        if result.returncode != 0:
            warn(f"ldid signing failed: {result.stderr}")
        else:
            success("Binary signed")
    
    def repackage_ipa(self):
        """Repackage the IPA"""
        log(f"Repackaging IPA to {self.output_path}...")
        
        payload_dir = os.path.join(self.work_dir, "Payload")
        
        with zipfile.ZipFile(self.output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(payload_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, self.work_dir)
                    zipf.write(file_path, arcname)
            
            # Add iTunesArtwork if exists
            artwork = os.path.join(self.work_dir, "iTunesArtwork")
            if os.path.exists(artwork):
                zipf.write(artwork, "iTunesArtwork")
        
        success(f"Created {self.output_path}")
        
        # Show size
        size = os.path.getsize(self.output_path)
        log(f"Size: {size / 1024 / 1024:.1f} MB")
    
    def run(self):
        """Full injection pipeline"""
        log("=" * 50)
        log("Waze OSM IPA Injector")
        log("=" * 50)
        
        try:
            app_dir = self.extract_ipa()
            self.copy_dylib(app_dir)
            self.inject_load_command(app_dir)
            self.sign_binary(app_dir)
            self.repackage_ipa()
            
            log("=" * 50)
            success("Injection complete!")
            log(f"Output: {os.path.abspath(self.output_path)}")
            log("=" * 50)
        finally:
            self.cleanup()

def main():
    parser = argparse.ArgumentParser(description="Inject WazeOSM dylib into Waze IPA")
    parser.add_argument("ipa", help="Path to Waze IPA file")
    parser.add_argument("dylib", help="Path to WazeOSM.dylib")
    parser.add_argument("-o", "--output", default="Waze-OSM.ipa", help="Output IPA path")
    
    args = parser.parse_args()
    
    injector = IPAInjector(args.ipa, args.dylib, args.output)
    injector.run()

if __name__ == "__main__":
    main()
