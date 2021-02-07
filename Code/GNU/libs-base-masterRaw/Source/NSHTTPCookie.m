// http://web.archive.org/web/20070805052634/http://wp.netscape.com/newsref/std/cookie_spec.html
#import "common.h"
#define	EXPOSE_NSHTTPCookie_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSString.h"
#import "Foundation/NSCalendarDate.h"
#import "GNUstepBase/Unicode.h"


// https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Cookies
// 这里面, 有对于 cookie 的介绍.

NSString * const NSHTTPCookieComment = @"Comment";
NSString * const NSHTTPCookieCommentURL = @"CommentURL";
NSString * const NSHTTPCookieDiscard = @"Discard";
NSString * const NSHTTPCookieDomain = @"Domain";
NSString * const NSHTTPCookieExpires = @"Expires";
NSString * const NSHTTPCookieMaximumAge = @"MaximumAge";
NSString * const NSHTTPCookieName = @"Name";
NSString * const NSHTTPCookieOriginURL = @"OriginURL";
NSString * const NSHTTPCookiePath = @"Path";
NSString * const NSHTTPCookiePort = @"Port";
NSString * const NSHTTPCookieSecure = @"Secure";
NSString * const NSHTTPCookieValue = @"Value";
NSString * const NSHTTPCookieVersion = @"Version";
static NSString * const HTTPCookieHTTPOnly = @"HTTPOnly";

// Internal data storage
typedef struct {
    NSDictionary	*_properties;
    // Cookie 里面, 就是一个字典而已.
} Internal;

#define	this	((Internal*)(self->_NSHTTPCookieInternal))
#define	inst	((Internal*)(o->_NSHTTPCookieInternal))

/* Bitmap of characters considered white space if in an old style property
 * list. This is the same as the set given by the isspace() function in the
 * POSIX locale, but (for cross-locale portability of property list files)
 * is fixed, rather than locale dependent.
 */
static const unsigned char whitespace[32] = {
    '\x00',
    '\x3f',
    '\x00',
    '\x00',
    '\x01',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
    '\x00',
};

#define IS_BIT_SET(a,i) ((((a) & (1<<(i)))) > 0)

#define GS_IS_WHITESPACE(X) IS_BIT_SET(whitespace[(X)/8], (X) % 8)

static id GSPropertyListFromCookieFormat(NSString *string, int version);
static NSMutableArray *GSCookieStrings(NSString *string);

@implementation NSHTTPCookie

+ (id) cookieWithProperties: (NSDictionary *)properties
{
    NSHTTPCookie	*o;
    
    o = [[self alloc] initWithProperties: properties];
    return AUTORELEASE(o);
}

+ (NSMutableArray *) _parseField: (NSString *)value
                       forHeader: (NSString *)header
                          andURL: (NSURL *)url
{
    int 			version;
    NSString 		*defaultPath;
    NSString		*defaultDomain;
    NSMutableArray 	*cookies;
    NSUInteger		count;
    
    // 如果, 是 Set-Cookie, 或者是 Set-Cookie2, 那么就是 cookie 的响应头字段了.
    if ([header isEqual: @"Set-Cookie"])
    {
        version = 0;
    }
    else if ([header isEqual: @"Set-Cookie2"])
    {
        version = 1;
    }
    else
    {
        return nil;
    }
    
    defaultDomain = [url host];
    defaultPath = [url path];
    if ([[url absoluteString] hasSuffix: @"/"] == NO)
    {
        defaultPath = [defaultPath stringByDeletingLastPathComponent];
    }
    
    // 经过 GSCookieStrings, cookie 的各项设置信息, 就被抽取出来了.
    cookies = GSCookieStrings(value);
    count = [cookies count];
    /* We could use an NSScanner here, but this string could contain all
     sorts of odd stuff. It's not quite a property list either - it has
     dates and also could have tokens without values. */
    while (count-- > 0)
    {
        NSHTTPCookie 		*cookie;
        NSMutableDictionary	*dict;
        NSString			*onecookie = [cookies objectAtIndex: count];
        
        NS_DURING
        dict = GSPropertyListFromCookieFormat(onecookie, version);
        NS_HANDLER
        dict = nil;
        NS_ENDHANDLER
        if ([dict count])
        {
            if ([dict objectForKey: NSHTTPCookiePath] == nil)
            {
                [dict setObject: defaultPath forKey: NSHTTPCookiePath];
            }
            if ([dict objectForKey: NSHTTPCookieDomain] == nil)
            {
                [dict setObject: defaultDomain forKey: NSHTTPCookieDomain];
            }
            cookie = [NSHTTPCookie cookieWithProperties: dict];
            if (cookie)
            {
                [cookies replaceObjectAtIndex: count withObject: cookie];
            }
            else
            {
                [cookies removeObjectAtIndex: count];
            }
        }
    }
    return cookies;
}

