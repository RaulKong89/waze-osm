#!/bin/bash
# inject.sh - Inject WazeOSM dylib into Waze 3.9.6 IPA
# This script modifies the IPA to include our OSM tweak

set -e

echo "=== Waze OSM IPA Injector ==="

# Check for required tools
command -v unzip >/dev/null 2>&1 || { echo "unzip required"; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "zip required"; exit 1; }
command -v ldid >/dev/null 2>&1 || { echo "ldid required"; exit 1; }
command -v xxd >/dev/null 2>&1 || { echo "xxd required"; exit 1; }

# Paths
IPA_IN="waze_3.9.6.ipa"
IPA_OUT="Waze-OSM-3.9.6.ipa"
DYLIB="waze-osm-tweak/.theos/obj/debug/armv7/WazeOSM.dylib"
PAYLOAD_DIR="Payload"

echo "Step 1: Extracting IPA..."
rm -rf "$PAYLOAD_DIR"
unzip -q "$IPA_IN"

echo "Step 2: Copying dylib to app bundle..."
APP_DIR=$(find "$PAYLOAD_DIR" -name "Waze.app" -type d | head -1)
if [ -z "$APP_DIR" ]; then
    echo "ERROR: Waze.app not found in IPA"
    exit 1
fi
echo "Found app at: $APP_DIR"
cp "$DYLIB" "$APP_DIR/WazeOSM.dylib"

echo "Step 3: Injecting load command into binary..."
BINARY="$APP_DIR/Waze"
cp "$BINARY" "$BINARY.backup"

# Use ldid to add the load command
# The -S flag signs, but we need to add the dylib first
# We'll use a Python script to inject the LC_LOAD_DYLIB command

python3 << 'PYEOF'
import struct
import sys
import os

binary_path = "Payload/Waze.app/Waze"

with open(binary_path, 'rb') as f:
    data = bytearray(f.read())

# Parse Mach-O header
magic = struct.unpack('<I', data[:4])[0]
if magic != 0xfeedface:
    print("ERROR: Not a 32-bit Mach-O binary")
    sys.exit(1)

cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = struct.unpack('<IIIIII', data[4:28])

# Find the end of load commands
offset = 28
end_of_cmds = 28 + sizeofcmds

# LC_LOAD_DYLIB command
# struct dylib_command {
#   uint32_t cmd;       // LC_LOAD_DYLIB = 0xC
#   uint32_t cmdsize;   // total size including name
#   uint32_t name_offset; // offset to library name string
#   uint32_t timestamp;
#   uint32_t current_version;
#   uint32_t compatibility_version;
# };

dylib_name = b"@executable_path/WazeOSM.dylib\x00"
# Pad to 8-byte alignment
while len(dylib_name) % 8 != 0:
    dylib_name += b'\x00'

cmdsize = 24 + len(dylib_name)  # 24 = size of dylib_command struct before name

# Check if we have space
# We'll add the command at the end of existing commands
new_cmd = struct.pack('<IIIIIII',
    0xC,                    // LC_LOAD_DYLIB
    cmdsize,                // total size
    24,                     // name offset (right after the command struct)
    0,                      // timestamp
    0,                      // current_version
    0                       // compatibility_version
)
new_cmd += dylib_name

# Insert the new command
data = data[:end_of_cmds] + new_cmd + data[end_of_cmds:]

# Update ncmds and sizeofcmds
ncmds += 1
sizeofcmds += cmdsize
struct.pack_into('<I', data, 16, ncmds)
struct.pack_into('<I', data, 20, sizeofcmds)

with open(binary_path, 'wb') as f:
    f.write(data)

print(f"Injected LC_LOAD_DYLIB for WazeOSM.dylib")
print(f"New ncmds: {ncmds}, sizeofcmds: {sizeofcmds}")
PYEOF

echo "Step 4: Signing with ldid..."
ldid -S "$BINARY"

echo "Step 5: Verifying injection..."
strings "$BINARY" | grep -i "WazeOSM" || echo "WARNING: dylib name not found in binary"

echo "Step 6: Repackaging IPA..."
rm -f "$IPA_OUT"
zip -qr "$IPA_OUT" "$PAYLOAD_DIR" iTunesArtwork

echo "=== Done! ==="
echo "Output: $IPA_OUT"
echo "Size: $(du -h "$IPA_OUT" | cut -f1)"
echo ""
echo "Installation:"
echo "1. Install Cydia Substrate (if not already installed)"
echo "2. Copy WazeOSM.dylib to /Library/MobileSubstrate/DynamicLibraries/"
echo "3. Install the IPA with ideviceinstaller or Cydia Impactor"
echo "4. Respring or reboot"
