//
//  WazeAppDelegate.m
//  WazeOSM - Native iOS app with OpenStreetMap
//

#import "WazeAppDelegate.h"
#import "WazeMapViewController.h"

@implementation WazeAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Create main map view controller
    WazeMapViewController *mapVC = [[WazeMapViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:mapVC];
    navController.navigationBarHidden = YES;
    
    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];
    
    // Request location permissions
    [[WazeLocationManager sharedManager] startTracking];
    
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Keep tracking in background
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Resume tracking
}

@end
