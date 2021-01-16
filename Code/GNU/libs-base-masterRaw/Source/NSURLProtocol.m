#import "common.h"

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

/* Define to 1 for experimental (net yet working) compression support
 */
#ifdef	USE_ZLIB
# undef	USE_ZLIB
#endif
#define	USE_ZLIB	0


#if	USE_ZLIB
#if	defined(HAVE_ZLIB_H)
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
#else
# undef	USE_ZLIB
# define	USE_ZLIB	0
#endif
#endif


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


// Internal data storage
typedef struct {
    NSInputStream			*input;
    NSOutputStream		*output;
    NSCachedURLResponse		*cachedResponse;
    id <NSURLProtocolClient>	client;
    NSURLRequest			*request;
    NSString                      *in;
    NSString                      *out;
#if	USE_ZLIB
    z_stream			z;		// context for decompress
    BOOL				compressing;	// are we compressing?
    BOOL				decompressing;	// are we decompressing?
    NSData			*compressed;	// only partially decompressed
#endif
} Internal;

#define	this	((Internal*)(self->_NSURLProtocolInternal))
#define	inst	((Internal*)(o->_NSURLProtocolInternal))

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
    /* In a multi-threaded environment we could have two threads release the
     * class at the same time ... causing -dealloc to be called twice at the
     * same time, so that we can get an exception as we try to decrement the
     * retain count beyond zero.  To avoid this we make the placeholder be a
     * subclass whose -retain method prevents us even calling -dealoc in any
     * normal circumstances.
     */
    return;
}
@end

@implementation	NSURLProtocol

// 类簇模式的实现.
+ (id) allocWithZone: (NSZone*)z
{
    NSURLProtocol	*o;
    
    if ((self == abstractClass) && (z == 0 || z == NSDefaultMallocZone()))
    {
        /* Return a default placeholder instance to avoid the overhead of
         * creating and destroying instances of the abstract class.
         */
        o = placeholder;
    }
    else
    {
        /* Create and return an instance of the concrete subclass.
         */
        o = (NSURLProtocol*)NSAllocateObject(self, 0, z);
    }
    return o;
}

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
        
        // 默认, 就这么多的 Protocol .
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

//Register any custom NSURLProtocol subclasses prior to making URL requests. When the URL loading system begins to load a request, it tries to initialize each registered protocol class with the specified request. The first NSURLProtocol subclass to return YES when sent a canInitWithRequest: message is used to load the request. There is no guarantee that all registered protocol classes will be consulted.
// 真正的网络请求, 是通过 NSProtocol 这个类完成的.
// 也就是说, 真正的 http 的 socket 通信, 是在这里完成的.
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

// 直接存到了 Request 里面.
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
    return this->cachedResponse;
}

- (id<NSURLProtocolClient>) client
{
    return this->client;
}

- (void) dealloc
{
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        Class	c = object_getClass(self);
        
        if (c != abstractClass && c != placeholderClass)
        {
            _NSURLProtocolInternal = NSZoneCalloc([self zone],
                                                  1, sizeof(Internal));
        }
    }
    return self;
}

- (id) initWithRequest: (NSURLRequest *)request
        cachedResponse: (NSCachedURLResponse *)cachedResponse
                client: (id <NSURLProtocolClient>)client
{
    Class	c = object_getClass(self);
    
    // 如果是占位符号.
    if (c == abstractClass || c == placeholderClass)
    {
        unsigned	count;
        
        DESTROY(self);
        [regLock lock]
        [regLock unlock];;
        count = [registered count];
        // 通过问询的方式, 生成最终可以处理该 request 的 protoco, 然后返回.
        while (count-- > 0)
        {
            Class	proto = [registered objectAtIndex: count];
            
            if ([proto canInitWithRequest: request] == YES)
            {
                self = [proto alloc];
                break;
            }
        }
        return [self initWithRequest: request
                      cachedResponse: cachedResponse
                              client: client];
    }
    
    if ((self = [self init]) != nil)
    {
        this->request = [request copy];
        this->cachedResponse = RETAIN(cachedResponse);
        this->client = RETAIN(client);
    }
    return self;
}

- (NSURLRequest *) request
{
    return this->request;
}

@end

@implementation	NSURLProtocol (Debug)
- (NSString*) in
{
    return (this) ? (this->in) : nil;
}
- (NSString*) out
{
    return (this) ? (this->out) : nil;
}
@end

@implementation	NSURLProtocol (Private)

+ (Class) _classToHandleRequest:(NSURLRequest *)request
{
    Class protoClass = nil;
    int count;
    [regLock lock];
    
    count = [registered count];
    while (count-- > 0)
    {
        Class	proto = [registered objectAtIndex: count];
        
        if ([proto canInitWithRequest: request] == YES)
        {
            protoClass = proto;
            break;
        }
    }
    [regLock unlock];
    return protoClass;
}

