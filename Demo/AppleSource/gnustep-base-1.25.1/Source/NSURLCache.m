#import "common.h"

#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"
#import "NSURLCache.h"


/*
 For convenience, NSURLSessionConfiguration has a property called requestCachePolicy;
 all requests created from sessions that use self configuration inherit their cache policy from the configuration.
 Currently, only HTTP and HTTPS responses are cached.
 */

/*
 只要, 资源是被这个类进行管理的, 用全局静态变量也是没有问题的.
 */
static NSURLCache	*shared = nil;

@implementation	NSURLCache


+ (void) setSharedURLCache: (NSURLCache *)cache
{
    /*
     因为不能管理调用者的线程, 所以该加锁的地方, 还是要进行加锁.
     */
    [gnustep_global_lock lock];
    ASSIGN(shared, cache);
    [gnustep_global_lock unlock];
}

- (void) dealloc
{
    if (self != 0)
    {
        RELEASE(self->memory);
        RELEASE(self->path);
        NSZoneFree([self zone], self);
    }
    [super dealloc];
}

+ (NSURLCache *) sharedURLCache
{
    NSURLCache	*c;
    /*
     因为会有 set 方法暴露出去, 所以这里的静态变量, 没有写到方法的内部.
     */
    [gnustep_global_lock lock];
    if (shared == nil)
    {
        NSString	*path = nil;
        shared = [[self alloc] initWithMemoryCapacity: 4 * 1024 * 1024 // 默认是 4 MB
                                         diskCapacity: 20 * 1024 * 1024 // 默认是 20 MB
                                             diskPath: path];
    }
    c = RETAIN(shared);
    [gnustep_global_lock unlock];
    return AUTORELEASE(c);
}

/*
 这里, 用的是 Request 作为 key, 而 Request 里面, hash 是通过 URL 的 hash 得到的.
 */
- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request
{
    return [self->memory objectForKey: request]; // 其实就是一个字典.
}

- (int) currentDiskUsage
{
    return self->diskUsage;
}

- (int) currentMemoryUsage
{
    return self->memoryUsage;
}

- (int) diskCapacity
{
    return self->diskCapacity;
}

- (id) initWithMemoryCapacity: (int)memoryCapacity
                 diskCapacity: (int)diskCapacity
                     diskPath: (NSString *)path
{
    if ((self = [super init]) != nil)
    {
        self->diskUsage = 0;
        self->diskCapacity = diskCapacity;
        self->memoryUsage = 0;
        self->memoryCapacity = memoryCapacity;
        self->path = [path copy];
        /*
         这里感觉有点问题, path 得到了, 不应该有个 loading 的操作.
         */
        self->memory = [NSMutableDictionary new];
    }
    return self;
}

- (int) memoryCapacity
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
        // FIXME ... disk storage
        self->memoryUsage -= [[item data] length]; // 减去所占空间
        [self->memory removeObjectForKey: request]; // 减去这个实例.
    }
}

- (void) setDiskCapacity: (int)diskCapacity
{
    [self notImplemented: _cmd];
}

- (void) setMemoryCapacity: (int)memoryCapacity
{
    [self notImplemented: _cmd];
}

/*
 这里, 原来是根据 value 里面设置的 policy 进行的设置.
 */

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
                    [self->memory removeObjectForKey: request]; // 删除原来的值.
                }
                while (self->memoryUsage + size > self->memoryCapacity)
                {
                    [self removeCachedResponseForRequest:
                     [[self->memory allKeys] lastObject]]; // 如果满了. 那么随便删一个值. 因为 NSDictionary 里面其实是无序的 key 的排列.
                }
                [self->memory setObject: cachedResponse forKey: request];
                self->memoryUsage += size;
            }
        }
            break;
        case NSURLCacheStorageNotAllowed: // 不保存. 直接返回.
            break;
            
        default:
            [NSException raise: NSInternalInconsistencyException
                        format: @"storing cached response with bad policy (%d)",
             [cachedResponse storagePolicy]];
    }
}

@end

