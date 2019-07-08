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
    NSInputStream		*requestDataStream;		// for sending the body
    unsigned		_writeOffset;	// Request data to write
    NSData		*_writedSoFarData;	// Request bytes written so far
    BOOL			_complete;
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
        // register is a common routine to cache handler for later code run.
        registered = [NSMutableArray new];
        [self registerClass: [_NSHTTPURLProtocol class]];
        [self registerClass: [_NSHTTPSURLProtocol class]];
        [self registerClass: [_NSFTPURLProtocol class]];
        [self registerClass: [_NSFileURLProtocol class]];
        [self registerClass: [_NSAboutURLProtocol class]];
        [self registerClass: [_NSDataURLProtocol class]];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
    NSURLProtocol	*o;
    o = placeholder;
    return o;
}

+ (id) propertyForKey: (NSString *)key inRequest: (NSURLRequest *)request
{
    return [request _propertyForKey: key];
}

+ (BOOL) registerClass: (Class)protocolClass
{
    if ([protocolClass isSubclassOfClass: [NSURLProtocol class]] == YES)
    {
        [registered addObject: protocolClass];
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
    [registered removeObjectIdenticalTo: protocolClass];
}

- (NSCachedURLResponse *) cachedResponse
{
    return cachedResponse;
}

- (id <NSURLProtocolClient>) client
{
    return client;
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
    /**
     * Class cluster mode. The real class is created in while loop. Find the first class to handel request.
     * May be a clear factory method is better.
     */
    if (c == abstractClass || c == placeholderClass)
    {
        unsigned	count;
        
        DESTROY(self);
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
        return [self initWithRequest: request
                      cachedResponse: cachedResponse
                              client: client];
    }
    return self;
}

- (NSURLRequest *) request
{
    return request;
}

@end

@implementation	NSURLProtocol (Private)

/**
 * Search in sequence. The first can handle request will be the target protocol.
 */
+ (Class) _classToHandleRequest:(NSURLRequest *)request
{
    Class protoClass = nil;
    int count;
    
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

- (void) dealloc
{
    [_parser release];			// received headers
    [requestDataStream release];			// for sending the body
    [_response release];
    [_credential release];
    [super dealloc];
}

- (void) startLoading
{
    const NSDictionary *methods = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   self, @"HEAD",
                                   self, @"GET",
                                   self, @"POST",
                                   self, @"PUT",
                                   self, @"DELETE",
                                   self, @"TRACE",
                                   self, @"OPTIONS",
                                   self, @"CONNECT",
                                   nil];
    /**
     * If method is wrong, return directly.
     */
    if ([methods objectForKey: [request HTTPMethod]] == nil)
    {
        [self stopLoading];
        [client URLProtocol: self didFailWithError:
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
    
    // redrect if request url is bad
    if ([[[request URL] fullPath] length] == 0)
    {
        NSString		*s = [[request URL] absoluteString];
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
            [client URLProtocol: self
               didFailWithError: e];
        }
        else
        {
            NSMutableURLRequest	*request;
            
            request = [[request mutableCopy] autorelease];
            [request setURL: url];
            [client URLProtocol: self
         wasRedirectedToRequest: request
               redirectResponse: nil];
        }
        if (NO == _isLoading)
        {
            return;	// Loading cancelled
        }
        if (nil != inputStream)
        {
            return;	// Following redirection
        }
    }
    
    NSURL    *url = [request URL];
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
    
    /**
     * Using input stream and outputstream to handle loading progerss.
     */
    [NSStream getStreamsToHost: host
                          port: port
                   inputStream: &inputStream
                  outputStream: &output];
    // GSIneternetInputStream and GSIneternetOutputStream
    if (!inputStream || !output)
    {
        [self stopLoading];
        [client URLProtocol: self didFailWithError:
         [NSError errorWithDomain: @"can't connect" code: 0 userInfo:
          [NSDictionary dictionaryWithObjectsAndKeys:
           url, @"NSErrorFailingURLKey",
           host, @"NSErrorFailingURLStringKey",
           @"can't find host", @"NSLocalizedDescription",
           nil]]];
        return;
    }
    [inputStream retain];
    [output retain];
    /**
     * If loading a https data. Set corresponding property.
     */
    if ([[url scheme] isEqualToString: @"https"] == YES)
    {
        NSUInteger            count;
        [inputStream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                          forKey: NSStreamSocketSecurityLevelKey];
        [output setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                     forKey: NSStreamSocketSecurityLevelKey];
        NSArray        *keys = [[NSArray alloc] initWithObjects:
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
                                nil];;
        count = [keys count];
        while (count-- > 0)
        {
            NSString      *key = [keys objectAtIndex: count];
            NSString      *str = [request _propertyForKey: key];
            
            if (nil != str)
            {
                [output setProperty: str forKey: key];
            }
        }
        /* If there is no value set for the server name, and the host in the
         * URL is a domain name rather than an address, we use that.
         */
        if (nil == [output propertyForKey: GSTLSServerName])
        {
            NSString  *host = [url host];
            unichar   c;
            
            c = [host length] == 0 ? 0 : [host characterAtIndex: 0];
            if (c != 0 && c != ':' && !isdigit(c))
            {
                [output setProperty: host forKey: GSTLSServerName];
            }
        }
    }
    [inputStream setDelegate: self];
    [output setDelegate: self];
    [inputStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                           forMode: NSDefaultRunLoopMode];
    [output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                      forMode: NSDefaultRunLoopMode];
    [inputStream open];
    [output open];
}

- (void) stopLoading
{
    _isLoading = NO;
    DESTROY(_writedSoFarData);
    if (inputStream != nil) // check two value inited with one value. It's common
    {
        [inputStream setDelegate: nil];
        [output setDelegate: nil];
        [inputStream removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [output removeFromRunLoop: [NSRunLoop currentRunLoop]
                          forMode: NSDefaultRunLoopMode];
        [inputStream close];
        [output close];
        DESTROY(inputStream);
        DESTROY(output);
    }
}

- (void) _didLoad: (NSData*)d
{
    [client URLProtocol: self didLoadData: d];
}

// get response.
- (void) _got: (NSStream*)stream
{
    unsigned char	buffer[BUFSIZ*64];
    int 		readCount;
    NSError	*e;
    NSData	*d;
    BOOL		wasInHeaders = NO;
    /**
     * Get data form stream.
     */
    readCount = [(NSInputStream *)stream read: buffer
                                    maxLength: sizeof(buffer)];
    if (readCount < 0)
    {
        [client URLProtocol: self didFailWithError: nil];
        return;
    }
    
    /**
     * The parse progress is translate into parser class.
     */
    wasInHeaders = [_parser isInHeaders];
    d = [NSData dataWithBytes: buffer length: readCount];
    if ([_parser parse: d] == NO && (_complete = [_parser isComplete]) == NO)
    {
        e = [NSError errorWithDomain: @"parse error"
                                code: 0
                            userInfo: nil];
        [self stopLoading];
        [client URLProtocol: self didFailWithError: e];
        return;
    }
    
    BOOL        isInHeaders = [_parser isInHeaders];
    GSMimeDocument    *document = [_parser mimeDocument];
    unsigned        bodyLength;
    _complete = [_parser isComplete];
    /**
     * YES == wasInHeaders && NO == isInHeaders means response can post to client.
     */
    if (YES == wasInHeaders && NO == isInHeaders)
    {
        GSMimeHeader        *info;
        int            len = -1;
        NSString        *ct;
        NSString        *st;
        NSString        *responseValue;
        
        info = [document headerNamed: @"http"];
        
        _version = [[info value] floatValue];
        if (_version < 1.1)
        {
            _shouldClose = YES;
        }
        else if ((responseValue = [[document headerNamed: @"connection"] value]) != nil
                 && [responseValue caseInsensitiveCompare: @"close"] == NSOrderedSame)
        {
            _shouldClose = YES;
        }
        else
        {
            _shouldClose = NO;    // Keep connection alive.
        }
        
        responseValue = [info objectForKey: NSHTTPPropertyStatusCodeKey];
        _statusCode = [responseValue intValue];
        
        responseValue = [[document headerNamed: @"content-length"] value];
        if ([responseValue length] > 0)
        {
            len = [responseValue intValue];
        }
        
        responseValue = [info objectForKey: NSHTTPPropertyStatusReasonKey];
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
        _response = [[NSHTTPURLResponse alloc]
                     initWithURL: [request URL]
                     MIMEType: ct
                     expectedContentLength: len
                     textEncodingName: [info parameterForKey: @"charset"]];
        [_response _setStatusCode: _statusCode text: responseValue];
        [document deleteHeaderNamed: @"http"];
        [_response _setHeaders: [document allHeaders]];
        
        if (_statusCode == 204 || _statusCode == 304)
        {
            _complete = YES;    // No body expected.
        }
        else if (_complete == NO && [d length] == 0)
        {
            _complete = YES;    // Had EOF ... terminate
        }
        
        if (_statusCode == 401)
        {
            /* This is an authentication challenge, so we keep reading
             * until the challenge is complete, then try to deal with it.
             */
        } else if (_statusCode >= 300 && _statusCode < 400) {
            /**
             * Redirect status
             */
            NSURL    *url;
            
            NS_DURING
            responseValue = [[document headerNamed: @"location"] value];
            url = [NSURL URLWithString: responseValue];
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
                [client URLProtocol: self
                   didFailWithError: e];
            }
            else
            {
                NSMutableURLRequest    *request;
                
                request = [[request mutableCopy] autorelease];
                [request setURL: url];
                [client URLProtocol: self
             wasRedirectedToRequest: request
                   redirectResponse: _response];
            }
        }
        else
        {
            NSURLCacheStoragePolicy policy;
            if ([request HTTPShouldHandleCookies] == YES
                && [_response isKindOfClass: [NSHTTPURLResponse class]] == YES)
            {
                /* Get cookies from the response and accept them into
                 * shared storage if policy permits
                 */
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
                 mainDocumentURL: [request mainDocumentURL]];
            }
            
            /* Tell the client that we have a response and how
             * it should be cached.
             */
            policy = [request cachePolicy];
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
            /**
             * So protocol don't handle for caching progress. It's connection responsibility.
             And eventully, response is pop up to connection.
             */
            [client URLProtocol: self
             didReceiveResponse: _response
             cacheStoragePolicy: policy];
        }
    }
    
    if (_complete == YES) {
        /**
         *
         状态码 401 Unauthorized 代表客户端错误，指的是由于缺乏目标资源要求的身份验证凭证，发送的请求未得到满足。
         这个状态码会与   WWW-Authenticate 首部一起发送，其中包含有如何进行验证的信息。
         这个状态类似于 403， 但是在该情况下，依然可以进行身份验证。
         */
        if (_statusCode == 401)
        {
            // If need authorization, tell client.
            NSURLProtectionSpace    *space;
            NSString            *authValue;
            NSURL            *url;
            int            failures = 0;
            
            /* This was an authentication challenge.
             */
            // authValue 中存储了验证的方式.
            authValue = [[document headerNamed: @"WWW-Authenticate"] value];
            url = [request URL];
            space = [GSHTTPAuthentication
                     protectionSpaceForAuthentication: authValue requestURL: url];
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
            else if ([request valueForHTTPHeaderField:@"Authorization"])
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
            [client URLProtocol: self didReceiveAuthenticationChallenge: _challenge];
            
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
                [client URLProtocol: self
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
                            authorizationForAuthentication: authValue
                            method: [request HTTPMethod]
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
                    policy = [request cachePolicy];
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
                    [client URLProtocol: self
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
                    request = [request mutableCopy];
                    [request setValue: auth
                   forHTTPHeaderField: @"Authorization"];
                    [self stopLoading];
                    [request release];
                    request = request;
                    DESTROY(cachedResponse);
                    [self startLoading];
                    return;
                }
            }
        }
        [inputStream removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [output removeFromRunLoop: [NSRunLoop currentRunLoop]
                          forMode: NSDefaultRunLoopMode];
        if (_shouldClose == YES)
        {
            [inputStream setDelegate: nil];
            [output setDelegate: nil];
            [inputStream close];
            [output close];
            DESTROY(inputStream);
            DESTROY(output);
        }
        
        /*
         * Tell superclass that we have successfully loaded the data
         * (as long as we haven't had the load terminated by the client).
         */
        if (_isLoading == YES)
        {
            d = [_parser data];
            bodyLength = [d length];
            if (bodyLength > _parseOffset)
            {
                if (_parseOffset > 0)
                {
                    d = [d subdataWithRange:
                         NSMakeRange(_parseOffset, bodyLength - _parseOffset)];
                }
                _parseOffset = bodyLength;
                [self _didLoad: d];
            }
            
            /* Check again in case the client cancelled the load inside
             * the URLProtocol:didLoadData: callback.
             */
            if (_isLoading == YES)
            {
                _isLoading = NO;
                [client URLProtocolDidFinishLoading: self];
            }
        }
        return;
    }
    
    /*
     * Report partial data if possible.
     */
    if ([_parser isInBody])
    {
        d = [_parser data];
        bodyLength = [d length];
        if (bodyLength > _parseOffset)
        {
            if (_parseOffset > 0)
            {
                d = [d subdataWithRange:
                     NSMakeRange(_parseOffset, [d length] - _parseOffset)];
            }
            _parseOffset = bodyLength;
            [self _didLoad: d];
        }
    }
}

- (void) stream: (NSStream*) stream handleEvent: (NSStreamEvent) event {
    if (stream == inputStream)
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
    else if (stream == output)
    {
        switch (event)
        {
                // output stream should output every data, include the http header and body.
            case NSStreamEventOpenCompleted: // opened and make output stream.
            {
                NSMutableData	*dataM;
                NSDictionary	*d;
                NSEnumerator	*e;
                NSString		*s;
                NSURL		*url;
                int		bodylength;
                
                DESTROY(_writedSoFarData);
                _writeOffset = 0;
                if ([request HTTPBodyStream] == nil)
                {
                    bodylength = [[request HTTPBody] length];
                    _version = 1.1;
                }
                else
                {
                    // Stream and close
                    bodylength = -1;
                    _version = 1.0;
                    _shouldClose = YES;
                }
                
                dataM = [[NSMutableData alloc] initWithCapacity: 1024];
                
                /* The request line is of the form:
                 * method /path?query HTTP/version
                 * where the query part may be missing
                 */
                [dataM appendData: [[request HTTPMethod]
                                    dataUsingEncoding: NSASCIIStringEncoding]];
                [dataM appendBytes: " " length: 1];
                url = [request URL];
                s = [[url fullPath] stringByAddingPercentEscapesUsingEncoding:
                     NSUTF8StringEncoding];
                if ([s hasPrefix: @"/"] == NO)
                {
                    [dataM appendBytes: "/" length: 1];
                }
                [dataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                s = [url query];
                if ([s length] > 0)
                {
                    [dataM appendBytes: "?" length: 1];
                    [dataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                s = [NSString stringWithFormat: @" HTTP/%0.1f\r\n", _version];
                [dataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                // dataM add all httpheaders
                d = [request allHTTPHeaderFields];
                e = [d keyEnumerator];
                while ((s = [e nextObject]) != nil)
                {
                    GSMimeHeader      *h;
                    
                    h = [[GSMimeHeader alloc] initWithName: s
                                                     value: [d objectForKey: s]
                                                parameters: nil];
                    [dataM appendData:
                     [h rawMimeDataPreservingCase: YES foldedAt: 0]];
                    RELEASE(h);
                }
                
                /* Use valueForHTTPHeaderField: to check for content-type
                 * header as that does a case insensitive comparison and
                 * we therefore won't end up adding a second header by
                 * accident because the two header names differ in case.
                 */
                if ([[request HTTPMethod] isEqual: @"POST"]
                    && [request valueForHTTPHeaderField:
                        @"Content-Type"] == nil)
                {
                    /* On MacOSX, this is automatically added to POST methods */
                    static char   *ct
                    = "Content-Type: application/x-www-form-urlencoded\r\n";
                    [dataM appendBytes: ct length: strlen(ct)];
                }
                if ([request valueForHTTPHeaderField: @"Host"] == nil)
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
                    [dataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                if (bodylength >= 0 && [request
                                        valueForHTTPHeaderField: @"Content-Length"] == nil)
                {
                    // Here, Content-Length is sure that accurate. cause it is form data length.
                    s = [NSString stringWithFormat: @"Content-Length: %d\r\n", bodylength];
                    [dataM appendData: [s dataUsingEncoding: NSASCIIStringEncoding]];
                }
                // append the end for headers
                [dataM appendBytes: "\r\n" length: 2];	// End of headers
                _writedSoFarData  = dataM;
            }
                // Fall through to do the write, So there is no break here.
            case NSStreamEventHasSpaceAvailable: // The stream can accept bytes for writing.
            {
                int	written;
                BOOL	sent = NO;
                if (_writedSoFarData != nil) // First write header data
                {
                    const unsigned char	*bytes = [_writedSoFarData bytes];
                    unsigned		len = [_writedSoFarData length];
                    
                    written = [output write: bytes + _writeOffset
                                  maxLength: len - _writeOffset];
                    if (written > 0)
                    {
                        _writeOffset += written;
                        if (_writeOffset >= len)
                        {
                            // _writedSoFarData has been output all
                            DESTROY(_writedSoFarData);
                            if (requestDataStream == nil)
                            {
                                requestDataStream = RETAIN([request HTTPBodyStream]);
                                if (requestDataStream == nil)
                                {
                                    NSData	*httpBody = [request HTTPBody];
                                    
                                    if (httpBody != nil)
                                    {
                                        /**
                                         * Why there must have a inputStream to read requestBody.
                                         */
                                        requestDataStream = [NSInputStream alloc];
                                        requestDataStream = [requestDataStream initWithData: httpBody];
                                        [requestDataStream open]; // requestDataStream is for sending body.
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
                else if (requestDataStream != nil) // write http body data
                {
                    if ([requestDataStream hasBytesAvailable])
                    {
                        unsigned char	buffer[BUFSIZ*64];
                        int		len;
                        
                        // read form stream.
                        len = [requestDataStream read: buffer maxLength: sizeof(buffer)];
                        if (len < 0)
                        {
                            [self stopLoading];
                            [client URLProtocol: self didFailWithError:
                             [NSError errorWithDomain: @"can't read body"
                                                 code: 0
                                             userInfo: nil]];
                            return;
                        }
                        else if (len > 0)
                        {
                            // write to output.
                            written = [output write: buffer maxLength: len];
                            if (written > 0)
                            {
                                len -= written;
                                if (len > 0)
                                {
                                    /* Couldn't write it all now, save and try
                                     * again later.
                                     */
                                    _writedSoFarData = [[NSData alloc] initWithBytes:
                                                        buffer + written length: len];
                                    _writeOffset = 0;
                                }
                                else if (len == 0 && ![requestDataStream hasBytesAvailable])
                                {
                                    /* all _body's bytes are read and written
                                     * so we shouldn't wait for another
                                     * opportunity to close _body and set
                                     * the flag 'sent'.
                                     */
                                    [requestDataStream close];
                                    DESTROY(requestDataStream);
                                    sent = YES;
                                }
                            }
                            else if ([output streamStatus]
                                     == NSStreamStatusWriting)
                            {
                                /* Couldn't write it all now, save and try
                                 * again later.
                                 */
                                _writedSoFarData = [[NSData alloc] initWithBytes:
                                                    buffer length: len];
                                _writeOffset = 0;
                            }
                        }
                        else
                        {
                            [requestDataStream close];
                            DESTROY(requestDataStream);
                            sent = YES;
                        }
                    }
                    else
                    {
                        [requestDataStream close];
                        DESTROY(requestDataStream);
                        sent = YES;
                    }
                }
                if (sent == YES)
                {
                    if (_shouldClose == YES)
                    {
                        [output setDelegate: nil];
                        [output removeFromRunLoop:
                         [NSRunLoop currentRunLoop]
                                          forMode: NSDefaultRunLoopMode];
                        [output close];
                        DESTROY(output);
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
    }
    
    if (event == NSStreamEventErrorOccurred)
    {
        NSError	*error = [[[stream streamError] retain] autorelease];
        [self stopLoading];
        [client URLProtocol: self didFailWithError: error];
    }
    else
    {
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
    if (cachedResponse)
    { // handle from cache
    }
    else
    {
        NSURL	*url = [request URL];
        NSHost	*host = [NSHost hostWithName: [url host]];
        
        if (host == nil)
        {
            host = [NSHost hostWithAddress: [url host]];
        }
        [NSStream getStreamsToHost: host
                              port: [[url port] intValue]
                       inputStream: &inputStream
                      outputStream: &output];
        if (inputStream == nil || output == nil)
        {
            [client URLProtocol: self didFailWithError:
             [NSError errorWithDomain: @"can't connect"
                                 code: 0
                             userInfo: nil]];
            return;
        }
        [inputStream retain];
        [output retain];
        if ([[url scheme] isEqualToString: @"https"] == YES)
        {
            [inputStream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                              forKey: NSStreamSocketSecurityLevelKey];
            [output setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                         forKey: NSStreamSocketSecurityLevelKey];
        }
        [inputStream setDelegate: self];
        [output setDelegate: self];
        [inputStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                          forMode: NSDefaultRunLoopMode];
        // set socket options for ftps requests
        [inputStream open];
        [output open];
    }
}

- (void) stopLoading
{
    if (inputStream)
    {
        [inputStream setDelegate: nil];
        [output setDelegate: nil];
        [inputStream removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
        [output removeFromRunLoop: [NSRunLoop currentRunLoop]
                          forMode: NSDefaultRunLoopMode];
        [inputStream close];
        [output close];
        DESTROY(inputStream);
        DESTROY(output);
    }
}

- (void) stream: (NSStream *) stream handleEvent: (NSStreamEvent) event
{
    if (stream == inputStream)
    {
        switch(event)
        {
            case NSStreamEventHasBytesAvailable:
            {
                NSLog(@"FTP input stream has bytes available");
                // implement FTP protocol
                //			[client URLProtocol: self didLoadData: [NSData dataWithBytes: buffer length: len]];	// notify
                return;
            }
            case NSStreamEventEndEncountered: 	// can this occur in parallel to NSStreamEventHasBytesAvailable???
                NSLog(@"FTP input stream did end");
                [client URLProtocolDidFinishLoading: self];
                return;
            case NSStreamEventOpenCompleted:
                // prepare to receive header
                NSLog(@"FTP input stream opened");
                return;
            default:
                break;
        }
    }
    else if (stream == output)
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
        [client URLProtocol: self didFailWithError: [stream streamError]];
    }
    else
    {
        NSLog(@"Unexpected event %"PRIuPTR" ignored on stream %@ of %@",
              event, stream, self);
    }
}

@end


/**
 * FileURLProtocol is just loading file data and call corresponding delegate method.
 There is no complex data loading progress. The response is fix with most parameter.
 All delegate is called in start loading method.
 */

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
    
    data = [NSData dataWithContentsOfFile: [[request URL] path]
            /* options: error: - don't use that because it is based on self */];
    if (data == nil)
    {
        [client URLProtocol: self didFailWithError:
         [NSError errorWithDomain: @"can't load file" code: 0 userInfo:
          [NSDictionary dictionaryWithObjectsAndKeys:
           [request URL], @"URL",
           [[request URL] path], @"path",
           nil]]];
        return;
    }
    
    /* FIXME ... maybe should infer MIME type and encoding from extension or BOM
     */
    r = [[NSURLResponse alloc] initWithURL: [request URL]
                                  MIMEType: @"text/html"
                     expectedContentLength: [data length]
                          textEncodingName: @"unknown"];
    [client URLProtocol: self
     didReceiveResponse: r
     cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [client URLProtocol: self didLoadData: data];
    [client URLProtocolDidFinishLoading: self];
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
    NSString      *spec = [[request URL] resourceSpecifier];
    NSRange       comma = [spec rangeOfString:@","];
    NSEnumerator  *types;
    NSString      *type;
    BOOL          base64 = NO;
    
    if (comma.location == NSNotFound)
    {
        NSDictionary      *ui;
        NSError           *error;
        
        ui = [NSDictionary dictionaryWithObjectsAndKeys:
              [request URL], @"URL",
              [[request URL] path], @"path",
              nil];
        error = [NSError errorWithDomain: @"can't load data"
                                    code: 0
                                userInfo: ui];
        [client URLProtocol: self didFailWithError: error];
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
    r = [[NSURLResponse alloc] initWithURL: [request URL]
                                  MIMEType: mime
                     expectedContentLength: [data length]
                          textEncodingName: encoding];
    
    [client URLProtocol: self
     didReceiveResponse: r
     cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [client URLProtocol: self didLoadData: data];
    [client URLProtocolDidFinishLoading: self];
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
    r = [[NSURLResponse alloc] initWithURL: [request URL]
                                  MIMEType: @"text/html"
                     expectedContentLength: 0
                          textEncodingName: @"utf-8"];
    [client URLProtocol: self
     didReceiveResponse: r
     cacheStoragePolicy: NSURLRequestUseProtocolCachePolicy];
    [client URLProtocol: self didLoadData: data];
    [client URLProtocolDidFinishLoading: self];
    RELEASE(r);
}

- (void) stopLoading
{
    return;
}

@end
