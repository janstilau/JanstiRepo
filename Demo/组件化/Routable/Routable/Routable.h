#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UPRouter;

/*
 `Routable` is a "factory" class which gives a more pleasant syntax for dealing with routers. `Routable` probably has fewer name collisions than `Router`, which is why `UPRouter`s are given a 2-letter prefix.
 */

/*
 在词典的项目里, 曾经使用了 Routable 
 */

typedef void (^RouterOpenCallback)(NSDictionary *params);

/**
 `UPRouterOptions` allows you to configure specific behavior for each router callback, such transition behaviors or default URL parameters.
 
 `UPRouterOptions` has a chainable factory DSL which gives a more pleasant syntax for giving specific configurations, like:
 
 ```
 UPRouterOptions *options = [[UPRouterOptions modal] withPresentationStyle: UIModalPresentationFormSheet];
 ```
 
 Now, you can also use an Objective-C factory method to set everything at once
 
 ```
 UPRouterOptions *options = [UPRouterOptions routerOptionsWithPresentationStyle: UIModalPresentationFormSheet
 transitionStyle: UIModalTransitionFormSheet
 defaultParams: nil
 isRoot: NO
 isModal: YES];
 ```
 
 Or, for most properties taking the default value:
 
 ```
 UPRouterOptions *options = [[UPRouterOptions alloc] init];
 [options setTransitionStyle:UIModalTransitionStyleCoverVertical];
 ```
 */

@interface UPRouterOptions : NSObject

// 指定初始化方法.
+ (instancetype)routerOptionsWithPresentationStyle: (UIModalPresentationStyle)presentationStyle
                                   transitionStyle: (UIModalTransitionStyle)transitionStyle
                                     defaultParams: (NSDictionary *)defaultParams
                                            isRoot: (BOOL)isRoot
                                           isModal: (BOOL)isModal;
/**
 @return A new instance of `UPRouterOptions` with its properties set to default
 */
+ (instancetype)routerOptions;

///-------------------------------
/// @name Options DSL
///-------------------------------
/**
 @return A new instance of `UPRouterOptions`, setting a modal presentation format.
 */
+ (instancetype)routerOptionsAsModal;
/**
 @return A new instance of `UPRouterOptions`, setting a `UIModalPresentationStyle` style.
 @param style The `UIModalPresentationStyle` attached to the mapped `UIViewController`
 */
+ (instancetype)routerOptionsWithPresentationStyle:(UIModalPresentationStyle)style;
/**
 @return A new instance of `UPRouterOptions`, setting a `UIModalTransitionStyle` style.
 @param style The `UIModalTransitionStyle` attached to the mapped `UIViewController`
 */
+ (instancetype)routerOptionsWithTransitionStyle:(UIModalTransitionStyle)style;
/**
 @return A new instance of `UPRouterOptions`, setting the defaultParams
 @param defaultParams The default parameters which are passed when opening the URL
 */
+ (instancetype)routerOptionsForDefaultParams:(NSDictionary *)defaultParams;
/**
 @return A new instance of `UPRouterOptions`, setting the `shouldOpenAsRootViewController` property to `YES`
 */
+ (instancetype)routerOptionsAsRoot;

//previously supported
/**
 @remarks not idiomatic objective-c naming for allocation and initialization, see +routerOptionsAsModal
 @return A new instance of `UPRouterOptions`, setting a modal presentation format.
 */
+ (instancetype)modal;
/**
 @remarks not idiomatic objective-c naming for allocation and initialization, see + routerOptionsWithPresentationStyle:
 @return A new instance of `UPRouterOptions`, setting a `UIModalPresentationStyle` style.
 @param style The `UIModalPresentationStyle` attached to the mapped `UIViewController`
 */
+ (instancetype)withPresentationStyle:(UIModalPresentationStyle)style;
/**
 @remarks not idiomatic objective-c naming for allocation and initialization see +routerOptionsWithTransitionStyle:
 @return A new instance of `UPRouterOptions`, setting a `UIModalTransitionStyle` style.
 @param style The `UIModalTransitionStyle` attached to the mapped `UIViewController`
 */