// 这是最最主要的一个方法, 在 NSURLProtocol 里面, 就是用该方法, 进行的 cookie 的解析, 然后存到了 NSHTTPCookieStorage sharedHTTPCookieStorage 内部.
// 这里, headerFields 就是 response 的响应头.
+ (NSArray *) cookiesWithResponseHeaderFields: (NSDictionary *)responseHeader
                                       forURL: (NSURL *)URL
{
    NSEnumerator   *keyIterator = [responseHeader keyEnumerator];
    NSMutableArray *a = [NSMutableArray array];
    NSString *filed;
    
    while ((filed = [keyIterator nextObject]))
    {
        // key: Set-Cookie
        // header: 整个响应头
        id value = [responseHeader objectForKey: header];
        NSMutableArray *suba = [self _parseField: value forHeader:filed andURL: URL];
        if (suba)
            [a addObjectsFromArray: suba];
    }
    
    return a;
}

// 从 cookie 反序列化成为 dict 的过程
+ (NSDictionary *) requestHeaderFieldsWithCookies: (NSArray *)cookies
{
    int version;
    NSString *field;
    NSHTTPCookie *ck;
    NSEnumerator *ckenum = [cookies objectEnumerator];
    
    if ([cookies count] == 0)
    {
        NSLog(@"NSHTTPCookie requestHeaderFieldWithCookies: empty array");
        return nil;
    }
    /* Assume these cookies all came from the same URL so we format based
     on the version of the first. */
    field = nil;
    version = [(NSHTTPCookie *)[cookies objectAtIndex: 0] version];
    if (version)
        field = @"$Version=\"1\"";
    while ((ck = [ckenum nextObject]))
    {
        NSString *str;
        // 首先, 拼接 cookie 的 key value 映射.
        str = [NSString stringWithFormat: @"%@=%@", [ck name], [ck value]];
        // 然后是 version 信息.
        if (field)
            field = [field stringByAppendingFormat: @"; %@", str];
        else
            field = str;
        if (version && [ck path])
            // 然后是 path 信息.
            field = [field stringByAppendingFormat: @"; $Path=\"%@\"", [ck path]];
    }
    
    return [NSDictionary dictionaryWithObject: field forKey: @"Cookie"];
}

- (NSString *) comment
{
    return [this->_properties objectForKey: NSHTTPCookieComment];
}

- (NSURL *) commentURL
{
    return [this->_properties objectForKey: NSHTTPCookieCommentURL];
}

- (void) dealloc
{
    if (this != 0)
    {
        RELEASE(this->_properties);
        NSZoneFree([self zone], this);
    }
    [super dealloc];
}

- (NSString *) domain
{
    return [this->_properties objectForKey: NSHTTPCookieDomain];
}

- (NSDate *) expiresDate
{
    return [this->_properties objectForKey: NSHTTPCookieExpires];
}

- (BOOL) _isValidProperty: (NSString *)prop
{
    return ([prop length]
            && [prop rangeOfString: @"\n"].location == NSNotFound);
}

- (id) initWithProperties: (NSDictionary *)properties
{
    NSMutableDictionary *rawProps;
    if ((self = [super init]) == nil)
        return nil;
    
    /* Check a few values.  Based on Mac OS X tests. */
    if (![self _isValidProperty: [properties objectForKey: NSHTTPCookiePath]]
        || ![self _isValidProperty: [properties objectForKey: NSHTTPCookieDomain]]
        || ![self _isValidProperty: [properties objectForKey: NSHTTPCookieName]]
        || ![self _isValidProperty: [properties objectForKey: NSHTTPCookieValue]]
        )
    {
        [self release];
        return nil;
    }
    
    rawProps = [[properties mutableCopy] autorelease];
    if ([rawProps objectForKey: @"Created"] == nil)
    {
        NSInteger seconds;
        NSDate	*now;
        
        /* Round to whole seconds, so that a serialization/deserialisation
         * cycle produces an identical object whic hcan be used to eliminate
         * duplicates.
         */
        seconds = [NSDate timeIntervalSinceReferenceDate];
        now = [NSDate dateWithTimeIntervalSinceReferenceDate: seconds];
        [rawProps setObject: now forKey: @"Created"];
    }
    if ([rawProps objectForKey: NSHTTPCookieExpires] == nil
        || [[rawProps objectForKey: NSHTTPCookieExpires]
            isKindOfClass: [NSDate class]] == NO)
    {
        [rawProps setObject: [NSNumber numberWithBool: YES]
                     forKey: NSHTTPCookieDiscard];
    }
    
    this->_properties = [rawProps copy];
    return self;
}

