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

@implementation _NSURLConnectionDataCollector  // 牛逼!!!!!!!!!!!

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

typedef struct
{
    NSMutableURLRequest		*_request;
    NSURLProtocol			*_protocol; // 真正的网络交互的操作, 完全交给了 NSURLProtocol, NSURLConnection 仅仅是一个包装类.
    id				_delegate;
    BOOL				_debug;
} Internal;

#define	this	((Internal*)(self->_NSURLConnectionInternal))
#define	inst	((Internal*)(o->_NSURLConnectionInternal))

@implementation	NSURLConnection

+ (id) allocWithZone: (NSZone*)z
{
    NSURLConnection	*o = [super allocWithZone: z];
    
    if (o != nil)
    {
        o->_NSURLConnectionInternal = NSZoneCalloc([self zone],
                                                   1, sizeof(Internal));
    }
    return o;
}

+ (BOOL) canHandleRequest: (NSURLRequest *)request
{
    return ([NSURLProtocol _classToHandleRequest: request] != nil); // 直接询问, NSURLProtocol.
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
    [this->_protocol stopLoading];
    DESTROY(this->_protocol);
    DESTROY(this->_delegate);
}

- (void) dealloc
{
    if (this != 0)
    {
        [self cancel]; // 主要是调用 protocol 停止 loading.
        DESTROY(this->_request);
        DESTROY(this->_delegate);
        NSZoneFree([self zone], this);
        _NSURLConnectionInternal = 0;
    }
    [super dealloc];
}

- (void) finalize
{
    if (this != 0)
    {
        [self cancel];
    }
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
    if ((self = [super init]) != nil)
    {
        this->_request = [request mutableCopyWithZone: [self zone]]; // 首先, request 进行了 copy, copy 的作用在于, 在后续的操作的时候, 不会收到影响.
        
        /* Enrich the request with the appropriate HTTP cookies,
         * if desired.
         */
        if ([this->_request HTTPShouldHandleCookies] == YES) // 如果, 原来的 request 里面设置了要包含 cookie 的东西, 就在这里加上 cookie 的内容, 到 request 的 http Header 里面.
            // 我们之前一直说, request 是一个数据类, 那么这个数据类里面, 设置了我们需要 HTTPShouldHandleCookies, 那么现在在这里, 如果request 里面设置了需要cookie, 就把这些信息, 放到 httpHeader 中.
            // 而什么时候会设置cookie 的内容呢, 要在 NSURLProtocol 里面, 在判断, request 中需要 cookie 的时候, 直接将值设置到了 HTTPShouldHandleCookies 中去了.
        {
            NSArray *cookies;
            
            cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage]
                       cookiesForURL: [this->_request URL]];
            if ([cookies count] > 0)
            {
                NSDictionary	*headers;
                NSEnumerator	*enumerator;
                NSString		*header;
                
                headers = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
                enumerator = [headers keyEnumerator];
                while (nil != (header = [enumerator nextObject]))
                {
                    [this->_request addValue: [headers valueForKey: header]
                          forHTTPHeaderField: header];
                }
            }
        }
        
        /* According to bug #35686, Cocoa has a bizarre deviation from the
         * convention that delegates are retained here.
         * For compatibility we retain the delegate and release it again
         * when the operation is over.
         */
        this->_delegate = [delegate retain]; // 在这个类的内部, 应该有对于 delegate 的解引用操作
        this->_protocol = [[NSURLProtocol alloc] // 在初始化的时候, 定义了一个新的 NSURLProtocol
                           initWithRequest: this->_request
                           cachedResponse: nil
                           client: (id<NSURLProtocolClient>)self];
        [this->_protocol startLoading];
        this->_debug = GSDebugSet(@"NSURLConnection");
    }
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


/*
 现在 NSSesstion 里面, didReceiveAuthenticationChallenge 提供了一个闭包, 不过逻辑是一样的.
 如果在 web端, 收到一个 basic 之后, 是会弹出一个账号密码的输入框, 然后用户输入账号密码之后点击确认, 浏览器会重发之前的请求, 并且在请求头里面, 添加用户密码的信息(base64). 这件事不用 web 开发人员进行设置, 而是浏览器自己执行的. 也就是浏览器自己封装了将数据密码添加到协议头中重发的这套逻辑了.
 那么在 iOS 中, 这套逻辑就变成了, 在NSURLS ession 里面, 生成一个新的 crendial, 这个 credential 里面包含了账号和密码, 交到闭包里面, 在闭包里面, 还是上面的那一套逻辑, 将这些内容封装到协议头里面, 然后发送.
 这就是类库的作用, 也就是虽然知道了最底层的 http 的机制, 但是不同的类库有着自己的实现逻辑. 这是需要再次学习的.
 */
