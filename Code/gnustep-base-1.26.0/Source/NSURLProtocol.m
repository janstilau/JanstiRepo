#import "common.h"

#define	EXPOSE_NSURLProtocol_IVARS	1
#import "Foundation/NSError.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSValue.h"

#import "GSPrivate.h"
#import "GSTLS.h"
#import "GSURLPrivate.h"
#import "GNUstepBase/GSMime.h"
#import "GNUstepBase/NSData+GNUstepBase.h"
#import "GNUstepBase/NSStream+GNUstepBase.h"
#import "GNUstepBase/NSString+GNUstepBase.h"
#import "GNUstepBase/NSURL+GNUstepBase.h"

#include	<zlib.h>

static void*
zalloc(void *opaque, unsigned nitems, unsigned size)
{
    return calloc(nitems, size);
}
static void
zfree(void *opaque, void *mem)
{
    free(mem);
}


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
- (oneway void) release
{
    return;
}
@end

@implementation	NSURLProtocol

+ (void) initialize
{
    if (registered == nil)
    {
        abstractClass = [NSURLProtocol class];
        placeholderClass = [NSURLProtocolPlaceholder class];
        placeholder = (NSURLProtocol*)NSAllocateObject(placeholderClass, 0,
                                                       NSDefaultMallocZone());
        [[NSObject leakAt: &placeholder] release];
        registered = [NSMutableArray new];
        [[NSObject leakAt: &registered] release];
        regLock = [NSLock new];
        [[NSObject leakAt: &regLock] release];
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

+ (BOOL) registerClass: (Class)protocolClass //
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

- (NSString*) description
{
    return [NSString stringWithFormat:@"%@ %@",
            [super description], self ? (id)self->request : nil];
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
    }
    return self;
}

- (id) initWithRequest: (NSURLRequest *)request
        cachedResponse: (NSCachedURLResponse *)cachedResponse
                client: (id <NSURLProtocolClient>)client
{
    Class	c = object_getClass(self);
    
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
                self = [proto alloc]; // 在这里挑选, 生成对应 url 的 protocol
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
        self->client = client;	// Not retained
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
    return (self) ? (self->in) : nil;
}
- (NSString*) out
{
    return (self) ? (self->out) : nil;
}
@end

@implementation	NSURLProtocol (Subclassing)

+ (BOOL) requestIsCacheEquivalent: (NSURLRequest *)a
                        toRequest: (NSURLRequest *)b
{
    a = [self canonicalRequestForRequest: a];
    b = [self canonicalRequestForRequest: b];
    return [a isEqual: b];
}

- (void) startLoading
{
    [self subclassResponsibility: _cmd];
}

- (void) stopLoading
{
    [self subclassResponsibility: _cmd];
}

@end


@implementation _NSHTTPURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"http"]; // 如果, 是一个 http 的请求, 就生成 HTTP 的 protocol
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
    return request;
}

- (void) cancelAuthenticationChallenge: (NSURLAuthenticationChallenge*)c
{
    if (c == _challenge)
    {
        DESTROY(_challenge);	// We should cancel the download
    }
}

- (void) continueWithoutCredentialForAuthenticationChallenge:
(NSURLAuthenticationChallenge*)c
{
    if (c == _challenge)
    {
        DESTROY(_credential);	// We download the challenge page
    }
}

