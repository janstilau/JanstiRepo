#import "common.h"

#define	EXPOSE_NSURLConnection_IVARS	1
#import "Foundation/NSError.h"
#import "Foundation/NSURLError.h"
#import "Foundation/NSRunLoop.h"
#import "GSURLPrivate.h"

@interface _NSURLConnectionDataCollector : NSObject
{
    NSURLConnection	*_connection;	// Not retained
    NSMutableData		*_data;
    NSError		*_error;
    NSURLResponse		*_response;
    BOOL			_done;
}

- (NSData*) data;
- (BOOL) done;
- (NSError*) error;
- (NSURLResponse*) response;
- (void) setConnection: (NSURLConnection *)c;

@end


// 一个简单的实现了 Connection 代理的一个类, 就是为了处理简单的网络交互.
@implementation _NSURLConnectionDataCollector

- (void) dealloc
{
    [_data release];
    [_error release];
    [_response release];
    [super dealloc];
}

- (BOOL) done
{
    return _done;
}

- (NSData*) data
{
    return _data;
}

- (id) init
{
    if (nil != (self = [super init]))
    {
        _data = [[NSMutableData alloc] init];      // Empty data unless we get an error
    }
    return self;
}

- (NSError*) error
{
    return _error;
}

- (NSURLResponse*) response
{
    return _response;
}

- (void) setConnection: (NSURLConnection*)c
{
    _connection = c;	// Not retained ... the connection retains us
}

- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error
{
    ASSIGN(_error, error);
    DESTROY(_data);       // On error, we make the data nil
    _done = YES;
}

- (void) connection: (NSURLConnection *)connection
 didReceiveResponse: (NSURLResponse*)response
{
    ASSIGN(_response, response);
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
    _done = YES;
}

- (void) connection: (NSURLConnection *)connection
     didReceiveData: (NSData *)data
{
    [_data appendData: data];
}

@end

@implementation	NSURLConnection

/*
 
 HTTP 的交互逻辑是一致的, 所以, URLConnection 和 Session, 还是要复用这块的逻辑. 也就是在 HTTPProtocol 里面的逻辑. 所以, 每一次网络请求, 其实是 HTTPProtocol 在处理数据的交互.
 URLConnection 和 Session 更多的是一个组织者, 在 HTTPProtocol 的上层, 做一些数据的组织.
 比如, 一个下载任务, 会是创建一个缓存文件, 然后不断地将 data 填充到这个缓存文件中. 这个过程, 如果直接在 HTTPProtocol 上交互, 会变得及其复杂. 所以, 会专门有 downloadTask 的概念产生.
 */


// 这里, 直接代理给了 NSURLProtocol 对象.
+ (BOOL) canHandleRequest: (NSURLRequest *)request
{
    return ([NSURLProtocol _classToHandleRequest: request] != nil);
}

+ (NSURLConnection *) connectionWithRequest: (NSURLRequest *)request
                                   delegate: (id)delegate
{
    NSURLConnection	*o = [self alloc];
    o = [o initWithRequest: request delegate: delegate];
    return AUTORELEASE(o);
}

- (void) cancel
{
    [self->_protocol stopLoading];
    DESTROY(self->_protocol);
    DESTROY(self->_delegate);
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
    if ((self = [super init]) == nil) { return nil; }
    
    self->_request = [request mutableCopyWithZone: [self zone]];
    if ([self->_request HTTPShouldHandleCookies] == YES)
    {
        NSArray *cookies;
        cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage]
                   cookiesForURL: [self->_request URL]];
        if ([cookies count] > 0)
        {
            NSDictionary    *headers;
            NSEnumerator    *enumerator;
            NSString        *header;
            
            headers = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
            enumerator = [headers keyEnumerator];
            while (nil != (header = [enumerator nextObject]))
            {
                [self->_request addValue: [headers valueForKey: header]
                      forHTTPHeaderField: header];
            }
        }
    }
    
    /* According to bug #35686, Cocoa has a bizarre deviation from the
     * convention that delegates are retained here.
     * For compatibility we retain the delegate and release it again
     * when the operation is over.
     */
    self->_delegate = [delegate retain];
    // 创建真正的网络交互的对象.
    self->_protocol = [[NSURLProtocol alloc]
                       initWithRequest: self->_request
                       cachedResponse: nil
                       client: (id<NSURLProtocolClient>)self];
    [self->_protocol startLoading];
    return self;
}

@end


@implementation NSObject (NSURLConnectionDelegate)

- (void) connection: (NSURLConnection *)connection
didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
    return;
}

- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error
{
    return;
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
    return;
}

- (void) connection: (NSURLConnection *)connection
didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
    if ([challenge proposedCredential] == nil
        || [challenge previousFailureCount] > 0)
    {
        /* continue without a credential if there is no proposed credential
         * at all or if an authentication failure has already happened.
         */
        [[challenge sender]
         continueWithoutCredentialForAuthenticationChallenge: challenge];
    }
}

