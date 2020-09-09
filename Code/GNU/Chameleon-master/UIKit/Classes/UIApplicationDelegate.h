#import <Foundation/Foundation.h>

@class UIApplication;

@protocol UIApplicationDelegate <NSObject>
@optional
- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
- (void)applicationDidFinishLaunching:(UIApplication *)application;     // not recommended
- (void)applicationDidBecomeActive:(UIApplication *)application;
- (void)applicationWillResignActive:(UIApplication *)application;
- (void)applicationWillTerminate:(UIApplication *)application;
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;
- (void)applicationDidEnterBackground:(UIApplication *)application;
- (void)applicationWillEnterForeground:(UIApplication *)application;

// non-standard

// these are all called immediately before the normal delegate methods of similar name
// these do NOT supercede the normal methods, if the normal ones also exist, they are also called!
- (void)application:(UIApplication *)application willFinishLaunchingOnDesktopWithOptions:(NSDictionary *)launchOptions;
- (void)application:(UIApplication *)application didFinishLaunchingOnDesktopWithOptions:(NSDictionary *)launchOptions;
- (void)applicationWillTerminateOnDesktop:(UIApplication *)application;

@end