- (void) dealloc
{
    [_parser release];			// received headers
    [_body release];			// for sending the body
    [_response release];
    [_credential release];
    [super dealloc];
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
    // 如果, 参数有问题, 直接不开始.
    if ([methods objectForKey: [self->request HTTPMethod]] == nil)
    {
        NSLog(@"Invalid HTTP Method: %@", self->request);
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError:
         [NSError errorWithDomain: @"Invalid HTTP Method"
                             code: 0
                         userInfo: nil]];
        return;
    }
    if (_isLoading == YES)
    {
        NSLog(@"startLoading when load in progress");
        return;
    }
    
    _statusCode = 0;	/* No status returned yet.	*/
    _isLoading = YES;
    _complete = NO;
    
    /* Perform a redirect if the path is empty.
     * As per MacOs-X documentation.
     */
    if ([[[self->request URL] fullPath] length] == 0)
    {
        NSString		*urlPath = [[self->request URL] absoluteString];
        NSURL		*url;
        
        if ([urlPath rangeOfString: @"?"].length > 0)
        {
            urlPath = [urlPath stringByReplacingString: @"?" withString: @"/?"];
        }
        else if ([urlPath rangeOfString: @"#"].length > 0)
        {
            urlPath = [urlPath stringByReplacingString: @"#" withString: @"/#"];
        }
        else
        {
            urlPath = [urlPath stringByAppendingString: @"/"];
        }
        url = [NSURL URLWithString: urlPath];
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
        if (NO == _isLoading)
        {
            return;	// Loading cancelled
        }
        if (nil != self->input)
        {
            return;	// Following redirection
        }
        // Fall through to continue original connect.
    }
    // 前面应该是一个错误处理机制, 到底为什么会出现这个错误没有深究.
    NSURL    *url = [self->request URL];
    NSHost    *host = [NSHost hostWithName: [url host]];
    int    port = [[url port] intValue];
    _parseOffset = 0;

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

        port = [[url scheme] isEqualToString: @"https"] ? 443 : 80;
    }

    // 这里, 初始化了 input , 和 output stream. 根据实现我们知道 是 GSInetInputStream, GSInetOutPutStream
    [NSStream getStreamsToHost: host
                      port: port
               inputStream: &self->input
              outputStream: &self->output];
    if (!self->input || !self->output)
    {
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError:
             [NSError errorWithDomain: @"can't connect" code: 0 userInfo:
              [NSDictionary dictionaryWithObjectsAndKeys:
               url, @"NSErrorFailingURLKey",
               host, @"NSErrorFailingURLStringKey",
               @"can't find host", @"NSLocalizedDescription",
               nil]]
         ];
        return;
    }
    [self->input retain];
    [self->output retain];
    if ([[url scheme] isEqualToString: @"https"] == YES) // 如果是 HTTPS, 仅仅是为 Stream 设置了一些特殊的属性.
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
    }
    // 设置 socket 的回调, 添加到 runloop 中, 开启 sorcketStream
    [self->input setDelegate: self];
    [self->output setDelegate: self];
    [self->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
                       forMode: NSDefaultRunLoopMode];
    [self->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                        forMode: NSDefaultRunLoopMode];
    [self->input open];
    [self->output open];
}

