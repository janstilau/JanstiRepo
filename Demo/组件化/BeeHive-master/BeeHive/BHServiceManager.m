#import "BHServiceManager.h"
#import "BHContext.h"
#import "BHAnnotation.h"
#import <objc/runtime.h>

static const NSString *kService = @"service";
static const NSString *kImpl = @"impl";

@interface BHServiceManager()

// 这里面, 记录的是, service 的 protocol 名字,
@property (nonatomic, strong) NSMutableDictionary *allServicesDict;
@property (nonatomic, strong) NSRecursiveLock *lock;

@end

@implementation BHServiceManager

+ (instancetype)sharedManager
{
    static id sharedManager = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

// 注册服务.
// 从 Plist 文件里面, 找到 service 以及对应的 Imp 的类名, 然后添加到 allServicesDict 内.
- (void)registerLocalServices
{
    NSString *serviceConfigName = [BHContext shareInstance].serviceConfigName;
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:serviceConfigName ofType:@"plist"];
    if (!plistPath) {
        return;
    }
    
    NSArray *serviceList = [[NSArray alloc] initWithContentsOfFile:plistPath];
    
    [self.lock lock];
    for (NSDictionary *dict in serviceList) {
        NSString *protocolKey = [dict objectForKey:@"service"];
        NSString *protocolImplClass = [dict objectForKey:@"impl"];
        if (protocolKey.length > 0 && protocolImplClass.length > 0) {
            [self.allServicesDict addEntriesFromDictionary:@{protocolKey:protocolImplClass}];
        }
    }
    [self.lock unlock];
}

// 注册服务.

- (void)registerService:(Protocol *)service implClass:(Class)implClass
{
    NSParameterAssert(service != nil);
    NSParameterAssert(implClass != nil);
    
    // 会提前检查一下, 是不是对应的 class 满足 protocol 的功能. 如果不满足, 直接返回.
    if (![implClass conformsToProtocol:service]) {
        if (self.enableException) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ module does not comply with %@ protocol", NSStringFromClass(implClass), NSStringFromProtocol(service)] userInfo:nil];
        }
        return;
    }
    
    if ([self checkValidService:service]) {
        if (self.enableException) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ protocol has been registed", NSStringFromProtocol(service)] userInfo:nil];
        }
        return;
    }
    
    NSString *key = NSStringFromProtocol(service);
    NSString *value = NSStringFromClass(implClass);
    
    // 将 protocol 和 对应的 imp 的字符串名, 添加到 allServicesDict 的内部.
    if (key.length > 0 && value.length > 0) {
        [self.lock lock];
        [self.allServicesDict addEntriesFromDictionary:@{key:value}];
        [self.lock unlock];
    }
    
}

- (id)createService:(Protocol *)service
{
    return [self createService:service withServiceName:nil];
}

- (id)createService:(Protocol *)service withServiceName:(NSString *)serviceName {
    return [self createService:service withServiceName:serviceName shouldCache:YES];
}

- (id)createService:(Protocol *)service withServiceName:(NSString *)serviceName shouldCache:(BOOL)shouldCache {
    if (!serviceName.length) {
        serviceName = NSStringFromProtocol(service);
    }
    id implInstance = nil;
    
    if (![self checkValidService:service]) {
        if (self.enableException) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ protocol does not been registed", NSStringFromProtocol(service)] userInfo:nil];
        }
        
    }
    
    // 如果有缓存, 那么就在缓存里面, 找一下之前存储过的 Imp.
    NSString *serviceStr = serviceName;
    if (shouldCache) {
        id protocolImpl = [[BHContext shareInstance] getServiceInstanceFromServiceName:serviceStr];
        if (protocolImpl) {
            return protocolImpl;
        }
    }
    
    // 找到了 Imp 的类对象.
    Class implClass = [self serviceImplClass:service];
    if ([[implClass class] respondsToSelector:@selector(singleton)]) {
        if ([[implClass class] singleton]) {
            // 如果, 支持单例模式.
            // 那么就使用 shareInstance 获取到单例, 然后返回.
            if ([[implClass class] respondsToSelector:@selector(shareInstance)])
                implInstance = [[implClass class] shareInstance];
            else
                implInstance = [[implClass alloc] init];
            if (shouldCache) {
                [[BHContext shareInstance] addServiceWithImplInstance:implInstance serviceName:serviceStr];
                return implInstance;
            } else {
                return implInstance;
            }
        }
    }
    return [[implClass alloc] init];
}

- (id)getServiceInstanceFromServiceName:(NSString *)serviceName
{
    return [[BHContext shareInstance] getServiceInstanceFromServiceName:serviceName];
}

- (void)removeServiceWithServiceName:(NSString *)serviceName
{
    [[BHContext shareInstance] removeServiceWithServiceName:serviceName];
}


#pragma mark - private
- (Class)serviceImplClass:(Protocol *)service
{
    NSString *serviceImpl = [[self servicesDict] objectForKey:NSStringFromProtocol(service)];
    if (serviceImpl.length > 0) {
        return NSClassFromString(serviceImpl);
    }
    return nil;
}

// 这里, 其实就检查, 是不是该 protocol 之前注册过了相关的 service.
- (BOOL)checkValidService:(Protocol *)service
{
    NSString *serviceImpl = [[self servicesDict] objectForKey:NSStringFromProtocol(service)];
    if (serviceImpl.length > 0) {
        return YES;
    }
    return NO;
}

- (NSMutableDictionary *)allServicesDict
{
    if (!_allServicesDict) {
        _allServicesDict = [NSMutableDictionary dictionary];
    }
    return _allServicesDict;
}

- (NSRecursiveLock *)lock
{
    if (!_lock) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return _lock;
}

- (NSDictionary *)servicesDict
{
    [self.lock lock];
    NSDictionary *dict = [self.allServicesDict copy];
    [self.lock unlock];
    return dict;
}


@end
