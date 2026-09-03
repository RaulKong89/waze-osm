//
//  WazeMapViewController.m
//  WazeOSM - Main map view with OpenStreetMap
//

#import "WazeMapViewController.h"
#import "WazeLocationManager.h"
#import "WazeAPIClient.h"
#import "WazeRouteManager.h"
#import "WazeSearchViewController.h"
#import "WazeSettingsViewController.h"

@interface WazeMapViewController () <MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate> {
    MKMapView *_mapView;
    UIButton *_locationButton;
    UIButton *_zoomInButton;
    UIButton *_zoomOutButton;
    UIView *_bottomBar;
    UISearchBar *_searchBar;
    UIButton *_menuButton;
    UIButton *_reportButton;
    UIButton *_shareButton;
    UIButton *_navigateButton;
    UIButton *_friendsButton;
    UIButton *_settingsButton;
    UIView *_etaBox;
    UILabel *_etaTimeLabel;
    UILabel *_etaDistanceLabel;
    UIView *_speedBox;
    UILabel *_speedValueLabel;
    UIActivityIndicatorView *_searchSpinner;
    NSArray *_searchResults;
    MKPolyline *_currentRoute;
    MKUserLocation *_userLocation;
}

@end

@implementation WazeMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setupMapView];
    [self setupTopBar];
    [self setupBottomBar];
    [self setupLocationButton];
    [self setupZoomControls];
    [self setupETABox];
    [self setupSpeedBox];
    
    // Add tile overlay for OpenStreetMap
    [self addOSMOverlay];
}

- (void)setupMapView {
    _mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    _mapView.delegate = self;
    _mapView.showsUserLocation = YES;
    _mapView.userTrackingMode = MKUserTrackingModeFollow;
    _mapView.mapType = MKMapTypeStandard;
    [self.view addSubview:_mapView];
}

- (void)addOSMOverlay {
    // Use OpenStreetMap tiles via MKTileOverlay
    NSString *template = @"https://tile.openstreetmap.org/{z}/{x}/{y}.png";
    MKTileOverlay *overlay = [[MKTileOverlay alloc] initWithURLTemplate:template];
    overlay.canReplaceMapContent = YES;
    [_mapView addOverlay:overlay level:MKOverlayLevelAboveLabels];
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKTileOverlay class]]) {
        return [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
    }
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];
        renderer.strokeColor = [UIColor colorWithRed:0.29 green:0.56 blue:0.85 alpha:1.0];
        renderer.lineWidth = 6.0;
        return renderer;
    }
    return nil;
}

- (void)setupTopBar {
    // Top bar with Waze blue color
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 50)];
    topBar.backgroundColor = [UIColor colorWithRed:0.29 green:0.56 blue:0.85 alpha:1.0];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topBar];
    
    // Menu button
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(8, 8, 36, 36);
    _menuButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    _menuButton.layer.cornerRadius = 6;
    [_menuButton setTitle:@"☰" forState:UIControlStateNormal];
    [_menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_menuButton addTarget:self action:@selector(menuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:_menuButton];
    
    // Search bar
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(50, 8, self.view.frame.size.width - 100, 36)];
    _searchBar.delegate = self;
    _searchBar.placeholder = @"Where to?";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:_searchBar];
    
    // Voice button
    UIButton *voiceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    voiceButton.frame = CGRectMake(self.view.frame.size.width - 44, 8, 36, 36);
    voiceButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    voiceButton.layer.cornerRadius = 6;
    [voiceButton setTitle:@"🎤" forState:UIControlStateNormal];
    [voiceButton addTarget:self action:@selector(voiceButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    voiceButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [topBar addSubview:voiceButton];
}

- (void)setupBottomBar {
    CGFloat barHeight = 65;
    CGFloat y = self.view.frame.size.height - barHeight;
    
    _bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, y, self.view.frame.size.width, barHeight)];
    _bottomBar.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    _bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_bottomBar];
    
    NSArray *buttons = @[
        @{@"title": @"⚠️", @"label": @"Report", @"action": @"reportButtonTapped:"},
        @{@"title": @"📍", @"label": @"Send", @"action": @"shareButtonTapped:"},
        @{@"title": @"🧭", @"label": @"Navigate", @"action": @"navigateButtonTapped:"},
        @{@"title": @"👥", @"label": @"Friends", @"action": @"friendsButtonTapped:"},
        @{@"title": @"⚙️", @"label": @"More", @"action": @"settingsButtonTapped:"}
    ];
    
    CGFloat buttonWidth = self.view.frame.size.width / 5;
    for (int i = 0; i < buttons.count; i++) {
        NSDictionary *btnInfo = buttons[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, barHeight);
        [btn setTitle:btnInfo[@"title"] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:22];
        [btn addTarget:self action:NSSelectorFromString(btnInfo[@"action"]) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:btn];
    }
}

