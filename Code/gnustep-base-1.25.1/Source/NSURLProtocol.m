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

static void
debugRead(id handle, int len, const unsigned char *ptr)
{
    int           pos;
    uint8_t       *hex;
    NSUInteger    hl;
    
    hl = ((len + 2) / 3) * 4;
    hex = malloc(hl + 1);
    hex[hl] = '\0';
    GSPrivateEncodeBase64(ptr, (NSUInteger)len, hex);
    
    for (pos = 0; pos < len; pos++)
    {
        if (0 == ptr[pos])
        {
            NSData        *data;
            char          *esc;
            
            data = [[NSData alloc] initWithBytesNoCopy: (void*)ptr
                                                length: len
                                          freeWhenDone: NO];
            esc = [data escapedRepresentation: 0];
            
            NSLog(@"Read for %p of %d bytes (escaped) - '%s'\n<[%s]>",
                  handle, len, esc, hex);
            free(esc);
            RELEASE(data);
            free(hex);
            return;
        }
    }
    NSLog(@"Read for %p of %d bytes - '%*.*s'\n<[%s]>",
          handle, len, len, len, ptr, hex);
    free(hex);
}
static void
debugWrite(id handle, int len, const unsigned char *ptr)
{
    int           pos;
    uint8_t       *hex;
    NSUInteger    hl;
    
    hl = ((len + 2) / 3) * 4;
    hex = malloc(hl + 1);
    hex[hl] = '\0';
    GSPrivateEncodeBase64(ptr, (NSUInteger)len, hex);
    
    for (pos = 0; pos < len; pos++)
    {
        if (0 == ptr[pos])
        {
            NSData        *data;
            char          *esc;
            
            data = [[NSData alloc] initWithBytesNoCopy: (void*)ptr
                                                length: len
                                          freeWhenDone: NO];
            esc = [data escapedRepresentation: 0];
            NSLog(@"Write for %p of %d bytes (escaped) - '%s'\n<[%s]>",
                  handle, len, esc, hex);
            free(esc);
            RELEASE(data);
            free(hex);
            return;
        }
    }
    NSLog(@"Write for %p of %d bytes - '%*.*s'\n<[%s]>",
          handle, len, len, len, ptr, hex);
    free(hex);
}

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
    id <NSURLProtocolClient>	client;		// Not retained
    NSURLRequest			*request;
#if	USE_ZLIB
    z_stream			z;		// context for decompress
    BOOL				compressing;	// are we compressing?
    BOOL				decompressing;	// are we decompressing?
    NSData			*compressed;	// only partially decompressed
#endif
} Internal;

#define	this	((Internal*)(self->_NSURLProtocolInternal))
#define	inst	((Internal*)(o->_NSURLProtocolInternal))

static NSMutableArray	*registered = nil; // static , 这是一个静态全局的变量, 所以在取值赋值的时候, 进行了加锁处理.
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

+ (void) initialize // 这里, NSURLProtocol 其实是起了一个分发的作用.
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
        
        // 将处理各个 scheme 的各个类, 添加到了一个数组中进行记录.
        [self registerClass: [_NSHTTPURLProtocol class]];
        [self registerClass: [_NSHTTPSURLProtocol class]];
        [self registerClass: [_NSFTPURLProtocol class]];
        [self registerClass: [_NSFileURLProtocol class]];
        [self registerClass: [_NSAboutURLProtocol class]];
        [self registerClass: [_NSDataURLProtocol class]];
    }
}


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
+ (void) unregisterClass: (Class)protocolClass
{
    [regLock lock];
    [registered removeObjectIdenticalTo: protocolClass];
    [regLock unlock];
}

+ (void) setProperty: (id)value
              forKey: (NSString *)key
           inRequest: (NSMutableURLRequest *)request
{
    [request _setProperty: value forKey: key];
}

+ (id) propertyForKey: (NSString *)key inRequest: (NSURLRequest *)request
{
    return [request _propertyForKey: key];
}


- (NSCachedURLResponse *) cachedResponse
{
    return this->cachedResponse;
}

- (id <NSURLProtocolClient>) client
{
    return this->client;
}

