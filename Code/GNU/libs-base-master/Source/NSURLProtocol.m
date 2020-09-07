#define	EXPOSE_NSURLProtocol_IVARS	1
#import "Foundation/NSError.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSValue.h"

#import "GSPrivate.h"
#import "GSURLPrivate.h"
#import "GNUstepBase/GSMime.h"
#import "GNUstepBase/GSTLS.h"
#import "GNUstepBase/NSData+GNUstepBase.h"
#import "GNUstepBase/NSStream+GNUstepBase.h"
#import "GNUstepBase/NSString+GNUstepBase.h"
#import "GNUstepBase/NSURL+GNUstepBase.h"


@interface	NSURLProtocol (Debug)
- (NSString*) in;
- (NSString*) out;
@end

@interface	GSSocketStreamPair : NSObject
{
    NSInputStream		*ip;
    NSOutputStream	*op;
    NSHost		*host;
    uint16_t		port;
    NSDate		*expires;
    BOOL			ssl;
}
+ (void) purge: (NSNotification*)n;
- (void) cache: (NSDate*)when;
- (void) close;
- (NSDate*) expires;
- (id) initWithHost: (NSHost*)h port: (uint16_t)p forSSL: (BOOL)s;
- (NSInputStream*) inputStream;
- (NSOutputStream*) outputStream;
@end

@implementation	GSSocketStreamPair

static NSMutableArray	*pairCache = nil;
static NSLock		*pairLock = nil;

+ (void) initialize
{
    if (pairCache == nil)
    {
        /* No use trying to use a dictionary ... NSHost objects all hash
         * to the same value.
         */
        pairCache = [NSMutableArray new];
        [[NSObject leakAt: &pairCache] release];
        pairLock = [NSLock new];
        [[NSObject leakAt: &pairLock] release];
        /*  Purge expired pairs at intervals.
         */
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(purge:)
                                                     name: @"GSHousekeeping" object: nil];
    }
}

+ (void) purge: (NSNotification*)n
{
    NSDate	*now = [NSDate date];
    unsigned	count;
    
    [pairLock lock];
    count = [pairCache count];
    while (count-- > 0)
    {
        GSSocketStreamPair	*p = [pairCache objectAtIndex: count];
        
        if ([[p expires] timeIntervalSinceDate: now] <= 0.0)
        {
            [pairCache removeObjectAtIndex: count];
        }
    }
    [pairLock unlock];
}

- (void) cache: (NSDate*)when
{
    NSTimeInterval	ti = [when timeIntervalSinceNow];
    
    if (ti <= 0.0)
    {
        [self close];
        return;
    }
    NSAssert(ip != nil, NSGenericException);
    if (ti > 120.0)
    {
        ASSIGN(expires, [NSDate dateWithTimeIntervalSinceNow: 120.0]);
    }
    else
    {
        ASSIGN(expires, when);
    }
    [pairLock lock];
    [pairCache addObject: self];
    [pairLock unlock];
}

- (void) close
{
    [ip setDelegate: nil];
    [op setDelegate: nil];
    [ip removeFromRunLoop: [NSRunLoop currentRunLoop]
                  forMode: NSDefaultRunLoopMode];
    [op removeFromRunLoop: [NSRunLoop currentRunLoop]
                  forMode: NSDefaultRunLoopMode];
    [ip close];
    [op close];
    DESTROY(ip);
    DESTROY(op);
}

- (void) dealloc
{
    [self close];
    DESTROY(host);
    DESTROY(expires);
    [super dealloc];
}

- (NSDate*) expires
{
    return expires;
}

- (id) init
{
    DESTROY(self);
    return nil;
}

- (id) initWithHost: (NSHost*)h port: (uint16_t)p forSSL: (BOOL)s;
{
    unsigned		count;
    NSDate		*now;
    
    now = [NSDate date];
    [pairLock lock];
    count = [pairCache count];
    while (count-- > 0)
    {
        GSSocketStreamPair	*pair = [pairCache objectAtIndex: count];
        
        if ([pair->expires timeIntervalSinceDate: now] <= 0.0)
        {
            [pairCache removeObjectAtIndex: count];
        }
        else if (pair->port == p && pair->ssl == s && [pair->host isEqual: h])
        {
            /* Found a match ... remove from cache and return as self.
             */
            DESTROY(self);
            self = [pair retain];
            [pairCache removeObjectAtIndex: count];
            [pairLock unlock];
            return self;
        }
    }
    [pairLock unlock];
    
    if ((self = [super init]) != nil)
    {
        [NSStream getStreamsToHost: host
                              port: port
                       inputStream: &ip
                      outputStream: &op];
        if (ip == nil || op == nil)
        {
            DESTROY(self);
            return nil;
        }
        ssl = s;
        port = p;
        host = [h retain];
        [ip retain];
        [op retain];
        if (ssl == YES)
        {
            [ip setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                     forKey: NSStreamSocketSecurityLevelKey];
            [op setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                     forKey: NSStreamSocketSecurityLevelKey];
        }
    }
    return self;
}

- (NSInputStream*) inputStream
{
    return ip;
}

- (NSOutputStream*) outputStream
{
    return op;
}

@end

@interface _NSAboutURLProtocol : NSURLProtocol
@end

@interface _NSFTPURLProtocol : NSURLProtocol
@end

@interface _NSFileURLProtocol : NSURLProtocol
@end

@interface _NSHTTPURLProtocol : NSURLProtocol
<NSURLAuthenticationChallengeSender>
{
    GSMimeParser		*_parser;	// Parser handling incoming data
    unsigned		_parseOffset;	// Bytes of body loaded in parser.
    float			_version;	// The HTTP version in use.
    int			_statusCode;	// The HTTP status code returned.
    NSInputStream		*_body;		// for sending the body
    unsigned		_writeOffset;	// Request data to write
    NSData		*_writeData;	// Request bytes written so far
    BOOL			_complete;
    BOOL			_debug;
    BOOL			_isLoading;
    BOOL			_shouldClose;
    NSURLAuthenticationChallenge	*_challenge;
    NSURLCredential		*_credential;
    NSHTTPURLResponse		*_response;
}
@end

