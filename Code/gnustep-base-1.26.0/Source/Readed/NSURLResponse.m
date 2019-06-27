#import "common.h"

#define	EXPOSE_NSURLResponse_IVARS	1
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSScanner.h"
#import "NSCallBacks.h"
#import "GNUstepBase/GSMime.h"


@interface	_GSMutableInsensitiveDictionary : NSMutableDictionary
@end

@implementation	NSURLResponse (Private)

- (void) _checkHeaders
{
    if (NSURLResponseUnknownLength == expectedContentLength)
    {
        NSString	*s= [self _valueForHTTPHeaderField: @"content-length"];
        
        if ([s length] > 0)
        {
            expectedContentLength = [s intValue];
        }
    }
    
    if (nil == MIMEType)
    {
        GSMimeHeader	*c;
        GSMimeParser	*p;
        NSScanner		*s;
        NSString		*v;
        
        v = [self _valueForHTTPHeaderField: @"content-type"];
        if (v == nil)
        {
            v = @"text/plain";	// No content type given.
        }
        s = [NSScanner scannerWithString: v];
        p = [GSMimeParser new];
        c = AUTORELEASE([GSMimeHeader new]);
        /* We just set the header body, so we know it will scan and don't need
         * to check the retrurn type.
         */
        (void)[p scanHeaderBody: s into: c];
        RELEASE(p);
        ASSIGNCOPY(MIMEType, [c value]);
        v = [c parameterForKey: @"charset"];
        ASSIGNCOPY(textEncodingName, v);
    }
}

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
    [self _checkHeaders];
}
- (void) _setStatusCode: (NSInteger)code text: (NSString*)text
{
    statusCode = code;
    ASSIGNCOPY(statusText, text);
}
- (void) _setValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
    if (headers == 0)
    {
        headers = [_GSMutableInsensitiveDictionary new];
    }
    [headers setObject: value forKey: field];
}
- (NSString *) _valueForHTTPHeaderField: (NSString *)field
{
    return [headers objectForKey: field];
}
@end


@implementation	NSURLResponse

+ (id) allocWithZone: (NSZone*)z
{
    NSURLResponse	*o = [super allocWithZone: z];
    return o;
}

- (id) copyWithZone: (NSZone*)z
{
    NSURLResponse	*o;
    
    if (NSShouldRetainWithZone(self, z) == YES)
    {
        o = RETAIN(self);
    }
    else
    {
        o = [[self class] allocWithZone: z];
        o = [o initWithURL: [self URL]
                  MIMEType: [self MIMEType]
     expectedContentLength: [self expectedContentLength]
          textEncodingName: [self textEncodingName]];
        if (o != nil)
        {
            ASSIGN(o->statusText, statusText);
            o->statusCode = statusCode;
            if (headers == 0)
            {
                o->headers = 0;
            }
            else
            {
                o->headers = [headers mutableCopy];
            }
        }
    }
    return o;
}

- (void) dealloc
{
    [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    // FIXME
    if ([aCoder allowsKeyedCoding])
    {
    }
    else
    {
    }
}

- (long long) expectedContentLength
{
    return expectedContentLength;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    // FIXME
    if ([aCoder allowsKeyedCoding])
    {
    }
    else
    {
    }
    return self;
}

/**
 * Initialises the receiver with the URL, MIMEType, expected length and
 * text encoding name provided.
 */
- (id) initWithURL: (NSURL *)URL
          MIMEType: (NSString *)MIMEType
expectedContentLength: (NSInteger)length
  textEncodingName: (NSString *)name
{
    if ((self = [super init]) != nil)
    {
        ASSIGN(URL, URL);
        ASSIGNCOPY(MIMEType, MIMEType);
        ASSIGNCOPY(textEncodingName, name);
        expectedContentLength = length;
    }
    return self;
}

- (id) initWithURL: (NSURL*)URL
        statusCode: (NSInteger)statusCode
       HTTPVersion: (NSString*)HTTPVersion
      headerFields: (NSDictionary*)headerFields
{
    self = [self initWithURL: URL
                    MIMEType: nil
       expectedContentLength: NSURLResponseUnknownLength
            textEncodingName: nil];
    if (nil != self)
    {
        statusCode = statusCode;
        headers = [headerFields copy];
        [self _checkHeaders];
    }
    return self;
}

- (NSString *) MIMEType
{
    return MIMEType;
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
    NSString	*disp = [self _valueForHTTPHeaderField: @"content-disposition"];
    NSString	*name = nil;
    
    if (disp != nil)
    {
        GSMimeParser	*p;
        GSMimeHeader	*h;
        NSScanner		*sc;
        
        // Try to get name from content disposition header.
        p = AUTORELEASE([GSMimeParser new]);
        h = [[GSMimeHeader alloc] initWithName: @"content-displosition"
                                         value: disp];
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
    // FIXME ... add type specific extension
    return name;
}

- (NSString *) textEncodingName
{
    return textEncodingName;
}

- (NSURL *) URL
{
    return URL;
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
    return AUTORELEASE([headers copy]);
}

- (NSInteger) statusCode
{
    return statusCode;
}
@end

