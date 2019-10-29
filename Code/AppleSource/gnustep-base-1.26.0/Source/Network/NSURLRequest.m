#import "common.h"

#define	EXPOSE_NSURLRequest_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"
#import "Foundation/NSCoder.h"

@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary
@end

@implementation	NSURLRequest

+ (id) allocWithZone: (NSZone*)z
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

- (void) dealloc
{
  [super dealloc];
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"<%@ %@>",
    NSStringFromClass([self class]), [[self URL] absoluteString]];
}

- (NSUInteger) hash
{
  return [self->URL hash]; // URL 的 hash. 这也是为什么, 在 Cache 的时候 要删除 timeStamp 这一个经常变化的参数的值.
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
      self->method = @"GET"; // 默认是 Get 方式.
      self->shouldHandleCookies = YES;
    }
  return self;
}

- (BOOL) isEqual: (NSURLRequest *)o
{
  if ([o isKindOfClass: [NSURLRequest class]] == NO) // 首先, 判断类型
    {
      return NO;
    }
  if (self->URL != o->URL
    && [self->URL isEqual: o->URL] == NO)// 然后. 判断  URL 是否相等.
    {
      return NO;
    }
  if (self->mainDocumentURL != o->mainDocumentURL
    && [self->mainDocumentURL isEqual: o->mainDocumentURL] == NO) // 判断 mainDocumentUrl, 干什么的???
    {
      return NO;
    }
  if (self->method != o->method
    && [self->method isEqual: o->method] == NO) // 判断 method
    {
      return NO;
    }
  if (self->body != o->body
    && [self->body isEqual: o->body] == NO) // 判断 body, 也就是一个 NSDate
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
  return self->mainDocumentURL;
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
      o->properties = [self->properties mutableCopy];
      ASSIGN(o->mainDocumentURL, self->mainDocumentURL);
      ASSIGN(o->body, self->body);
      ASSIGN(o->bodyStream, self->bodyStream);
      ASSIGN(o->method, self->method);
      o->shouldHandleCookies = self->shouldHandleCookies;
      o->debug = self->debug;
      o->headers = [self->headers mutableCopy];
    }
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
/* NB. I checked MacOS-X 4.2, and this method actually lets you set any
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
