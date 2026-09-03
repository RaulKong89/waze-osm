// WazeOSM Tweak - Fara substrate, doar Objective-C runtime
// iOS 6 compatibil, Waze 3.9.6

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// OSM Tile URL
#define OSM_URL @"https://tile.openstreetmap.org/%d/%d/%d.png"

// Original method IMPs
static IMP orig_URLForX = NULL;
static IMP orig_URLForTile = NULL;

// Swizzle method
static void swizzleMethod(Class cls, SEL origSEL, SEL newSEL) {
    Method origMethod = class_getClassMethod(cls, origSEL);
    Method newMethod = class_getClassMethod(cls, newSEL);
    
    if (origMethod && newMethod) {
        IMP newIMP = method_getImplementation(newMethod);
        method_setImplementation(origMethod, newIMP);
    }
}

// Hook: URLForX:y:zoom: -> OSM URL
static id new_URLForX(id self, SEL _cmd, int x, int y, int zoom) {
    NSString *url = [NSString stringWithFormat:OSM_URL, zoom, x, y];
    return [NSURL URLWithString:url];
}

// Hook: URLForTile: -> OSM URL  
static id new_URLForTile(id self, SEL _cmd, int x, int y, int zoom, int layer) {
    NSString *url = [NSString stringWithFormat:OSM_URL, zoom, x, y];
    return [NSURL URLWithString:url];
}

// Hook: NSURLRequest creation
static id new_NSURLRequestWithURL(id self, SEL _cmd, NSURL *url) {
    NSString *urlStr = [url absoluteString];
    
    // Check if Google Maps tile
    if ([urlStr rangeOfString:@"google" options:NSCaseInsensitiveSearch].location != NSNotFound &&
        [urlStr rangeOfString:@"tile" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // Extract x,y,z from URL
        // Format: ...&x=123&y=456&z=15
        NSScanner *scanner = [NSScanner scannerWithString:urlStr];
        int x = 0, y = 0, z = 0;
        
        [scanner scanUpToString:@"x=" intoString:nil];
        if ([scanner scanString:@"x=" intoString:nil]) {
            [scanner scanInt:&x];
        }
        
        [scanner scanUpToString:@"y=" intoString:nil];
        if ([scanner scanString:@"y=" intoString:nil]) {
            [scanner scanInt:&y];
        }
        
        [scanner scanUpToString:@"z=" intoString:nil];
        if ([scanner scanString:@"z=" intoString:nil]) {
            [scanner scanInt:&z];
        }
        
        if (x > 0 && y > 0 && z > 0) {
            NSString *osmUrl = [NSString stringWithFormat:OSM_URL, z, x, y];
            return [NSURL URLWithString:osmUrl];
        }
    }
    
    return url;
}

// Constructor
__attribute__((constructor))
static void init() {
    NSLog(@"[WazeOSM] Loading...");
    
    // Hook GMSTileURLProvider
    Class tileProvider = NSClassFromString(@"GMSTileURLProvider");
    if (tileProvider) {
        // Try to hook URLForX:y:zoom:
        Method m = class_getClassMethod(tileProvider, @selector(URLForX:y:zoom:));
        if (m) {
            method_setImplementation(m, (IMP)new_URLForX);
            NSLog(@"[WazeOSM] Hooked URLForX:y:zoom:");
        }
    }
    
    // Hook NSURL
    Class nsurl = [NSURL class];
    if (nsurl) {
        Method m = class_getClassMethod(nsurl, @selector(URLWithString:));
        if (m) {
            // Can't easily swizzle NSURLWithString, but we can try
            NSLog(@"[WazeOSM] Found NSURL URLWithString:");
        }
    }
    
    NSLog(@"[WazeOSM] Loaded successfully!");
}