+ (instancetype)withTransitionStyle:(UIModalTransitionStyle)style;
/**
 @remarks not idiomatic objective-c naming for allocation and initialization, see +routerOptionsForDefaultParams:
 @return A new instance of `UPRouterOptions`, setting the defaultParams
 @param defaultParams The default parameters which are passed when opening the URL
 */
+ (instancetype)forDefaultParams:(NSDictionary *)defaultParams;
/**
 @remarks not idiomatic objective-c naming for allocation and initialization, see +routerOptionsAsRoot
 @return A new instance of `UPRouterOptions`, setting the `shouldOpenAsRootViewController` property to `YES`
 */
+ (instancetype)root;

/**
 @remarks not idiomatic objective-c naming; overrides getter to wrap around setter
 @return The same instance of `UPRouterOptions`, setting a modal presentation format.
 */
- (UPRouterOptions *)modal;
/**
 @remarks not idiomatic objective-c naming; wraps around setter
 @return The same instance of `UPRouterOptions`, setting a `UIModalPresentationStyle` style.
 @param style The `UIModalPresentationStyle` attached to the mapped `UIViewController`
 */
- (UPRouterOptions *)withPresentationStyle:(UIModalPresentationStyle)style;
/**
 @remarks not idiomatic objective-c naming; wraps around setter
 @return The same instance of `UPRouterOptions`, setting a `UIModalTransitionStyle` style.
 @param style The `UIModalTransitionStyle` attached to the mapped `UIViewController`
 */
- (UPRouterOptions *)withTransitionStyle:(UIModalTransitionStyle)style;
/**
 @remarks not idiomatic objective-c naming; wraps around setter
 @return The same instance of `UPRouterOptions`, setting the defaultParams
 @param defaultParams The default parameters which are passed when opening the URL
 */
- (UPRouterOptions *)forDefaultParams:(NSDictionary *)defaultParams;
/**
 @remarks not idiomatic objective-c naming; wraps around setter
 @return A new instance of `UPRouterOptions`, setting the `shouldOpenAsRootViewController` property to `YES`
 */
- (UPRouterOptions *)root;

///-------------------------------
/// @name Properties
///-------------------------------

/**
 The property determining if the mapped `UIViewController` should be opened modally or pushed in the navigation stack.
 */
@property (readwrite, nonatomic, getter=isModal) BOOL modal;
/*
 UIModalPresentationStyle.automatic
 For most view controllers, UIKit maps this style to the UIModalPresentationStyle.pageSheet style, but some system view controllers may map it to a different style.
 
 UIModalPresentationStyle.fullScreen
 The views belonging to the presenting view controller are removed after the presentation completes.
 
 UIModalPresentationStyle.pageSheet
 In a horizontally and vertically regular environment, this option adds a dimming layer over the background content and displays the view controller's content with roughly page-sized dimensions, where the height is greater than the width.
 The actual dimensions vary according to the device's screen size and orientation, but a portion of the underlying content always remains visible.
 In a vertically regular, but horizontally compact environment, this option displays a sheet interface, where a portion of the underlying content remains visible near the top of the screen.
 In a vertically compact environment, this option is essentially the same as UIModalPresentationStyle.fullScreen.
 In cases where the underlying content remains visible, the presenting view controller doesn't receive the viewWillDisappear(_:) and viewDidDisappear(_:) callbacks.
 */

@property (readwrite, nonatomic) UIModalPresentationStyle presentationStyle;
/*
 UIModalTransitionStyle.coverVertical
 When the view controller is presented, its view slides up from the bottom of the screen. On dismissal, the view slides back down. This is the default transition style.
 
 UIModalTransitionStyle.flipHorizontal
 When the view controller is presented, the current view initiates a horizontal 3D flip from right-to-left, resulting in the revealing of the new view as if it were on the back of the previous view. On dismissal, the flip occurs from left-to-right, returning to the original view.
 
 UIModalTransitionStyle.crossDissolve
 When the view controller is presented, the current view fades out while the new view fades in at the same time. On dismissal, a similar type of cross-fade is used to return to the original view.
 
 UIModalTransitionStyle.partialCurl
 When the view controller is presented, one corner of the current view curls up to reveal the presented view underneath. On dismissal, the curled up page unfurls itself back on top of the presented view. A view controller presented using this transition is itself prevented from presenting any additional view controllers.
 This transition style is supported only if the parent view controller is presenting a full-screen view and you use the UIModalPresentationStyle.fullScreen modal presentation style. Attempting to use a different form factor for the parent view or a different presentation style triggers an exception.
 */
