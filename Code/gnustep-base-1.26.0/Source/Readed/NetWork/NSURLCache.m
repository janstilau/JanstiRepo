#import "common.h"

#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"


static NSURLCache	*shared = nil;

@implementation	NSURLCache

+ (id) allocWithZone: (NSZone*)z
{
  NSURLCache	*o = [super allocWithZone: z];
  return o;
}

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

/**
 * request is used as a key. So the hash method and isEqual method must be used. And copy method.
 */
- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request
{
  return [memory objectForKey: request];
}

- (NSUInteger) currentDiskUsage
{
  return diskUsage;
}

- (NSUInteger) currentMemoryUsage
{
  return memoryUsage;
}

- (NSUInteger) diskCapacity
{
  return diskCapacity;
}

- (id) initWithMemoryCapacity: (NSUInteger)memoryCapacity
		 diskCapacity: (NSUInteger)diskCapacity
		     diskPath: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      diskUsage = 0;
      diskCapacity = diskCapacity;
      memoryUsage = 0;
      memoryCapacity = memoryCapacity;
      path = [path copy];
      memory = [NSMutableDictionary new];
    }
  return self;
}

- (NSUInteger) memoryCapacity
{
  return memoryCapacity;
}

- (void) removeAllCachedResponses
{
  // FIXME ... disk storage
  [memory removeAllObjects];
  diskUsage = 0;
  memoryUsage = 0;
}

- (void) removeCachedResponseForRequest: (NSURLRequest *)request
{
  NSCachedURLResponse	*item = [self cachedResponseForRequest: request];

  if (item != nil)
    {
      // FIXME ... disk storage
      memoryUsage -= [[item data] length]; // So memoryUsage is form data length.
      [memory removeObjectForKey: request];
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
// FIXME ... maybe on disk?

      case NSURLCacheStorageAllowedInMemoryOnly:
        {
	  unsigned		size = [[cachedResponse data] length];

	  if (size < memoryCapacity)
	    {
	      NSCachedURLResponse	*old;

	      old = [memory objectForKey: request];
	      if (old != nil)
		{
		  memoryUsage -= [[old data] length];
		  [memory removeObjectForKey: request];
		}
	      while (memoryUsage + size > memoryCapacity)
	        {
// FIXME ... should delete least recently used.
                /**
                 * Here just remove a random one.
                 */
		  [self removeCachedResponseForRequest:
		    [[memory allKeys] lastObject]];
		}
	      [memory setObject: cachedResponse forKey: request];
	      memoryUsage += size;
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