- (void) dealloc
{
    if (this != 0)
    {
        [self stopLoading];
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
            DESTROY(this->input);
            DESTROY(this->output);
        }
        DESTROY(this->cachedResponse);
        DESTROY(this->request);
#if	USE_ZLIB
        if (this->compressing == YES)
        {
            deflateEnd(&this->z);
        }
        else if (this->decompressing == YES)
        {
            inflateEnd(&this->z);
        }
        DESTROY(this->compressed);
#endif
        NSZoneFree([self zone], this);
        _NSURLProtocolInternal = 0;
    }
    [super dealloc];
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"%@ %@",
            [super description], this ? (id)this->request : nil];
}

- (id) init // 创建了 Interal
{
    if ((self = [super init]) != nil)
    {
        Class	c = object_getClass(self);
        
        if (c != abstractClass && c != placeholderClass)
        {
            _NSURLProtocolInternal = NSZoneCalloc([self zone], //
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
    
    if (c == abstractClass || c == placeholderClass) // 在 initWithReuqst 里面, 在生成真正的类的对象, 类簇模式.
    {
        unsigned	count;
        
        DESTROY(self);
        [regLock lock];
        count = [registered count];
        while (count-- > 0)
        {
            Class	proto = [registered objectAtIndex: count];
            
            if ([proto canInitWithRequest: request] == YES) // canInitWithRequest 很简单, 就是判断一下 scheme 的类型.
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
        this->request = [request copy];
        this->cachedResponse = RETAIN(cachedResponse);
        this->client = client;	// Not retained // 这里, 进行了 client 的赋值, 一般这个client 就是 NSURLConnection
    }
    return self;
}

- (NSURLRequest *) request
{
    return this->request;
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

+ (BOOL) canInitWithRequest: (NSURLRequest *)request
{
    [self subclassResponsibility: _cmd];
    return NO;
}

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
    return [[[request URL] scheme] isEqualToString: @"http"]; // 检查 schema
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

- (void) startLoading // 简单的来说, 就是建立了 socket 链接, 然后根据 socket 链接的代理方法进行解析工作.
{
    static NSDictionary *methods = nil;
    if (methods == nil) // 所有的 http 的方法进行了汇总.
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
    _debug = GSDebugSet(@"NSURLProtocol");
    if (YES == [this->request _debug]) _debug = YES; // 这应该是 GNU 的实现.
    
    if ([methods objectForKey: [this->request HTTPMethod]] == nil) // 方法设置的有问题, 不是 http 协议中的一种.
    {
        NSLog(@"Invalid HTTP Method: %@", this->request);
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
    
    _statusCode = 0;	/* No status returned yet.	*/ // 所以, 应该是 response 也是由这个类进行创建的.
    _isLoading = YES;
    _complete = NO;
    
    // 进行重定向工作.
    if ([[[this->request URL] fullPath] length] == 0) // 如果本身的URL 就是有问题
    {
        NSString		*sourceURL = [[this->request URL] absoluteString];
        NSURL		*url;
        
        if ([sourceURL rangeOfString: @"?"].length > 0)
        {
            sourceURL = [sourceURL stringByReplacingString: @"?" withString: @"/?"];
        }
        else if ([sourceURL rangeOfString: @"#"].length > 0)
        {
            sourceURL = [sourceURL stringByReplacingString: @"#" withString: @"/#"];
        }
        else
        {
            sourceURL = [sourceURL stringByAppendingString: @"/"];
        }
        url = [NSURL URLWithString: sourceURL];
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
            NSMutableURLRequest	*request;
            
            request = [[this->request mutableCopy] autorelease];
            [request setURL: url];
            [this->client URLProtocol: self
               wasRedirectedToRequest: request
                     redirectResponse: nil];
        }
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
    
    NSURL    *url = [this->request URL];
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
        port = [[url scheme] isEqualToString: @"https"] ? 443 : 80; // 这里, 做了保险处理, 就是 port 为 443 或者 80, 是和 http 进行匹配的.
    }
    
    [NSStream getStreamsToHost: host
                          port: port
                   inputStream: &this->input
                  outputStream: &this->output]; // Creates and returns by reference an NSInputStream object and NSOutputStream object for a socket connection with a given host on a given port.
    if (!this->input || !this->output) // 如果没能建立一个 socket 链接.
    {
        if (_debug == YES)
        {
            NSLog(@"%@ did not create streams for %@:%@",
                  self, host, [url port]);
        }
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
    
    [this->input retain];
    [this->output retain];
    if ([[url scheme] isEqualToString: @"https"] == YES) // 如果是 https 的链接.
    {
        static NSArray        *keys;
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
                    GSTLSVerify,
                    nil];
        }
        
        NSUInteger            count;
        [this->input setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                          forKey: NSStreamSocketSecurityLevelKey];
        [this->output setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                           forKey: NSStreamSocketSecurityLevelKey];
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
        if (_debug) [this->output setProperty: @"YES" forKey: GSTLSDebug];
    }
    [this->input setDelegate: self];
    [this->output setDelegate: self];
    [this->input scheduleInRunLoop: [NSRunLoop currentRunLoop]
                           forMode: NSDefaultRunLoopMode];
    [this->output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                            forMode: NSDefaultRunLoopMode];
    [this->input open];
    [this->output open]; // 然后后面就是 根据 input, output 的回调进行处理.
}

- (void) stopLoading // 移出 input, ouput 的操作.
{
    if (_debug == YES)
    {
        NSLog(@"%@ stopLoading", self);
    }
    _isLoading = NO;
    DESTROY(_writeData);
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
        DESTROY(this->input);
        DESTROY(this->output);
    }
}

- (void) _didLoad: (NSData*)d
{
    [this->client URLProtocol: self didLoadData: d];
}

// 这里再次确定一个事情, 就是协议就是协议, 它只是能够确定最基本的操作过程, 但是到底这个过程是怎么回事, 还是需要各个类库的代码进行完成.

- (void) _got: (NSStream*)stream
{
    unsigned char	buffer[BUFSIZ*64]; // 2014 & 64
    int 		readCount;
    NSError	*e;
    NSData	*newInputData;
    BOOL		wasInHeaders = NO;
    
    readCount = [(NSInputStream *)stream read: buffer
                                    maxLength: sizeof(buffer)];
    // 读信息.
    if (readCount < 0) // 有问题.
    {
        if ([stream  streamStatus] == NSStreamStatusError)
        {
            e = [stream streamError];
            if (_debug)
            {
                NSLog(@"%@ receive error %@", self, e);
            }
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
    newInputData = [NSData dataWithBytes: buffer length: readCount];
    if ([_parser parse: newInputData] == NO && (_complete = [_parser isComplete]) == NO) // 分析出错. 这里解析的代码没看先.
    {
        if (_debug == YES)
        {
            NSLog(@"%@ HTTP parse failure - %@", self, _parser);
        }
        e = [NSError errorWithDomain: @"parse error"
                                code: 0
                            userInfo: nil];
        [self stopLoading];
        [this->client URLProtocol: self didFailWithError: e];
        return;
    }
    
    BOOL        isInHeaders = [_parser isInHeaders];
    GSMimeDocument    *document = [_parser mimeDocument]; // HTTP 协议的一些信息.
    unsigned        bodyLength;
    _complete = [_parser isComplete];
    if (YES == wasInHeaders && NO == isInHeaders) // 如果, 之前是在分析 header, 现在分析完毕了. 这个时候就能通过 header 里面的信息, 确定一些事情了.
    {
        GSMimeHeader        *info;
        int            len = -1;
        NSString        *mimeType;
        NSString        *st;
        NSString        *parseHttpValue;
        
        info = [document headerNamed: @"http"];
        
        _version = [[info value] floatValue]; // 根据返回的内容, 判断要不要保持连接.
        if (_version < 1.1)
        {
            _shouldClose = YES;
        }
        else if ((parseHttpValue = [[document headerNamed: @"connection"] value]) != nil
                 && [parseHttpValue caseInsensitiveCompare: @"close"] == NSOrderedSame)
        {
            _shouldClose = YES;
        }
        else
        {
            _shouldClose = NO;    // Keep connection alive.
        }
        
        parseHttpValue = [info objectForKey: NSHTTPPropertyStatusCodeKey];
        _statusCode = [parseHttpValue intValue];
        
        parseHttpValue = [[document headerNamed: @"content-length"] value];
        if ([parseHttpValue length] > 0)
        {
            len = [parseHttpValue intValue];
        }
        
        parseHttpValue = [info objectForKey: NSHTTPPropertyStatusReasonKey]; // 服务器端返回的 status code 的解释一句.
        
        info = [document headerNamed: @"content-type"];
        mimeType = [document contentType];
        st = [document contentSubtype];
        if (mimeType && st)
        {
            mimeType = [mimeType stringByAppendingFormat: @"/%@", st];
        }
        else
        {
            mimeType = nil;
        }
        _response = [[NSHTTPURLResponse alloc]
                     initWithURL: [this->request URL]
                     MIMEType: mimeType
                     expectedContentLength: len
                     textEncodingName: [info parameterForKey: @"charset"]]; // 这里, 就是根据返回的结果, 建立一个 response.
        [_response _setStatusCode: _statusCode text: parseHttpValue];
        [document deleteHeaderNamed: @"http"];
        [_response _setHeaders: [document allHeaders]];
        
        if (_statusCode == 204 || _statusCode == 304) // 没有 body 的内容
        {
            _complete = YES;    // No body expected.
        }
        else if (_complete == NO && [newInputData length] == 0)
        {
            _complete = YES;    // Had EOF ... terminate
        }
        
        if (_statusCode == 401) // 请求错误
        {
            /* This is an authentication challenge, so we keep reading
             * until the challenge is complete, then try to deal with it.
             */
        }
        else if (_statusCode >= 300 && _statusCode < 400) // 重定向.
        {
            NSURL    *url;
            
            NS_DURING
            parseHttpValue = [[document headerNamed: @"location"] value];
            url = [NSURL URLWithString: parseHttpValue];
            NS_HANDLER
            url = nil;
            NS_ENDHANDLER
            if (url == nil)
            {
                NSError    *e;
                e = [NSError errorWithDomain: @"Invalid redirect request"
                                        code: 0
                                    userInfo: nil];
                [self stopLoading];
                [this->client URLProtocol: self
                         didFailWithError: e];
            }
            else
            {
                NSMutableURLRequest    *request;
                
                request = [[this->request mutableCopy] autorelease];
                [request setURL: url];
                [this->client URLProtocol: self
                   wasRedirectedToRequest: request
                         redirectResponse: _response]; // 如果是重定向, 相当于要新开始一个新的 protocol, 这个 protocol 的 loading 也就结束了.
            }
        }
        else
        {
            NSURLCacheStoragePolicy policy; // 这里进行 cookie 的一些设置工作.
            // 因为现在其实 response 的返回, 也就是 header 解析完之后开始解析 body 的时候. 也就是说, 现在只有 response 而 body 的内容可能还在进行解析操作.
            // 所以, 这里是对 response 的处理. 而 cookie 是存储在 response 里面, 所以, 这里进行 cookie 的处理是没有问题的.
            // 所以说, 各个类其实就是责任的抽象体. 这里, 我们将 cookie 设置进去, 回头我们发现如果需要用到 cookie 的时候, 我们在用相同的方法抽取出来.
            if ([this->request HTTPShouldHandleCookies] == YES
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
            [this->client URLProtocol: self
                   didReceiveResponse: _response
                   cacheStoragePolicy: policy]; // 这里, connection 没有对 policy 进行处理. 可能第三方框架会进行 处理.
        }
        
#if    USE_ZLIB
        s = [[document headerNamed: @"content-encoding"] value]; // 解压的一些操作.
        if ([s isEqualToString: @"gzip"] || [s isEqualToString: @"x-gzip"])
        {
            this->decompressing = YES;
            this->z.opaque = 0;
            this->z.zalloc = zalloc;
            this->z.zfree = zfree;
            this->z.next_in = 0;
            this->z.avail_in = 0;
            inflateInit2(&this->z, 1);    // FIXME
        }
#endif
    }
    
    if (_complete == YES) // 如果 获取信息完毕.
    {
        if (_statusCode == 401) // 授权相关.
        {
            NSURLProtectionSpace    *space;
            NSString            *Authenticate;
            NSURL            *url;
            int            failures = 0;
            
            /* This was an authentication challenge.
             www-authenticate . 这种就是说, 浏览器进行弹框, 用户输入密码, 然后返回这些用户账号, 密码数据, 用的 base64, 之后如果服务器验证成功, 就返回之前请求的数据.
             */
            Authenticate = [[document headerNamed: @"WWW-Authenticate"] value];
            url = [this->request URL];
            space = [GSHTTPAuthentication
                     protectionSpaceForAuthentication: Authenticate requestURL: url];
            DESTROY(_credential); // reset 操作.
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
            
            /* Allow the client to control the credential we send
             * or whether we actually send at all.
             */
            [this->client URLProtocol: self
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
                [this->client URLProtocol: self
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
                            authorizationForAuthentication: Authenticate
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
                    // 在这个类里面, cookie 的存储是用了 CookieStorage 类的单例, 所以, 我觉得其实在真正的 apple 的实现里面, 是用了 [NSURLCache class] 这个类进行了存储的管理. 不过, 在 GNU 的实现里面, 没有用这个东西. 不知道是为了什么.
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
                    NSMutableURLRequest    *request;
                    
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
        
        // 已经完成了, 不是授权相关的一些东西.
        [this->input removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [this->output removeFromRunLoop: [NSRunLoop currentRunLoop]
                                forMode: NSDefaultRunLoopMode];
        if (_shouldClose == YES) // 如果要关闭, 那么就关闭 socket 链接.
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
        if (_isLoading == YES) // 进行最后的一些解析工作 , 然后通知代理, 取数据完成了.
        {
            newInputData = [_parser data];
            bodyLength = [newInputData length];
            if (bodyLength > _parseOffset)
            {
                if (_parseOffset > 0)
                {
                    newInputData = [newInputData subdataWithRange:
                         NSMakeRange(_parseOffset, bodyLength - _parseOffset)];
                }
                _parseOffset = bodyLength;
                [self _didLoad: newInputData];
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
    else if (_isLoading == YES && _statusCode != 401) // 如果还在进行 loading,
    {
        /*
         * Report partial data if possible.
         */
        if ([_parser isInBody])
        {
            newInputData = [_parser data];
            bodyLength = [newInputData length];
            if (bodyLength > _parseOffset)
            {
                if (_parseOffset > 0)
                {
                    newInputData = [newInputData subdataWithRange:
                         NSMakeRange(_parseOffset, [newInputData length] - _parseOffset)];
                }
                _parseOffset = bodyLength;
                [this->client URLProtocol: self didLoadData: newInputData]; // 通知代理, 又来了新的数据了.
            }
        }
    }
    
    if (_complete == NO && readCount == 0 && _isLoading == YES)
    { // 出错了.
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



// Stream 的 delegate 方法
- (void) stream: (NSStream*) stream handleEvent: (NSStreamEvent) event
{
    /* Make sure no action triggered by anything else destroys us prematurely.
     */
    IF_NO_GC([[self retain] autorelease];)
    
    if (stream == this->input) // 接受, 也就是建立 response 的过程.
    {
        switch(event)
        {
            case NSStreamEventHasBytesAvailable:
            case NSStreamEventEndEncountered:
                [self _got: stream];
                return;
            case NSStreamEventOpenCompleted:
                return;
            default:
                break;
        }
    }
    else if (stream == this->output) // 发送消息.
    {
        switch (event)
        {
            case NSStreamEventOpenCompleted:
            {
                NSMutableData	*m;
                NSDictionary	*d;
                NSEnumerator	*e;
                NSString		*s;
                NSURL		*u;
                int		l;
                
                if (_debug == YES)
                {
                    NSLog(@"%@ HTTP output stream opened", self);
                }
                DESTROY(_writeData);
                _writeOffset = 0;
                if ([this->request HTTPBodyStream] == nil)
                {
                    // Not streaming
                    l = [[this->request HTTPBody] length];
                    _version = 1.1;
                }
                else
                {
                    // Stream and close
                    l = -1;
                    _version = 1.0;
                    _shouldClose = YES;
                }
                
                m = [[NSMutableData alloc] initWithCapacity: 1024];
                
                /* The request line is of the form:
                 * method /path?query HTTP/version
                 * where the query part may be missing
                 */
                [m appendData: [[this->request HTTPMethod]
                                dataUsingEncoding: NSASCIIStringEncoding]];
                [m appendBytes: " " length: 1];
                u = [this->request URL];
                s = [[u fullPath] stringByAddingPercentEscapesUsingEncoding:
                     NSUTF8StringEncoding];
                if ([s hasPrefix: @"/"] == NO)
                {
                    [m appendBytes: "/" length: 1];
                }
                [m appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                s = [u query];
                if ([s length] > 0)
                {
                    [m appendBytes: "?" length: 1];
                    [m appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                s = [NSString stringWithFormat: @" HTTP/%0.1f\r\n", _version];
                [m appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                
                d = [this->request allHTTPHeaderFields];
                e = [d keyEnumerator];
                while ((s = [e nextObject]) != nil)
                {
                    GSMimeHeader      *h;
                    
                    h = [[GSMimeHeader alloc] initWithName: s
                                                     value: [d objectForKey: s]
                                                parameters: nil];
                    [m appendData:
                     [h rawMimeDataPreservingCase: YES foldedAt: 0]];
                    RELEASE(h);
                }
                
                /* Use valueForHTTPHeaderField: to check for content-type
                 * header as that does a case insensitive comparison and
                 * we therefore won't end up adding a second header by
                 * accident because the two header names differ in case.
                 */
                if ([[this->request HTTPMethod] isEqual: @"POST"]
                    && [this->request valueForHTTPHeaderField:
                        @"Content-Type"] == nil)
                {
                    /* On MacOSX, this is automatically added to POST methods */
                    static char   *ct
                    = "Content-Type: application/x-www-form-urlencoded\r\n";
                    [m appendBytes: ct length: strlen(ct)];
                }
                if ([this->request valueForHTTPHeaderField: @"Host"] == nil)
                {
                    NSString      *s = [u scheme];
                    id	        p = [u port];
                    id	        h = [u host];
                    
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
                    [m appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                if (l >= 0 && [this->request
                               valueForHTTPHeaderField: @"Content-Length"] == nil)
                {
                    s = [NSString stringWithFormat: @"Content-Length: %d\r\n", l];
                    [m appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                [m appendBytes: "\r\n" length: 2];	// End of headers
                _writeData  = m;
            }			// Fall through to do the write
                
            case NSStreamEventHasSpaceAvailable:
            {
                int	written;
                BOOL	sent = NO;
                
                // FIXME: should also send out relevant Cookies
                if (_writeData != nil)
                {
                    const unsigned char	*bytes = [_writeData bytes];
                    unsigned		len = [_writeData length];
                    
                    written = [this->output write: bytes + _writeOffset
                                        maxLength: len - _writeOffset];
                    if (written > 0)
                    {
                        if (_debug == YES)
                        {
                            debugWrite(self, written, bytes + _writeOffset);
                        }
                        _writeOffset += written;
                        if (_writeOffset >= len)
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
                        unsigned char	buffer[BUFSIZ*64];
                        int		len;
                        
                        len = [_body read: buffer maxLength: sizeof(buffer)];
                        if (len < 0)
                        {
                            if (_debug == YES)
                            {
                                NSLog(@"%@ error reading from HTTPBody stream %@",
                                      self, [NSError _last]);
                            }
                            [self stopLoading];
                            [this->client URLProtocol: self didFailWithError:
                             [NSError errorWithDomain: @"can't read body"
                                                 code: 0
                                             userInfo: nil]];
                            return;
                        }
                        else if (len > 0)
                        {
                            written = [this->output write: buffer maxLength: len];
                            if (written > 0)
                            {
                                if (_debug == YES)
                                {
                                    debugWrite(self, written, buffer);
                                }
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
                            else if ([this->output streamStatus]
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
                    if (_debug)
                    {
                        NSLog(@"%@ request sent", self);
                    }
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
    else
    {
        NSLog(@"Unexpected event %"PRIuPTR
              " occurred on stream %@ not being used by %@",
              event, stream, self);
    }
    if (event == NSStreamEventErrorOccurred)
    {
        NSError	*error = [[[stream streamError] retain] autorelease];
        
        [self stopLoading];
        [this->client URLProtocol: self didFailWithError: error];
    }
    else
    {
        NSLog(@"Unexpected event %"PRIuPTR" ignored on stream %@ of %@",
              event, stream, self);
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
    
    data = [NSData dataWithContentsOfFile: [[this->request URL] path]
            /* options: error: - don't use that because it is based on self */];
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
    
    /* FIXME ... maybe should infer MIME type and encoding from extension or BOM
     */
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
    NSString      *spec = [[this->request URL] resourceSpecifier];
    NSRange       comma = [spec rangeOfString:@","];
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

- (void) stopLoading
{
    return;
}

@end