- (BOOL) isSecure
{
    return [[this->_properties objectForKey: NSHTTPCookieSecure] boolValue];
}

- (BOOL) isHTTPOnly
{
    return [[this->_properties objectForKey: HTTPCookieHTTPOnly] boolValue];
}

- (BOOL) isSessionOnly
{
    return [[this->_properties objectForKey: NSHTTPCookieDiscard] boolValue];
}

- (NSString *) name
{
    return [this->_properties objectForKey: NSHTTPCookieName];
}

- (NSString *) path
{
    return [this->_properties objectForKey: NSHTTPCookiePath];
}

- (NSArray *) portList
{
    return [[this->_properties objectForKey: NSHTTPCookiePort]
            componentsSeparatedByString: @","];
}

- (NSDictionary *) properties
{
    return this->_properties;
}

- (NSString *) value
{
    return [this->_properties objectForKey: NSHTTPCookieValue];
}

- (NSUInteger) version
{
    return [[this->_properties objectForKey: NSHTTPCookieVersion] integerValue];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<NSHTTPCookie %p: %@=%@>", self,
            [self name], [self value]];
}

- (NSUInteger) hash
{
    return [[self properties] hash];
}

- (BOOL) isEqual: (id)other
{
    return [[other properties] isEqual: [self properties]];
}

@end

#define inrange(ch,min,max) ((ch)>=(min) && (ch)<=(max))
#define char2num(ch) \
inrange(ch,'0','9') \
? ((ch)-0x30) \
: (inrange(ch,'a','f') \
? ((ch)-0x57) : ((ch)-0x37))

typedef	struct	{
    const unsigned char	*ptr;
    unsigned	end;
    unsigned	pos;
    unsigned	lin;
    NSString	*err;
    int           opt;
    BOOL		key;
    BOOL		old;
} pldata;

/*
 *	Returns YES if there is any non-whitespace text remaining.
 */
static BOOL skipSpace(pldata *pld)
{
    unsigned char	c;
    
    while (pld->pos < pld->end)
    {
        c = pld->ptr[pld->pos];
        
        if (GS_IS_WHITESPACE(c) == NO)
        {
            return YES;
        }
        if (c == '\n')
        {
            pld->lin++;
        }
        pld->pos++;
    }
    pld->err = @"reached end of string";
    return NO;
}