@property (readwrite, nonatomic) UIModalTransitionStyle transitionStyle;
/*
 Default parameters sent to the `UIViewController`'s initWithRouterParams: method. This is useful if you want to pass some non-`NSString` information. These parameters will be overwritten by any parameters passed in the URL in open:.
 */
@property (readwrite, nonatomic, strong) NSDictionary *defaultParams;
/*
 The property determining if the mapped `UIViewController` instance should be set as the root view controller of the router's `UINavigationController` instance.
 */
@property (readwrite, nonatomic, assign) BOOL shouldOpenAsRootViewController;

@end



/*
 `UPRouter` is the main class you interact with to map URLs to either opening `UIViewController`s or running anonymous functions.
 
 For example:
 
 [[Routable sharedRouter] map:@"users/:id" toController:[UserController class]];
 [[Routable sharedRouter] setNavigationController: aNavigationController];
 
 // In UserController.m
 @implementation UserController
 
 // params will be non-nil
 - (id)initWithRouterParams:(NSDictionary *)params {
 if ((self = [self initWithNibName:nil bundle:nil])) {
 self.userId = [params objectForKey:@"id"];
 }
 return self;
 }
 
 Anonymous methods can also be routed:
 
 [[Routable sharedRouter] map:@"logout" toCallback:^(NSDictionary *params) {
 [User logout];
 }];
 
 [[Routable sharedRouter] map:@"invalidate/:id" toCallback:^(NSDictionary *params) {
 [Cache invalidate: [params objectForKey:@"id"]]];
 }];
 
 If you wish to do custom allocation of a controller, you can use controllerWithRouterParams:
 
 [[Routable sharedRouter] map:@"users/:id" toController:[StoryboardController class]];
 
 @implementation StoryboardController
 
 + (id)controllerWithRouterParams:(NSDictionary *)params {
 UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard" bundle:nil];
 StoryboardController *instance = [storyboard instantiateViewControllerWithIdentifier:@"sbController"];
 instance.userId = [params objectForKey:@"id"];
 
 return instance;
 }
 
 */
@interface UPRouter : NSObject

///-------------------------------
/// @name Navigation Controller
///-------------------------------

/**
 The `UINavigationController` instance which mapped `UIViewController`s will be pushed onto.
 */
@property (readwrite, nonatomic, strong) UINavigationController *navigationController;

/**
 Pop to the last `UIViewController` mapped with the router; this will either dismiss the presented `UIViewController` (i.e. modal) or pop the top view controller in the navigationController. The transition is animated.
 */
- (void)pop;

/**
 Pop to the last `UIViewController` mapped with the router; this will either dismiss the presented `UIViewController` (i.e. modal) or pop the top view controller in the navigationController.
 @param animated Whether or not the transition is animated;
 */

- (void)popViewControllerFromRouterAnimated:(BOOL)animated;
/**
 Pop to the last `UIViewController` mapped with the router; this will either dismiss the presented `UIViewController` (i.e. modal) or pop the top view controller in the navigationController.
 @param animated Whether or not the transition is animated;
 @remarks not idiomatic objective-c naming
 */
- (void)pop:(BOOL)animated;

///-------------------------------
/// @name Mapping URLs
///-------------------------------

/**
 The property controls for throwing exception or not in your app. NOT throwing any exceptions if set to `YES`, default `NO`;
 */
@property (readwrite, nonatomic, assign) BOOL ignoresExceptions;

/**
 Map a URL format to an anonymous callback
 @param format A URL format (i.e. "users/:id" or "logout")
 @param callback The callback to run when the URL is triggered in `open:`
 */
