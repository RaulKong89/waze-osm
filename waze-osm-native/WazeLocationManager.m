//
//  WazeLocationManager.m
//  WazeOSM - Location tracking
//

#import "WazeLocationManager.h"

@implementation WazeLocationManager

+ (instancetype)sharedManager {
    static WazeLocationManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = 5;
    }
    return self;
}

- (void)startTracking {
    if ([CLLocationManager locationServicesEnabled]) {
        [_locationManager startUpdatingLocation];
    }
}

- (void)stopTracking {
    [_locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *location = [locations lastObject];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WazeLocationUpdated" object:location];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[WazeOSM] Location error: %@", error);
}

@end