static inline id parseQuotedString(pldata* pld)
{
    unsigned	start = ++pld->pos;
    unsigned	escaped = 0;
    unsigned	shrink = 0;
    BOOL		hex = NO;
    NSString	*obj;
    
    while (pld->pos < pld->end)
    {
        unsigned char	c = pld->ptr[pld->pos];
        
        if (escaped)
        {
            if (escaped == 1 && c >= '0' && c <= '7')
            {
                escaped = 2;
                hex = NO;
            }
            else if (escaped == 1 && (c == 'u' || c == 'U'))
            {
                escaped = 2;
                hex = YES;
            }
            else if (escaped > 1)
            {
                if (hex && isxdigit(c))
                {
                    shrink++;
                    escaped++;
                    if (escaped == 6)
                    {
                        escaped = 0;
                    }
                }
                else if (c >= '0' && c <= '7')
                {
                    shrink++;
                    escaped++;
                    if (escaped == 4)
                    {
                        escaped = 0;
                    }
                }
                else
                {
                    pld->pos--;
                    escaped = 0;
                }
            }
            else
            {
                escaped = 0;
            }
        }
        else
        {
            if (c == '\\')
            {
                escaped = 1;
                shrink++;
            }
            else if (c == '"')
            {
                break;
            }
        }
        if (c == '\n')
            pld->lin++;
        pld->pos++;
    }
    if (pld->pos >= pld->end)
    {
        pld->err = @"reached end of string while parsing quoted string";
        return nil;
    }
    if (pld->pos - start - shrink == 0)
    {
        obj = @"";
    }
    else
    {
        unsigned	length;
        unichar	*chars;
        unichar	*temp = NULL;
        unsigned	int temp_length = 0;
        unsigned	j;
        unsigned	k;
        
        if (!GSToUnicode(&temp, &temp_length, &pld->ptr[start],
                         pld->pos - start, NSUTF8StringEncoding,
                         NSDefaultMallocZone(), 0))
        {
            pld->err = @"invalid utf8 data while parsing quoted string";
            return nil;
        }
        length = temp_length - shrink;
        chars = NSAllocateCollectable(sizeof(unichar) * length, 0);
        escaped = 0;
        hex = NO;
        for (j = 0, k = 0; j < temp_length; j++)
        {
            unichar c = temp[j];
            
            if (escaped)
            {
                if (escaped == 1 && c >= '0' && c <= '7')
                {
                    chars[k] = c - '0';
                    hex = NO;
                    escaped++;
                }
                else if (escaped == 1 && (c == 'u' || c == 'U'))
                {
                    chars[k] = 0;
                    hex = YES;
                    escaped++;
                }
                else if (escaped > 1)
                {
                    if (hex && isxdigit(c))
                    {
                        chars[k] <<= 4;
                        chars[k] |= char2num(c);
                        escaped++;
                        if (escaped == 6)
                        {
                            escaped = 0;
                            k++;
                        }
                    }
                    else if (c >= '0' && c <= '7')
                    {
                        chars[k] <<= 3;
                        chars[k] |= (c - '0');
                        escaped++;
                        if (escaped == 4)
                        {
                            escaped = 0;
                            k++;
                        }
                    }
                    else
                    {
                        escaped = 0;
                        j--;
                        k++;
                    }
                }
                else
                {
                    escaped = 0;
                    switch (c)
                    {
                        case 'a' : chars[k] = '\a'; break;
                        case 'b' : chars[k] = '\b'; break;
                        case 't' : chars[k] = '\t'; break;
                        case 'r' : chars[k] = '\r'; break;
                        case 'n' : chars[k] = '\n'; break;
                        case 'v' : chars[k] = '\v'; break;
                        case 'f' : chars[k] = '\f'; break;
                        default  : chars[k] = c; break;
                    }
                    k++;
                }
            }
            else
            {
                chars[k] = c;
                if (c == '\\')
                {
                    escaped = 1;
                }
                else
                {
                    k++;
                }
            }
        }
        
        NSZoneFree(NSDefaultMallocZone(), temp);
        length = k;
        
        obj = [NSString alloc];
        obj = [obj initWithCharactersNoCopy: chars
                                     length: length
                               freeWhenDone: YES];
    }
    pld->pos++;
    return obj;
}

/* In cookies, keys are terminated by '=' and values are terminated by ';'
 or and EOL */
static inline id parseUnquotedString(pldata *pld, char endChar)
{
    unsigned	start = pld->pos;
    unsigned	i;
    unsigned	length;
    id		obj;
    unichar	*chars;
    
    while (pld->pos < pld->end)
    {
        if ((pld->ptr[pld->pos]) == endChar)
            break;
        pld->pos++;
    }
    
    length = pld->pos - start;
    chars = NSAllocateCollectable(sizeof(unichar) * length, 0);
    for (i = 0; i < length; i++)
    {
        chars[i] = pld->ptr[start + i];
    }
    
    {
        obj = [NSString alloc];
        obj = [obj initWithCharactersNoCopy: chars
                                     length: length
                               freeWhenDone: YES];
    }
    return obj;
}