- (void) connection: (NSURLConnection *)connection
didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
    if ([challenge proposedCredential] == nil
        || [challenge previousFailureCount] > 0)
    {
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
             redirectResponse: (NSURLResponse *)response // responsse 为返回值, 它的里面应该提供了上面 request 的信息.
{
    return request; // 这里, 仅仅是简单的返回重定向的 request, 也就是说, 我们可以根据参数值, 改变新的 request 的配置. 当然, 这是NSObject 的默认实现.
}// 这个是NSO bject 的非正式协议, 也就是说, 如果自己写一个 delegate 的话, 没有实现的方法, 也就这样实现了.

@end



@implementation NSURLConnection (NSURLConnectionSynchronousLoading)

// A synchronous load is
+ (NSData *) sendSynchronousRequest: (NSURLRequest *)request
                  returningResponse: (NSURLResponse **)response
                              error: (NSError **)error
{
    NSData	*data = nil;
    
    if (0 != response)
    {
        *response = nil; // 首先, 设置为 nil 了, 这样好不好???
    }
    if (0 != error)
    {
        *error = nil; // 首先, 设置为 nil 了, 这样好不好???
    }
    if ([self canHandleRequest: request] == YES)
    {
        _NSURLConnectionDataCollector	*collector;
        NSURLConnection			*conn;
        
        collector = [_NSURLConnectionDataCollector new];
        conn = [[self alloc] initWithRequest: request delegate: collector]; // 这里, 建立了一个 connection
        if (nil != conn)
        {
            NSRunLoop	*loop;
            NSDate	*limit;
            
            [collector setConnection: conn];
            loop = [NSRunLoop currentRunLoop];
            limit = [[NSDate alloc] initWithTimeIntervalSinceNow:
                     [request timeoutInterval]];
            
            while ([collector done] == NO && [limit timeIntervalSinceNow] > 0.0) // while 作为 runloop run 的控制条件, 里面的是一次次的执行 runloop 的 runmode 方法. 这个方法, 只会 run 一次.
            {// Runs the loop once, blocking for input in the specified mode until a given date.
                // 这样, 这个 runloop 一定可以执行, 因为 connection, 其实是添加到 runloop 的 input 源里面去了. 太厉害了.
                [loop runMode: NSDefaultRunLoopMode beforeDate: limit]; // 还能这样同步, 太牛了.
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


@implementation	NSURLConnection (URLProtocolClient)

// NSURLConnection 的功能, 完全是代理的 NSProtocol 的代理方法

- (void) URLProtocol: (NSURLProtocol *)protocol
cachedResponseIsValid: (NSCachedURLResponse *)cachedResponse
{
    return;
}

- (void) URLProtocol: (NSURLProtocol *)protocol
    didFailWithError: (NSError *)error
{
    id    connectionDelegate = this->_delegate;
    this->_delegate = nil;
    [connectionDelegate connection: self didFailWithError: error]; // 在 Protocol 中发生了问题, 然后通过 connection 知会connection 的代理.
    DESTROY(connectionDelegate);
}

- (void) URLProtocol: (NSURLProtocol *)protocol
         didLoadData: (NSData *)data
{
    [this->_delegate connection: self didReceiveData: data]; // socket 在到达了 body 的时候, 会到这里来.
}

- (void) URLProtocol: (NSURLProtocol *)protocol
didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
    [this->_delegate connection: self
didReceiveAuthenticationChallenge: challenge];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveResponse: (NSURLResponse *)response
  cacheStoragePolicy: (NSURLCacheStoragePolicy)policy // 这里, iOS 的后面的版本, 其实是去除了 policy 了, 其实在NSURLC onnectionDataDelegate 里面, 是没有 policy 这个参数的.
{
    [this->_delegate connection: self didReceiveResponse: response]; // protocol 的头信息解析完之后, 会到这里来.
    if (policy == NSURLCacheStorageAllowed
        || policy == NSURLCacheStorageAllowedInMemoryOnly)
    {
    }
}

- (void) URLProtocol: (NSURLProtocol *)protocol
wasRedirectedToRequest: (NSURLRequest *)newRequest
    redirectResponse: (NSURLResponse *)redirectResponse // protocol 的重定向消息会到达这里.
{
    if (this->_debug)
    {
        NSLog(@"%@ tell delegate %@ about redirect to %@ as a result of %@",
              self, this->_delegate, newRequest, redirectResponse);
    }
    newRequest = [this->_delegate connection: self
                             willSendRequest: newRequest
                            redirectResponse: redirectResponse];
    if (this->_protocol == nil)
    {
        if (this->_debug)
        {
            NSLog(@"%@ delegate cancelled request", self);
        }
        /* Our protocol is nil, so we have been cancelled by the delegate.
         */
        return;
    }
    if (newRequest != nil)
    {
        if (this->_debug)
        {
            NSLog(@"%@ delegate allowed redirect to %@", self, newRequest);
        }
        /* Follow the redirect ... stop the old load and start a new one.
         */
        [this->_protocol stopLoading]; // 这里, 先停止之前的 loading, 然后开始新的 request loading
        DESTROY(this->_protocol);
        ASSIGNCOPY(this->_request, newRequest);
        this->_protocol = [[NSURLProtocol alloc]
                           initWithRequest: this->_request
                           cachedResponse: nil
                           client: (id<NSURLProtocolClient>)self];
        [this->_protocol startLoading];
    }
    else if (this->_debug)
    {
        NSLog(@"%@ delegate cancelled redirect", self);
    }
}

- (void) URLProtocolDidFinishLoading: (NSURLProtocol *)protocol // protocol 在解析完成之后.
{
    id    o = this->_delegate;
    
    this->_delegate = nil;
    [o connectionDidFinishLoading: self];
    DESTROY(o);
}

- (void) URLProtocol: (NSURLProtocol *)protocol
didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
    [this->_delegate connection: self
didCancelAuthenticationChallenge: challenge];
}

@end

