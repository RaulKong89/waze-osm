# Makefile for WazeOSM - Cross-compile on Linux for iOS 6 armv7
# No Theos required

# Configuration
TARGET = armv7-apple-darwin11
SDK_PATH = /usr/share/iPhoneOS6.1.sdk
CC = clang
CXX = clang++
LD = ld
STRIP = strip

# Compiler flags
CFLAGS = -arch armv7 -isysroot $(SDK_PATH) -miphoneos-version-min=6.0 \
         -fobjc-arc -fmodules -fmodule-name=WazeOSM \
         -O2 -Wall -Werror

LDFLAGS = -arch armv7 -isysroot $(SDK_PATH) -miphoneos-version-min=6.0 \
          -dynamiclib -install_name @executable_path/WazeOSM.dylib \
          -framework Foundation -framework UIKit -framework CoreGraphics \
          -framework CoreLocation -framework MapKit \
          -lsubstrate -L.

# Source and output
SOURCE = Tweak.xm
OBJECT = Tweak.o
OUTPUT = WazeOSM.dylib

# Default target
all: $(OUTPUT)

# Compile
$(OBJECT): $(SOURCE)
	$(CC) $(CFLAGS) -c $< -o $@

# Link
$(OUTPUT): $(OBJECT)
	$(CC) $(LDFLAGS) -o $@ $<
	$(STRIP) -x $@

# Clean
clean:
	rm -f $(OBJECT) $(OUTPUT)

# Install to device (requires SSH)
install: $(OUTPUT)
	scp $(OUTPUT) root@192.168.50.131:/Library/MobileSubstrate/DynamicLibraries/
	ssh root@192.168.50.131 "killall -9 Waze"

.PHONY: all clean install