- (void) connection: (NSURLConnection *)connection
     didReceiveData: (NSData *)data
{
    return;
}

- (void) connection: (NSURLConnection *)connection
 didReceiveResponse: (NSURLResponse *)response
{
    return;
}

- (NSCachedURLResponse *) connection: (NSURLConnection *)connection
                   willCacheResponse: (NSCachedURLResponse *)cachedResponse
{
    return cachedResponse;
}

- (NSURLRequest *) connection: (NSURLConnection *)connection
              willSendRequest: (NSURLRequest *)request
             redirectResponse: (NSURLResponse *)response
{
    return request;
}

@end



@implementation NSURLConnection (NSURLConnectionSynchronousLoading)

+ (NSData *) sendSynchronousRequest: (NSURLRequest *)request
                  returningResponse: (NSURLResponse **)response
                              error: (NSError **)error
{
    NSData	*data = nil;
    
    // 对于这种传出参数, 应该在函数的开始, 进行归零处理. 否则, 不能很好的体现这个函数里面对于传出参数的影响.
    if (0 != response)
    {
        *response = nil;
    }
    if (0 != error)
    {
        *error = nil;
    }
    if ([self canHandleRequest: request] != YES) { return data; }
    
    _NSURLConnectionDataCollector    *collector = [_NSURLConnectionDataCollector new];
    NSURLConnection *conn = [[self alloc] initWithRequest: request delegate: collector];
    if (nil != conn)
    {
        NSRunLoop    *loop;
        NSDate    *limit;
        
        [collector setConnection: conn];
        loop = [NSRunLoop currentRunLoop];
        
        // 这里, 专门创建一个 runloop 来进行信息的收集工作.
        // 有了 runloop, 这块代码就会一直卡在这里, 所以内存分配方面的考虑也不用了.
        while ([collector done] == NO && [limit timeIntervalSinceNow] > 0.0)
        {
            [loop runMode: NSDefaultRunLoopMode beforeDate: limit];
        }
        [limit release];
        if (NO == [collector done])
        {
            data = nil;
            if (0 != response)
            {
                *response = nil;
            }
            if (0 != error)
            {
                *error = [NSError errorWithDomain: NSURLErrorDomain
                                             code: NSURLErrorTimedOut
                                         userInfo: nil];
            }
        } else {
            data = [[[collector data] retain] autorelease];
            if (0 != response)
            {
                *response = [[[collector response] retain] autorelease];
            }
            if (0 != error)
            {
                *error = [[[collector error] retain] autorelease];
            }
        }
        [conn release];
    }
    [collector release];
    
    return data;
}

@end


@implementation	NSURLConnection (URLProtocolClient)

// connection 对于 protocol 的代理处理, 基本就是将处理转移到了外界. 可以在这里, 根据当前的任务类型, 做一些管理工作.
- (void) URLProtocol: (NSURLProtocol *)protocol
cachedResponseIsValid: (NSCachedURLResponse *)cachedResponse
{
    return;
}

- (void) URLProtocol: (NSURLProtocol *)protocol
    didFailWithError: (NSError *)error
{
    id    o = self->_delegate;
    
    self->_delegate = nil;
    [o connection: self didFailWithError: error];
    DESTROY(o);
}

- (void) URLProtocol: (NSURLProtocol *)protocol
         didLoadData: (NSData *)data
{
    [self->_delegate connection: self didReceiveData: data];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
    [self->_delegate connection: self
didReceiveAuthenticationChallenge: challenge];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveResponse: (NSURLResponse *)response
  cacheStoragePolicy: (NSURLCacheStoragePolicy)policy
{
    [self->_delegate connection: self didReceiveResponse: response];
    if (policy == NSURLCacheStorageAllowed
        || policy == NSURLCacheStorageAllowedInMemoryOnly)
    {
        
    }
}

// 如果需要重定向, 这里是直接创建一下新的加载过程, 放弃之前的加载. 这也应该是浏览器的默认实现.
- (void) URLProtocol: (NSURLProtocol *)protocol
wasRedirectedToRequest: (NSURLRequest *)request
    redirectResponse: (NSURLResponse *)redirectResponse
{
    request = [self->_delegate connection: self
                          willSendRequest: request
                         redirectResponse: redirectResponse];
    if (request != nil)
    {
        [self->_protocol stopLoading];
        DESTROY(self->_protocol);
        ASSIGNCOPY(self->_request, request);
        self->_protocol = [[NSURLProtocol alloc]
                           initWithRequest: self->_request
                           cachedResponse: nil
                           client: (id<NSURLProtocolClient>)self];
        [self->_protocol startLoading];
    }
}

- (void) URLProtocolDidFinishLoading: (NSURLProtocol *)protocol
{
    id    o = self->_delegate;
    
    self->_delegate = nil;
    [o connectionDidFinishLoading: self];
    DESTROY(o);
}

- (void) URLProtocol: (NSURLProtocol *)protocol
didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
    [self->_delegate connection: self
didCancelAuthenticationChallenge: challenge];
}

@end

