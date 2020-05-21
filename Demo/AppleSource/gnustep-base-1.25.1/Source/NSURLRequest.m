#import "common.h"

#define	EXPOSE_NSURLRequest_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#import "Foundation/NSCoder.h"


/* Defines to get easy access to internals from mutable/immutable
 * versions of the class and from categories.
 */
#define	self	((Internal*)(self->_NSURLRequestInternal))
#define	inst	((Internal*)(((NSURLRequest*)o)->_NSURLRequestInternal))

@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary

@end

@implementation	NSURLRequest

+ (id) allocWithZone: (NSZone*)z //  这里不明白为啥一定要写在 allocWithZone 方法里面.
{
    NSURLRequest	*o = [super allocWithZone: z];
    return o;
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
    NSURLRequest	*o = [[self class] allocWithZone: NSDefaultMallocZone()];
    
    o = [o initWithURL: URL
           cachePolicy: cachePolicy
       timeoutInterval: timeoutInterval];
    return AUTORELEASE(o);
}

- (NSURLRequestCachePolicy) cachePolicy
{
    return self->cachePolicy;
}

- (id) copyWithZone: (NSZone*)z
{
    NSURLRequest	*o;
    
    if (NSShouldRetainWithZone(self, z) == YES
        && [self isKindOfClass: [NSMutableURLRequest class]] == NO)
    {
        o = RETAIN(self); // 不可变对象, 直接自身.
    }
    else
    {
        o = [[self class] allocWithZone: z];
        o = [o initWithURL: [self URL]
               cachePolicy: [self cachePolicy]
           timeoutInterval: [self timeoutInterval]];
        if (o != nil)
        {
            inst->properties = [self->properties mutableCopy];
            ASSIGN(inst->mainDocumentURL, self->mainDocumentURL);
            ASSIGN(inst->body, self->body);
            ASSIGN(inst->bodyStream, self->bodyStream);
            ASSIGN(inst->method, self->method);
            inst->shouldHandleCookies = self->shouldHandleCookies;
            inst->debug = self->debug;
            inst->headers = [self->headers mutableCopy];
        } // 内部元素一顿复制操作.
    }
    return o;
}

- (void) dealloc
{
    if (self != 0)
    {
        RELEASE(self->body);
        RELEASE(self->bodyStream);
        RELEASE(self->method);
        RELEASE(self->URL);
        RELEASE(self->mainDocumentURL);
        RELEASE(self->properties);
        RELEASE(self->headers);
        NSZoneFree([self zone], self);
    }
    [super dealloc];
}

- (NSString*) description
{
    return [NSString stringWithFormat: @"<%@ %@>",
            NSStringFromClass([self class]), [[self URL] absoluteString]];
}

- (NSUInteger) hash // 这里, Request 的 hash 是通过URL 的 hash 达成的. 在 MC 的代码里面, 去除时间戳这些东西, 其实也是为了这些, 因为 在 get 的时候, 所有的参数都是URL 的一部分.
{
    return [self->URL hash];
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
        self->URL = RETAIN(URL);
        self->cachePolicy = cachePolicy;
        self->timeoutInterval = timeoutInterval;
        self->mainDocumentURL = nil;
        self->method = @"GET";// 默认 get
        self->shouldHandleCookies = YES;
    }
    // 所以, 这其实就是一顿记录的事情.
    return self;
}

- (BOOL) isEqual: (id)o
{
    if ([o isKindOfClass: [NSURLRequest class]] == NO)
    {
        return NO;
    }
    if (self->URL != inst->URL
        && [self->URL isEqual: inst->URL] == NO)
    {
        return NO;
    }
    if (self->mainDocumentURL != inst->mainDocumentURL
        && [self->mainDocumentURL isEqual: inst->mainDocumentURL] == NO)
    {
        return NO;
    }
    if (self->method != inst->method
        && [self->method isEqual: inst->method] == NO)
    {
        return NO;
    }
    if (self->body != inst->body
        && [self->body isEqual: inst->body] == NO)
    {
        return NO;
    }
    if (self->bodyStream != inst->bodyStream
        && [self->bodyStream isEqual: inst->bodyStream] == NO)
    {
        return NO;
    }
    if (self->properties != inst->properties
        && [self->properties isEqual: inst->properties] == NO)
    {
        return NO;
    }
    if (self->headers != inst->headers
        && [self->headers isEqual: inst->headers] == NO)
    {
        return NO;
    }
    return YES;
}

