#import "common.h"

#define	EXPOSE_NSURLRequest_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#import "Foundation/NSCoder.h"


typedef struct {
  NSData			*body;
  NSInputStream			*bodyStream;
    
  NSString			*method;
  NSMutableDictionary		*headers;
    
  BOOL				shouldHandleCookies;
  BOOL                          debug;
    
  NSURL				*URL;
  NSURL				*mainDocumentURL;
    
  NSURLRequestCachePolicy	cachePolicy;
  NSTimeInterval		timeoutInterval;
  NSMutableDictionary		*properties;
} Internal; // NSURLRequest 仅仅是一个数据类, 真正的根据这些数据进行操作的, 还是要在网络操作操作类中.
 
/* Defines to get easy access to internals from mutable/immutable
 * versions of the class and from categories.
 */
#define	this	((Internal*)(self->_NSURLRequestInternal))
#define	inst	((Internal*)(((NSURLRequest*)o)->_NSURLRequestInternal))

@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary
@end

@implementation	NSURLRequest

+ (id) allocWithZone: (NSZone*)z //  这里不明白为啥一定要写在 allocWithZone 方法里面.
{
  NSURLRequest	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLRequestInternal = NSZoneCalloc(z, 1, sizeof(Internal)); // initializes it to all bits zero
    }
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
  return this->cachePolicy;
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
	  inst->properties = [this->properties mutableCopy];
	  ASSIGN(inst->mainDocumentURL, this->mainDocumentURL);
	  ASSIGN(inst->body, this->body);
	  ASSIGN(inst->bodyStream, this->bodyStream);
	  ASSIGN(inst->method, this->method);
	  inst->shouldHandleCookies = this->shouldHandleCookies;
	  inst->debug = this->debug;
          inst->headers = [this->headers mutableCopy];
	} // 内部元素一顿复制操作.
    }
  return o;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->body);
      RELEASE(this->bodyStream);
      RELEASE(this->method);
      RELEASE(this->URL);
      RELEASE(this->mainDocumentURL);
      RELEASE(this->properties);
      RELEASE(this->headers);
      NSZoneFree([self zone], this);
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
  return [this->URL hash];
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
      this->URL = RETAIN(URL);
      this->cachePolicy = cachePolicy;
      this->timeoutInterval = timeoutInterval;
      this->mainDocumentURL = nil;
      this->method = @"GET";// 默认 get
      this->shouldHandleCookies = YES;
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
  if (this->URL != inst->URL
    && [this->URL isEqual: inst->URL] == NO)
    {
      return NO;
    }
  if (this->mainDocumentURL != inst->mainDocumentURL
    && [this->mainDocumentURL isEqual: inst->mainDocumentURL] == NO)
    {
      return NO;
    }
  if (this->method != inst->method
    && [this->method isEqual: inst->method] == NO)
    {
      return NO;
    }
  if (this->body != inst->body
    && [this->body isEqual: inst->body] == NO)
    {
      return NO;
    }
  if (this->bodyStream != inst->bodyStream
    && [this->bodyStream isEqual: inst->bodyStream] == NO)
    {
      return NO;
    }
  if (this->properties != inst->properties
    && [this->properties isEqual: inst->properties] == NO)
    {
      return NO;
    }
  if (this->headers != inst->headers
    && [this->headers isEqual: inst->headers] == NO)
    {
      return NO;
    }
  return YES;
}

- (NSURL *) mainDocumentURL
{
  return this->mainDocumentURL; // this 指向了 internal
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
      [o setMainDocumentURL: this->mainDocumentURL];
      inst->properties = [this->properties mutableCopy];
      ASSIGN(inst->mainDocumentURL, this->mainDocumentURL);
      ASSIGN(inst->body, this->body);
      ASSIGN(inst->bodyStream, this->bodyStream);
      ASSIGN(inst->method, this->method);
      inst->shouldHandleCookies = this->shouldHandleCookies;
      inst->debug = this->debug;
      inst->headers = [this->headers mutableCopy];
    } // 一顿复制操作. mutableCopy
  return o;
}

- (int) setDebug: (int)flag
{
  int   old = this->debug;

  this->debug = flag ? YES : NO;
  return old;
}

- (NSTimeInterval) timeoutInterval
{
  return this->timeoutInterval;
}

- (NSURL *) URL
{
  return this->URL;
}

@end


@implementation NSMutableURLRequest

- (void) setCachePolicy: (NSURLRequestCachePolicy)cachePolicy
{
  this->cachePolicy = cachePolicy;
}

- (void) setMainDocumentURL: (NSURL *)URL
{
  ASSIGN(this->mainDocumentURL, URL);
}

- (void) setTimeoutInterval: (NSTimeInterval)seconds
{
  this->timeoutInterval = seconds;
}

- (void) setURL: (NSURL *)URL
{
  ASSIGN(this->URL, URL);
}

@end

@implementation NSURLRequest (NSHTTPURLRequest)

- (NSDictionary *) allHTTPHeaderFields
{
  NSDictionary	*fields;

  if (this->headers == nil)
    {
      fields = [NSDictionary dictionary];
    }
  else
    {
      fields = [NSDictionary dictionaryWithDictionary: this->headers];
    }
    // 所以, headers 只不过是一个字典而已, 里面可以放任意的内容.
  return fields;
}

- (NSData *) HTTPBody
{
  return this->body;
}

- (NSInputStream *) HTTPBodyStream
{
  return this->bodyStream;
}

- (NSString *) HTTPMethod
{
  return this->method;
}

- (BOOL) HTTPShouldHandleCookies
{
  return this->shouldHandleCookies;
}

- (NSString *) valueForHTTPHeaderField: (NSString *)field
{
  return [this->headers objectForKey: field];
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
  DESTROY(this->body);
  ASSIGN(this->bodyStream, inputStream);
}

- (void) setHTTPBody: (NSData *)data
{
  DESTROY(this->bodyStream);
  ASSIGNCOPY(this->body, data);
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
  ASSIGNCOPY(this->method, method);
}

- (void) setHTTPShouldHandleCookies: (BOOL)should
{
  this->shouldHandleCookies = should;
}

- (void) setValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
  if (this->headers == nil)
    {
      this->headers = [_GSMutableInsensitiveDictionary new];
    }
  [this->headers setObject: value forKey: field];
}

@end

@implementation	NSURLRequest (Private)

- (BOOL) _debug
{
  return this->debug;
}

- (id) _propertyForKey: (NSString*)key
{
  return [this->properties objectForKey: key];
}

- (void) _setProperty: (id)value forKey: (NSString*)key
{
  if (this->properties == nil)
    {
      this->properties = [NSMutableDictionary new];
      [this->properties setObject: value forKey: key];
    }
}
@end
