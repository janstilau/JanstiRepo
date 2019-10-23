#import "common.h"
#define	EXPOSE_NSHTTPCookie_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSString.h"
#import "Foundation/NSCalendarDate.h"
#import "GNUstepBase/Unicode.h"

NSString * const NSHTTPCookieComment = @"Comment"; // 不知道干什么的
NSString * const NSHTTPCookieCommentURL = @"CommentURL"; // 不知道干什么的
NSString * const NSHTTPCookieDiscard = @"Discard"; // 不知道干什么的
NSString * const NSHTTPCookieDomain = @"Domain"; // cookie 所在的域
NSString * const NSHTTPCookieExpires = @"Expires"; // cookie 的过期时间
NSString * const NSHTTPCookieMaximumAge = @"MaximumAge"; // 不知道干什么的
NSString * const NSHTTPCookieName = @"Name"; // key 值
NSString * const NSHTTPCookieOriginURL = @"OriginURL";
NSString * const NSHTTPCookiePath = @"Path"; // path 值
NSString * const NSHTTPCookiePort = @"Port"; //
NSString * const NSHTTPCookieSecure = @"Secure"; //  标记为 Secure 的Cookie只应通过被HTTPS协议加密过的请求发送给服务端
NSString * const NSHTTPCookieValue = @"Value"; // value 值
NSString * const NSHTTPCookieVersion = @"Version"; // version 值
static NSString * const HTTPCookieHTTPOnly = @"HTTPOnly"; // 标明了 HTTPOnly 的 cookie 无法被 js 代码拿到


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
static NSRange GSRangeOfCookie(NSString *string);

@implementation NSHTTPCookie

+ (id) cookieWithProperties: (NSDictionary *)properties
{
    NSHTTPCookie	*o;
    
    o = [[self alloc] initWithProperties: properties];
    return AUTORELEASE(o);
}

+ (NSMutableArray *) _parseField: (NSString *)field 
                       forHeader: (NSString *)header
                          andURL: (NSURL *)url
{
    int version;
    NSString *defaultPath, *defaultDomain;
    NSMutableArray *result;
    
    if ([header isEqual: @"Set-Cookie"])
        version = 0;
    else if ([header isEqual: @"Set-Cookie2"])
        version = 1;
    else
        return nil; // 如果不是 cookie 相关的 field 值, 直接返回 nil.
    
    result = [NSMutableArray array];
    defaultDomain = [url host];
    defaultPath = [url path];
    if ([[url absoluteString] hasSuffix: @"/"] == NO)
        defaultPath = [defaultPath stringByDeletingLastPathComponent];
    // 这里, 如果 cookie 里面没有明确的标明 path 和 domain, 是用的 url 的 host 和 path 进行的设置.
    
    while (1)
    {
        NSHTTPCookie *cookie;
        NSMutableDictionary *dict;
        NSString *onecookie;
        NSRange range = GSRangeOfCookie(field);
        
        if (range.location == NSNotFound)
            break;
        onecookie = [field substringWithRange: range];
        NS_DURING
        dict = GSPropertyListFromCookieFormat(onecookie, version);
        NS_HANDLER
        dict = nil;
        NS_ENDHANDLER
        if ([dict count])
        {
            // 将 从字符串提取信息到 dict 的过程, 放到了 GSPropertyListFromCookieFormat, 现在 dict 里面就是cookie相关的信息 dict 里.
            if ([dict objectForKey: NSHTTPCookiePath] == nil)
                [dict setObject: defaultPath forKey: NSHTTPCookiePath];
            if ([dict objectForKey: NSHTTPCookieDomain] == nil)
                [dict setObject: defaultDomain forKey: NSHTTPCookieDomain];
            cookie = [NSHTTPCookie cookieWithProperties: dict];
            if (cookie) {[result addObject: cookie]; } // 生成 cookie, 并且添加到了返回结果中.
        }
        if ([field length] <= NSMaxRange(range))
            break;
        field = [field substringFromIndex: NSMaxRange(range)+1]; // 不断地切割 field, 将 cookie 的值一个个取出来.
    }
    return result;
}


// 因为, cookie 就是放到了 http header 里面, 所以这就是一个提取 cookie 的一个简便方法.
+ (NSArray *) cookiesWithResponseHeaderFields: (NSDictionary *)headerFields
                                       forURL: (NSURL *)URL
{
    NSEnumerator   *henum = [headerFields keyEnumerator];
    NSMutableArray *resultM = [NSMutableArray array];
    NSString *header;
    
    while ((header = [henum nextObject]))
    {
        NSMutableArray *aCookie = [self _parseField: [headerFields objectForKey: header]
                                          forHeader: header
                                             andURL: URL];
        if (aCookie)
            [resultM addObjectsFromArray: aCookie];
    }
    
    return resultM;
}

