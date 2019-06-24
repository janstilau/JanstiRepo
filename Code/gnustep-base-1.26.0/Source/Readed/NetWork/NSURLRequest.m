#import "common.h"

#define	EXPOSE_NSURLRequest_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#import "Foundation/NSCoder.h"

/* Defines to get easy access to internals from mutable/immutable
 * versions of the class and from categories.
 */

@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary
@end

@implementation	NSURLRequest

+ (id) allocWithZone: (NSZone*)z
{
    NSURLRequest	*aRequest = [super allocWithZone: z];
    return aRequest;
}

+ (id) requestWithURL: (NSURL *)URL
{
    return [self requestWithURL: URL
                    cachePolicy: NSURLRequestUseProtocolCachePolicy
                timeoutInterval: 60.0];
}

+ (id) requestWithURL: (NSURL *)URL
          cachePolicy: (NSURLRequestCachePolicy)cachePolicy
      timeoutInterval: (NSTimeInterval)timeoutInterval
{
    NSURLRequest	*aRequest = [[self class] allocWithZone: NSDefaultMallocZone()];
    
    aRequest = [aRequest initWithURL: URL
           cachePolicy: cachePolicy
       timeoutInterval: timeoutInterval];
    return AUTORELEASE(aRequest);
}

- (NSURLRequestCachePolicy) cachePolicy
{
    return cachePolicy;
}

- (id) copyWithZone: (NSZone*)z
{
    NSURLRequest	*aRequest;
    
    if (NSShouldRetainWithZone(self, z) == YES
        && [self isKindOfClass: [NSMutableURLRequest class]] == NO)
    {
        aRequest = RETAIN(self);
    }
    else
    {
        aRequest = [[self class] allocWithZone: z];
        aRequest = [aRequest initWithURL: [self URL]
               cachePolicy: [self cachePolicy]
           timeoutInterval: [self timeoutInterval]];
        if (aRequest != nil)
        {
            // copy every item. just like business code.
            aRequest->properties = [properties mutableCopy];
            ASSIGN(aRequest->mainDocumentURL, mainDocumentURL);
            ASSIGN(aRequest->body, body);
            ASSIGN(aRequest->bodyStream, bodyStream);
            ASSIGN(aRequest->method, method);
            aRequest->shouldHandleCookies = shouldHandleCookies;
            aRequest->debug = debug;
            aRequest->headers = [headers mutableCopy];
        }
    }
    return aRequest;
}

- (NSString*) description
{
    return [NSString stringWithFormat: @"<%@ %@>",
            NSStringFromClass([self class]), [[self URL] absoluteString]];
}

- (NSUInteger) hash
{
    return [URL hash];
}

- (id) init
{
    return [self initWithURL: nil];
}

- (id) initWithURL: (NSURL *)URL
{
    return [self initWithURL: URL
                 cachePolicy: NSURLRequestUseProtocolCachePolicy
             timeoutInterval: 60.0];
}

- (id) initWithURL: (NSURL *)URL
       cachePolicy: (NSURLRequestCachePolicy)cachePolicy
   timeoutInterval: (NSTimeInterval)timeoutInterval
{
    if ([URL isKindOfClass: [NSURL class]] == NO)
    {
        URL = nil;
    }
    if ((self = [super init]) != nil)
    {
        URL = RETAIN(URL);
        cachePolicy = cachePolicy;
        timeoutInterval = timeoutInterval;
        mainDocumentURL = nil;
        method = @"GET";
        shouldHandleCookies = YES;
    }
    return self;
}

- (BOOL) isEqual: (id)aRequest
{
//    if ([aRequest isKindOfClass: [NSURLRequest class]] == NO)
//    {
//        return NO;
//    }
//    if (URL != aRequest->URL
//        && [URL isEqual: aRequest->URL] == NO)
//    {
//        return NO;
//    }
//    if (mainDocumentURL != aRequest->mainDocumentURL
//        && [mainDocumentURL isEqual: aRequest->mainDocumentURL] == NO)
//    {
//        return NO;
//    }
//    if (method != aRequest->method
//        && [method isEqual: aRequest->method] == NO)
//    {
//        return NO;
//    }
//    if (body != aRequest->body
//        && [body isEqual: aRequest->body] == NO)
//    {
//        return NO;
//    }
//    if (bodyStream != aRequest->bodyStream
//        && [bodyStream isEqual: aRequest->bodyStream] == NO)
//    {
//        return NO;
//    }
//    if (properties != aRequest->properties
//        && [properties isEqual: aRequest->properties] == NO)
//    {
//        return NO;
//    }
//    if (headers != aRequest->headers
//        && [headers isEqual: aRequest->headers] == NO)
//    {
//        return NO;
//    }
    return YES;
}