@interface _NSHTTPSURLProtocol : _NSHTTPURLProtocol
@end

@interface _NSDataURLProtocol : NSURLProtocol
@end


static NSMutableArray	*registered = nil;
static NSLock		*regLock = nil;
static Class		abstractClass = nil;
static Class		placeholderClass = nil;
static NSURLProtocol	*placeholder = nil;

@interface	NSURLProtocolPlaceholder : NSURLProtocol
@end
@implementation	NSURLProtocolPlaceholder
- (void) dealloc
{
    if (self == placeholder)
    {
        [self retain];
        return;
    }
    [super dealloc];
}
@end

/*
 这个也是类簇模式的使用.
 */
@implementation	NSURLProtocol

+ (void) initialize
{
    if (registered == nil)
    {
        abstractClass = [NSURLProtocol class];
        placeholderClass = [NSURLProtocolPlaceholder class];
        placeholder = (NSURLProtocol*)NSAllocateObject(placeholderClass, 0,
                                                       NSDefaultMallocZone());
        registered = [NSMutableArray new];
        regLock = [NSLock new];
        
        /*
         提前把各个 Request 对应的 protocol 类要定义好.
         */
        [self registerClass: [_NSHTTPURLProtocol class]];
        [self registerClass: [_NSHTTPSURLProtocol class]];
        [self registerClass: [_NSFTPURLProtocol class]];
        [self registerClass: [_NSFileURLProtocol class]];
        [self registerClass: [_NSAboutURLProtocol class]];
        [self registerClass: [_NSDataURLProtocol class]];
    }
}

+ (id) propertyForKey: (NSString *)key inRequest: (NSURLRequest *)request
{
    return [request _propertyForKey: key];
}

/*
 Register any custom NSURLProtocol subclasses prior to making URL requests. When the URL loading system begins to load a request, it tries to initialize each registered protocol class with the specified request. The first NSURLProtocol subclass to return YES when sent a canInitWithRequest: message is used to load the request. There is no guarantee that all registered protocol classes will be consulted.
 实际上, request 的网络交互, 是用各自的 protocol 对象进行控制的.
 */
+ (BOOL) registerClass: (Class)protocolClass
{
    if ([protocolClass isSubclassOfClass: [NSURLProtocol class]] == YES)
    {
        [regLock lock];
        [registered addObject: protocolClass];
        [regLock unlock];
        return YES;
    }
    return NO;
}

+ (void) setProperty: (id)value
              forKey: (NSString *)key
           inRequest: (NSMutableURLRequest *)request
{
    [request _setProperty: value forKey: key];
}

+ (void) unregisterClass: (Class)protocolClass
{
    [regLock lock];
    [registered removeObjectIdenticalTo: protocolClass];
    [regLock unlock];
}

- (NSCachedURLResponse *) cachedResponse
{
    return self->cachedResponse;
}

- (id <NSURLProtocolClient>) client
{
    return self->client;
}