- (void) stopLoading
{
    if (_debug == YES)
    {
        NSLog(@"%@ stopLoading", self);
    }
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

// 这里, 获取到了 dataBody 里面的数据, 该怎么处理, 应该交给 外界.
- (void) _didLoad: (NSData*)d
{
    [self->client URLProtocol: self didLoadData: d];
}

- (void) gotDataFromServer: (NSStream*)stream
{
    unsigned char	buffer[BUFSIZ*64];
    int 		readCount;
    NSError	*error;
    NSData	*data;
    BOOL		wasInHeaders = NO;
    
    readCount = [(NSInputStream *)stream read: buffer
                                    maxLength: sizeof(buffer)];
    if (readCount < 0) // 发生了错误, 通知给外界.
    {
        if ([stream  streamStatus] == NSStreamStatusError)
        {
            error = [stream streamError];
            if (_debug)
            {
                NSLog(@"%@ receive error %@", self, error);
            }
            [self stopLoading];
            [self->client URLProtocol: self didFailWithError: error];
        }
        return;
    }
    if (_parser == nil)
    {
        _parser = [GSMimeParser new]; // 这个类实在太大, 不做分析了.
        [_parser setIsHttp];
    }
    wasInHeaders = [_parser isInHeaders];
    data = [NSData dataWithBytes: buffer length: readCount];
    if ([_parser parse: data] == NO && (_complete = [_parser isComplete]) == NO) // 如果, 解析过程出现了问题, 直接报错.
    {
        if (_debug == YES)
        {
            NSLog(@"%@ HTTP parse failure - %@", self, _parser);
        }
        error = [NSError errorWithDomain: @"parse error"
                                code: 0
                            userInfo: nil];
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError: error];
        return;
    }



        BOOL        isInHeaders = [_parser isInHeaders];
        GSMimeDocument    *document = [_parser mimeDocument];
        unsigned        bodyLength;

        _complete = [_parser isComplete];
        if (YES == wasInHeaders && NO == isInHeaders) // Response 完成了, 开始接受 data 的数据, 要把 response 返回出去.
        {
           GSMimeHeader        *info;
           int            contentLength = -1;
           NSString        *contentType;
           NSString        *contentSubType;
           NSString        *responseValue;
           
           info = [document headerNamed: @"http"];
           
           _version = [[info value] floatValue];
           responseValue = [info objectForKey: NSHTTPPropertyStatusCodeKey];
           _statusCode = [responseValue intValue]; // 状态码
           
           responseValue = [[document headerNamed: @"content-length"] value];
           if ([responseValue length] > 0)
           {
               contentLength = [responseValue intValue];
           }
           
           responseValue = [info objectForKey: NSHTTPPropertyStatusReasonKey];
           
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
            // 构建 response 对象.
           _response = [[NSHTTPURLResponse alloc]
                        initWithURL: [self->request URL]
                        MIMEType: contentType
                        expectedContentLength: contentLength
                        textEncodingName: [info parameterForKey: @"charset"]];
           [_response _setStatusCode: _statusCode text: responseValue];
           [document deleteHeaderNamed: @"http"];
           [_response _setHeaders: [document allHeaders]];
           
           if (_statusCode == 204 || _statusCode == 304) // 没有 body 数据
           {
               _complete = YES;    // No body expected.
           }
           else if (_complete == NO && [data length] == 0) // data 没有值.
           {
               _complete = YES;    // Had EOF ... terminate
           }
           
           if (_statusCode == 401) // 需要验证.
           {
               /* This is an authentication challenge, so we keep reading
                * until the challenge is complete, then try to deal with it.
                */
           }
           else if (_statusCode >= 300 && _statusCode < 400) // 重定向.
           {
               NSURL    *url;
               
               responseValue = [[document headerNamed: @"location"] value]; // 取得重定向的地址.
               url = [NSURL URLWithString: responseValue];
               
               if (url == nil)
               {
                   NSError    *e;
                   
                   e = [NSError errorWithDomain: @"Invalid redirect request"
                                           code: 0
                                       userInfo: nil];
                   [self stopLoading];
                   [self->client URLProtocol: self
                            didFailWithError: e]; // 重定向地址有问题.
               }
               else
               {
                   NSMutableURLRequest    *request;
                   request = [[self->request mutableCopy] autorelease];
                   [request setURL: url]; // 通知外界重定向. connection 的做法是, 取消当前的请求, 然后按照重定向的 request 发送新的请求.
                   [self->client URLProtocol: self
                      wasRedirectedToRequest: request
                            redirectResponse: _response];
               }
           }
           else // 其他的 response, 做一些默认的操作.
           {
               NSURLCacheStoragePolicy policy;
               
               /* Get cookies from the response and accept them into
                * shared storage if policy permits
                */
               if ([self->request HTTPShouldHandleCookies] == YES &&
                   [_response isKindOfClass: [NSHTTPURLResponse class]] == YES) // 在这里, 做了存储 cookie 值的机制.
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
               [self->client URLProtocol: self
                      didReceiveResponse: _response
                      cacheStoragePolicy: policy]; // 通知外界,  需不需要进行存储工作.
           }
        }

        if (_complete == YES) // 没有 data 数据.
        {
           if (_statusCode == 401) // 需要验证. 稍后再看.
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
                        didReceiveAuthenticationChallenge: _challenge]; // Connection 的默认处理是直接抛给它的代理.
               
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
               data = [_parser data];
               bodyLength = [data length];
               if (bodyLength > _parseOffset)
               {
                   if (_parseOffset > 0)
                   {
                       data = [data subdataWithRange:
                            NSMakeRange(_parseOffset, bodyLength - _parseOffset)];
                   }
                   _parseOffset = bodyLength;
                   [self _didLoad: data];
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
            * Report partial data if possible.
            */
           if ([_parser isInBody])
           {
               data = [_parser data];
               bodyLength = [data length];
               if (bodyLength > _parseOffset)
               {
                   if (_parseOffset > 0)
                   {
                       data = [data subdataWithRange:
                            NSMakeRange(_parseOffset, [data length] - _parseOffset)];
                   }
                   _parseOffset = bodyLength;
                   [self _didLoad: data];
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

// 这里能够调用过来, 是 stream 在 runloop 的回调了进行了分发.
- (void) stream: (NSStream*) stream handleEvent: (NSStreamEvent) event
{
    if (stream == self->input)
    {
        switch(event)
        {
            case NSStreamEventHasBytesAvailable:
            case NSStreamEventEndEncountered:
                [self gotDataFromServer: stream];
                return;
            default:
                break;
        }
    } else if (stream == self->output)
    {
        switch (event)// 所以, HTTP 请求, 就是按照 Http 的格式, 向Socket 的服务器端, 发送组织好的数据结构而已.
        {
            case NSStreamEventOpenCompleted:
                [self constructRequestHeader];
            case NSStreamEventHasSpaceAvailable:
                [self sendBody];
                return;
            default:
                break;
        }
    }
    if (event == NSStreamEventErrorOccurred)
    {
        NSError	*error = [[[stream streamError] retain] autorelease];
        
        [self stopLoading];
        [self->client URLProtocol: self didFailWithError: error];
    }
}

- (void)constructRequestHeader {
    NSStream *stream = self->output;
    NSMutableData    *outputDataM;
    NSDictionary    *d;
    NSEnumerator    *e;
    NSString        *urlPath;
    NSURL        *url;
    int        requestLength;
    
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
    _writeOffset = 0;
    if ([self->request HTTPBodyStream] == nil)
    {
        // Not streaming
        requestLength = [[self->request HTTPBody] length];
        _version = 1.1;
    } else
    {
        // Stream and close
        requestLength = -1;
        _version = 1.0;
        _shouldClose = YES;
    }
    
    outputDataM = [[NSMutableData alloc] initWithCapacity: 1024];
    
    /* The request line is of the form:
     * method /path?query HTTP/version
     * where the query part may be missing
     */
    [outputDataM appendData: [[self->request HTTPMethod]
                    dataUsingEncoding: NSASCIIStringEncoding]];
    [outputDataM appendBytes: " " length: 1];
    // Http 就是拥有固定格式的一套协议, 所以, 这里必须完全按照协议来
    url = [self->request URL];
    urlPath = [[url fullPath] stringByAddingPercentEscapesUsingEncoding:
         NSUTF8StringEncoding];
    if ([urlPath hasPrefix: @"/"] == NO)
    {
        [outputDataM appendBytes: "/" length: 1];
    }
    [outputDataM appendData: [urlPath dataUsingEncoding: NSASCIIStringEncoding]];
    // Http 就是拥有固定格式的一套协议, 所以, 这里必须完全按照协议来
    urlPath = [url query];
    if ([urlPath length] > 0)
    {
        [outputDataM appendBytes: "?" length: 1];
        [outputDataM appendData: [urlPath dataUsingEncoding: NSASCIIStringEncoding]];
        // Http 就是拥有固定格式的一套协议, 所以, 这里必须完全按照协议来
    }
    
    urlPath = [NSString stringWithFormat: @" HTTP/%0.1f\r\n", _version];
    [outputDataM appendData: [urlPath dataUsingEncoding: NSASCIIStringEncoding]];
    // Http 就是拥有固定格式的一套协议, 所以, 这里必须完全按照协议来
    
    d = [self->request allHTTPHeaderFields];
    e = [d keyEnumerator];
    while ((urlPath = [e nextObject]) != nil)
    {
        GSMimeHeader      *h;
        
        h = [[GSMimeHeader alloc] initWithName: urlPath
                                         value: [d objectForKey: urlPath]
                                    parameters: nil];
        [outputDataM appendData:
         [h rawMimeDataPreservingCase: YES foldedAt: 0]];
        // Http 就是拥有固定格式的一套协议, 所以, 这里必须完全按照协议来
    }
    
    /* Use valueForHTTPHeaderField: to check for content-type
     * header as that does a case insensitive comparison and
     * we therefore won't end up adding a second header by
     * accident because the two header names differ in case.
     */
    if ([[self->request HTTPMethod] isEqual: @"POST"]
        && [self->request valueForHTTPHeaderField:
            @"Content-Type"] == nil)
    {
        // 如果是 Post, 又没有指定 data 的 type, 就指定表格.
        static char   *ct
        = "Content-Type: application/x-www-form-urlencoded\r\n";
        [outputDataM appendBytes: ct length: strlen(ct)];
    }
    if (requestLength >= 0 &&
        [self->request valueForHTTPHeaderField: @"Content-Length"] == nil)
    {
        urlPath = [NSString stringWithFormat: @"Content-Length: %d\r\n", requestLength];
        [outputDataM appendData: [urlPath dataUsingEncoding: NSASCIIStringEncoding]];
        // 指定内容大小.
    }
    [outputDataM appendBytes: "\r\n" length: 2];    // End of headers
    // 到这里, header 算是完成了.
    _writeData  = outputDataM;
}

- (void)sendBody {
    NSStream *stream = self->output;
    int    written;
    BOOL    sent = NO;
    
    if (_writeData != nil)
    {
        const unsigned char    *bytes = [_writeData bytes];
        unsigned        len = [_writeData length];
        
        written = [self->output write: bytes + _writeOffset
                            maxLength: len - _writeOffset];
        if (written > 0)
        {
            _writeOffset += written; // 更新偏移量.
            if (_writeOffset >= len) // 如果, _writeData 写完了.  开始写 body 的数据
            {
                DESTROY(_writeData);
                if (_body == nil)
                {
                    _body = RETAIN([self->request HTTPBodyStream]);
                     [_body open];
                }
            }
        }
    } else if (_body != nil) {
        if ([_body hasBytesAvailable])
        {
            unsigned char    buffer[BUFSIZ*64];
            int        len;
            
            len = [_body read: buffer maxLength: sizeof(buffer)]; // 先从 body 读取数据出来, 才能发送出去.
            if (len < 0) // 读取失败了.
            {
                [self stopLoading];
                [self->client URLProtocol: self didFailWithError:
                 [NSError errorWithDomain: @"can't read body"
                                     code: 0
                                 userInfo: nil]];
                return;
            }
            else if (len > 0)
            {
                written = [self->output write: buffer maxLength: len]; //从读取出来的数据中, 发送数据给 output stream
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
                    else if (len == 0 && ![_body hasBytesAvailable]) // body 都读取完了.
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
                } else if ([self->output streamStatus]
                         == NSStreamStatusWriting) {
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
        else // body 也写完了, 该结束发送请求了.
        {
            [_body close];
            DESTROY(_body);
            sent = YES;
        }
    }
    if (sent == YES)
    {
        if (_shouldClose == YES) // 发送请求结束, 下面就是 input 等待接受了.
        {
            [self->output setDelegate: nil];
            [self->output removeFromRunLoop:
             [NSRunLoop currentRunLoop]
                                    forMode: NSDefaultRunLoopMode];
            [self->output close];
            DESTROY(self->output);
        }
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
    
    data = [NSData dataWithContentsOfFile: [[self->request URL] path]
            /* options: error: - don't use that because it is based on self */];
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
