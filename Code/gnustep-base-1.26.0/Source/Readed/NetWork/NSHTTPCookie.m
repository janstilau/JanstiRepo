#import "common.h"
#define	EXPOSE_NSHTTPCookie_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSString.h"
#import "Foundation/NSCalendarDate.h"
#import "GNUstepBase/Unicode.h"

/**
 *
 https://blog.csdn.net/sinat_36594453/article/details/88870899#cookie%E6%9C%BA%E5%88%B6
 介绍 cookie 的基本知识.
 name    Cookie的名称，Cookie一旦创建，名称便不可更改
 value    Cookie的值，如果值为Unicode字符，需要为字符编码。如果为二进制数据，则需要使用BASE64编码
 maxAge    Cookie失效的时间，单位秒。如果为整数，则该Cookie在maxAge秒后失效。如果为负数，该Cookie为临时Cookie，关闭浏览器即失效，浏览器也不会以任何形式保存该Cookie。如果为0，表示删除该Cookie。默认为-1。
 secure    该Cookie是否仅被使用安全协议传输。安全协议。安全协议有HTTPS，SSL等，在网络上传输数据之前先将数据加密。默认为false。
 path    Cookie的使用路径。如果设置为“/sessionWeb/”，则只有contextPath为“/sessionWeb”的程序可以访问该Cookie。如果设置为“/”，则本域名下contextPath都可以访问该Cookie。注意最后一个字符必须为“/”。
 domain    可以访问该Cookie的域名。如果设置为“.google.com”，则所有以“google.com”结尾的域名都可以访问该Cookie。注意第一个字符必须为“.”。
 comment    该Cookie的用处说明，浏览器显示Cookie信息的时候显示该说明。
 version    Cookie使用的版本号。0表示遵循Netscape的Cookie规范，1表示遵循W3C的RFC 2109规范
 ---------------------
 作者：longgege001
 来源：CSDN
 原文：https://blog.csdn.net/longgege001/article/details/81274088
 版权声明：本文为博主原创文章，转载请附上博文链接！
 */

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
static NSRange GSRangeOfCookie(NSString *string);

@implementation NSHTTPCookie

+ (id) allocWithZone: (NSZone*)z
{
    NSHTTPCookie	*o = [super allocWithZone: z];
    return o;
}

+ (id) cookieWithProperties: (NSDictionary *)properties
{
    NSHTTPCookie	*o;
    
    o = [[self alloc] initWithProperties: properties];
    return AUTORELEASE(o);
}

/* fieldValue will be cookie content. for example
 * Set-Cookie: JSESSIONID=7A6D610CBD77353FAEAFF169AC7B1D16; Path=/; HttpOnly
 * client should create a cookie form the up infomation.
 */
+ (NSMutableArray *) _parseField: (NSString *)fieldValue
                       forHeader: (NSString *)filedName
                          andURL: (NSURL *)url
{
    int version;
    // must have set-cookie. So this is method to get cookie from server response.
    if ([filedName isEqual: @"Set-Cookie"])
        version = 0;
    else if ([filedName isEqual: @"Set-Cookie2"])
        version = 1;
    else
        return nil;
    NSMutableArray *resultM = [NSMutableArray array];
    NSString * defaultDomain = [url host];
    NSString *defaultPath = [url path];
    if ([[url absoluteString] hasSuffix: @"/"] == NO)
        defaultPath = [defaultPath stringByDeletingLastPathComponent];
    
    /* We could use an NSScanner here, but this string could contain all
     sorts of odd stuff. It's not quite a property list either - it has
     dates and also could have tokens without values. */
    
    /*
     * a lot of text parse code. No need to look at every one.
     */
    while (1)
    {
        NSHTTPCookie *cookie;
        NSMutableDictionary *dict;
        NSString *onecookie;
        NSRange range = GSRangeOfCookie(fieldValue);
        
        if (range.location == NSNotFound) break;
        onecookie = [fieldValue substringWithRange: range];
        NS_DURING
        dict = GSPropertyListFromCookieFormat(onecookie, version);
        NS_HANDLER
        dict = nil;
        NS_ENDHANDLER
        if ([dict count])
        {
            if ([dict objectForKey: NSHTTPCookiePath] == nil)
                [dict setObject: defaultPath forKey: NSHTTPCookiePath];
            if ([dict objectForKey: NSHTTPCookieDomain] == nil)
                [dict setObject: defaultDomain forKey: NSHTTPCookieDomain];
            cookie = [NSHTTPCookie cookieWithProperties: dict];
            if (cookie)
                [resultM addObject: cookie];
        }
        if ([fieldValue length] <= NSMaxRange(range))
            break;
        fieldValue = [fieldValue substringFromIndex: NSMaxRange(range)+1];
    }
    return resultM;
}

