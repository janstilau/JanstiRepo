#import "common.h"
#define	EXPOSE_NSCachedURLResponse_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSCoder.h"

// Internal data storage
typedef struct {
    NSData			*data; // 响应数据
    NSURLResponse			*response; // 响应头数据
    NSDictionary			*userInfo; // 自定义的一些信息.
    NSURLCacheStoragePolicy	storagePolicy;
} Internal;

#define	this	((Internal*)(self->_NSCachedURLResponseInternal))


@implementation	NSCachedURLResponse

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

