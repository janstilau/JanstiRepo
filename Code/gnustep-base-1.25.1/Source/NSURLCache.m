#import "common.h"

#define	EXPOSE_NSURLCache_IVARS	1
#import "GSURLPrivate.h"

typedef struct {
  unsigned		diskCapacity;
  unsigned		memoryCapacity;
  unsigned		diskUsage;
  unsigned		memoryUsage;
  NSString		*path;
  NSMutableDictionary	*memory;
} Internal; // 我其实不太明白, 为什么这些数据类都要整一个 interval 的一个东西出来. 直接定义成为属性不好吗.
 
#define	this	((Internal*)(self->_NSURLCacheInternal))


/*
For convenience, NSURLSessionConfiguration has a property called requestCachePolicy;
 all requests created from sessions that use this configuration inherit their cache policy from the configuration.
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
  return [this->memory objectForKey: request]; // 其实就是一个字典.
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
      // FIXME ... disk storage
      this->memoryUsage -= [[item data] length]; // 减去所占空间
      [this->memory removeObjectForKey: request]; // 减去这个实例.
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
	  if (size < this->memoryCapacity)
	    {
	      NSCachedURLResponse	*old;
	      old = [this->memory objectForKey: request];
	      if (old != nil)
		{
		  this->memoryUsage -= [[old data] length];
		  [this->memory removeObjectForKey: request]; // 删除原来的值.
		}
	      while (this->memoryUsage + size > this->memoryCapacity)
	        {
		  [self removeCachedResponseForRequest:
		    [[this->memory allKeys] lastObject]]; // 如果满了. 那么随便删一个值. 因为 NSDictionary 里面其实是无序的 key 的排列.
		}
	      [this->memory setObject: cachedResponse forKey: request];
	      this->memoryUsage += size;
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

