//
//  WazeSearchViewController.m
//  WazeOSM - Search view controller
//

#import "WazeSearchViewController.h"

@implementation WazeSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, 40)];
    label.text = @"Search";
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont boldSystemFontOfSize:24];
    [self.view addSubview:label];
}

@end
