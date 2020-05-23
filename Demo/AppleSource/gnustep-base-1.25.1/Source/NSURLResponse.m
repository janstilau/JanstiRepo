#import "common.h"

#define	EXPOSE_NSURLResponse_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSScanner.h"
#import "NSCallBacks.h"
#import "GNUstepBase/GSMime.h"

@interface NSMutableDictionary:NSObject
@end

@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary
@end


// 这其实仅仅是一个数据类而已.

@implementation	NSURLResponse (Private)

- (void) _setHeaders: (id)headers
{
  NSEnumerator	*e;
  NSString	*v;

  if ([headers isKindOfClass: [NSDictionary class]] == YES)
    {
      NSString		*k;

      e = [(NSDictionary*)headers keyEnumerator];
      while ((k = [e nextObject]) != nil)
	{
	  v = [(NSDictionary*)headers objectForKey: k];
	  [self _setValue: v forHTTPHeaderField: k];
	}
    }
  else if ([headers isKindOfClass: [NSArray class]] == YES)
    {
      GSMimeHeader	*h;

      e = [(NSArray*)headers objectEnumerator];
      while ((h = [e nextObject]) != nil)
        {
	  NSString	*n = [h namePreservingCase: YES];
	  NSString	*v = [h fullValue];

	  [self _setValue: v forHTTPHeaderField: n];
	}
    }
}
- (void) _setStatusCode: (NSInteger)code text: (NSString*)text
{
  self->statusCode = code;
  ASSIGNCOPY(self->statusText, text);
}
- (void) _setValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
  if (self->headers == 0)
    {
      self->headers = [_GSMutableInsensitiveDictionary new];
    }
  [self->headers setObject: value forKey: field];
}
- (NSString *) _valueForHTTPHeaderField: (NSString *)field
{
  return [self->headers objectForKey: field];
}
@end

// Response 中的 data , 是不会伴随到这个类里面的, 响应里面的数据, 要么是随着数据一点点的下载到本地, 要么是在回调中一次性的拿到.

@implementation	NSURLResponse

- (long long) expectedContentLength
{
  return self->expectedContentLength;
}

/**
 * Initialises the receiver with the URL, MIMEType, expected length and
 * text encoding name provided.
 */
- (id) initWithURL: (NSURL *)URL
  MIMEType: (NSString *)MIMEType
  expectedContentLength: (int)length
  textEncodingName: (NSString *)name
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(self->URL, URL);
      ASSIGNCOPY(self->MIMEType, MIMEType);
      ASSIGNCOPY(self->textEncodingName, name);
      self->expectedContentLength = length;
    }
  return self;
}

- (id) initWithURL: (NSURL*)URL
	statusCode: (int)statusCode
       HTTPVersion: (NSString*)HTTPVersion
      headerFields: (NSDictionary*)headerFields
{
  self = [self initWithURL: URL
		  MIMEType: nil
     expectedContentLength: NSURLResponseUnknownLength // (long long - 1)
	  textEncodingName: nil];
  if (nil != self)
    {
      self->statusCode = statusCode;
      self->headers = [headerFields copy];
    }
  return self;
}

- (NSString *) MIMEType
{
  return self->MIMEType;
}

/**
 * Returns a suggested file name for storing the response data, with
 * suggested names being found in the following order:<br />
 * <list>
 *   <item>content-disposition header</item>
 *   <item>last path component of URL</item>
 *   <item>host name from URL</item>
 *   <item>'unknown'</item>
 * </list>
 * If possible, an extension based on the MIME type of the response
 * is also appended.<br />
 * The result should always be a valid file name.
 */
- (NSString *) suggestedFilename
{
  NSString	*disposition = [self _valueForHTTPHeaderField: @"content-disposition"];
  NSString	*name = nil;

  if (disposition != nil)
    {
      GSMimeParser	*p;
      GSMimeHeader	*h;
      NSScanner		*sc;

      // Try to get name from content disposition header.
      p = AUTORELEASE([GSMimeParser new]);
      h = [[GSMimeHeader alloc] initWithName: @"content-displosition"
				       value: disposition];
      IF_NO_GC([h autorelease];)
      sc = [NSScanner scannerWithString: [h value]];
      if ([p scanHeaderBody: sc into: h] == YES)
        {
	  name = [h parameterForKey: @"filename"];
	  name = [name stringByDeletingPathExtension];
	}
    }

  if ([name length] == 0)
    {
      name = [[[self URL] absoluteString] lastPathComponent];
      name = [name stringByDeletingPathExtension];
    }
  if ([name length] == 0)
    {
      name = [[self URL] host];
    }
  if ([name length] == 0)
    {
      name = @"unknown";
    }

  return name;
}

- (NSString *) textEncodingName
{
  return self->textEncodingName;
}

- (NSURL *) URL
{
  return self->URL;
}

@end


@implementation NSHTTPURLResponse

+ (NSString *) localizedStringForStatusCode: (NSInteger)statusCode
{
// FIXME ... put real responses in here
  return [NSString stringWithFormat: @"%"PRIdPTR, statusCode];
}

- (NSDictionary *) allHeaderFields
{
  return AUTORELEASE([self->headers copy]);
}

- (NSInteger) statusCode
{
  return self->statusCode;
}
@end