- (void) dealloc
{
    [self stopLoading];
    if (self->input != nil)
    {
        [self->input setDelegate: nil];
        [self->output setDelegate: nil];
        [self->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [self->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        [self->input close];
        [self->output close];
        DESTROY(self->input);
        DESTROY(self->output);
        DESTROY(self->in);
        DESTROY(self->out);
    }
    DESTROY(self->cachedResponse);
    DESTROY(self->request);
    DESTROY(self->client);
#if    USE_ZLIB
    if (self->compressing == YES)
    {
        deflateEnd(&self->z);
    }
    else if (self->decompressing == YES)
    {
        inflateEnd(&self->z);
    }
    DESTROY(self->compressed);
    #endif
    [super dealloc];
}


- (id) initWithRequest: (NSURLRequest *)request
        cachedResponse: (NSCachedURLResponse *)cachedResponse
                client: (id <NSURLProtocolClient>)client
{
    Class	c = object_getClass(self);
    
    /*
     类簇模式的实现方法, 首先判断一下, 是不是 placeHolder
     */
    if (c == abstractClass || c == placeholderClass)
    {
        unsigned	count;
        
        DESTROY(self);
        [regLock lock];
        count = [registered count];
        while (count-- > 0)
        {
            Class	proto = [registered objectAtIndex: count];
            
            if ([proto canInitWithRequest: request] == YES)
            {
                self = [proto alloc];
                break;
            }
        }
        [regLock unlock];
        return [self initWithRequest: request
                      cachedResponse: cachedResponse
                              client: client];
    }
    if ((self = [self init]) != nil)
    {
        self->request = [request copy];
        self->cachedResponse = RETAIN(cachedResponse);
        self->client = RETAIN(client);
    }
    return self;
}

- (NSURLRequest *) request
{
    return self->request;
}

@end

@implementation	NSURLProtocol (Debug)
- (NSString*) in
{
    return (self->in);
}
- (NSString*) out
{
    return (self->out);
}
@end

@implementation	NSURLProtocol (Subclassing)

+ (NSURLRequest *) canonicalRequestForRequest: (NSURLRequest *)request
{
    return request;
}

+ (BOOL) requestIsCacheEquivalent: (NSURLRequest *)a
                        toRequest: (NSURLRequest *)b
{
    a = [self canonicalRequestForRequest: a];
    b = [self canonicalRequestForRequest: b];
    return [a isEqual: b];
}

@end



/*
 最最主要的类, HTTP 的网络请求控制.
 */
@implementation _NSHTTPURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"http"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
    return request;
}

- (void) startLoading
{
    static NSDictionary *methods = nil;
    
    if (methods == nil)
    {
        methods = [[NSDictionary alloc] initWithObjectsAndKeys:
                   self, @"HEAD",
                   self, @"GET",
                   self, @"POST",
                   self, @"PUT",
                   self, @"DELETE",
                   self, @"TRACE",
                   self, @"OPTIONS",
                   self, @"CONNECT",
                   nil];
    }
    /*
     错误判断, 一般不会出现这种情况.
     */
    if ([methods objectForKey: [self->request HTTPMethod]] == nil)
    {
        NSLog(@"Invalid HTTP Method: %@", self->request);
        [self stopLoading];
        /*
         外界, 一般仅仅是将错误再向上抛而已.
         */
        [self->client URLProtocol: self
                 didFailWithError:
         [NSError errorWithDomain: @"Invalid HTTP Method"
                             code: 0
                         userInfo: nil]];
        return;
    }
    if (_isLoading == YES)
    {
        return;
    }
    
    _statusCode = 0;	/* No status returned yet.	*/
    _isLoading = YES;
    _complete = NO;
    
    /*
     做一层 URL 错误的容错处理.
     */
    if ([[[self->request URL] fullPath] length] == 0)
    {
        NSString		*s = [[self->request URL] absoluteString];
        NSURL		*url;
        
        if ([s rangeOfString: @"?"].length > 0)
        {
            s = [s stringByReplacingString: @"?" withString: @"/?"];
        }
        else if ([s rangeOfString: @"#"].length > 0)
        {
            s = [s stringByReplacingString: @"#" withString: @"/#"];
        }
        else
        {
            s = [s stringByAppendingString: @"/"];
        }
        url = [NSURL URLWithString: s];
        if (url == nil)
        {
            NSError	*e;
            
            e = [NSError errorWithDomain: @"Invalid redirect request"
                                    code: 0
                                userInfo: nil];
            [self stopLoading];
            [self->client URLProtocol: self
                     didFailWithError: e];
        }
        else
        {
            NSMutableURLRequest	*request;
            
            request = [[self->request mutableCopy] autorelease];
            [request setURL: url];
            [self->client URLProtocol: self
               wasRedirectedToRequest: request
                     redirectResponse: nil];
        }
    }
    
    
    
    NSURL    *url = [self->request URL];
    NSHost    *host = [NSHost hostWithName: [url host]];
    int    port = [[url port] intValue];
    
    _parseOffset = 0;
    DESTROY(_parser);
    
    if (host == nil)
    {
        host = [NSHost hostWithAddress: [url host]];    // try dotted notation
    }
    if (host == nil)
    {
        host = [NSHost hostWithAddress: @"127.0.0.1"];    // final default
    }
    if (port == 0)
    {
        // default if not specified
        port = [[url scheme] isEqualToString: @"https"] ? 443 : 80;
    }
    
    /*
     生成对应的 input, output Socket 网络流链接.
     */
    [NSStream getStreamsToHost: host
                          port: port
                   inputStream: &self->input
                  outputStream: &self->output];
    if (!self->input || !self->output)
    {
        if (_debug == YES)
        {
            NSLog(@"%@ did not create streams for %@:%@",
                  self, host, [url port]);
        }
        [self stopLoading];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys: url, @"NSErrorFailingURLKey", host, @"NSErrorFailingURLStringKey",@"can't find host", @"NSLocalizedDescription", nil];
        [self->client URLProtocol: self
                 didFailWithError:
         [NSError errorWithDomain: @"can't connect"
                             code: 0
                         userInfo:info]];
        return;
    }
    
    [self->input retain];
    [self->output retain];
    
    /*
     如果是 HTTPS 请求, 那么就要在 Socket 链接上, 进行特殊的设置.
     */
    if ([[url scheme] isEqualToString: @"https"] == YES)
    {
        static NSArray        *keys;
        NSUInteger            count;
        
        [self->input setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                          forKey: NSStreamSocketSecurityLevelKey];
        [self->output setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                           forKey: NSStreamSocketSecurityLevelKey];
        if (nil == keys)
        {
            keys = [[NSArray alloc] initWithObjects:
                    GSTLSCAFile,
                    GSTLSCertificateFile,
                    GSTLSCertificateKeyFile,
                    GSTLSCertificateKeyPassword,
                    GSTLSDebug,
                    GSTLSPriority,
                    GSTLSRemoteHosts,
                    GSTLSRevokeFile,
                    GSTLSServerName,
                    GSTLSVerify,
                    nil];
        }
        count = [keys count];
        while (count-- > 0)
        {
            NSString      *key = [keys objectAtIndex: count];
            NSString      *str = [self->request _propertyForKey: key];
            
            if (nil != str)
            {
                [self->output setProperty: str forKey: key];
            }
        }
        /* If there is no value set for the server name, and the host in the
         * URL is a domain name rather than an address, we use that.
         */
        if (nil == [self->output propertyForKey: GSTLSServerName])
        {
            NSString  *host = [url host];
            unichar   c;
            
            c = [host length] == 0 ? 0 : [host characterAtIndex: 0];
            if (c != 0 && c != ':' && !isdigit(c))
            {
                [self->output setProperty: host forKey: GSTLSServerName];
            }
        }
        if (_debug) [self->output setProperty: @"YES" forKey: GSTLSDebug];
    }
    
    [self->input setDelegate: self];
    [self->output setDelegate: self];
    /*
     流, 是和 runloop 相关的一套机制.
     */
    [self->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
                           forMode: NSDefaultRunLoopMode];
    [self->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                            forMode: NSDefaultRunLoopMode];
    [self->input open];
    [self->output open];
}

/*
 stopLoading 除了自己数据的控制外, 更为重要的, 是要把自己占用的 socket 资源释放掉.
 */