- (void)map:(NSString *)format toCallback:(RouterOpenCallback)callback;
/**
 Map a URL format to an anonymous callback and `UPRouterOptions` options
 @param format A URL format (i.e. "users/:id" or "logout")
 @param callback The callback to run when the URL is triggered in `open:`
 @param options Configuration for the route
 */
- (void)map:(NSString *)format toCallback:(RouterOpenCallback)callback withOptions:(UPRouterOptions *)options;
/**
 Map a URL format to an anonymous callback and `UPRouterOptions` options
 @param format A URL format (i.e. "users/:id" or "logout")
 @param controllerClass The `UIViewController` `Class` which will be instanstiated when the URL is triggered in `open:`
 */
- (void)map:(NSString *)format toController:(Class)controllerClass;
/**
 Map a URL format to an anonymous callback and `UPRouterOptions` options
 @param format A URL format (i.e. "users/:id" or "logout")
 @param controllerClass The `UIViewController` `Class` which will be instanstiated when the URL is triggered in `open:`
 @param options Configuration for the route, such as modal settings
 */
- (void)map:(NSString *)format toController:(Class)controllerClass withOptions:(UPRouterOptions *)options;

///-------------------------------
/// @name Opening URLs
///-------------------------------

/**
 A convenience method for opening a URL using `UIApplication` `openURL:`.
 @param url The URL the OS will open (i.e. "http://google.com")
 */
- (void)openExternal:(NSString *)url;

/**
 Triggers the appropriate functionality for a mapped URL, such as an anonymous function or opening a `UIViewController`. `UIViewController` transitions will be animated;
 @param url The URL being opened (i.e. "users/16")
 @exception RouteNotFoundException Thrown if url does not have a valid mapping
 @exception NavigationControllerNotProvided Thrown if url opens a `UIViewController` and navigationController has not been assigned
 @exception RoutableInitializerNotFound Thrown if the mapped `UIViewController` instance does not implement -initWithRouterParams: or +allocWithRouterParams:
 */
- (void)open:(NSString *)url;

/**
 Triggers the appropriate functionality for a mapped URL, such as an anonymous function or opening a `UIViewController`
 @param url The URL being opened (i.e. "users/16")
 @param animated Whether or not `UIViewController` transitions are animated.
 @exception RouteNotFoundException Thrown if url does not have a valid mapping
 @exception NavigationControllerNotProvided Thrown if url opens a `UIViewController` and navigationController has not been assigned
 @exception RoutableInitializerNotFound Thrown if the mapped `UIViewController` instance does not implement -initWithRouterParams: or +allocWithRouterParams:
 */
- (void)open:(NSString *)url animated:(BOOL)animated;

/**
 Triggers the appropriate functionality for a mapped URL, such as an anonymous function or opening a `UIViewController`
 @param url The URL being opened (i.e. "users/16")
 @param animated Whether or not `UIViewController` transitions are animated.
 @param extraParams more paramters to pass in while opening a `UIViewController`; take priority over route-specific default parameters
 @exception RouteNotFoundException Thrown if url does not have a valid mapping
 @exception NavigationControllerNotProvided Thrown if url opens a `UIViewController` and navigationController has not been assigned
 @exception RoutableInitializerNotFound Thrown if the mapped `UIViewController` instance does not implement -initWithRouterParams: or +allocWithRouterParams:
 */
- (void)open:(NSString *)url animated:(BOOL)animated extraParams:(NSDictionary *)extraParams;

/**
 Get params of a given URL, simply return the params dictionary NOT using a block
 @param url The URL being detected (i.e. "users/16")
 */
- (NSDictionary*)paramsOfUrl:(NSString*)url;

@end


@interface Routable : UPRouter

/*
 A singleton instance of `UPRouter` which can be accessed anywhere in the app.
 @return A singleton instance of `UPRouter`.
 */
+ (instancetype)sharedRouter;

/*
 A new instance of `UPRouter`, in case you want to use multiple routers in your app.
 @remarks Unnecessary method; can use [[Routable alloc] init] instead
 @return A new instance of `UPRouter`.
 */
+ (instancetype)newRouter;

@end