// 这里就是一个逆过程, 将 cookie 的值, 转化成为一个 NSDiction 中
+ (NSDictionary *) requestHeaderFieldsWithCookies: (NSArray *)cookies
{
    int version;
    NSString *cookieText;
    NSHTTPCookie *aCookie;
    NSEnumerator *cookieEnumerator = [cookies objectEnumerator];
    
    if ([cookies count] == 0)
    {
        NSLog(@"NSHTTPCookie requestHeaderFieldWithCookies: empty array");
        return nil;
    }
    /* Assume these cookies all came from the same URL so we format based
     on the version of the first. */
    cookieText = nil;
    version = [(NSHTTPCookie *)[cookies objectAtIndex: 0] version];
    if (version)
        cookieText = @"$Version=\"1\"";
    // 这里, 用的第一个元素的 version 值, 当做了所有的 version 值.
    while ((aCookie = [cookieEnumerator nextObject]))
    {
        NSString *str;
        str = [NSString stringWithFormat: @"%@=%@", [aCookie name], [aCookie value]]; // cookie最原始的内容
        if (cookieText)
            cookieText = [cookieText stringByAppendingFormat: @"; %@", str]; // domain 的内容
        else
            cookieText = str;
        if (version && [aCookie path]) // path 只会在 version 为 1 的时候才会有用.
            cookieText = [cookieText stringByAppendingFormat: @"; $Path=\"%@\"", [aCookie path]]; // path 的内容
    }
    
    return [NSDictionary dictionaryWithObject: cookieText forKey: @"Cookie"];
}

- (NSString *) comment
{
    return [self->_properties objectForKey: NSHTTPCookieComment];
}

- (NSURL *) commentURL
{
    return [self->_properties objectForKey: NSHTTPCookieCommentURL];
}

- (NSString *) domain
{
    return [self->_properties objectForKey: NSHTTPCookieDomain];
}

- (NSDate *) expiresDate
{
    return [self->_properties objectForKey: NSHTTPCookieExpires];
}

- (BOOL) _isValidProperty: (NSString *)prop
{
    return ([prop length] &&
            [prop rangeOfString: @"\n"].location == NSNotFound);
}

- (id) initWithProperties: (NSDictionary *)properties
{
    NSMutableDictionary *rawProps;
    if ((self = [super init]) == nil)
        return nil;
    
    /* Check a few values.  Based on Mac OS X tests. */
    if (![self _isValidProperty: [properties objectForKey: NSHTTPCookiePath]] ||
        ![self _isValidProperty: [properties objectForKey: NSHTTPCookieDomain]] ||
        ![self _isValidProperty: [properties objectForKey: NSHTTPCookieName]] ||
        ![self _isValidProperty: [properties objectForKey: NSHTTPCookieValue]]
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
    
    self->_properties = [rawProps copy];
    return self;
}

- (BOOL) isSecure
{
    return [[self->_properties objectForKey: NSHTTPCookieSecure] boolValue];
}

- (BOOL) isHTTPOnly
{
    return [[self->_properties objectForKey: HTTPCookieHTTPOnly] boolValue];
}

- (BOOL) isSessionOnly
{
    return [[self->_properties objectForKey: NSHTTPCookieDiscard] boolValue];
}

- (NSString *) name
{
    return [self->_properties objectForKey: NSHTTPCookieName];
}

- (NSString *) path
{
    return [self->_properties objectForKey: NSHTTPCookiePath];
}

- (NSArray *) portList
{
    return [[self->_properties objectForKey: NSHTTPCookiePort]
            componentsSeparatedByString: @","];
}

- (NSDictionary *) properties
{
    return self->_properties;
}

- (NSString *) value
{
    return [self->_properties objectForKey: NSHTTPCookieValue];
}

- (NSUInteger) version
{
    return [[self->_properties objectForKey: NSHTTPCookieVersion] integerValue];
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

/* Look for the comma that separates cookies. Commas can also occur in
 date strings, like "expires", but perhaps it can occur other places.
 For instance, the key/value pair  key=value1,value2 is not really
 valid, but should we handle it anyway? Definitely we should handle the
 perfectly normal case of:
 
 Set-Cookie: domain=test.com; expires=Thu, 12-Sep-2109 14:58:04 GMT;
 session=foo
 Set-Cookie: bar=baz
 
 which gets concatenated into something like:
 
 Set-Cookie: domain=test.com; expires=Thu, 12-Sep-2109 14:58:04 GMT;
 session=foo,bar=baz
 
 */
static NSRange 
GSRangeOfCookie(NSString *string)
{
    pldata		_pld;
    pldata		*pld = &_pld;
    NSData		*d;
    NSRange               range;
    
    /*
     * An empty string is a nil property list.
     */
    range = NSMakeRange(NSNotFound, NSNotFound);
    if ([string length] == 0)
    {
        return range;
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
    
    while (skipSpace(pld) == YES)
    {
        if (pld->ptr[pld->pos] == ',')
        {
            /* Look ahead for something that will tell us if this is a
             separate cookie or not */
            unsigned saved_pos = pld->pos;
            while (pld->ptr[pld->pos] != '=' && pld->ptr[pld->pos] != ';'
                   && pld->ptr[pld->pos] != ',' && pld->pos < pld->end )
                pld->pos++;
            if (pld->ptr[pld->pos] == '=')
            {
                /* Separate comment */
                range = NSMakeRange(0, saved_pos-1);
                break;
            }
            pld->pos = saved_pos;
        }
        pld->pos++;
    }
    if (range.location == NSNotFound)
        range = NSMakeRange(0, [string length]);
    
    return range;
}
