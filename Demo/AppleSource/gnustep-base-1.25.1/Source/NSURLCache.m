#import "common.h"

#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"
#import "NSURLCache.h"


/*
 For convenience, NSURLSessionConfiguration has a property called requestCachePolicy;
 all requests created from sessions that use self configuration inherit their cache policy from the configuration.
 Currently, only HTTP and HTTPS responses are cached.
 
 也就是说, 现在 http, https 的请求, 系统的类库会根据 reqeust 里面的 cachePolicy 操作 NSURLCache 的内容.
 
 所以, 很多类它的功能是配置, 尤其是那些用 configuration 结尾的类. 有些操作, 最后是有一个真正具体的数据类来进行的, 而这些真正具体的数据类的内容, 其实是要从配置类中获取的.
 
 Http request 的默认缓存策略是用 http 协议的缓存策略
 1. 有没有缓存. 有的话下一步, 不然直接 sourceload
 2. 过没过期. 没过期直接返回. 过期了下一步
 3. 会发一个 head 询问有没有进行变化, 变化了 sourceLoad, 没变化直接返回缓存.
 */

// 这个类居然没有看见保存的代码.
// 如果想要人工管理缓存, 可以用 storeCachedResponse:forRequest: 这个方法.

static NSURLCache	*shared = nil;

@implementation	NSURLCache

+ (id) allocWithZone: (NSZone*)z
{
    NSURLCache	*o = [super allocWithZone: z];
    
    if (o != nil)
    {
        o->_NSURLCacheInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
    return o;
}

+ (void) setSharedURLCache: (NSURLCache *)cache
{
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