- (void) stopLoading
{
    _isLoading = NO;
    DESTROY(_writeData);
    if (self->input != nil)
    {
        [self->input setDelegate: nil];
        [self->output setDelegate: nil];
        [self->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [self->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        [self->input close];
        [self->output close];
        DESTROY(self->input);
        DESTROY(self->output);
    }
}

- (void) _didLoad: (NSData*)d
{
    [self->client URLProtocol: self didLoadData: d];
}

/*
 流获取到数据的回调.
 */
- (void) _got: (NSStream*)stream
{
    unsigned char	buffer[BUFSIZ*64];
    int 		readCount;
    NSError	*e;
    NSData	*bufferData;
    BOOL		wasInHeaders = NO;
    
    readCount = [(NSInputStream *)stream read: buffer
                                    maxLength: sizeof(buffer)];
    if (readCount < 0)
    {
        if ([stream  streamStatus] == NSStreamStatusError)
        {
            e = [stream streamError];
            if (_debug)
            {
                NSLog(@"%@ receive error %@", self, e);
            }
            [self stopLoading];
            [self->client URLProtocol: self didFailWithError: e];
        }
        return;
    }
    
    if (_parser == nil) {
        _parser = [GSMimeParser new];
        [_parser setIsHttp];
    }
    
    wasInHeaders = [_parser isInHeaders];
    bufferData = [NSData dataWithBytes: buffer length: readCount];
    /*
     如果, 解析有问题, 直接报错.
     */
    if ([_parser parse: bufferData] == NO && (_complete = [_parser isComplete]) == NO)
    {
        e = [NSError errorWithDomain: @"parse error"
                                code: 0
                            userInfo: nil];
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError: e];
        return;
    }
    
    
    BOOL        isInHeaders = [_parser isInHeaders];
    GSMimeDocument    *document = [_parser mimeDocument];
    unsigned        bodyLength;
    
    _complete = [_parser isComplete];
    /*
     如果, 之前在 header 里面, 现在不在了, 证明响应头已经完毕了.
     */
    if (YES == wasInHeaders && NO == isInHeaders)
    {
        GSMimeHeader        *info;
        int            bodyLength = -1;
        NSString        *contentType;
        NSString        *contentSubType;
        NSString        *itemValue;
        
        info = [document headerNamed: @"http"];
        
        _version = [[info value] floatValue];
        if (_version < 1.1)
        {
            _shouldClose = YES;
        }
        else if ((itemValue = [[document headerNamed: @"connection"] value]) != nil
                 && [itemValue caseInsensitiveCompare: @"close"] == NSOrderedSame)
        {
            _shouldClose = YES;
        }
        else
        {
            _shouldClose = NO;    // Keep connection alive.
        }
            
        /*
         状态码
         */
        itemValue = [info objectForKey: NSHTTPPropertyStatusCodeKey];
        _statusCode = [itemValue intValue];
        
        /*
         body 长度
         */
        itemValue = [[document headerNamed: @"content-length"] value];
        if ([itemValue length] > 0)
        {
            bodyLength = [itemValue intValue];
        }
        
        itemValue = [info objectForKey: NSHTTPPropertyStatusReasonKey];
        
        info = [document headerNamed: @"content-type"];
        contentType = [document contentType];
        contentSubType = [document contentSubtype];
        if (contentType && contentSubType)
        {
            contentType = [contentType stringByAppendingFormat: @"/%@", contentSubType];
        }
        else
        {
            contentType = nil;
        }
        
        /*
         根据, 已经获取的信息, 创建一个 response 对象出来.
         */
        
        
        _response = [[NSHTTPURLResponse alloc]
                     initWithURL: [self->request URL]
                     MIMEType: contentType
                     expectedContentLength: bodyLength
                     textEncodingName: [info parameterForKey: @"charset"]];
        [_response _setStatusCode: _statusCode text: itemValue];
        [document deleteHeaderNamed: @"http"];
        [_response _setHeaders: [document allHeaders]];
        
        if (_statusCode == 204 || _statusCode == 304)
        {
            _complete = YES;    // No body expected.
        }
        else if (_complete == NO && [bufferData length] == 0) // 没有 body 信息.
        {
            _complete = YES;
        }
        
        if (_statusCode == 401)
        {
            /* This is an authentication challenge, so we keep reading
             * until the challenge is complete, then try to deal with it.
             */
        }
        else if (_statusCode >= 300 && _statusCode < 400) // 重定向信息.
        {
            NSURL    *url;
            
            itemValue = [[document headerNamed: @"location"] value];
            url = [NSURL URLWithString: itemValue];
            
            if (url == nil)
            {
                NSError    *e;
                
                e = [NSError errorWithDomain: @"Invalid redirect request"
                                        code: 0
                                    userInfo: nil];
                [self stopLoading];
                [self->client URLProtocol: self
                         didFailWithError: e];
            }
            else // 重定向, urlConnect 里面, 结束了上一个请求, 并且开启了重定向的新请求.
            {
                NSMutableURLRequest    *request;
                
                request = [[self->request mutableCopy] autorelease];
                [request setURL: url];
                [self->client URLProtocol: self
                   wasRedirectedToRequest: request
                         redirectResponse: _response];
            }
        }
        else
        {
            NSURLCacheStoragePolicy policy;
            
            /*
             进行 cookie 的存储, NSHTTPCookieStorage 进行存储.
             如果想要存储的 cookie 有效, 那么发送网络请求的时候, 一定再去 NSHTTPCookieStorage 进行相对应的读取操作.
             */
            if ([self->request HTTPShouldHandleCookies] == YES
                && [_response isKindOfClass: [NSHTTPURLResponse class]] == YES)
            {
                NSDictionary    *hdrs;
                NSArray    *cookies;
                NSURL        *url;
                
                url = [_response URL];
                hdrs = [_response allHeaderFields];
                cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: hdrs
                                                                 forURL: url];
                [[NSHTTPCookieStorage sharedHTTPCookieStorage]
                 setCookies: cookies
                 forURL: url
                 mainDocumentURL: [self->request mainDocumentURL]];
            }
            
            /* Tell the client that we have a response and how
             * it should be cached.
             */
            policy = [self->request cachePolicy];
            if (policy
                == (NSURLCacheStoragePolicy)NSURLRequestUseProtocolCachePolicy)
            {
                if ([self isKindOfClass: [_NSHTTPSURLProtocol class]] == YES)
                {
                    /* For HTTPS we should not allow caching unless the
                     * request explicitly wants it.
                     */
                    policy = NSURLCacheStorageNotAllowed;
                }
                else
                {
                    /* For HTTP we allow caching unless the request
                     * specifically denies it.
                     */
                    policy = NSURLCacheStorageAllowed;
                }
            }
            /*
             告诉外界, response 已经获取到了.
             */
            [self->client URLProtocol: self
                   didReceiveResponse: _response
                   cacheStoragePolicy: policy];
        }
    }
    
    if (_complete == YES)
    {
        /*
         401 代表, 需要进行验证.
         验证的过程, 没有太看明白.
         */
        if (_statusCode == 401)
        {
            NSURLProtectionSpace    *space;
            NSString            *hdr;
            NSURL            *url;
            int            failures = 0;
            
            /* This was an authentication challenge.
             */
            hdr = [[document headerNamed: @"WWW-Authenticate"] value];
            url = [self->request URL];
            space = [GSHTTPAuthentication
                     protectionSpaceForAuthentication: hdr requestURL: url];
            DESTROY(_credential);
            if (space != nil)
            {
                /* Create credential from user and password
                 * stored in the URL.
                 * Returns nil if we have no username or password.
                 */
                _credential = [[NSURLCredential alloc]
                               initWithUser: [url user]
                               password: [url password]
                               persistence: NSURLCredentialPersistenceForSession];
                if (_credential == nil)
                {
                    /* No credential from the URL, so we try using the
                     * default credential for the protection space.
                     */
                    ASSIGN(_credential,
                           [[NSURLCredentialStorage sharedCredentialStorage]
                            defaultCredentialForProtectionSpace: space]);
                }
            }
            
            if (_challenge != nil)
            {
                /* The failure count is incremented if we have just
                 * tried a request in the same protection space.
                 */
                if (YES == [[_challenge protectionSpace] isEqual: space])
                {
                    failures = [_challenge previousFailureCount] + 1;
                }
            }
            else if ([self->request valueForHTTPHeaderField:@"Authorization"])
            {
                /* Our request had an authorization header, so we should
                 * count that as a failure or we wouldn't have been
                 * challenged.
                 */
                failures = 1;
            }
            DESTROY(_challenge);
            
            /*
             在这里, 构建验证的信息, 交给外界处理.
             */
            _challenge = [[NSURLAuthenticationChallenge alloc]
                          initWithProtectionSpace: space
                          proposedCredential: _credential
                          previousFailureCount: failures
                          failureResponse: _response
                          error: nil
                          sender: self];
            
            /* Allow the client to control the credential we send
             * or whether we actually send at all.
             */
            [self->client URLProtocol: self
    didReceiveAuthenticationChallenge: _challenge];
            
            if (_challenge == nil)
            {
                NSError    *e;
                
                /* The client cancelled the authentication challenge
                 * so we must cancel the download.
                 */
                e = [NSError errorWithDomain: @"Authentication cancelled"
                                        code: 0
                                    userInfo: nil];
                [self stopLoading];
                [self->client URLProtocol: self
                         didFailWithError: e];
            }
            else
            {
                NSString    *auth = nil;
                
                if (_credential != nil)
                {
                    GSHTTPAuthentication    *authentication;
                    
                    /* Get information about basic or
                     * digest authentication.
                     */
                    authentication = [GSHTTPAuthentication
                                      authenticationWithCredential: _credential
                                      inProtectionSpace: space];
                    
                    /* Generate authentication header value for the
                     * authentication type in the challenge.
                     */
                    auth = [authentication
                            authorizationForAuthentication: hdr
                            method: [self->request HTTPMethod]
                            path: [url fullPath]];
                }
                
                if (auth == nil)
                {
                    NSURLCacheStoragePolicy policy;
                    
                    /* We have no authentication credentials so we
                     * treat this as a download of the challenge page.
                     */
                    
                    /* Tell the client that we have a response and how
                     * it should be cached.
                     */
                    policy = [self->request cachePolicy];
                    if (policy == (NSURLCacheStoragePolicy)
                        NSURLRequestUseProtocolCachePolicy)
                    {
                        if ([self isKindOfClass: [_NSHTTPSURLProtocol class]])
                        {
                            /* For HTTPS we should not allow caching unless
                             * the request explicitly wants it.
                             */
                            policy = NSURLCacheStorageNotAllowed;
                        }
                        else
                        {
                            /* For HTTP we allow caching unless the request
                             * specifically denies it.
                             */
                            policy = NSURLCacheStorageAllowed;
                        }
                    }
                    [self->client URLProtocol: self
                           didReceiveResponse: _response
                           cacheStoragePolicy: policy];
                    /* Fall through to code providing page data.
                     */
                }
                else
                {
                    NSMutableURLRequest    *request;
                    
                    /* To answer the authentication challenge,
                     * we must retry with a modified request and
                     * with the cached response cleared.
                     */
                    request = [self->request mutableCopy];
                    [request setValue: auth
                   forHTTPHeaderField: @"Authorization"];
                    [self stopLoading];
                    [self->request release];
                    self->request = request;
                    DESTROY(self->cachedResponse);
                    [self startLoading];
                    return;
                }
            }
        }
        
        [self->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [self->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        if (_shouldClose == YES)
        {
            [self->input setDelegate: nil];
            [self->output setDelegate: nil];
            [self->input close];
            [self->output close];
            DESTROY(self->input);
            DESTROY(self->output);
        }
        
        /*
         * Tell superclass that we have successfully loaded the data
         * (as long as we haven't had the load terminated by the client).
         */
        if (_isLoading == YES)
        {
            bufferData = [_parser data];
            bodyLength = [bufferData length];
            if (bodyLength > _parseOffset)
            {
                if (_parseOffset > 0)
                {
                    bufferData = [bufferData subdataWithRange:
                         NSMakeRange(_parseOffset, bodyLength - _parseOffset)];
                }
                _parseOffset = bodyLength;
                [self _didLoad: bufferData];
            }
            
            /* Check again in case the client cancelled the load inside
             * the URLProtocol:didLoadData: callback.
             */
            if (_isLoading == YES)
            {
                _isLoading = NO;
                [self->client URLProtocolDidFinishLoading: self];
            }
        }
    }
    else if (_isLoading == YES && _statusCode != 401)
    {
        /*
         还在 loading 的过程里面, 把获取到的 body, 不断的抛出去给外界.
         */
        if ([_parser isInBody])
        {
            bufferData = [_parser data];
            bodyLength = [bufferData length];
            if (bodyLength > _parseOffset)
            {
                if (_parseOffset > 0)
                {
                    bufferData = [bufferData subdataWithRange:
                         NSMakeRange(_parseOffset, [bufferData length] - _parseOffset)];
                }
                _parseOffset = bodyLength;
                [self _didLoad: bufferData];
            }
        }
    }
    
    if (_complete == NO && readCount == 0 && _isLoading == YES)
    {
        /* The read failed ... dropped, but parsing is not complete.
         * The request was sent, so we can't know whether it was
         * lost in the network or the remote end received it and
         * the response was lost.
         */
        if (_debug == YES)
        {
            NSLog(@"%@ HTTP response not received - %@", self, _parser);
        }
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError:
         [NSError errorWithDomain: @"receive incomplete"
                             code: 0
                         userInfo: nil]];
    }
}

- (void)output:(NSStream *)stream handleEvent: (NSStreamEvent) event{
    switch (event)
    {
        case NSStreamEventOpenCompleted:
        {
            NSMutableData    *dataM;
            NSDictionary    *fileds;
            NSEnumerator    *e;
            NSString        *urlEsacped;
            NSURL        *url;
            int        l;
            
            if (_debug == YES)
            {
                NSLog(@"%@ HTTP output stream opened", self);
            }
            self->in = [[NSString alloc]
                        initWithFormat: @"(%@:%@ <-- %@:%@)",
                        [stream propertyForKey: GSStreamLocalAddressKey],
                        [stream propertyForKey: GSStreamLocalPortKey],
                        [stream propertyForKey: GSStreamRemoteAddressKey],
                        [stream propertyForKey: GSStreamRemotePortKey]];
            self->out = [[NSString alloc]
                         initWithFormat: @"(%@:%@ --> %@:%@)",
                         [stream propertyForKey: GSStreamLocalAddressKey],
                         [stream propertyForKey: GSStreamLocalPortKey],
                         [stream propertyForKey: GSStreamRemoteAddressKey],
                         [stream propertyForKey: GSStreamRemotePortKey]];
            DESTROY(_writeData);
            _writeOffset = 0;
                
            /*
             将要输出的 HTTP 序列化到 dataM 中.
             注意, HTTP 是可阅读格式, 所以都是文本信息.
             */
            dataM = [[NSMutableData alloc] initWithCapacity: 1024];
            [dataM appendData: [[self->request HTTPMethod]
                            dataUsingEncoding: NSASCIIStringEncoding]];
            [dataM appendBytes: " " length: 1];
            url = [self->request URL];
            urlEsacped = [[url fullPath] stringByAddingPercentEscapesUsingEncoding:
                 NSUTF8StringEncoding];
            if ([urlEsacped hasPrefix: @"/"] == NO)
            {
                [dataM appendBytes: "/" length: 1];
            }
            [dataM appendData: [urlEsacped dataUsingEncoding: NSASCIIStringEncoding]];
            urlEsacped = [url query];
            if ([urlEsacped length] > 0)
            {
                [dataM appendBytes: "?" length: 1];
                [dataM appendData: [urlEsacped dataUsingEncoding: NSASCIIStringEncoding]];
            }
            urlEsacped = [NSString stringWithFormat: @" HTTP/%0.1f\r\n", _version];
            [dataM appendData: [urlEsacped dataUsingEncoding: NSASCIIStringEncoding]];
            
            /*
             request 里面的 HTTPHeaderFiled 仅仅在这里, 得到了使用.
             一个个的添加到 dataM 中去.
             */
            fileds = [self->request allHTTPHeaderFields];
            e = [fileds keyEnumerator];
            while ((urlEsacped = [e nextObject]) != nil)
            {
                GSMimeHeader      *h;
                
                h = [[GSMimeHeader alloc] initWithName: urlEsacped
                                                 value: [fileds objectForKey: urlEsacped]
                                            parameters: nil];
                [dataM appendData: [h rawMimeDataPreservingCase: YES foldedAt: 0]];
                RELEASE(h);
            }
            
            /*
             添加 post 的相关信息.
             */
            if ([[self->request HTTPMethod] isEqual: @"POST"]
                && [self->request valueForHTTPHeaderField:
                    @"Content-Type"] == nil)
            {
                /* On MacOSX, this is automatically added to POST methods */
                static char   *ct
                = "Content-Type: application/x-www-form-urlencoded\r\n";
                [dataM appendBytes: ct length: strlen(ct)];
            }
            
            /*
             添加 Host 的相关信息.
             */
            if ([self->request valueForHTTPHeaderField: @"Host"] == nil)
            {
                NSString      *s = [url scheme];
                id            p = [url port];
                id            h = [url host];
                
                if (h == nil)
                {
                    h = @"";    // Must send an empty host header
                }
                if (([s isEqualToString: @"http"] && [p intValue] == 80)
                    || ([s isEqualToString: @"https"] && [p intValue] == 443))
                {
                    /* Some buggy systems object to the port being in
                     * the Host header when it's the default (optional)
                     * value.
                     * To keep them happy let's omit it in those cases.
                     */
                    p = nil;
                }
                if (nil == p)
                {
                    s = [NSString stringWithFormat: @"Host: %@\r\n", h];
                }
                else
                {
                    s = [NSString stringWithFormat: @"Host: %@:%@\r\n", h, p];
                }
                [dataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
            }
            
            if (l >= 0 && [self->request
                           valueForHTTPHeaderField: @"Content-Length"] == nil)
            {
                urlEsacped = [NSString stringWithFormat: @"Content-Length: %d\r\n", l];
                [dataM appendData: [urlEsacped dataUsingEncoding: NSASCIIStringEncoding]];
            }
            [dataM appendBytes: "\r\n" length: 2];    // End of headers
            _writeData  = dataM;
            
            // 当 Stocket Open 的时候, 做数据的准备工作, 在有空间的时间, 进行发送.
        }            // Fall through to do the write
            
        case NSStreamEventHasSpaceAvailable:
        {
            int    written;
            BOOL    sent = NO;
            
            // FIXME: should also send out relevant Cookies
            if (_writeData != nil)
            {
                const unsigned char    *bytes = [_writeData bytes];
                unsigned        len = [_writeData length];
                
                written = [self->output write: bytes + _writeOffset
                                    maxLength: len - _writeOffset];
                if (written > 0)
                {
                    _writeOffset += written;
                    if (_writeOffset >= len) // 如果当前的 _writeData 写完了, 就该写 body 的信息了.
                    {
                        DESTROY(_writeData);
                        if (_body == nil)
                        {
                            _body = RETAIN([self->request HTTPBodyStream]);
                            if (_body == nil)
                            {
                                NSData    *d = [self->request HTTPBody];
                                
                                if (d != nil)
                                {
                                    _body = [NSInputStream alloc];
                                    _body = [_body initWithData: d];
                                    [_body open];
                                }
                                else
                                {
                                    sent = YES;
                                }
                            }
                        }
                    }
                }
            }
            else if (_body != nil)
            {
                if ([_body hasBytesAvailable])
                {
                    unsigned char    buffer[BUFSIZ*64];
                    int        len;
                    
                    len = [_body read: buffer maxLength: sizeof(buffer)]; // 先读到缓存 buffer 里面,
                    if (len < 0)
                    {
                        if (_debug == YES)
                        {
                            NSLog(@"%@ error reading from HTTPBody stream %@",
                                  self, [NSError _last]);
                        }
                        [self stopLoading];
                        [self->client URLProtocol: self didFailWithError:
                         [NSError errorWithDomain: @"can't read body"
                                             code: 0
                                         userInfo: nil]];
                        return;
                    }
                    else if (len > 0)
                    {
                        written = [self->output write: buffer maxLength: len]; // 然后 outputSocket 再将缓存的信息输出.
                        if (written > 0)
                        {
                            len -= written;
                            if (len > 0)
                            {
                                /* Couldn't write it all now, save and try
                                 * again later.
                                 */
                                _writeData = [[NSData alloc] initWithBytes:
                                              buffer + written length: len];
                                _writeOffset = 0;
                            }
                            else if (len == 0 && ![_body hasBytesAvailable])
                            {
                                /* all _body's bytes are read and written
                                 * so we shouldn't wait for another
                                 * opportunity to close _body and set
                                 * the flag 'sent'.
                                 */
                                [_body close];
                                DESTROY(_body);
                                sent = YES;
                            }
                        }
                        else if ([self->output streamStatus]
                                 == NSStreamStatusWriting)
                        {
                            /* Couldn't write it all now, save and try
                             * again later.
                             */
                            _writeData = [[NSData alloc] initWithBytes:
                                          buffer length: len];
                            _writeOffset = 0;
                        }
                    }
                    else
                    {
                        [_body close];
                        DESTROY(_body);
                        sent = YES;
                    }
                }
                else
                {
                    [_body close];
                    DESTROY(_body);
                    sent = YES;
                }
            }
            if (sent == YES)
            {
                if (_shouldClose == YES)
                {
                    if (_debug)
                    {
                        NSLog(@"%@ request sent ... closing", self);
                    }
                    [self->output setDelegate: nil];
                    [self->output removeFromRunLoop:
                     [NSRunLoop currentRunLoop]
                                            forMode: NSDefaultRunLoopMode];
                    [self->output close];
                    DESTROY(self->output);
                }
                else if (_debug)
                {
                    NSLog(@"%@ request sent", self);
                }
            }
            return;  // done
        }
        default:
            break;
    }
}

- (void) stream: (NSStream*) stream handleEvent: (NSStreamEvent) event
{
    if (stream == self->input)
    {
        switch(event)
        {
            case NSStreamEventHasBytesAvailable:
            case NSStreamEventEndEncountered:
                [self _got: stream];
                return;
                
            case NSStreamEventOpenCompleted:
                if (_debug == YES)
                {
                    NSLog(@"%@ HTTP input stream opened", self);
                }
                return;
                
            default:
                break;
        }
    }
    else if (stream == self->output)
    {
        [self output:stream handleEvent:event];
    }
    
    if (event == NSStreamEventErrorOccurred)
    {
        NSError	*error = [[[stream streamError] retain] autorelease];
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError: error];
    }
}

- (void) useCredential: (NSURLCredential*)credential
forAuthenticationChallenge: (NSURLAuthenticationChallenge*)challenge
{
    if (challenge == _challenge)
    {
        ASSIGN(_credential, credential);
    }
}
@end

/*
 HTTPS 和 HTTP 的功能实现, 完全一致.
 */
@implementation _NSHTTPSURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"https"];
}

