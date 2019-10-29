#import "common.h"
#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"

static NSURLCache	*shared = nil;

@implementation	NSURLCache

+ (void) setSharedURLCache: (NSURLCache *)cache
{
    // 这里有一个加锁的处理.
    [gnustep_global_lock lock];
    ASSIGN(shared, cache);
    [gnustep_global_lock unlock];
}

- (void) dealloc
{
    RELEASE(self->memory);
    RELEASE(self->path);
    NSZoneFree([self zone], self);
    [super dealloc];
}

+ (NSURLCache *) sharedURLCache
{
    NSURLCache	*c;
    
    [gnustep_global_lock lock];
    if (shared == nil)
    {
        NSString	*path = nil;
        
        // FIXME user-library-path/Caches/current-app-name
        
        shared = [[self alloc] initWithMemoryCapacity: 4 * 1024 * 1024
                                         diskCapacity: 20 * 1024 * 1024
                                             diskPath: path];
        
    }
    c = RETAIN(shared);
    [gnustep_global_lock unlock];
    return AUTORELEASE(c);
}

- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request
{
    // FIXME ... handle disk cache
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
    // FIXME ... disk storage
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
        self->memoryUsage -= [[item data] length];
        [self->memory removeObjectForKey: request];
    }
}

- (void) setDiskCapacity: (NSUInteger)diskCapacity
{
    [self notImplemented: _cmd];
    // FIXME
}

- (void) setMemoryCapacity: (NSUInteger)memoryCapacity
{
    [self notImplemented: _cmd];
    // FIXME
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

