#import "common.h"

#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"


@implementation NSCachedURLResponse

- (NSData *) data {
    return self->data;
}

- (id) initWithResponse: (NSURLResponse *)response data: (NSData *)data {
    return [self initWithResponse: response
                             data: data
                         userInfo: nil
                    storagePolicy: NSURLCacheStorageAllowed];
}

- (id) initWithResponse: (NSURLResponse *)response
                   data: (NSData *)data
               userInfo: (NSDictionary *)userInfo
          storagePolicy: (NSURLCacheStoragePolicy)storagePolicy;
{
    if ((self = [super init]) != nil)
    {
        ASSIGNCOPY(self->data, data);
        ASSIGNCOPY(self->response, response);
        ASSIGNCOPY(self->userInfo, userInfo);
        self->storagePolicy = storagePolicy;
    }
    return self;
}

- (NSURLResponse *) response
{
    return self->response;
}

- (NSURLCacheStoragePolicy) storagePolicy
{
    return self->storagePolicy;
}

- (NSDictionary *) userInfo
{
    return self->userInfo;
}

@end


static NSURLCache	*shared = nil;

@implementation	NSURLCache

/*
 这个类, 并没有提供太多的实现层面上的东西. 很多应该实现的东西没有实现.
*/

/*
 因为这里有一个 change 的操作, 所以单例变成了静态变量.
 */
+ (void) setSharedURLCache: (NSURLCache *)cache
{
    [gnustep_global_lock lock];
    ASSIGN(shared, cache);
    [gnustep_global_lock unlock];
}

+ (NSURLCache *) sharedURLCache
{
    NSURLCache	*c;
    
    [gnustep_global_lock lock];
    if (shared == nil)
    {
        NSString	*path = nil;
        /*
         initWithMemoryCapacity 真正有价值的地方, 通过 init 方法, 读取原始的资源.
         这里相应的地方, 都有加锁处理.
         */
        shared = [[self alloc] initWithMemoryCapacity: 4 * 1024 * 1024
                                         diskCapacity: 20 * 1024 * 1024
                                             diskPath: path];
    }
    c = RETAIN(shared);
    [gnustep_global_lock unlock];
    return AUTORELEASE(c);
}

/*
 直接返回内存里面的存储值.
 */
- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request
{
    return [self->memory objectForKey: request];
}

- (NSUInteger) currentDiskUsage
{
    return self->diskUsage;
}

- (NSUInteger) currentMemoryUsage
{
    return self->memoryUsage;
}

- (NSUInteger) diskCapacity
{
    return self->diskCapacity;
}

- (id) initWithMemoryCapacity: (NSUInteger)memoryCapacity
                 diskCapacity: (NSUInteger)diskCapacity
                     diskPath: (NSString *)path
{
    if ((self = [super init]) != nil)
    {
        self->diskUsage = 0;
        self->diskCapacity = diskCapacity;
        self->memoryUsage = 0;
        self->memoryCapacity = memoryCapacity;
        self->path = [path copy];
        self->memory = [NSMutableDictionary new];
    }
    return self;
}

- (NSUInteger) memoryCapacity
{
    return self->memoryCapacity;
}

- (void) removeAllCachedResponses
{
    [self->memory removeAllObjects];
    self->diskUsage = 0;
    self->memoryUsage = 0;
}

- (void) removeCachedResponseForRequest: (NSURLRequest *)request
{
    NSCachedURLResponse	*item = [self cachedResponseForRequest: request];
    
    if (item != nil)
    {
        self->memoryUsage -= [[item data] length];
        [self->memory removeObjectForKey: request];
    }
}

- (void) storeCachedResponse: (NSCachedURLResponse *)cachedResponse
                  forRequest: (NSURLRequest *)request
{
    switch ([cachedResponse storagePolicy])
    {
        case NSURLCacheStorageAllowed:
            
        case NSURLCacheStorageAllowedInMemoryOnly:
        {
            unsigned		size = [[cachedResponse data] length];
            
            if (size < self->memoryCapacity)
            {
                NSCachedURLResponse	*old;
                
                old = [self->memory objectForKey: request];
                if (old != nil)
                {
                    self->memoryUsage -= [[old data] length];
                    [self->memory removeObjectForKey: request];
                }
                while (self->memoryUsage + size > self->memoryCapacity)
                {
                    // FIXME ... should delete least recently used.
                    [self removeCachedResponseForRequest:
                     [[self->memory allKeys] lastObject]];
                }
                [self->memory setObject: cachedResponse forKey: request];
                self->memoryUsage += size;
            }
        }
            break;
            
        case NSURLCacheStorageNotAllowed:
            break;
            
        default:
            [NSException raise: NSInternalInconsistencyException
                        format: @"storing cached response with bad policy (%d)",
             [cachedResponse storagePolicy]];
    }
}

@end