@end

@implementation	NSURLProtocol (Subclassing)

@end



@implementation _NSHTTPURLProtocol
// HTTP Protocol 的实现方式, 很复杂. 有着完整的 socket 解析的流程.
// 只能是 Http 开头的, 才可以.
+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"http"];
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

// 开始请求, 就是创建 SOCKET 链接.
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
    if ([methods objectForKey: [this->request HTTPMethod]] == nil)
    {
        // 如果, 是非法的请求, 直接通知外界.
        [self stopLoading];
        [this->client URLProtocol: self didFailWithError:
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
    if ([[[this->request URL] fullPath] length] == 0)
    {
        NSString		*s = [[this->request URL] absoluteString];
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
            // 如果路径确实不对, 直接通知上层报错.
            NSError	*e;
            
            e = [NSError errorWithDomain: @"Invalid redirect request"
                                    code: 0
                                userInfo: nil];
            [self stopLoading];
            [this->client URLProtocol: self
                     didFailWithError: e];
        }
        else
        {   // 路径修复了, 通知上层 URL Connection 的处理是停止当前 loading, 然后重新开启一个 protocol 进行 loading
            NSMutableURLRequest    *request = [[this->request mutableCopy] autorelease];
            [request setURL: url];
            [this->client URLProtocol: self
               wasRedirectedToRequest: request
                     redirectResponse: nil];
        }
        
        // 如果路径不对, 上层一般会结束任务 StopLoading, 那么 loading 自然是 NO
        // 如果通知了上层重定位, 上层会做一系列的处理, 如果没有调用 stop, 就是 protocol 还可以处理任务, 才会继续执行.
        if (NO == _isLoading)
        {
            return;	// Loading cancelled
        }
        if (nil != this->input)
        {
            return;	// Following redirection
        }
        // Fall through to continue original connect.
    }
    [self openSocket];
}

- (void)openSocket
{
    NSURL    *url = [this->request URL];
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
    // 在这里, 初始化了 接受 socket 和 输出 socket.
    [NSStream getStreamsToHost: host
                          port: port
                   inputStream: &this->input
                  outputStream: &this->output];
    // 如果, 开启 socket 失败了, 直接通知上层.
    // 一般情况下, 是不会失败的. 因为这其实是一个本地的过程, 这个时候 socket 还没有进行连接, 仅仅是填充数据而已.
    // 下面, 一个根本没有的 url, 报错也是域名有问题, 而不是 socket 创建失败.
    /*
     Error Domain=NSURLErrorDomain Code=-1001 "The request timed out." UserInfo={_kCFStreamErrorCodeKey=-2102, NSUnderlyingError=0x60000000c690 {Error Domain=kCFErrorDomainCFNetwork Code=-1001 "(null)" UserInfo={_kCFStreamErrorCodeKey=-2102, _kCFStreamErrorDomainKey=4}}, _NSURLErrorFailingURLSessionTaskErrorKey=LocalDataTask <90A5B3D5-3260-461D-B571-72EC4A35F668>.<1>, _NSURLErrorRelatedURLSessionTaskErrorKey=(
         "LocalDataTask <90A5B3D5-3260-461D-B571-72EC4A35F668>.<1>"
     ), NSLocalizedDescription=The request timed out., NSErrorFailingURLStringKey=https://heheda.com/, NSErrorFailingURLKey=https://heheda.com/, _kCFStreamErrorDomainKey=4}
     */
    if (!this->input || !this->output)
    {
        [self stopLoading];
        [this->client URLProtocol: self didFailWithError:
         [NSError errorWithDomain: @"can't connect" code: 0 userInfo:
          [NSDictionary dictionaryWithObjectsAndKeys:
           url, @"NSErrorFailingURLKey",
           host, @"NSErrorFailingURLStringKey",
           @"can't find host", @"NSLocalizedDescription",
           nil]]];
        return;
    }
    // 如果是 https, 有特殊的安全配置.
    //
    if ([[url scheme] isEqualToString: @"https"] == YES)
    {
        static NSArray        *keys;
        NSUInteger            count;
        
        [this->input setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                          forKey: NSStreamSocketSecurityLevelKey];
        [this->output setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
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
            NSString      *str = [this->request _propertyForKey: key];
            
            if (nil != str)
            {
                [this->output setProperty: str forKey: key];
            }
        }
        /* If there is no value set for the server name, and the host in the
         * URL is a domain name rather than an address, we use that.
         */
        if (nil == [this->output propertyForKey: GSTLSServerName])
        {
            NSString  *host = [url host];
            unichar   c;
            
            c = [host length] == 0 ? 0 : [host characterAtIndex: 0];
        }
    }
    // socket 设置代理, 添加到 runloop, 然后开始运行.
    [this->input setDelegate: self];
    [this->output setDelegate: self];
    [this->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
                           forMode: NSDefaultRunLoopMode];
    [this->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                            forMode: NSDefaultRunLoopMode];
    [this->input open];
    [this->output open];
}

