#import "common.h"
#define	EXPOSE_NSCachedURLResponse_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSCoder.h"

// Internal data storage
typedef struct {
  NSData			*data;
  NSURLResponse			*response;
  NSDictionary			*userInfo;
  NSURLCacheStoragePolicy	storagePolicy;
} Internal;
 
#define	this	((Internal*)(self->_NSCachedURLResponseInternal))


// 这真的是一个纯纯的数据类, 一点逻辑都没写在这个类里面.
@implementation	NSCachedURLResponse

+ (id) allocWithZone: (NSZone*)z
{
  NSCachedURLResponse	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSCachedURLResponseInternal = NSZoneMalloc(z, sizeof(Internal));
      memset(o->_NSCachedURLResponseInternal, '\0', sizeof(Internal));
    }
  return o;
}

- (id) copyWithZone: (NSZone*)z
{
  NSCachedURLResponse	*o;

  if (NSShouldRetainWithZone(self, z) == YES)
    {
      o = RETAIN(self);
    }
  else
    {
      o = [[self class] allocWithZone: z];
      o = [o initWithResponse: [self response]
			 data: [self data]
		     userInfo: [self userInfo]
		storagePolicy: [self storagePolicy]];
    }
  return o;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->data);
      RELEASE(this->response);
      RELEASE(this->userInfo);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSData *) data
{
  return this->data;
}

- (id) initWithResponse: (NSURLResponse *)response data: (NSData *)data
{
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
      ASSIGNCOPY(this->data, data);
      ASSIGNCOPY(this->response, response);
      ASSIGNCOPY(this->userInfo, userInfo);
      this->storagePolicy = storagePolicy;
    }
  return self;
}

- (NSURLResponse *) response
{
  return this->response;
}

- (NSURLCacheStoragePolicy) storagePolicy
{
  return this->storagePolicy;
}

- (NSDictionary *) userInfo
{
  return this->userInfo;
}

@end

