#import "BeeHive.h"

@implementation BeeHive

#pragma mark - public

// 这个类, 是总的入口. 一般来说, 业务类应该只使用该类提供的方法, 将使用者的使用负担减小到最底.
+ (instancetype)shareInstance
{
    static dispatch_once_t p;
    static id BHInstance = nil;
    dispatch_once(&p, ^{
        BHInstance = [[self alloc] init];
    });
    return BHInstance;
}

// 调用 BHModuleManager 进行 Module 的注册工作
+ (void)registerDynamicModule:(Class)moduleClass
{
    [[BHModuleManager sharedManager] registerDynamicModule:moduleClass];
}

// 调用 BHServiceManager 进行 Service 的注册工作
// 这是 protocol 和 IMP 的 Register 的过程.
- (void)registerService:(Protocol *)proto service:(Class) serviceClass
{
    [[BHServiceManager sharedManager] registerService:proto implClass:serviceClass];
}

// 调用 BHServiceManager 进行 Service 的生成工作
// 业务类, 在真的需要和其他模块进行交互的时候, 调用该方法, 调用其他模块的功能.
// 这是 protocol 和 IMP 的 Resolve 的过程.
- (id)createService:(Protocol *)proto;
{
    return [[BHServiceManager sharedManager] createService:proto];
}

+ (void)triggerCustomEvent:(NSInteger)eventType
{
    if(eventType < 1000) {
        return;
    }
    [[BHModuleManager sharedManager] triggerEvent:eventType];
}

#pragma mark - Private

// 因为, Context 里面, 存储了两个 Plist 的路径, 所以, 这里 context 变化了之后, 要进行重新的加载工作.
-(void)setContext:(BHContext *)context
{
    _context = context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadStaticServices];
        [self loadStaticModules];
    });
}


// Module 的加载工作, 在自己的 manager 中进行.
- (void)loadStaticModules
{
    [[BHModuleManager sharedManager] loadLocalModules];
    [[BHModuleManager sharedManager] registedAllModules];
    
}

// Service 的加载工作, 在自己的 service 中进行.
-(void)loadStaticServices
{
    [BHServiceManager sharedManager].enableException = self.enableException;
    [[BHServiceManager sharedManager] registerLocalServices];
}

@end