- (void) stopLoading
{
    _isLoading = NO;
    // 主要是 Socket 的关闭处理.
    if (this->input != nil)
    {
        [this->input setDelegate: nil];
        [this->output setDelegate: nil];
        [this->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [this->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        [this->input close];
        [this->output close];
    }
}

- (void) _didLoad: (NSData*)d
{
    [this->client URLProtocol: self didLoadData: d];
}

// input socket 的接受过程, 其实就是 Response 的解析的过程.
- (void) inputStreamDidGot: (NSStream*)stream
{
    unsigned char	buffer[BUFSIZ*64];
    int 		readCount;
    NSError	*e;
    NSData	*data;
    BOOL		wasInHeaders = NO;
    
    readCount = [(NSInputStream *)stream read: buffer
                                    maxLength: sizeof(buffer)];
    if (readCount < 0)
    {
        // 如果, socket 读取发生了问题, 直接报错结束网络交互.
        if ([stream  streamStatus] == NSStreamStatusError)
        {
            e = [stream streamError];
            [self stopLoading];
            [this->client URLProtocol: self didFailWithError: e];
        }
        return;
    }
    
    if (_parser == nil)
    {
        _parser = [GSMimeParser new];
        [_parser setIsHttp];
    }
    wasInHeaders = [_parser isInHeaders];
    data = [NSData dataWithBytes: buffer length: readCount];
    if ([_parser parse: data] == NO && (_complete = [_parser isComplete]) == NO)
    {
        // 如果, 解析失败了, 直接报错, 停止网络交互
        e = [NSError errorWithDomain: @"parse error"
                                code: 0
                            userInfo: nil];
        [self stopLoading];
        [this->client URLProtocol: self didFailWithError: e];
        return;
    }
    else
    {
        BOOL		isInHeaders = [_parser isInHeaders];
        GSMimeDocument	*document = [_parser mimeDocument];
        unsigned		bodyLength;
        _complete = [_parser isComplete];
        
        // 这里, 就是判断出, 头信息接收完了, 可以建立 response 了.
        if (YES == wasInHeaders && NO == isInHeaders)
        {
            GSMimeHeader		*info;
            int			len = -1;
            NSString		*ct;
            NSString		*st;
            NSString		*s;
            
            info = [document headerNamed: @"http"];
            
            // 这里, 就是 http 协议里面, 1.1 之后 Http 可以保持长链接的原因所在. 在这里进行了判断.
            _version = [[info value] floatValue];
            if (_version < 1.1)
            {
                _shouldClose = YES;
            }
            else if ((s = [[document headerNamed: @"connection"] value]) != nil
                     && [s caseInsensitiveCompare: @"close"] == NSOrderedSame)
            {
                _shouldClose = YES;
            }
            else
            {
                _shouldClose = NO;	// Keep connection alive.
            }
            
            s = [info objectForKey: NSHTTPPropertyStatusCodeKey];
            _statusCode = [s intValue];
            
            s = [[document headerNamed: @"content-length"] value];
            if ([s length] > 0)
            {
                len = [s intValue];
            }
            
            s = [info objectForKey: NSHTTPPropertyStatusReasonKey];
            info = [document headerNamed: @"content-type"];
            ct = [document contentType];
            st = [document contentSubtype];
            if (ct && st)
            {
                ct = [ct stringByAppendingFormat: @"/%@", st];
            }
            else
            {
                ct = nil;
            }
            // 上面各种值的赋值, 都是确定 Http 相应需要的各种信息.
            _response = [[NSHTTPURLResponse alloc]
                         initWithURL: [this->request URL]
                         MIMEType: ct
                         expectedContentLength: len
                         textEncodingName: [info parameterForKey: @"charset"]];
            [_response _setStatusCode: _statusCode text: s];
            [document deleteHeaderNamed: @"http"];
            [_response _setHeaders: [document allHeaders]];
            
            if (_statusCode == 204 || _statusCode == 304)
            {
                _complete = YES;	// No body expected.
            }
            else if (_complete == NO && [data length] == 0)
            {
                _complete = YES;	// Had EOF ... terminate
            }
            
            if (_statusCode == 401)
            {
            }
            else if (_statusCode >= 300 && _statusCode < 400)
            { // 这里进行重定向操作.
                NSURL	*url;
                
                NS_DURING
                s = [[document headerNamed: @"location"] value];
                url = [NSURL URLWithString: s];
                NS_HANDLER
                url = nil;
                NS_ENDHANDLER
                
                if (url == nil)
                {
                    NSError	*e;
                    
                    e = [NSError errorWithDomain: @"Invalid redirect request"
                                            code: 0
                                        userInfo: nil];
                    [self stopLoading];
                    [this->client URLProtocol: self
                             didFailWithError: e];
                }
                else
                {
                    // 在这里, 抽取出重定向的地址, 交给上层 client 决定. Connection 里面, 是直接结束本次请求, 然后进行重定向的请求.
                    NSMutableURLRequest	*request;
                    request = [[this->request mutableCopy] autorelease];
                    [request setURL: url];
                    [this->client URLProtocol: self
                       wasRedirectedToRequest: request
                             redirectResponse: _response];
                }
            }
            else
            {
                NSURLCacheStoragePolicy policy;
                if ([this->request HTTPShouldHandleCookies] == YES
                    && [_response isKindOfClass: [NSHTTPURLResponse class]] == YES)
                {
                    // cookie 的存储. 直接存储到了 [NSHTTPCookieStorage sharedHTTPCookieStorage] 中.
                    NSDictionary	*hdrs;
                    NSArray	*cookies;
                    NSURL		*url;
                    
                    url = [_response URL];
                    hdrs = [_response allHeaderFields];
                    cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: hdrs
                                                                     forURL: url];
                    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
                     setCookies: cookies
                     forURL: url
                     mainDocumentURL: [this->request mainDocumentURL]];
                }
                
                /* Tell the client that we have a response and how
                 * it should be cached.
                 */
                policy = [this->request cachePolicy];
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
                // 通知上层, 响应头结束了. 这就是 session 里面 response 代理方法调用的原因.
                [this->client URLProtocol: self
                       didReceiveResponse: _response
                       cacheStoragePolicy: policy];
            }
            
#if	USE_ZLIB
            s = [[document headerNamed: @"content-encoding"] value];
            if ([s isEqualToString: @"gzip"] || [s isEqualToString: @"x-gzip"])
            {
                this->decompressing = YES;
                this->z.opaque = 0;
                this->z.zalloc = zalloc;
                this->z.zfree = zfree;
                this->z.next_in = 0;
                this->z.avail_in = 0;
                inflateInit2(&this->z, 1);	// FIXME
            }
#endif
        }
        
        if (_complete == YES)
        {
            if (_statusCode == 401)
            {
                NSURLProtectionSpace	*space;
                NSString			*hdr;
                NSURL			*url;
                int			failures = 0;
                
                /* This was an authentication challenge.
                 */
                hdr = [[document headerNamed: @"WWW-Authenticate"] value];
                url = [this->request URL];
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
                else if ([this->request valueForHTTPHeaderField:@"Authorization"])
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
                
               
                // 这里, 交给上层处理了 _challenge, 然后拿到上层的处理结果, 继续处理后面的事情.
                [this->client URLProtocol: self
        didReceiveAuthenticationChallenge: _challenge];
                
                if (_challenge == nil)
                {
                    NSError	*e;
                    
                    /* The client cancelled the authentication challenge
                     * so we must cancel the download.
                     */
                    e = [NSError errorWithDomain: @"Authentication cancelled"
                                            code: 0
                                        userInfo: nil];
                    [self stopLoading];
                    [this->client URLProtocol: self
                             didFailWithError: e];
                }
                else
                {
                    NSString	*auth = nil;
                    
                    if (_credential != nil)
                    {
                        GSHTTPAuthentication	*authentication;
                        
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
                                method: [this->request HTTPMethod]
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
                        policy = [this->request cachePolicy];
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
                        [this->client URLProtocol: self
                               didReceiveResponse: _response
                               cacheStoragePolicy: policy];
                        /* Fall through to code providing page data.
                         */
                    }
                    else
                    {
                        NSMutableURLRequest	*request;
                        
                        /* To answer the authentication challenge,
                         * we must retry with a modified request and
                         * with the cached response cleared.
                         */
                        request = [this->request mutableCopy];
                        [request setValue: auth
                       forHTTPHeaderField: @"Authorization"];
                        [self stopLoading];
                        [this->request release];
                        this->request = request;
                        DESTROY(this->cachedResponse);
                        [self startLoading];
                        return;
                    }
                }
            }
            
            [this->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                                   forMode: NSDefaultRunLoopMode];
            [this->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                    forMode: NSDefaultRunLoopMode];
            if (_shouldClose == YES)
            {
                [this->input setDelegate: nil];
                [this->output setDelegate: nil];
                [this->input close];
                [this->output close];
                DESTROY(this->input);
                DESTROY(this->output);
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
                    [this->client URLProtocolDidFinishLoading: self];
                }
            }
        }
        else if (_isLoading == YES && _statusCode != 401)
        {
            // 读取数据, 交给上层.
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
            [this->client URLProtocol: self didFailWithError:
             [NSError errorWithDomain: @"receive incomplete"
                                 code: 0
                             userInfo: nil]];
        }
    }
}