static BOOL
_setCookieKey(NSMutableDictionary *dict, NSString *key, NSString *value)
{
    if ([dict count] == 0)
    {
        /* This must be the name=value pair */
        if ([value length] == 0)
            return NO;
        [dict setObject: key forKey: NSHTTPCookieName];
        [dict setObject: value forKey: NSHTTPCookieValue];
        return YES;
    }
    if ([[key lowercaseString] isEqual: @"comment"])
        [dict setObject: value forKey: NSHTTPCookieComment];
    else if ([[key lowercaseString] isEqual: @"commenturl"])
        [dict setObject: value forKey: NSHTTPCookieCommentURL];
    else if ([[key lowercaseString] isEqual: @"discard"])
        [dict setObject: [NSNumber numberWithBool: YES]
                 forKey: NSHTTPCookieDiscard];
    else if ([[key lowercaseString] isEqual: @"domain"])
        [dict setObject: value forKey: NSHTTPCookieDomain];
    else if ([[key lowercaseString] isEqual: @"expires"])
    {
        NSDate *expireDate;
        expireDate = [NSCalendarDate dateWithString: value
                                     calendarFormat: @"%a, %d-%b-%Y %I:%M:%S %Z"];
        if (expireDate)
            [dict setObject: expireDate forKey: NSHTTPCookieExpires];
    }
    else if ([[key lowercaseString] isEqual: @"max-age"])
        [dict setObject: value forKey: NSHTTPCookieMaximumAge];
    else if ([[key lowercaseString] isEqual: @"originurl"])
        [dict setObject: value forKey: NSHTTPCookieOriginURL];
    else if ([[key lowercaseString] isEqual: @"path"])
        [dict setObject: value forKey: NSHTTPCookiePath];
    else if ([[key lowercaseString] isEqual: @"port"])
        [dict setObject: value forKey: NSHTTPCookiePort];
    else if ([[key lowercaseString] isEqual: @"secure"])
        [dict setObject: [NSNumber numberWithBool: YES]
                 forKey: NSHTTPCookieSecure];
    else if ([[key lowercaseString] isEqual:@"httponly"])
        [dict setObject: [NSNumber numberWithBool: YES]
                 forKey: HTTPCookieHTTPOnly];
    else if ([[key lowercaseString] isEqual: @"version"])
        [dict setObject: value forKey: NSHTTPCookieVersion];
    return YES;
}

static id
GSPropertyListFromCookieFormat(NSString *string, int version)
{
    NSMutableDictionary	*dict;
    pldata		_pld;
    pldata		*pld = &_pld;
    NSData		*d;
    BOOL			moreCharacters;
    
    /*
     * An empty string is a nil property list.
     */
    if ([string length] == 0)
    {
        return nil;
    }
    
    d = [string dataUsingEncoding: NSUTF8StringEncoding];
    NSCAssert(d, @"Couldn't get utf8 data from string.");
    _pld.ptr = (unsigned char*)[d bytes];
    _pld.pos = 0;
    _pld.end = [d length];
    _pld.err = nil;
    _pld.lin = 0;
    _pld.opt = 0;
    _pld.key = NO;
    _pld.old = YES;	// OpenStep style
    
    dict = [[NSMutableDictionary allocWithZone: NSDefaultMallocZone()]
            initWithCapacity: 0];
    while (skipSpace(pld) == YES)
    {
        id	key;
        id	val;
        
        if (pld->ptr[pld->pos] == '"')
        {
            key = parseQuotedString(pld);
        }
        else
        {
            unsigned int oldpos = pld->pos;
            unsigned int keyvalpos = 0;
            id keyval = parseUnquotedString(pld, ';');
            keyvalpos = pld->pos;
            pld->pos = oldpos;
            key = parseUnquotedString(pld, '=');
            
            // Detect value-less cookies like HTTPOnly; and Secure;
            if ([keyval length] < [key length])
            {
                pld->pos = keyvalpos;
                key = keyval;
            }
        }
        if (key == nil)
        {
            DESTROY(dict);
            break;
        }
        moreCharacters = skipSpace(pld);
        if (moreCharacters == NO || pld->ptr[pld->pos] == ';')
        {
            pld->pos++;
            if (_setCookieKey(dict, key, @"") == NO)
            {
                pld->err = @"invalid cookie pair";
                DESTROY(dict);
            }
            RELEASE(key);
        }
        else if (pld->ptr[pld->pos] == '=')
        {
            pld->pos++;
            if (skipSpace(pld) == NO)
            {
                RELEASE(key);
                DESTROY(dict);
                break;
            }
            if (pld->ptr[pld->pos] == '"')
            {
                val = parseQuotedString(pld);
            }
            else
            {
                val = parseUnquotedString(pld, ';');
            }
            if (val == nil)
            {
                RELEASE(key);
                DESTROY(dict);
                break;
            }
            skipSpace(pld);
            if (_setCookieKey(dict, key, val) == NO)
            {
                pld->err = @"invalid cookie pair";
                DESTROY(dict);
            }
            RELEASE(key);
            RELEASE(val);
            if (pld->ptr[pld->pos] == ';')
            {
                pld->pos++;
            }
            else
            {
                break;
            }
        }
        else
        {
            pld->err = @"unexpected character (wanted '=' or ';')";
            RELEASE(key);
            DESTROY(dict);
            break;
        }
    }
    if (dict == nil && _pld.err != nil)
    {
        RELEASE(dict);
        [NSException raise: NSGenericException
                    format: @"Parse failed at line %d (char %d) - %@",
         _pld.lin + 1, _pld.pos + 1, _pld.err];
    }
    return AUTORELEASE(dict);
}