+ (NSArray *) cookiesWithResponseHeaderFields: (NSDictionary *)headerFields
                                       forURL: (NSURL *)URL
{
    NSEnumerator   *headerFieldIter = [headerFields keyEnumerator];
    NSMutableArray *a = [NSMutableArray array];
    NSString *header;
    
    while ((header = [headerFieldIter nextObject]))
    {
        // extra cookie from http header field.
        NSMutableArray *suba = [self _parseField: [headerFields objectForKey: header] forHeader: header andURL: URL];
        if (suba)
            [a addObjectsFromArray: suba];
    }
    
    return a;
}

/*
 * switch the cookie to request header filed value/
 */
+ (NSDictionary *) requestHeaderFieldsWithCookies: (NSArray *)cookies
{
    int version;
    NSString *field;
    NSHTTPCookie *aCookie;
    NSEnumerator *arrarIter = [cookies objectEnumerator];
    
    if ([cookies count] == 0)
    {
        NSLog(@"NSHTTPCookie requestHeaderFieldWithCookies: empty array");
        return nil;
    }
    /* Assume these cookies all came from the same URL so we format based
     on the version of the first. */
    // So get the first one and get the property as all items have is. common
    field = nil;
    version = [(NSHTTPCookie *)[cookies objectAtIndex: 0] version];
    if (version)
        field = @"$Version=\"1\"";
    while ((aCookie = [arrarIter nextObject]))
    {
        // Just a string append progress for cookie.
        NSString *str;
        str = [NSString stringWithFormat: @"%@=%@", [aCookie name], [aCookie value]];
        if (field)
            field = [field stringByAppendingFormat: @"; %@", str];
        else
            field = str;
        if (version && [aCookie path])
            field = [field stringByAppendingFormat: @"; $Path=\"%@\"", [aCookie path]];
    }
    
    return [NSDictionary dictionaryWithObject: field forKey: @"Cookie"];
}


// just a container for infos.
- (NSString *) comment
{
    return [_cookInnerDict objectForKey: NSHTTPCookieComment];
}

- (NSURL *) commentURL
{
    return [_cookInnerDict objectForKey: NSHTTPCookieCommentURL];
}

- (NSString *) domain
{
    return [_cookInnerDict objectForKey: NSHTTPCookieDomain];
}

- (NSDate *) expiresDate
{
    return [_cookInnerDict objectForKey: NSHTTPCookieExpires];
}

- (BOOL) _isValidProperty: (NSString *)prop
{
    return ([prop length] && [prop rangeOfString: @"\n"].location == NSNotFound);
}

// designated init method.
- (id) initWithProperties: (NSDictionary *)properties
{
    NSMutableDictionary *rawProps;
    if (![self _isValidProperty: [properties objectForKey: NSHTTPCookiePath]] // cookie must have path. subPath can use super path cookie
        || ![self _isValidProperty: [properties objectForKey: NSHTTPCookieDomain]] // cookie domain. .google.com. must start with .
        || ![self _isValidProperty: [properties objectForKey: NSHTTPCookieName]] // cookie name
        || ![self _isValidProperty: [properties objectForKey: NSHTTPCookieValue]] // cooke value
        )
    {
        [self release];
        return nil;
    }
    
    rawProps = [[properties mutableCopy] autorelease];
    if ([rawProps objectForKey: @"Created"] == nil) // cookie create time.
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
    
    _cookInnerDict = [rawProps copy];
    return self;
}

- (BOOL) isSecure
{
    return [[_cookInnerDict objectForKey: NSHTTPCookieSecure] boolValue];
}

- (BOOL) isHTTPOnly
{
    return [[_cookInnerDict objectForKey: HTTPCookieHTTPOnly] boolValue];
}

- (BOOL) isSessionOnly
{
    return [[_cookInnerDict objectForKey: NSHTTPCookieDiscard] boolValue];
}

- (NSString *) name
{
    return [_cookInnerDict objectForKey: NSHTTPCookieName];
}

- (NSString *) path
{
    return [_cookInnerDict objectForKey: NSHTTPCookiePath];
}

- (NSArray *) portList
{
    return [[_cookInnerDict objectForKey: NSHTTPCookiePort]
            componentsSeparatedByString: @","];
}

- (NSDictionary *) properties
{
    return _cookInnerDict;
}

- (NSString *) value
{
    return [_cookInnerDict objectForKey: NSHTTPCookieValue];
}

- (NSUInteger) version
{
    return [[_cookInnerDict objectForKey: NSHTTPCookieVersion] integerValue];
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
