#import "Routable.h"

@implementation Routable

+ (instancetype)sharedRouter {
    static Routable *_sharedRouter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedRouter = [[Routable alloc] init];
    });
    return _sharedRouter;
}

//really unnecessary; kept for backward compatibility.
+ (instancetype)newRouter {
    return [[self alloc] init];
}

@end

@interface RouterParams : NSObject

@property (readwrite, nonatomic, strong) UPRouterOptions *routerOptions;

@property (readwrite, nonatomic, strong) NSDictionary *openParams;
@property (readwrite, nonatomic, strong) NSDictionary *extraParams;
@property (readwrite, nonatomic, strong) NSDictionary *controllerParams;

@end

@implementation RouterParams

- (instancetype)initWithRouterOptions: (UPRouterOptions *)routerOptions openParams: (NSDictionary *)openParams extraParams: (NSDictionary *)extraParams{
    [self setRouterOptions:routerOptions];
    [self setExtraParams: extraParams];
    [self setOpenParams:openParams];
    return self;
}

- (NSDictionary *)controllerParams {
    NSMutableDictionary *controllerParams = [NSMutableDictionary dictionaryWithDictionary:self.routerOptions.defaultParams];
    [controllerParams addEntriesFromDictionary:self.extraParams];
    [controllerParams addEntriesFromDictionary:self.openParams];
    return controllerParams;
}
//fake getter. Not idiomatic Objective-C. Use accessor controllerParams instead
- (NSDictionary *)getControllerParams {
    return [self controllerParams];
}
@end

// H 文件里面的, 主要是 UI 表象部分.
/*
 实际上, UPRouterOptions 的核心数据就这两种.
 这里, 如果使用 Swift 的 Enum 会是更加好的做法. 前面的各种 UI 的配置, 只会在 openClass 有值的情况下才有效.
 从这个意义来说, UPRouterOptions 的 type 只有两种,
 UI 带有各种配置的关联至.
 CallBack 没有关联值.
 */
@interface UPRouterOptions ()

@property (readwrite, nonatomic, strong) Class openClass;
@property (readwrite, nonatomic, copy) RouterOpenCallback callback;

@end

@implementation UPRouterOptions

// 这里, 指定初始化方法, 是类方法. 而不是常用的 init 方法.
// Designated init method.
+ (instancetype)routerOptionsWithPresentationStyle: (UIModalPresentationStyle)presentationStyle
                                   transitionStyle: (UIModalTransitionStyle)transitionStyle
                                     defaultParams: (NSDictionary *)defaultParams
                                            isRoot: (BOOL)isRoot
                                           isModal: (BOOL)isModal {
    UPRouterOptions *options = [[UPRouterOptions alloc] init];
    options.presentationStyle = presentationStyle;
    options.transitionStyle = transitionStyle;
    options.defaultParams = defaultParams;
    options.shouldOpenAsRootViewController = isRoot;
    options.modal = isModal;
    return options;
}

// 以下, 大部分都是对于 Designated init method 的简便写法而已.
// 个人觉得, 这种大量的方法, 没有必要.
+ (instancetype)routerOptions {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:NO];
}

+ (instancetype)routerOptionsAsModal {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:YES];
}
+ (instancetype)routerOptionsWithPresentationStyle:(UIModalPresentationStyle)style {
    return [self routerOptionsWithPresentationStyle:style
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:NO];
}
+ (instancetype)routerOptionsWithTransitionStyle:(UIModalTransitionStyle)style {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:style
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:NO];
}
+ (instancetype)routerOptionsForDefaultParams:(NSDictionary *)defaultParams {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:defaultParams
                                             isRoot:NO
                                            isModal:NO];
}
+ (instancetype)routerOptionsAsRoot {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:YES
                                            isModal:NO];
}

+ (instancetype)modal {
    return [self routerOptionsAsModal];
}
+ (instancetype)withPresentationStyle:(UIModalPresentationStyle)style {
    return [self routerOptionsWithPresentationStyle:style];
}
+ (instancetype)withTransitionStyle:(UIModalTransitionStyle)style {
    return [self routerOptionsWithTransitionStyle:style];
}
+ (instancetype)forDefaultParams:(NSDictionary *)defaultParams {
    return [self routerOptionsForDefaultParams:defaultParams];
}
+ (instancetype)root {
    return [self routerOptionsAsRoot];
}

//Wrappers around setters (to continue DSL-like syntax)
- (UPRouterOptions *)modal {
    [self setModal:YES];
    return self;
}
- (UPRouterOptions *)withPresentationStyle:(UIModalPresentationStyle)style {
    [self setPresentationStyle:style];
    return self;
}
- (UPRouterOptions *)withTransitionStyle:(UIModalTransitionStyle)style {
    [self setTransitionStyle:style];
    return self;
}
- (UPRouterOptions *)forDefaultParams:(NSDictionary *)defaultParams {
    [self setDefaultParams:defaultParams];
    return self;
}
- (UPRouterOptions *)root {
    [self setShouldOpenAsRootViewController:YES];
    return self;
}
@end



