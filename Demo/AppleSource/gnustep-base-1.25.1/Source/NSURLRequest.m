#import "common.h"

#define	EXPOSE_NSURLRequest_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"
#import "NSMutableDictionary.h"

#import "Foundation/NSCoder.h"

@interface NSMutableDictionary:NSObject
@end

@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary

@end

@implementation	NSURLRequest

- (NSURLRequestCachePolicy) cachePolicy
{
    return self->cachePolicy;
}

/*
 因为这是在 MRC 环境, 所以, 这里 dealloc 会进行 Release 的操作.
 */
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

/*
  这里, Request 的 hash 是通过URL 的 hash 达成的. 在 MC 的代码里面, 去除时间戳这些东西, 其实也是为了这些, 因为 在 get 的时候, 所有的参数都是URL 的一部分.
 */
- (int) hash
{
    return [self->URL hash];
}

/*
 初始化方法的代理使用.
 */
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
    return self;
}

- (BOOL) isEqual: (NSURLRequest *)o
{
    /*
        一顿的判断操作.
     */
    if ([o isKindOfClass: [NSURLRequest class]] == NO)
    {
        return NO;
    }
    if (self->URL != o->URL
        && [self->URL isEqual: o->URL] == NO)
    {
        return NO;
    }
    if (self->mainDocumentURL != o->mainDocumentURL
        && [self->mainDocumentURL isEqual: o->mainDocumentURL] == NO)
    {
        return NO;
    }
    if (self->method != o->method
        && [self->method isEqual: o->method] == NO)
    {
        return NO;
    }
    if (self->body != o->body
        && [self->body isEqual: o->body] == NO)
    {
        return NO;
    }
    if (self->bodyStream != o->bodyStream
        && [self->bodyStream isEqual: o->bodyStream] == NO)
    {
        return NO;
    }
    if (self->properties != o->properties
        && [self->properties isEqual: o->properties] == NO)
    {
        return NO;
    }
    if (self->headers != o->headers
        && [self->headers isEqual: o->headers] == NO)
    {
        return NO;
    }
    return YES;
}

- (NSURL *) mainDocumentURL
{
    return self->mainDocumentURL; // self 指向了 internal
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
/*
 从以上就看出来了, 所谓的 Request , 就是一个数据类而已.
 */

@end


@implementation NSMutableURLRequest

/*
 所谓的 Mutable 就是将 set 的权力暴露出来了.
 */

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
