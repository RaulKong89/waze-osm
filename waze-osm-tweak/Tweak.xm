// WazeOSM Tweak - Hook Google Maps tile URLs to OpenStreetMap
// iOS 6 compatible, Waze 3.9.6

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// OSM Tile URL format
#define OSM_TILE_URL @"https://tile.openstreetmap.org/%d/%d/%d.png"

// Original function pointers
static id (*orig_URLForX)(id, SEL, int, int, int);
static id (*orig_URLForTile)(id, SEL, int, int, int, int);

// Hook: URLForX:y:zoom: -> OSM URL
static id hooked_URLForX(id self, SEL _cmd, int x, int y, int zoom) {
    NSString *osmURL = [NSString stringWithFormat:OSM_TILE_URL, zoom, x, y];
    NSLog(@"[WazeOSM] Tile %d/%d/%d -> OSM", zoom, x, y);
    return [NSURL URLWithString:osmURL];
}

// Hook: URLForTile: -> OSM URL
static id hooked_URLForTile(id self, SEL _cmd, int x, int y, int zoom, int layer) {
    NSString *osmURL = [NSString stringWithFormat:OSM_TILE_URL, zoom, x, y];
    return [NSURL URLWithString:osmURL];
}

// Hook: GMSServices provideAPIKey - accept any key
static BOOL hooked_provideAPIKey(id self, SEL _cmd, NSString *apiKey) {
    NSLog(@"[WazeOSM] API Key accepted");
    return YES;
}

// Hook: GMSMapView initWithFrame
static id hooked_initWithFrame(id self, SEL _cmd, CGRect frame) {
    id result = orig_initWithFrame(self, _cmd, frame);
    NSLog(@"[WazeOSM] GMSMapView initialized");
    return result;
}

// Constructor
__attribute__((constructor))
static void initialize() {
    NSLog(@"[WazeOSM] Initializing...");
    
    // Hook GMSTileURLProvider
    Class tileURLProvider = NSClassFromString(@"GMSTileURLProvider");
    if (tileURLProvider) {
        Method urlForX = class_getClassMethod(tileURLProvider, @selector(URLForX:y:zoom:));
        if (urlForX) {
            orig_URLForX = (void *)method_getImplementation(urlForX);
            method_setImplementation(urlForX, (IMP)hooked_URLForX);
            NSLog(@"[WazeOSM] Hooked URLForX:y:zoom:");
        }
        
        Method urlForTile = class_getClassMethod(tileURLProvider, @selector(URLForTile:));
        if (urlForTile) {
            orig_URLForTile = (void *)method_getImplementation(urlForTile);
            method_setImplementation(urlForTile, (IMP)hooked_URLForTile);
            NSLog(@"[WazeOSM] Hooked URLForTile:");
        }
    }
    
    // Hook GMSServices
    Class gmsServices = NSClassFromString(@"GMSServices");
    if (gmsServices) {
        Method provideAPIKey = class_getClassMethod(gmsServices, @selector(provideAPIKey:));
        if (provideAPIKey) {
            method_setImplementation(provideAPIKey, (IMP)hooked_provideAPIKey);
            NSLog(@"[WazeOSM] Hooked GMSServices provideAPIKey:");
        }
    }
    
    // Hook GMSMapView
    Class mapView = NSClassFromString(@"GMSMapView");
    if (mapView) {
        Method initWithFrame = class_getInstanceMethod(mapView, @selector(initWithFrame:));
        if (initWithFrame) {
            orig_initWithFrame = (void *)method_getImplementation(initWithFrame);
            method_setImplementation(initWithFrame, (IMP)hooked_initWithFrame);
            NSLog(@"[WazeOSM] Hooked GMSMapView initWithFrame:");
        }
    }
    
    NSLog(@"[WazeOSM] Initialized successfully!");
}

// Original function storage
static id (*orig_initWithFrame)(id, SEL, CGRect);