@interface UPRouter ()

/*
 routes 里面存放的是,
 host 和 UPRouterOptions 的对应关系.
 目前 routes 存放两种 UPRouterOptions, 一种是 vc, 一种是闭包 callback.
 */
// Map of URL format NSString -> RouterOptions
// i.e. "users/:id"
@property (readwrite, nonatomic, strong) NSMutableDictionary *routes;

@end

#define ROUTE_NOT_FOUND_FORMAT @"No route found for URL %@"
#define INVALID_CONTROLLER_FORMAT @"Your controller class %@ needs to implement either the static method %@ or the instance method %@"



@implementation UPRouter

- (id)init {
    if ((self = [super init])) {
        self.routes = [NSMutableDictionary dictionary];
    }
    return self;
}

// 配置 Routable

- (void)map:(NSString *)format toCallback:(RouterOpenCallback)callback {
    [self map:format toCallback:callback withOptions:nil];
}

- (void)map:(NSString *)format toCallback:(RouterOpenCallback)callback withOptions:(UPRouterOptions *)options {
    if (!options) {
        options = [UPRouterOptions routerOptions];
    }
    options.callback = callback;
    [self.routes setObject:options forKey:format];
}

- (void)map:(NSString *)format toController:(Class)controllerClass {
    [self map:format toController:controllerClass withOptions:nil];
}

- (void)map:(NSString *)format toController:(Class)controllerClass withOptions:(UPRouterOptions *)options {
    if (!options) {
        options = [UPRouterOptions routerOptions];
    }
    options.openClass = controllerClass;
    [self.routes setObject:options forKey:format];
}

- (void)openExternal:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

// 使用 Routable

- (void)open:(NSString *)url {
    [self open:url animated:YES];
}

- (void)open:(NSString *)url animated:(BOOL)animated {
    [self open:url animated:animated extraParams:nil];
}

// 最终 open 的实现部分.
- (void)open:(NSString *)url
    animated:(BOOL)animated
 extraParams:(NSDictionary *)extraParams
{
    RouterParams *params = [self routerParamsForUrl:url extraParams: extraParams];
    UPRouterOptions *options = params.routerOptions;
    
    // 如果有回调, 那么使用回调.
    if (options.callback) {
        RouterOpenCallback callback = options.callback;
        callback([params controllerParams]);
        return;
    }
    
    // 如果是 VC 的弹出, 就走下面的 VC 的创建, 弹出的工作.
    if (!self.navigationController) {
        if (_ignoresExceptions) {
            return;
        }
        @throw [NSException exceptionWithName:@"NavigationControllerNotProvided"
                                       reason:@"Router#navigationController has not been set to a UINavigationController instance"
                                     userInfo:nil];
    }
    
    UIViewController *controller = [self controllerForRouterParams:params];
    if (self.navigationController.presentedViewController) {
        // 撤回已经 present 出来的 VC.
        [self.navigationController dismissViewControllerAnimated:animated completion:nil];
    }
    
    // 如果是模态弹出. 那么包装一层 nav 进行弹出.
    if ([options isModal]) {
        if ([controller.class isSubclassOfClass:UINavigationController.class]) {
            [self.navigationController presentViewController:controller
                                                    animated:animated
                                                  completion:nil];
        } else {
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
            navigationController.modalPresentationStyle = controller.modalPresentationStyle;
            navigationController.modalTransitionStyle = controller.modalTransitionStyle;
            [self.navigationController presentViewController:navigationController
                                                    animated:animated
                                                  completion:nil];
        }
    } else if (options.shouldOpenAsRootViewController) {
        // 特殊的配置, 进行 nav 的整体替换.
        [self.navigationController setViewControllers:@[controller] animated:animated];
    } else {
        // 最最一般的配置.
        [self.navigationController pushViewController:controller animated:animated];
    }
}

- (NSDictionary*)paramsOfUrl:(NSString*)url {
    return [[self routerParamsForUrl:url] controllerParams];
}

//Stack operations
- (void)popViewControllerFromRouterAnimated:(BOOL)animated {
    if (self.navigationController.presentedViewController) {
        [self.navigationController dismissViewControllerAnimated:animated completion:nil];
    }
    else {
        [self.navigationController popViewControllerAnimated:animated];
    }
}
- (void)pop {
    [self popViewControllerFromRouterAnimated:YES];
}
- (void)pop:(BOOL)animated {
    [self popViewControllerFromRouterAnimated:animated];
}

/*
 [[Routable sharedRouter] map:@"users/:id" toController:[UserController class]];
 
 NSString *aUrl = @"users/4";
 [[Routable sharedRouter] open:aUrl];
 */
