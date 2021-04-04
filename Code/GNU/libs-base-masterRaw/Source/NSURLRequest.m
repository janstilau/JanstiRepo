#import "common.h"

#define	EXPOSE_NSURLRequest_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#import "Foundation/NSCoder.h"

@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary
@end

@implementation	NSURLRequest


- (NSURLRequestCachePolicy) cachePolicy
{
    return self->cachePolicy;
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
        self->method = @"GET";
        self->shouldHandleCookies = YES;
    }
    return self;
}

- (BOOL) isEqual: (id)o
{
    return YES;
}

- (NSURL *) mainDocumentURL
{
    return self->mainDocumentURL;
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
    return fields;
}

- (NSData *) HTTPBody
{
    return nil;
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
    ASSIGN(self->bodyStream, inputStream);
}

- (void) setHTTPBody: (NSData *)data
{
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