@end

@implementation _NSFTPURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"ftp"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
    return request;
}

- (void) startLoading
{
    if (self->cachedResponse)
    { // handle from cache
    }
    else
    {
        NSURL	*url = [self->request URL];
        NSHost	*host = [NSHost hostWithName: [url host]];
        
        if (host == nil)
        {
            host = [NSHost hostWithAddress: [url host]];
        }
        [NSStream getStreamsToHost: host
                              port: [[url port] intValue]
                       inputStream: &self->input
                      outputStream: &self->output];
        if (self->input == nil || self->output == nil)
        {
            [self->client URLProtocol: self didFailWithError:
             [NSError errorWithDomain: @"can't connect"
                                 code: 0
                             userInfo: nil]];
            return;
        }
        [self->input retain];
        [self->output retain];
        if ([[url scheme] isEqualToString: @"https"] == YES)
        {
            [self->input setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                              forKey: NSStreamSocketSecurityLevelKey];
            [self->output setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                               forKey: NSStreamSocketSecurityLevelKey];
        }
        [self->input setDelegate: self];
        [self->output setDelegate: self];
        [self->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [self->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        // set socket options for ftps requests
        [self->input open];
        [self->output open];
    }
}

- (void) stopLoading
{
    if (self->input)
    {
        [self->input setDelegate: nil];
        [self->output setDelegate: nil];
        [self->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [self->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        [self->input close];
        [self->output close];
        DESTROY(self->input);
        DESTROY(self->output);
    }
}

- (void) stream: (NSStream *) stream handleEvent: (NSStreamEvent) event
{
    if (stream == self->input)
    {
        switch(event)
        {
            case NSStreamEventHasBytesAvailable:
            {
                NSLog(@"FTP input stream has bytes available");
                // implement FTP protocol
                //			[self->client URLProtocol: self didLoadData: [NSData dataWithBytes: buffer length: len]];	// notify
                return;
            }
            case NSStreamEventEndEncountered: 	// can this occur in parallel to NSStreamEventHasBytesAvailable???
                NSLog(@"FTP input stream did end");
                [self->client URLProtocolDidFinishLoading: self];
                return;
            case NSStreamEventOpenCompleted:
                // prepare to receive header
                NSLog(@"FTP input stream opened");
                return;
            default:
                break;
        }
    }
    else if (stream == self->output)
    {
        NSLog(@"An event occurred on the output stream.");
        // if successfully opened, send out FTP request header
    }
    else
    {
        NSLog(@"Unexpected event %"PRIuPTR
              " occurred on stream %@ not being used by %@",
              event, stream, self);
    }
    if (event == NSStreamEventErrorOccurred)
    {
        NSLog(@"An error %@ occurred on stream %@ of %@",
              [stream streamError], stream, self);
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError: [stream streamError]];
    }
    else
    {
        NSLog(@"Unexpected event %"PRIuPTR" ignored on stream %@ of %@",
              event, stream, self);
    }
}

@end

@implementation _NSFileURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"file"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
    return request;
}

- (void) startLoading
{
    // check for GET/PUT/DELETE etc so that we can also write to a file
    NSData	*data;
    NSURLResponse	*r;
    
    /*
     这里比较粗暴, 直接就是 File 的全部读取.
     */
    data = [NSData dataWithContentsOfFile: [[self->request URL] path]];
    if (data == nil)
    {
        [self->client URLProtocol: self didFailWithError:
         [NSError errorWithDomain: @"can't load file" code: 0 userInfo:
          [NSDictionary dictionaryWithObjectsAndKeys:
           [self->request URL], @"URL",
           [[self->request URL] path], @"path",
           nil]]];
        return;
    }
    
    /* FIXME ... maybe should infer MIME type and encoding from extension or BOM
     */
    r = [[NSURLResponse alloc] initWithURL: [self->request URL]
                                  MIMEType: @"text/html"
                     expectedContentLength: [data length]
                          textEncodingName: @"unknown"];
    [self->client URLProtocol: self
           didReceiveResponse: r
           cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [self->client URLProtocol: self didLoadData: data];
    [self->client URLProtocolDidFinishLoading: self];
    RELEASE(r);
}

- (void) stopLoading
{
    return;
}

@end

@implementation _NSDataURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"data"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
    return request;
}

- (void) startLoading
{
    NSURLResponse *r;
    NSString      *mime = @"text/plain";
    NSString      *encoding = @"US-ASCII";
    NSData        *data;
    NSString      *spec = [[self->request URL] resourceSpecifier];
    NSRange       comma = [spec rangeOfString:@","];
    NSEnumerator  *types;
    NSString      *type;
    BOOL          base64 = NO;
    
    if (comma.location == NSNotFound)
    {
        NSDictionary      *ui;
        NSError           *error;
        
        ui = [NSDictionary dictionaryWithObjectsAndKeys:
              [self->request URL], @"URL",
              [[self->request URL] path], @"path",
              nil];
        error = [NSError errorWithDomain: @"can't load data"
                                    code: 0
                                userInfo: ui];
        [self->client URLProtocol: self didFailWithError: error];
        return;
    }
    types = [[[spec substringToIndex: comma.location]
              componentsSeparatedByString: @";"] objectEnumerator];
    while (nil != (type = [types nextObject]))
    {
        if ([type isEqualToString: @"base64"])
        {
            base64 = YES;
        }
        else if ([type hasPrefix: @"charset="])
        {
            encoding = [type substringFromIndex: 8];
        }
        else if ([type length] > 0)
        {
            mime = type;
        }
    }
    spec = [spec substringFromIndex: comma.location + 1];
    if (YES == base64)
    {
        data = [GSMimeDocument decodeBase64:
                [spec dataUsingEncoding: NSUTF8StringEncoding]];
    }
    else
    {
        data = [[spec stringByReplacingPercentEscapesUsingEncoding:
                 NSUTF8StringEncoding] dataUsingEncoding: NSUTF8StringEncoding];
    }
    r = [[NSURLResponse alloc] initWithURL: [self->request URL]
                                  MIMEType: mime
                     expectedContentLength: [data length]
                          textEncodingName: encoding];
    /*
     这里, response, 和 data 的顺序不能变, 虽然都是同步操作.
     */
    [self->client URLProtocol: self
           didReceiveResponse: r
           cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [self->client URLProtocol: self didLoadData: data];
    [self->client URLProtocolDidFinishLoading: self];
    RELEASE(r);
}

- (void) stopLoading
{
    return;
}

@end

@implementation _NSAboutURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"about"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
    return request;
}

- (void) startLoading
{
    NSURLResponse	*r;
    NSData	*data = [NSData data];	// no data
    
    // we could pass different content depending on the url path
    r = [[NSURLResponse alloc] initWithURL: [self->request URL]
                                  MIMEType: @"text/html"
                     expectedContentLength: 0
                          textEncodingName: @"utf-8"];
    [self->client URLProtocol: self
           didReceiveResponse: r
           cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [self->client URLProtocol: self didLoadData: data];
    [self->client URLProtocolDidFinishLoading: self];
    RELEASE(r);
}

- (void) stopLoading
{
    return;
}

@end