- (void)setupLocationButton {
    _locationButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _locationButton.frame = CGRectMake(self.view.frame.size.width - 54, self.view.frame.size.height - 140, 44, 44);
    _locationButton.backgroundColor = [UIColor whiteColor];
    _locationButton.layer.cornerRadius = 22;
    _locationButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _locationButton.layer.shadowOffset = CGSizeMake(0, 2);
    _locationButton.layer.shadowOpacity = 0.3;
    [_locationButton setTitle:@"📍" forState:UIControlStateNormal];
    [_locationButton addTarget:self action:@selector(locationButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    _locationButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_locationButton];
}

- (void)setupZoomControls {
    _zoomInButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _zoomInButton.frame = CGRectMake(self.view.frame.size.width - 46, self.view.frame.size.height - 200, 36, 36);
    _zoomInButton.backgroundColor = [UIColor whiteColor];
    _zoomInButton.layer.cornerRadius = 6;
    _zoomInButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [_zoomInButton setTitle:@"+" forState:UIControlStateNormal];
    [_zoomInButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_zoomInButton addTarget:self action:@selector(zoomInTapped:) forControlEvents:UIControlEventTouchUpInside];
    _zoomInButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_zoomInButton];
    
    _zoomOutButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _zoomOutButton.frame = CGRectMake(self.view.frame.size.width - 46, self.view.frame.size.height - 160, 36, 36);
    _zoomOutButton.backgroundColor = [UIColor whiteColor];
    _zoomOutButton.layer.cornerRadius = 6;
    _zoomOutButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [_zoomOutButton setTitle:@"−" forState:UIControlStateNormal];
    [_zoomOutButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_zoomOutButton addTarget:self action:@selector(zoomOutTapped:) forControlEvents:UIControlEventTouchUpInside];
    _zoomOutButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_zoomOutButton];
}

- (void)setupETABox {
    _etaBox = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 80, 60, 70, 50)];
    _etaBox.backgroundColor = [UIColor whiteColor];
    _etaBox.layer.cornerRadius = 8;
    _etaBox.hidden = YES;
    _etaBox.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:_etaBox];
    
    _etaTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 60, 20)];
    _etaTimeLabel.font = [UIFont boldSystemFontOfSize:16];
    _etaTimeLabel.textAlignment = NSTextAlignmentCenter;
    _etaTimeLabel.text = @"-- min";
    [_etaBox addSubview:_etaTimeLabel];
    
    _etaDistanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 25, 60, 15)];
    _etaDistanceLabel.font = [UIFont systemFontOfSize:11];
    _etaDistanceLabel.textAlignment = NSTextAlignmentCenter;
    _etaDistanceLabel.textColor = [UIColor grayColor];
    _etaDistanceLabel.text = @"-- km";
    [_etaBox addSubview:_etaDistanceLabel];
}

- (void)setupSpeedBox {
    _speedBox = [[UIView alloc] initWithFrame:CGRectMake(10, self.view.frame.size.height - 140, 60, 40)];
    _speedBox.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    _speedBox.layer.cornerRadius = 8;
    _speedBox.hidden = YES;
    _speedBox.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_speedBox];
    
    _speedValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 50, 20)];
    _speedValueLabel.font = [UIFont boldSystemFontOfSize:18];
    _speedValueLabel.textAlignment = NSTextAlignmentCenter;
    _speedValueLabel.textColor = [UIColor whiteColor];
    _speedValueLabel.text = @"0";
    [_speedBox addSubview:_speedValueLabel];
    
    UILabel *unitLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 25, 50, 12)];
    unitLabel.font = [UIFont systemFontOfSize:9];
    unitLabel.textAlignment = NSTextAlignmentCenter;
    unitLabel.textColor = [UIColor whiteColor];
    unitLabel.text = @"km/h";
    [_speedBox addSubview:unitLabel];
}

#pragma mark - Button Actions

- (void)menuButtonTapped:(id)sender {
    // Show side menu
}

- (void)voiceButtonTapped:(id)sender {
    // Voice search
}

- (void)locationButtonTapped:(id)sender {
    [_mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
}

- (void)zoomInTapped:(id)sender {
    MKCoordinateRegion region = [_mapView region];
    region.span.latitudeDelta *= 0.5;
    region.span.longitudeDelta *= 0.5;
    [_mapView setRegion:region animated:YES];
}

- (void)zoomOutTapped:(id)sender {
    MKCoordinateRegion region = [_mapView region];
    region.span.latitudeDelta *= 2.0;
    region.span.longitudeDelta *= 2.0;
    [_mapView setRegion:region animated:YES];
}

- (void)reportButtonTapped:(id)sender {
    // Show report options
}

- (void)shareButtonTapped:(id)sender {
    // Share location
}

- (void)navigateButtonTapped:(id)sender {
    // Start navigation
}

- (void)friendsButtonTapped:(id)sender {
    // Show friends
}

- (void)settingsButtonTapped:(id)sender {
    // Show settings
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self searchForQuery:searchBar.text];
}

- (void)searchForQuery:(NSString *)query {
    // Use Nominatim for search
    NSString *encodedQuery = [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *urlString = [NSString stringWithFormat:@"https://nominatim.openstreetmap.org/search?format=json&q=%@&limit=10", encodedQuery];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeout:10.0];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (data) {
            NSArray *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [self showSearchResults:results];
        }
    }];
}

- (void)showSearchResults:(NSArray *)results {
    // Show search results
    if (results.count > 0) {
        NSDictionary *firstResult = results[0];
        NSString *lat = firstResult[@"lat"];
        NSString *lon = firstResult[@"lon"];
        
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);
        [_mapView setCenterCoordinate:coord animated:YES];
        
        // Add pin
        MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
        annotation.coordinate = coord;
        annotation.title = firstResult[@"display_name"];
        [_mapView addAnnotation:annotation];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    _userLocation = userLocation;
    
    // Show speed
    if (userLocation.location.speed > 0) {
        int speedKmh = (int)(userLocation.location.speed * 3.6);
        _speedValueLabel.text = [NSString stringWithFormat:@"%d", speedKmh];
        _speedBox.hidden = NO;
    }
}

@end