- (NSURL *) mainDocumentURL
{
    return self->mainDocumentURL; // self 指向了 internal
}

- (id) mutableCopyWithZone: (NSZone*)z
{
    NSMutableURLRequest	*o;
    
    o = [NSMutableURLRequest allocWithZone: z];
    o = [o initWithURL: [self URL]
           cachePolicy: [self cachePolicy]
       timeoutInterval: [self timeoutInterval]];
    if (o != nil)
    {
        [o setMainDocumentURL: self->mainDocumentURL];
        inst->properties = [self->properties mutableCopy];
        ASSIGN(inst->mainDocumentURL, self->mainDocumentURL);
        ASSIGN(inst->body, self->body);
        ASSIGN(inst->bodyStream, self->bodyStream);
        ASSIGN(inst->method, self->method);
        inst->shouldHandleCookies = self->shouldHandleCookies;
        inst->debug = self->debug;
        inst->headers = [self->headers mutableCopy];
    } // 一顿复制操作. mutableCopy
    return o;
}

- (int) setDebug: (int)flag
{
    int   old = self->debug;
    
    self->debug = flag ? YES : NO;
    return old;
}

- (NSTimeInterval) timeoutInterval
{
    return self->timeoutInterval;
}

- (NSURL *) URL
{
    return self->URL;
}

@end


@implementation NSMutableURLRequest

- (void) setCachePolicy: (NSURLRequestCachePolicy)cachePolicy
{
    self->cachePolicy = cachePolicy;
}

- (void) setMainDocumentURL: (NSURL *)URL
{
    ASSIGN(self->mainDocumentURL, URL);
}

- (void) setTimeoutInterval: (NSTimeInterval)seconds
{
    self->timeoutInterval = seconds;
}

- (void) setURL: (NSURL *)URL
{
    ASSIGN(self->URL, URL);
}

@end

@implementation NSURLRequest (NSHTTPURLRequest)

- (NSDictionary *) allHTTPHeaderFields
{
    NSDictionary	*fields;
    
    if (self->headers == nil)
    {
        fields = [NSDictionary dictionary];
    }
    else
    {
        fields = [NSDictionary dictionaryWithDictionary: self->headers];
    }
    // 所以, headers 只不过是一个字典而已, 里面可以放任意的内容.
    return fields;
}

- (NSData *) HTTPBody
{
    return self->body;
}

- (NSInputStream *) HTTPBodyStream
{
    return self->bodyStream;
}

- (NSString *) HTTPMethod
{
    return self->method;
}

- (BOOL) HTTPShouldHandleCookies
{
    return self->shouldHandleCookies;
}

- (NSString *) valueForHTTPHeaderField: (NSString *)field
{
    return [self->headers objectForKey: field];
}

@end



@implementation NSMutableURLRequest (NSMutableHTTPURLRequest)

- (void) addValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
    NSString	*old = [self valueForHTTPHeaderField: field];
    
    if (old != nil)
    {
        value = [old stringByAppendingFormat: @",%@", value]; // 这里, addValue , 证明协议头里面是可以放多个值得.
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
    DESTROY(self->body);
    ASSIGN(self->bodyStream, inputStream);
}

- (void) setHTTPBody: (NSData *)data
{
    DESTROY(self->bodyStream);
    ASSIGNCOPY(self->body, data);
}

- (void) setHTTPMethod: (NSString *)method
{
    /* NB. I checked MacOS-X 4.2, and self method actually lets you set any
     * copyable value (including non-string classes), but setting nil is
     * equivalent to resetting to the default value of 'GET'
     */
    if (method == nil)
    {
        method = @"GET";
    }
    ASSIGNCOPY(self->method, method);
}

- (void) setHTTPShouldHandleCookies: (BOOL)should
{
    self->shouldHandleCookies = should;
}

- (void) setValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
    if (self->headers == nil)
    {
        self->headers = [_GSMutableInsensitiveDictionary new];
    }
    [self->headers setObject: value forKey: field];
}

@end

@implementation	NSURLRequest (Private)

- (BOOL) _debug
{
    return self->debug;
}

- (id) _propertyForKey: (NSString*)key
{
    return [self->properties objectForKey: key];
}

- (void) _setProperty: (id)value forKey: (NSString*)key
{
    if (self->properties == nil)
    {
        self->properties = [NSMutableDictionary new];
        [self->properties setObject: value forKey: key];
    }
}
@end
