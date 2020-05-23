#import "common.h"
#define	EXPOSE_NSCachedURLResponse_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSCoder.h"

// 这真的是一个纯纯的数据类, 一点逻辑都没写在这个类里面.
@implementation	NSCachedURLResponse

- (NSData *) data
{
  return self->data;
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

