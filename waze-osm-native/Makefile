export THEOS = $(HOME)/theos
export SDK_VERSION = 6.1
export ARCHS = armv7
export TARGET = iphone:clang:6.1:6.1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = WazeOSM
WazeOSM_FILES = main.m WazeAppDelegate.m WazeMapViewController.m WazeSearchViewController.m WazeSettingsViewController.m WazeNavigationManager.m WazeLocationManager.m WazeAPIClient.m WazeRouteManager.m WazeUIHelper.m
WazeOSM_FRAMEWORKS = Foundation UIKit CoreLocation MapKit CoreGraphics AVFoundation
WazeOSM_PRIVATE_FRAMEWORKS = 
WazeOSM_CFLAGS = -fobjc-arc
WazeOSM_LDFLAGS = -framework Foundation -framework UIKit -framework CoreLocation -framework MapKit -framework CoreGraphics -framework AVFoundation

include $(THEOS)/makefiles/application.mk
