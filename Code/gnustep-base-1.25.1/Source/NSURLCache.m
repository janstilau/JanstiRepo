#import "common.h"

#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"

// FIXME ... locking and disk storage needed
typedef struct {
  unsigned		diskCapacity;
  unsigned		memoryCapacity;
  unsigned		diskUsage;
  unsigned		memoryUsage;
  NSString		*path;
  NSMutableDictionary	*memory;
} Internal;
 
#define	this	((Internal*)(self->_NSURLCacheInternal))
#define	inst	((Internal*)(o->_NSURLCacheInternal))


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
  if (this != 0)
    {
      RELEASE(this->memory);
      RELEASE(this->path);
      NSZoneFree([self zone], this);
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
  // FIXME ... disk storage
  [this->memory removeAllObjects];
  this->diskUsage = 0;
  this->memoryUsage = 0;
}

- (void) removeCachedResponseForRequest: (NSURLRequest *)request
{
  NSCachedURLResponse	*item = [self cachedResponseForRequest: request];

  if (item != nil)
    {
      // FIXME ... disk storage
      this->memoryUsage -= [[item data] length];
      [this->memory removeObjectForKey: request];
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

