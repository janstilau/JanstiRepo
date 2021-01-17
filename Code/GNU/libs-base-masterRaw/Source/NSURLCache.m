#import "common.h"

#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"

// FIXME ... locking and disk storage needed
typedef struct {
    unsigned		diskCapacity; // 磁盘的容量
    unsigned		memoryCapacity; // 内存的容量
    unsigned		diskUsage; // 磁盘的使用量
    unsigned		memoryUsage; // 内存的使用量
    NSString		*path;
    NSMutableDictionary	*memory;
} Internal;

#define	this	((Internal*)(self->_NSURLCacheInternal))
#define	inst	((Internal*)(o->_NSURLCacheInternal))


static NSURLCache	*shared = nil;

@implementation	NSURLCache

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
        shared = [[self alloc] initWithMemoryCapacity: 4 * 1024 * 1024
                                         diskCapacity: 20 * 1024 * 1024
                                             diskPath: path];
        
    }
    c = RETAIN(shared);
    [gnustep_global_lock unlock];
    return AUTORELEASE(c);
}

// 所以, 其实就是使用了 dict 作为了 hash 表快速查询.
- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request
{
    return [this->memory objectForKey: request];
}

- (NSUInteger) currentDiskUsage
{
    return this->diskUsage;
}

- (NSUInteger) currentMemoryUsage
{
    return this->memoryUsage;
}

- (NSUInteger) diskCapacity
{
    return this->diskCapacity;
}

- (id) initWithMemoryCapacity: (NSUInteger)memoryCapacity
                 diskCapacity: (NSUInteger)diskCapacity
                     diskPath: (NSString *)path
{
    if ((self = [super init]) != nil)
    {
        this->diskUsage = 0;
        this->diskCapacity = diskCapacity;
        this->memoryUsage = 0;
        this->memoryCapacity = memoryCapacity;
        this->path = [path copy];
        this->memory = [NSMutableDictionary new];
    }
    return self;
}

- (NSUInteger) memoryCapacity
{
    return this->memoryCapacity;
}

- (void) removeAllCachedResponses
{
    [this->memory removeAllObjects];
    this->diskUsage = 0;
    this->memoryUsage = 0;
}

- (void) removeCachedResponseForRequest: (NSURLRequest *)request
{
    NSCachedURLResponse	*item = [self cachedResponseForRequest: request];
    
    if (item != nil)
    {
        this->memoryUsage -= [[item data] length];
        [this->memory removeObjectForKey: request];
    }
}

- (void) setDiskCapacity: (NSUInteger)diskCapacity
{
    [self notImplemented: _cmd];
}

- (void) setMemoryCapacity: (NSUInteger)memoryCapacity
{
    [self notImplemented: _cmd];
}

- (void) storeCachedResponse: (NSCachedURLResponse *)cachedResponse
                  forRequest: (NSURLRequest *)request
{
    switch ([cachedResponse storagePolicy])
    {
        case NSURLCacheStorageAllowed:
            // FIXME ... maybe on disk?
            
        case NSURLCacheStorageAllowedInMemoryOnly:
        {
            unsigned		size = [[cachedResponse data] length];
            
            if (size < this->memoryCapacity)
            {
                NSCachedURLResponse	*old;
                
                old = [this->memory objectForKey: request];
                if (old != nil)
                {
                    this->memoryUsage -= [[old data] length];
                    [this->memory removeObjectForKey: request];
                }
                while (this->memoryUsage + size > this->memoryCapacity)
                {
                    // FIXME ... should delete least recently used.
                    [self removeCachedResponseForRequest:
                     [[this->memory allKeys] lastObject]];
                }
                [this->memory setObject: cachedResponse forKey: request];
                this->memoryUsage += size;
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