/* Split a string containing comma seprated cookeie settings into an array
 * of individual cookie specifications.
 * Look for the comma that separates cookies. Commas can also occur in
 * date strings, like "expires", but perhaps it can occur other places.
 * For instance, the key/value pair  key=value1,value2 is not really
 * valid, but should we handle it anyway? Definitely we should handle the
 * perfectly normal case of:
 *
 * Set-Cookie: domain=test.com; expires=Thu, 12-Sep-2109 14:58:04 GMT;
 *   session=foo
 * Set-Cookie: bar=baz
 *
 * which gets concatenated into something like:
 *
 * Set-Cookie: domain=test.com; expires=Thu, 12-Sep-2109 14:58:04 GMT;
 *   session=foo,bar=baz
 */
static NSMutableArray* 
GSCookieStrings(NSString *string)
{
    unsigned char		*ptr;
    unsigned		pos;
    unsigned		end;
    NSData		*d;
    NSMutableArray	*cookies;
    unsigned		start = 0;
    unsigned 		saved = 0;
    
    if ([string length] == 0)
    {
        return nil;
    }
    
    d = [string dataUsingEncoding: NSUTF8StringEncoding];
    ptr = (unsigned char*)[d bytes];
    pos = 0;
    end = [d length];
    
    cookies = [NSMutableArray arrayWithCapacity: 4];
    while (pos < end)
    {
        while (pos < end && isspace(ptr[pos]))
        {
            pos++;
        }
        start = pos;
        
        while (pos < end)
        {
            if (ptr[pos] == ',')
            {
                /* Look ahead for something that will tell us if this is a
                 * separate cookie or not.  We look for something of the form
                 * ' token =' where a space represents any optional whitespace.
                 */
                saved = pos++;
                while (pos < end && isspace(ptr[pos]))
                {
                    pos++;
                }
                if (pos < end)
                {
                    const char *bad = "()<>@,;:\\\"/[]?={}";
                    int	c = ptr[pos];
                    
                    /* skip past token characters.
                     */
                    while (c > 32 && c < 128 && strchr(bad, c) == 0)
                    {
                        pos++;
                        if (pos < end)
                        {
                            c = ptr[pos];
                        }
                    }
                    while (pos < end && isspace(ptr[pos]))
                    {
                        pos++;
                    }
                    if (pos < end && '=' == ptr[pos])
                    {
                        pos = saved + 1;
                        /* We found a comma separator: so make the text before
                         * the comma a cooke string as long as it is not empty.
                         */
                        while (saved > start
                               && isspace(ptr[saved - 1]))
                        {
                            saved--;
                        }
                        if (saved > start)
                        {
                            NSString	*str = [NSString alloc];
                            
                            str = [str initWithBytes: ptr + start
                                              length: saved - start
                                            encoding: NSUTF8StringEncoding];
                            [cookies addObject: str];
                            RELEASE(str);
                        }
                        start = saved = pos;
                    }
                }
                pos = saved;
            }
            pos++;
        }
    }
    if (pos > start)
    {
        /* There was data after the last comma; make it into a cookie string
         * as long as it's not empty after removing spaces
         */
        saved = pos;
        while (saved > start
               && isspace(ptr[saved - 1]))
        {
            saved--;
        }
        if (saved > start)
        {
            NSString	*str = [NSString alloc];
            
            /* There may not be room to add a nul terminator, so we use an
             * initialiser which doesn't need one.
             */
            str = [str initWithBytes: ptr + start
                              length: saved - start
                            encoding: NSUTF8StringEncoding];
            [cookies addObject: str];
            RELEASE(str);
        }
    }
    return cookies;	// The individual cookies
}
