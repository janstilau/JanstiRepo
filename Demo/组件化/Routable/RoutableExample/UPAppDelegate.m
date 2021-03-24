//
//  UPAppDelegate.m
//  Routable
//
//  Created by Clay Allsopp on 4/3/13.
//  Copyright (c) 2013 TurboProp Inc. All rights reserved.
//

#import "UPAppDelegate.h"
#import "Routable.h"

@interface UserController : UIViewController

@end

@implementation UserController

- (id)initWithRouterParams:(NSDictionary *)params {
    if ((self = [self initWithNibName:nil bundle:nil])) {
        self.title = @"User";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *modal = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [modal setBackgroundColor:[UIColor yellowColor]];
    [modal setTitle:@"Modal" forState:UIControlStateNormal];
    [modal addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
    [modal sizeToFit];
    [modal setFrame:CGRectMake(0, self.view.bounds.size.height - modal.frame.size.height, modal.frame.size.width, modal.frame.size.height)];
    
    [self.view addSubview:modal];
}

- (void)tapped:(id)sender {
    [[Routable sharedRouter] open:@"modal"];
}

@end

@interface ModalController : UIViewController

@end

@implementation ModalController

- (id)initWithRouterParams:(NSDictionary *)params {
    if ((self = [self initWithNibName:nil bundle:nil])) {
        self.title = @"Modal";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *modal = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [modal setBackgroundColor:[UIColor redColor]];
    [modal setTitle:@"Close" forState:UIControlStateNormal];
    [modal addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
    [modal sizeToFit];
    [modal setFrame:CGRectMake(0, 200, modal.frame.size.width, modal.frame.size.height)];
    [self.view addSubview:modal];
    
    UIButton *user = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [user setBackgroundColor:[UIColor greenColor]];
    [user setTitle:@"User" forState:UIControlStateNormal];
    [user addTarget:self action:@selector(tappedUser:) forControlEvents:UIControlEventTouchUpInside];
    [user sizeToFit];
    [user setFrame:CGRectMake(self.view.bounds.size.width - user.frame.size.width , 200, user.frame.size.width, user.frame.size.height)];
    
    [self.view addSubview:user];
}

- (void)tapped:(id)sender {
    [[Routable sharedRouter] pop];
}

- (void)tappedUser:(id)sender {
    [[Routable sharedRouter] open:@"user"];
}

@end

@implementation UPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithNibName:nil bundle:nil];
    
    [[Routable sharedRouter] map:@"user" toController:[UserController class]];
    [[Routable sharedRouter] map:@"modal" toController:[ModalController class]
                     withOptions:[[UPRouterOptions modal] withPresentationStyle:UIModalPresentationFormSheet]];
    [[Routable sharedRouter] setNavigationController:nav];
    
    [self.window setRootViewController:nav];
    [self.window makeKeyAndVisible];
    
    [[Routable sharedRouter] open:@"user"];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
