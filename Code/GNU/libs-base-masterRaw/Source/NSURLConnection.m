#import "common.h"

#define	EXPOSE_NSURLConnection_IVARS	1
#import "Foundation/NSError.h"
#import "Foundation/NSURLError.h"
#import "Foundation/NSRunLoop.h"
#import "GSURLPrivate.h"
#import <Foundation/Foundation.h>

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
        _data = [NSMutableData new];      // Empty data unless we get an error
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

@implementation NSURLConnection (NSURLConnectionSynchronousLoading)

+ (NSData *) sendSynchronousRequest: (NSURLRequest *)request
                  returningResponse: (NSURLResponse **)response
                              error: (NSError **)error
{
    NSData    *data = nil;
    
    if (0 != response)
    {
        *response = nil;
    }
    if (0 != error)
    {
        *error = nil;
    }
    if ([self canHandleRequest: request] == YES)
    {
        _NSURLConnectionDataCollector    *collector;
        NSURLConnection            *conn;
        
        collector = [_NSURLConnectionDataCollector new];
        conn = [[self alloc] initWithRequest: request delegate: collector];
        if (nil != conn)
        {
            NSRunLoop    *loop;
            NSDate    *limit;
            
            [collector setConnection: conn];
            loop = [NSRunLoop currentRunLoop];
            limit = [[NSDate alloc] initWithTimeIntervalSinceNow:
                     [request timeoutInterval]];
            
            //
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
            }
            else
            {
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
    }
    return data;
}

@end



@implementation	NSURLConnection

+ (BOOL) canHandleRequest: (NSURLRequest *)request
{
    return ([NSURLProtocol _classToHandleRequest: request] != nil);
}

- (void) cancel
{
    // 直接, 控制所使用的 protocol, 停止 load.
    [self->_protocol stopLoading];
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
    if ((self = [super init]) != nil)
    {
        self->_request = [request mutableCopyWithZone: [self zone]];
        
        // 如果, request 里面设置了, 想要 cookie 的信息.
        // 那么在发送网络请求之前, 就找 [NSHTTPCookieStorage sharedHTTPCookieStorage] 查找对应的 url 存储的 cookie 值.
        if ([self->_request HTTPShouldHandleCookies] == YES)
        {
            NSArray *cookies;
            
            cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage]
                       cookiesForURL: [self->_request URL]];
            if ([cookies count] > 0)
            {
                NSDictionary	*headers;
                NSEnumerator	*enumerator;
                NSString		*header;
                
                headers = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
                enumerator = [headers keyEnumerator];
                while (nil != (header = [enumerator nextObject]))
                {
                    [self->_request addValue: [headers valueForKey: header]
                          forHTTPHeaderField: header];
                }
            }
        }
        
        // 实际的网络请求, 是交给了 protocol 进行链接,  数据传输.
        self->_delegate = [delegate retain];
        self->_protocol = [[NSURLProtocol alloc]
                           initWithRequest: self->_request
                           cachedResponse: nil
                           client: (id<NSURLProtocolClient>)self];
        [self->_protocol startLoading];
    }
    return self;
}


- (void) URLProtocol: (NSURLProtocol *)protocol
cachedResponseIsValid: (NSCachedURLResponse *)cachedResponse
{
    return;
}

// 把 Protocol 的各种代理方法包装下, 交给上层的代理.
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
        // FIXME ... cache response here?
    }
}

// 发现了重定向, 直接就是开始新的连接了.
- (void) URLProtocol: (NSURLProtocol *)protocol
wasRedirectedToRequest: (NSURLRequest *)request
    redirectResponse: (NSURLResponse *)redirectResponse
{
    request = [self->_delegate connection: self
                          willSendRequest: request
                         redirectResponse: redirectResponse];
    if (self->_protocol == nil)
    {
        if (self->_debug)
        {
            NSLog(@"%@ delegate cancelled request", self);
        }
        /* Our protocol is nil, so we have been cancelled by the delegate.
         */
        return;
    }
    if (request != nil)
    {
        if (self->_debug)
        {
            NSLog(@"%@ delegate allowed redirect to %@", self, request);
        }
        /* Follow the redirect ... stop the old load and start a new one.
         */
        [self->_protocol stopLoading];
        DESTROY(self->_protocol);
        ASSIGNCOPY(self->_request, request);
        self->_protocol = [[NSURLProtocol alloc]
                           initWithRequest: self->_request
                           cachedResponse: nil
                           client: (id<NSURLProtocolClient>)self];
        [self->_protocol startLoading];
    }
    else if (self->_debug)
    {
        NSLog(@"%@ delegate cancelled redirect", self);
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