// Socket 的代理方法. 仅仅就这一个而已.
- (void) stream: (NSStream*) stream handleEvent: (NSStreamEvent) event
{
    if (stream == this->input)
    {
        switch(event)
        {
            case NSStreamEventHasBytesAvailable:
            case NSStreamEventEndEncountered:
                [self inputStreamDidGot: stream];
                return;
            case NSStreamEventOpenCompleted:
                return;
            default:
                break;
        }
    }
    else if (stream == this->output)
    {
        switch (event)
        {
            case NSStreamEventOpenCompleted:
            {
                NSMutableData	*outputDataM;
                NSDictionary	*d;
                NSEnumerator	*e;
                NSString		*s;
                NSURL		*url;
                int		dataLength;
                
                if (_debug == YES)
                {
                    NSLog(@"%@ HTTP output stream opened", self);
                }
                this->in = [[NSString alloc]
                            initWithFormat: @"(%@:%@ <-- %@:%@)",
                            [stream propertyForKey: GSStreamLocalAddressKey],
                            [stream propertyForKey: GSStreamLocalPortKey],
                            [stream propertyForKey: GSStreamRemoteAddressKey],
                            [stream propertyForKey: GSStreamRemotePortKey]];
                this->out = [[NSString alloc]
                             initWithFormat: @"(%@:%@ --> %@:%@)",
                             [stream propertyForKey: GSStreamLocalAddressKey],
                             [stream propertyForKey: GSStreamLocalPortKey],
                             [stream propertyForKey: GSStreamRemoteAddressKey],
                             [stream propertyForKey: GSStreamRemotePortKey]];
                _writeOffset = 0;
                // 如果, 没有 bodryStram, 就是固定长度的 length data, 应该就是内存里面的值.
                if ([this->request HTTPBodyStream] == nil)
                {
                    // Not streaming
                    dataLength = [[this->request HTTPBody] length];
                    _version = 1.1;
                } else {
                    dataLength = -1;
                    _version = 1.0;
                    _shouldClose = YES;
                }
                
                outputDataM = [[NSMutableData alloc] initWithCapacity: 1024];
                
                /* The request line is of the form:
                 * method /path?query HTTP/version
                 * where the query part may be missing
                 */
                // 按照 Http 的格式, 输出数据.
                // 拼接 Method 的信息.
                [outputDataM appendData: [[this->request HTTPMethod]
                                dataUsingEncoding: NSASCIIStringEncoding]];
                // 固定格式, Method 和 path 之间的空格.
                [outputDataM appendBytes: " " length: 1];
                url = [this->request URL];
                NSString *urlPath = [[url fullPath] stringByAddingPercentEscapesUsingEncoding:
                     NSUTF8StringEncoding];
                if ([urlPath hasPrefix: @"/"] == NO)
                {
                    [outputDataM appendBytes: "/" length: 1];
                }
                // 拼接 Path 的信息.
                [outputDataM appendData: [urlPath dataUsingEncoding: NSASCIIStringEncoding]];
                NSString *query = [url query];
                // 拼接 query 的信息.
                if ([query length] > 0)
                {
                    [outputDataM appendBytes: "?" length: 1];
                    [outputDataM appendData: [query dataUsingEncoding: NSASCIIStringEncoding]];
                }
                // 拼接 version 的信息.
                NSString *version = [NSString stringWithFormat: @" HTTP/%0.1f\r\n", _version];
                [outputDataM appendData: [version dataUsingEncoding: NSASCIIStringEncoding]];
                
                // 拼接 request 的头信息.
                NSDictionary *headers = [this->request allHTTPHeaderFields];
                e = [headers keyEnumerator];
                while ((s = [e nextObject]) != nil)
                {
                    GSMimeHeader      *h;
                    
                    h = [[GSMimeHeader alloc] initWithName: s
                                                     value: [d objectForKey: s]
                                                parameters: nil];
                    [outputDataM appendData:
                     [h rawMimeDataPreservingCase: YES foldedAt: 0]];
                }
                
                if ([[this->request HTTPMethod] isEqual: @"POST"]
                    && [this->request valueForHTTPHeaderField:
                        @"Content-Type"] == nil)
                {
                    /* On MacOSX, this is automatically added to POST methods */
                    static char   *ct
                    = "Content-Type: application/x-www-form-urlencoded\r\n";
                    [outputDataM appendBytes: ct length: strlen(ct)];
                }
                
                // 拼接 host 的信息. 补全 Host.
                if ([this->request valueForHTTPHeaderField: @"Host"] == nil)
                {
                    NSString      *s = [url scheme];
                    id	        p = [url port];
                    id	        h = [url host];
                    
                    if (h == nil)
                    {
                        h = @"";	// Must send an empty host header
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
                    [outputDataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                
                // 拼接 Length 的信息.
                if (dataLength >= 0 && [this->request
                               valueForHTTPHeaderField: @"Content-Length"] == nil)
                {
                    s = [NSString stringWithFormat: @"Content-Length: %d\r\n", dataLength];
                    [outputDataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                [outputDataM appendBytes: "\r\n" length: 2];	// End of headers
                
                // 到这里, 其实是发送 Http 请求的头信息的地方.
                _writeData  = outputDataM;
            }			// Fall through to do the write, 构建完之后, 直接进入发送的阶段.
                
            case NSStreamEventHasSpaceAvailable:
            {
                int	written;
                BOOL	requestSendDone = NO;
                
                // writeData 里面, 是 Header 的信息.
                // 一点点的输出.
                if (_writeData != nil)
                {
                    const unsigned char	*bytes = [_writeData bytes];
                    unsigned		len = [_writeData length];
                    
                    // 使用 output socket 输出数据.
                    written = [this->output write: bytes+_writeOffset maxLength: len-_writeOffset];
                    if (written > 0)
                    {
                        _writeOffset += written;
                        if (_writeOffset >= len) // 如果 header 输出完了, 就输出 Body .
                        {
                            DESTROY(_writeData);
                            if (_body == nil)
                            {
                                _body = RETAIN([this->request HTTPBodyStream]);
                                if (_body == nil)
                                {
                                    NSData	*d = [this->request HTTPBody];
                                    
                                    if (d != nil)
                                    {
                                        _body = [NSInputStream alloc];
                                        _body = [_body initWithData: d];
                                        [_body open];
                                    }
                                    else
                                    {
                                        requestSendDone = YES;
                                    }
                                }
                            }
                        }
                    }
                }
                else if (_body != nil)
                {
                    // 如果 Body 还有值, 就继续输出.
                    if ([_body hasBytesAvailable])
                    {
                        unsigned char	buffer[BUFSIZ*64];
                        int		len;
                        // 先读取 body 信息到 Buffer 里面.
                        len = [_body read: buffer maxLength: sizeof(buffer)];
                        if (len < 0)
                        {  // 读取失败, 直接报错.
                            [self stopLoading];
                            [this->client URLProtocol: self didFailWithError:
                             [NSError errorWithDomain: @"can't read body"
                                                 code: 0
                                             userInfo: nil]];
                            return;
                        }
                        else if (len > 0)
                        {
                            // Socket 输出.
                            written = [this->output write: buffer maxLength: len];
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
                                    requestSendDone = YES;
                                }
                            }
                            else if ([this->output streamStatus]
                                     == NSStreamStatusWriting)
                            {
                                // 这里, 发生了阻塞的情况, 把数据存到缓存区里面.
                                _writeData = [[NSData alloc] initWithBytes:
                                              buffer length: len];
                                _writeOffset = 0;
                            }
                        }
                        else
                        {
                            [_body close];
                            DESTROY(_body);
                            requestSendDone = YES;
                        }
                    }
                    else
                    {
                        [_body close];
                        DESTROY(_body);
                        requestSendDone = YES;
                    }
                }
                // 输出完成了, 如果设置了自动关闭, 那么就关闭 output socket.
                if (requestSendDone == YES)
                {
                    if (_shouldClose == YES)
                    {
                        [this->output setDelegate: nil];
                        [this->output removeFromRunLoop:
                         [NSRunLoop currentRunLoop]
                                                forMode: NSDefaultRunLoopMode];
                        [this->output close];
                        DESTROY(this->output);
                    }
                }
                return;  // done
            }
            default:
                break;
        }
    }
    // 如果, socket 发生了错误, 直接停止网络, 在 stopLoading 里面, 会停止 socket 的链接.
    if (event == NSStreamEventErrorOccurred)
    {
        NSError	*error = [[[stream streamError] retain] autorelease];
        
        [self stopLoading];
        [this->client URLProtocol: self didFailWithError: error];
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
    if (this->cachedResponse)
    { // handle from cache
    }
    else
    {
        NSURL	*url = [this->request URL];
        NSHost	*host = [NSHost hostWithName: [url host]];
        
        if (host == nil)
        {
            host = [NSHost hostWithAddress: [url host]];
        }
        [NSStream getStreamsToHost: host
                              port: [[url port] intValue]
                       inputStream: &this->input
                      outputStream: &this->output];
        if (this->input == nil || this->output == nil)
        {
            [this->client URLProtocol: self didFailWithError:
             [NSError errorWithDomain: @"can't connect"
                                 code: 0
                             userInfo: nil]];
            return;
        }
        [this->input retain];
        [this->output retain];
        if ([[url scheme] isEqualToString: @"https"] == YES)
        {
            [this->input setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                              forKey: NSStreamSocketSecurityLevelKey];
            [this->output setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                               forKey: NSStreamSocketSecurityLevelKey];
        }
        [this->input setDelegate: self];
        [this->output setDelegate: self];
        [this->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [this->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        // set socket options for ftps requests
        [this->input open];
        [this->output open];
    }
}

- (void) stopLoading
{
    if (this->input)
    {
        [this->input setDelegate: nil];
        [this->output setDelegate: nil];
        [this->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [this->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        [this->input close];
        [this->output close];
        DESTROY(this->input);
        DESTROY(this->output);
    }
}

- (void) stream: (NSStream *) stream handleEvent: (NSStreamEvent) event
{
    if (stream == this->input)
    {
        switch(event)
        {
            case NSStreamEventHasBytesAvailable:
            {
                NSLog(@"FTP input stream has bytes available");
                // implement FTP protocol
                //			[this->client URLProtocol: self didLoadData: [NSData dataWithBytes: buffer length: len]];	// notify
                return;
            }
            case NSStreamEventEndEncountered: 	// can this occur in parallel to NSStreamEventHasBytesAvailable???
                NSLog(@"FTP input stream did end");
                [this->client URLProtocolDidFinishLoading: self];
                return;
            case NSStreamEventOpenCompleted:
                // prepare to receive header
                NSLog(@"FTP input stream opened");
                return;
            default:
                break;
        }
    }
    else if (stream == this->output)
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
        [this->client URLProtocol: self didFailWithError: [stream streamError]];
    }
    else
    {
        NSLog(@"Unexpected event %"PRIuPTR" ignored on stream %@ of %@",
              event, stream, self);
    }
}

@end

// 以 file 为 schema 的请求, 就是读取相应位置的文件内容然后返回就可以了.
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
    NSData	*data;
    NSURLResponse	*r;
    
    data = [NSData dataWithContentsOfFile: [[this->request URL] path]];
    // 如果, 读不到文件内容, 失败
    if (data == nil)
    {
        [this->client URLProtocol: self didFailWithError:
         [NSError errorWithDomain: @"can't load file" code: 0 userInfo:
          [NSDictionary dictionaryWithObjectsAndKeys:
           [this->request URL], @"URL",
           [[this->request URL] path], @"path",
           nil]]];
        return;
    }
    // 否则模拟网络请求, response, data, end.
    r = [[NSURLResponse alloc] initWithURL: [this->request URL]
                                  MIMEType: @"text/html"
                     expectedContentLength: [data length]
                          textEncodingName: @"unknown"];
    [this->client URLProtocol: self
           didReceiveResponse: r
           cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [this->client URLProtocol: self didLoadData: data];
    [this->client URLProtocolDidFinishLoading: self];
    RELEASE(r);
}

- (void) stopLoading
{
    return;
}

@end
/*
<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAUAAAADqCAIAAABcAgvBAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAP+lSURBVHherP0HgJRF8vgPTw47m5ecBEFRMGHOHqYznHp66pmzqJjzeZ6enuHM2TNgODNmPTFnRcWEICiC5Li7bJ7dyeH9VNUzD8Oi3n1//7cYnu2urq6urq6qrn5m5hlvQcGr4PF4crmc3++nXCwWDVNeXrdgQLUcQ9muPp8PJPypaiv4ItV8Pk8ThUAgYK1UtYvXChAry1+QwYAqV/oaH5qsx7o0QKFQzOcLVBnOaIzMCiaMVZUcCfPWZEjjL9yVYbmE/LVBhFrplVhQJQIBt+zS2BVVu3hwcDZKRbpK86iEAQoQGL0BeDg4FWVosgHuiAAFawJpDMuBVvhQKGcFlHMwoLpu93IwVsaHso1oTUB59xJnrlLwehFbmjA/WyNF9hbAhV4EqhbUJWVbXqNxtWHKVHAxDuh6eROJRDQaNQxcudLd6/W7enMl0aLoE6TxV0pGdMpWBayssgmGq44miw6xcQCUq8C6mF+BgsrnZbqQOtYpGBWRqknsYn6Ro8nkVEpyl+lLwOVsUOKZd/taAWDZWPhQKITKQJYRC1AoaUEwVK2JC57p99NkYgsr8JQxAjV6kceQ0FgTSBVMmowA/Nq2K4T8d6cjnUvT4QqxiadAwS27IOZCL5fMysaHqxWstSQPnKFxyiBRlHWhrHORGTEvYadAE8QUlNglc6asJGvGtSZrLQeaXOVTtY52pUko1qkaGFsK5TIYpQFVQzp1BevlMiRQ2qrRoi9BltMAphCrIqetFEibi8sfVvBT52eUtaYJjSlTmTgDuWAcstlsMBi0UVRbMhBSUC11FFBhhB6MOzQFra7xZ8MARuBCoZDjqmqRJritbXi/CjDkqgwpEKu8zNbrYZ5lU7XxTOmwtj6/DeU064prGLv+GmWZZFK21dIWB6gC4K2dlxXyedOFNHHFjV16Vf0aO7ArXCELBNCXo1zXD7lCAxgHA2sC3CY0Y70MqY3/B9ApOGAj2uSoYi5UbfnhbwVrMkoT1fCAOzoYQ4IBKAvHkuSAlbli2eX4coA53osM5RK6QxhnoBzpEtvV5QwBGKoUuLoMjUC4KN5FUrWyC27rbwMztb42CvLQz8q/yBPllfBr8Qdp+F76KV/lcrwp2MpSKs3UroZ3wbq7YDRGZgVbu/8Ka/NhE/OyBXcmUvFUBh/w5oo5XyFf8ATRQMGb9XqC/lzO4/dJbERi+krIWSNcmayiLN03DIk0IpbiZY3VWwwBCwpEtiweUC4PrUohLGwUrcLPiGwI7AD2fpFdWp0pUSwWzNb57/SAQG2ogMNKXzFrXAIBCvg...
 />
*/
// data 这种协议, 就是为了解析上面的数据的.
@implementation _NSDataURLProtocol

// 以 data 作为 schema. 和以 http 作为 schema 没有任何的区别. 各个浏览器, 包括 qt 都支持这种解析, 所以这是一个行业标椎.
+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
    return [[[request URL] scheme] isEqualToString: @"data"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request
{
    return request;
}

// Data 这种 schema 就是根据 path 去 loading data, 然后模拟 response, 回传 data.
- (void) startLoading
{
    NSURLResponse *r;
    NSString      *mime = @"text/plain";
    NSString      *encoding = @"US-ASCII";
    NSData        *data;
    NSString      *spec = [[this->request URL] resourceSpecifier];
    NSRange       comma = [spec rangeOfString:@","]; // data 这种协议, 标准就是, 逗号后面是数据.
    NSEnumerator  *types;
    NSString      *type;
    BOOL          base64 = NO;
    
    if (comma.location == NSNotFound)
    {
        NSDictionary      *ui;
        NSError           *error;
        
        ui = [NSDictionary dictionaryWithObjectsAndKeys:
              [this->request URL], @"URL",
              [[this->request URL] path], @"path",
              nil];
        error = [NSError errorWithDomain: @"can't load data"
                                    code: 0
                                userInfo: ui];
        [this->client URLProtocol: self didFailWithError: error];
        return;
    }
    // types 就是 [data:image/png , base64] 这两项组成的数组
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
    // 上面, 可以确定, 后面数据的格式.
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
    
    // 然后就是读取数据了.
    r = [[NSURLResponse alloc] initWithURL: [this->request URL]
                                  MIMEType: mime
                     expectedContentLength: [data length]
                          textEncodingName: encoding];
    
    [this->client URLProtocol: self
           didReceiveResponse: r
           cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [this->client URLProtocol: self didLoadData: data];
    [this->client URLProtocolDidFinishLoading: self];
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

// 对于这种, 可以直接完成的请求, 直接在 start loading 里面做完所有的事情.
- (void) startLoading
{
    NSURLResponse	*r;
    NSData	*data = [NSData data];	// no data
    
    // we could pass different content depending on the url path
    r = [[NSURLResponse alloc] initWithURL: [this->request URL]
                                  MIMEType: @"text/html"
                     expectedContentLength: 0
                          textEncodingName: @"utf-8"];
    [this->client URLProtocol: self
           didReceiveResponse: r
           cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [this->client URLProtocol: self didLoadData: data];
    [this->client URLProtocolDidFinishLoading: self];
    RELEASE(r);
}

// StopLoading, 不是自己主动调用的, 而是使用 protocol 的对象, 在需要的时候停止网络请求才会调用的.
- (void) stopLoading
{
    return;
}

@end