// 通过 Url, 获取最终的数据,
- (RouterParams *)routerParamsForUrl:(NSString *)url extraParams: (NSDictionary *)extraParams {
    if (!url) {
        if (_ignoresExceptions) {
            return nil;
        }
        @throw [NSException exceptionWithName:@"RouteNotFoundException"
                                       reason:[NSString stringWithFormat:ROUTE_NOT_FOUND_FORMAT, url]
                                     userInfo:nil];
    }
    
    NSArray *givenParts = url.pathComponents;
    NSArray *legacyParts = [url componentsSeparatedByString:@"/"];
    if ([legacyParts count] != [givenParts count]) {
        NSLog(@"Routable Warning - your URL %@ has empty path components - this will throw an error in an upcoming release", url);
        givenParts = legacyParts;
    }
    
    __block RouterParams *openParams = nil;
    [self.routes enumerateKeysAndObjectsUsingBlock:
     ^(NSString *routerUrl, UPRouterOptions *routerOptions, BOOL *stop) {
        // 是注册的时候, 填入的 format, 例如 user/:id/:name 这些.
        NSArray *routerParts = [routerUrl pathComponents];
        
        if ([routerParts count] == [givenParts count]) {
            NSDictionary *givenParams = [self paramsForUrlComponents:givenParts routerUrlComponents:routerParts];
            if (givenParams) {
                // givenParams 是 Url 里面带的数据
                // extraParams 是方法调用的时候, 带来的数据.
                // routerOptions 是 Map 的时候, url 对应的 Options.
                openParams = [[RouterParams alloc] initWithRouterOptions:routerOptions openParams:givenParams extraParams: extraParams];
                *stop = YES;
            }
        }
    }];
    
    if (!openParams) {
        if (_ignoresExceptions) {
            return nil;
        }
        @throw [NSException exceptionWithName:@"RouteNotFoundException"
                                       reason:[NSString stringWithFormat:ROUTE_NOT_FOUND_FORMAT, url]
                                     userInfo:nil];
    }
    return openParams;
}

- (RouterParams *)routerParamsForUrl:(NSString *)url {
    return [self routerParamsForUrl:url extraParams: nil];
}

// 这里, 传递过来的数据是 ["user", ":name", "age"], ["user", "Justin", "23"]
// 如果, 不是 : 开头的, 那么就是路径判断了, 就是 else if 里面的逻辑. 如果路径不相匹配, 直接 params = nil.
- (NSDictionary *)paramsForUrlComponents:(NSArray *)givenUrlComponents
                     routerUrlComponents:(NSArray *)routerUrlComponents {
    
    __block NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [routerUrlComponents enumerateObjectsUsingBlock:
     ^(NSString *routerComponent, NSUInteger idx, BOOL *stop) {
        NSString *givenComponent = givenUrlComponents[idx];
        if ([routerComponent hasPrefix:@":"]) {
            NSString *key = [routerComponent substringFromIndex:1];
            [params setObject:givenComponent forKey:key];
        } else if (![routerComponent isEqualToString:givenComponent]) {
            params = nil;
            *stop = YES;
        }
    }];
    return params;
}

// 最终, 进行 VC 的创造的部分.
// 还是根据数据部分, 进行创建.
// 这里, 注册的 VC, 必须实现 allocWithRouterParams, initWithRouterParams 方法才可以.
- (UIViewController *)controllerForRouterParams:(RouterParams *)params {
    SEL CONTROLLER_CLASS_SELECTOR = sel_registerName("allocWithRouterParams:");
    SEL CONTROLLER_SELECTOR = sel_registerName("initWithRouterParams:");
    UIViewController *controller = nil;
    Class controllerClass = params.routerOptions.openClass;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([controllerClass respondsToSelector:CONTROLLER_CLASS_SELECTOR]) {
        controller = [controllerClass performSelector:CONTROLLER_CLASS_SELECTOR withObject:[params controllerParams]];
    } else if ([params.routerOptions.openClass instancesRespondToSelector:CONTROLLER_SELECTOR]) {
        controller = [[params.routerOptions.openClass alloc] performSelector:CONTROLLER_SELECTOR withObject:[params controllerParams]];
    }
#pragma clang diagnostic pop
    if (!controller) {
        if (_ignoresExceptions) {
            return controller;
        }
        @throw [NSException exceptionWithName:@"RoutableInitializerNotFound"
                                       reason:[NSString stringWithFormat:INVALID_CONTROLLER_FORMAT, NSStringFromClass(controllerClass), NSStringFromSelector(CONTROLLER_CLASS_SELECTOR),  NSStringFromSelector(CONTROLLER_SELECTOR)]
                                     userInfo:nil];
    }
    
    controller.modalTransitionStyle = params.routerOptions.transitionStyle;
    controller.modalPresentationStyle = params.routerOptions.presentationStyle;
    return controller;
}

@end