- (NSURL *) mainDocumentURL
{
    return mainDocumentURL;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
    NSMutableURLRequest	*aRequest;
    
    aRequest = [NSMutableURLRequest allocWithZone: z];
    aRequest = [aRequest initWithURL: [self URL]
           cachePolicy: [self cachePolicy]
       timeoutInterval: [self timeoutInterval]];
    if (aRequest != nil)
    {
        [aRequest setMainDocumentURL: mainDocumentURL];
        aRequest->properties = [properties mutableCopy];
        ASSIGN(aRequest->mainDocumentURL, mainDocumentURL);
        ASSIGN(aRequest->body, body);
        ASSIGN(aRequest->bodyStream, bodyStream);
        ASSIGN(aRequest->method, method);
        aRequest->shouldHandleCookies = shouldHandleCookies;
        aRequest->debug = debug;
        aRequest->headers = [headers mutableCopy];
    }
    return aRequest;
}

- (int) setDebug: (int)flag
{
    int   old = debug;
    
    debug = flag ? YES : NO;
    return old;
}

- (NSTimeInterval) timeoutInterval
{
    return timeoutInterval;
}

- (NSURL *) URL
{
    return URL;
}

@end


@implementation NSMutableURLRequest

- (void) setCachePolicy: (NSURLRequestCachePolicy)cachePolicy
{
    cachePolicy = cachePolicy;
}

- (void) setMainDocumentURL: (NSURL *)URL
{
    ASSIGN(mainDocumentURL, URL);
}

- (void) setTimeoutInterval: (NSTimeInterval)seconds
{
    timeoutInterval = seconds;
}

- (void) setURL: (NSURL *)URL
{
    ASSIGN(URL, URL);
}

@end

@implementation NSURLRequest (NSHTTPURLRequest)

- (NSDictionary *) allHTTPHeaderFields
{
    NSDictionary	*fields;
    
    if (headers == nil)
    {
        fields = [NSDictionary dictionary];
    }
    else
    {
        fields = [NSDictionary dictionaryWithDictionary: headers];
    }
    return fields;
}

- (NSData *) HTTPBody
{
    return body;
}

- (NSInputStream *) HTTPBodyStream
{
    return bodyStream;
}

- (NSString *) HTTPMethod
{
    return method;
}

- (BOOL) HTTPShouldHandleCookies
{
    return shouldHandleCookies;
}

- (NSString *) valueForHTTPHeaderField: (NSString *)field
{
    return [headers objectForKey: field];
}

@end



@implementation NSMutableURLRequest (NSMutableHTTPURLRequest)

- (void) addValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
    NSString	*old = [self valueForHTTPHeaderField: field];
    
    if (old != nil)
    {
        value = [old stringByAppendingFormat: @",%@", value];
    }
    [self setValue: value forHTTPHeaderField: field];
}

- (void) setAllHTTPHeaderFields: (NSDictionary *)headerFields
{
    NSEnumerator	*enumerator = [headerFields keyEnumerator];
    NSString	*field;
    
    while ((field = [enumerator nextObject]) != nil)
    {
        id	value = [headerFields objectForKey: field];
        
        if ([value isKindOfClass: [NSString class]] == YES)
        {
            [self setValue: (NSString*)value forHTTPHeaderField: field];
        }
    }
}

- (void) setHTTPBodyStream: (NSInputStream *)inputStream
{
    DESTROY(body);
    ASSIGN(bodyStream, inputStream);
}

- (void) setHTTPBody: (NSData *)data
{
    DESTROY(bodyStream);
    ASSIGNCOPY(body, data);
}

- (void) setHTTPMethod: (NSString *)method
{
    /* NB. I checked MacOS-X 4.2, and this method actually lets you set any
     * copyable value (including non-string classes), but setting nil is
     * equivalent to resetting to the default value of 'GET'
     */
    if (method == nil)
    {
        method = @"GET";
    }
    ASSIGNCOPY(method, method);
}

- (void) setHTTPShouldHandleCookies: (BOOL)should
{
    shouldHandleCookies = should;
}

- (void) setValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
    if (headers == nil)
    {
        headers = [_GSMutableInsensitiveDictionary new];
    }
    [headers setObject: value forKey: field];
}

@end

@implementation	NSURLRequest (Private)

- (BOOL) _debug
{
    return debug;
}

- (id) _propertyForKey: (NSString*)key
{
    return [properties objectForKey: key];
}

- (void) _setProperty: (id)value forKey: (NSString*)key
{
    if (properties == nil)
    {
        properties = [NSMutableDictionary new];
        [properties setObject: value forKey: key];
    }
}
@end
