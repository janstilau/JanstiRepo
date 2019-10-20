#import "common.h"
#define	EXPOSE_NSURL_IVARS	1
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSException.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLHandle.h"
#import "Foundation/NSValue.h"

#import "GNUstepBase/NSURL+GNUstepBase.h"


NSString * const NSURLErrorDomain = @"NSURLErrorDomain";
NSString * const NSErrorFailingURLStringKey = @"NSErrorFailingURLStringKey";

@interface	NSString (NSURLPrivate)
- (NSString*) _stringByAddingPercentEscapes;
@end

@implementation	NSString (NSURLPrivate)

// 什么叫做百分号转移. 就是有一些字符, 不能显示, 或者在 URL 有着特殊的含义, 就用 %加上编号进行表示的方法.
- (NSString*) _stringByAddingPercentEscapes
{
    NSData	*data = [self dataUsingEncoding: NSUTF8StringEncoding];
    NSString	*s = nil;
    
    if (data != nil)
    {
        unsigned char	*src = (unsigned char*)[data bytes];
        unsigned int	slen = [data length];
        unsigned char	*dst;
        unsigned int	spos = 0;
        unsigned int	dpos = 0;
        
        dst = (unsigned char*)NSZoneMalloc(NSDefaultMallocZone(), slen * 3);// 直接用了3 倍的空间, 猜测是, URL 的空间不会很大, 开启稍微大一点的空间不会有危险.
        while (spos < slen)
        {
            unsigned char	c = src[spos++];
            unsigned int	hi;
            unsigned int	lo;
            
            if (c <= 32
                || c > 126
                || c == 34
                || c == 35
                || c == 37
                || c == 59
                || c == 60
                || c == 62
                || c == 63
                || c == 91
                || c == 92
                || c == 93
                || c == 94
                || c == 96
                || c == 123
                || c == 124
                || c == 125)
            {
                dst[dpos++] = '%';
                hi = (c & 0xf0) >> 4; // 前 4 个字节.
                dst[dpos++] = (hi > 9) ? 'A' + hi - 10 : '0' + hi;
                lo = (c & 0x0f);// 后 4 个字节.
                dst[dpos++] = (lo > 9) ? 'A' + lo - 10 : '0' + lo;
            }
            else
            {
                dst[dpos++] = c;
            }
        }
        s = [[NSString alloc] initWithBytes: dst
                                     length: dpos
                                   encoding: NSASCIIStringEncoding];
        NSZoneFree(NSDefaultMallocZone(), dst);
        IF_NO_GC([s autorelease];)
    }
    return s;
}

@end

@interface	NSURL (GSPrivate)
- (NSURL*) _URLBySettingPath: (NSString*)newPath; 
@end

@implementation	NSURL (GSPrivate)

- (NSURL*) _URLBySettingPath: (NSString*)newPath 
{
    if ([self isFileURL])
    {
        return [NSURL fileURLWithPath: newPath];
    }
    else
    {
        NSURL	*u;
        u = [[NSURL alloc] initWithScheme: [self scheme]
                                     user: [self user]
                                 password: [self password]
                                     host: [self host]
                                     port: [self port]
                                 fullPath: newPath
                          parameterString: [self parameterString]
                                    query: [self query]
                                 fragment: [self fragment]];
        return [u autorelease];
    }
}

@end


#define	myData ((parsedURL*)(self->_parseModel))
#define	baseData ((self->_baseURL == 0)?0:((parsedURL*)(self->_baseURL->_parseModel)))

static NSLock	*clientsLock = nil;

/*
 * Local utility functions.
 */
static char *buildURL(parsedURL *base, parsedURL *rel, BOOL standardize);
static id clientForHandle(void *data, NSURLHandle *hdl);
static char *findUp(char *str);
static char *unescape(const char *from, char * to);

/**
 * Build an absolute URL as a C string
 */
static char *buildURL(parsedURL *base, parsedURL *rel, BOOL standardize)
{
    const char	*rpath;
    char		*buf;
    char		*ptr;
    char		*tmp;
    int		l;
    unsigned int	len = 1;
    
    if (NO == rel->hasNoPath)
    {
        len += 1;                         // trailing '/' to be added
    }
    if (rel->scheme != 0)
    {
        len += strlen(rel->scheme) + 3;	// scheme://
    }
    else if (YES == rel->isGeneric)
    {
        len += 2;                         // need '//' even if no scheme
    }
    if (rel->user != 0)
    {
        len += strlen(rel->user) + 1;	// user...@
    }
    if (rel->password != 0)
    {
        len += strlen(rel->password) + 1;	// :password
    }
    if (rel->host != 0)
    {
        len += strlen(rel->host) + 1;	// host.../
    }
    if (rel->port != 0)
    {
        len += strlen(rel->port) + 1;	// :port
    }
    if (rel->path != 0)
    {
        rpath = rel->path;
    }
    else
    {
        rpath = "";
    }
    len += strlen(rpath) + 1;	// path
    if (base != 0 && base->path != 0)
    {
        len += strlen(base->path) + 1;	// path
    }
    if (rel->parameters != 0)
    {
        len += strlen(rel->parameters) + 1;	// ;parameters
    }
    if (rel->query != 0)
    {
        len += strlen(rel->query) + 1;		// ?query
    }
    if (rel->fragment != 0)
    {
        len += strlen(rel->fragment) + 1;		// #fragment
    }
    
    ptr = buf = (char*)NSZoneMalloc(NSDefaultMallocZone(), len);
    
    if (rel->scheme != 0)
    {
        l = strlen(rel->scheme);
        memcpy(ptr, rel->scheme, l);
        ptr += l;
        *ptr++ = ':';
    }
    if (rel->isGeneric == YES
        || rel->user != 0 || rel->password != 0 || rel->host != 0 || rel->port != 0)
    {
        *ptr++ = '/';
        *ptr++ = '/';
        if (rel->user != 0 || rel->password != 0)
        {
            if (rel->user != 0)
            {
                l = strlen(rel->user);
                memcpy(ptr, rel->user, l);
                ptr += l;
            }
            if (rel->password != 0)
            {
                *ptr++ = ':';
                l = strlen(rel->password);
                memcpy(ptr, rel->password, l);
                ptr += l;
            }
            if (rel->host != 0 || rel->port != 0)
            {
                *ptr++ = '@';
            }
        }
        if (rel->host != 0)
        {
            l = strlen(rel->host);
            memcpy(ptr, rel->host, l);
            ptr += l;
        }
        if (rel->port != 0)
        {
            *ptr++ = ':';
            l = strlen(rel->port);
            memcpy(ptr, rel->port, l);
            ptr += l;
        }
    }
    
    /*
     * Now build path.
     */
    
    tmp = ptr;
    if (rel->pathIsAbsolute == YES)
    {
        if (rel->hasNoPath == NO)
        {
            *tmp++ = '/';
        }
        l = strlen(rpath);
        memcpy(tmp, rpath, l);
        tmp += l;
    }
    else if (base == 0)
    {
        l = strlen(rpath);
        memcpy(tmp, rpath, l);
        tmp += l;
    }
    else if (rpath[0] == 0)
    {
        if (base->hasNoPath == NO)
        {
            *tmp++ = '/';
        }
        if (base->path)
        {
            l = strlen(base->path);
            memcpy(tmp, base->path, l);
            tmp += l;
        }
    }
    else
    {
        char	*start = base->path;
        
        if (start != 0)
        {
            char	*end = strrchr(start, '/');
            
            if (end != 0)
            {
                *tmp++ = '/';
                memcpy(tmp, start, end - start);
                tmp += (end - start);
            }
        }
        *tmp++ = '/';
        l = strlen(rpath);
        memcpy(tmp, rpath, l);
        tmp += l;
    }
    *tmp = '\0';
    
    if (standardize == YES)
    {
        /*
         * Compact '/./'  to '/' and strip any trailing '/.'
         */
        tmp = ptr;
        while (*tmp != '\0')
        {
            if (tmp[0] == '/' && tmp[1] == '.'
                && (tmp[2] == '/' || tmp[2] == '\0'))
            {
                /*
                 * Ensure we don't remove the leading '/'
                 */
                if (tmp == ptr && tmp[2] == '\0')
                {
                    tmp[1] = '\0';
                }
                else
                {
                    l = strlen(&tmp[2]) + 1;
                    memmove(tmp, &tmp[2], l);
                }
            }
            else
            {
                tmp++;
            }
        }
        /*
         * Reduce any sequence of '/' characters to a single '/'
         */
        tmp = ptr;
        while (*tmp != '\0')
        {
            if (tmp[0] == '/' && tmp[1] == '/')
            {
                l = strlen(&tmp[1]) + 1;
                memmove(tmp, &tmp[1], l);
            }
            else
            {
                tmp++;
            }
        }
        /*
         * Reduce any '/something/../' sequence to '/' and a trailing
         * "/something/.." to ""
         */
        tmp = ptr;
        while ((tmp = findUp(tmp)) != 0)
        {
            char	*next = &tmp[3];
            
            while (tmp > ptr)
            {
                if (*--tmp == '/')
                {
                    break;
                }
            }
            /*
             * Ensure we don't remove the leading '/'
             */
            if (tmp == ptr && *next == '\0')
            {
                tmp[1] = '\0';
            }
            else
            {
                l = strlen(next) + 1;
                memmove(tmp, next, l);
            }
        }
        /*
         * if we have an empty path, we standardize to a single slash.
         */
        tmp = ptr;
        if (*tmp == '\0')
        {
            memcpy(tmp, "/", 2);
        }
    }
    ptr = &ptr[strlen(ptr)];
    
    if (rel->parameters != 0)
    {
        *ptr++ = ';';
        l = strlen(rel->parameters);
        memcpy(ptr, rel->parameters, l);
        ptr += l;
    }
    if (rel->query != 0)
    {
        *ptr++ = '?';
        l = strlen(rel->query);
        memcpy(ptr, rel->query, l);
        ptr += l;
    }
    if (rel->fragment != 0)
    {
        *ptr++ = '#';
        l = strlen(rel->fragment);
        memcpy(ptr, rel->fragment, l);
        ptr += l;
    }
    *ptr = '\0';
    return buf;
}

static id clientForHandle(void *data, NSURLHandle *hdl)
{
    id	client = nil;
    
    if (data != 0)
    {
        [clientsLock lock];
        client = (id)NSMapGet((NSMapTable*)data, hdl);
        [clientsLock unlock];
    }
    return client;
}

/**
 * Locate a '/../ or trailing '/..'
 */
static char *findUp(char *str)
{
    while (*str != '\0')
    {
        if (str[0] == '/' && str[1] == '.' && str[2] == '.'
            && (str[3] == '/' || str[3] == '\0'))
        {
            return str;
        }
        str++;
    }
    return 0;
}

/*
 * Check a string to see if it contains only legal data characters
 * or percent escape sequences.
 */
static BOOL legal(const char *str, const char *extras)
{
    const char	*mark = "-_.!~*'()";
    
    if (str != 0)
    {
        while (*str != 0)
        {
            if (*str == '%' && isxdigit(str[1]) && isxdigit(str[2]))
            {
                str += 3;
            }
            else if (isalnum(*str))
            {
                str++;
            }
            else if (strchr(mark, *str) != 0)
            {
                str++;
            }
            else if (strchr(extras, *str) != 0)
            {
                str++;
            }
            else
            {
                return NO;
            }
        }
    }
    return YES;
}

/*
 * Convert percent escape sequences to individual characters.
 */
static char *unescape(const char *from, char * to)
{
    while (*from != '\0')
    {
        if (*from == '%')
        {
            unsigned char	c;
            
            from++;
            if (isxdigit(*from))
            {
                if (*from <= '9')
                {
                    c = *from - '0';
                }
                else if (*from <= 'F')
                {
                    c = *from - 'A' + 10;
                }
                else
                {
                    c = *from - 'a' + 10;
                }
                from++;
            }
            else
            {
                c = 0;	// Avoid compiler warning
                [NSException raise: NSGenericException
                            format: @"Bad percent escape sequence in URL string"];
            }
            c <<= 4;
            if (isxdigit(*from))
            {
                if (*from <= '9')
                {
                    c |= *from - '0';
                }
                else if (*from <= 'F')
                {
                    c |= *from - 'A' + 10;
                }
                else
                {
                    c |= *from - 'a' + 10;
                }
                from++;
                *to++ = c;
            }
            else
            {
                [NSException raise: NSGenericException
                            format: @"Bad percent escape sequence in URL string"];
            }
        }
        else
        {
            *to++ = *from++;
        }
    }
    *to = '\0';
    return to;
}



@implementation NSURL

static NSUInteger	urlAlign;

+ (NSURL*) fileURLWithPathComponents: (NSArray*)components
{
    return [self fileURLWithPath: [NSString pathWithComponents: components]];
}

+ (id) fileURLWithPath: (NSString*)aPath
{
    return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath]);
}

+ (id) fileURLWithPath: (NSString*)aPath isDirectory: (BOOL)isDir
{
    return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath
                                              isDirectory: isDir]);
}

+ (id) URLWithString: (NSString*)aUrlString
{
    return AUTORELEASE([[NSURL alloc] initWithString: aUrlString]);
}

+ (id) URLWithString: (NSString*)aUrlString
       relativeToURL: (NSURL*)aBaseUrl
{
    return AUTORELEASE([[NSURL alloc] initWithString: aUrlString
                                       relativeToURL: aBaseUrl]);
}

- (id) initFileURLWithPath: (NSString*)aPath
{
    NSFileManager	*mgr = [NSFileManager defaultManager];
    BOOL		flag = NO;
    
    if ([aPath isAbsolutePath] == NO) //  [aPath isAbsolutePath] 就是根据不同操作系统的不同路径前缀进行的判断.
    {
        aPath = [[mgr currentDirectoryPath]
                 stringByAppendingPathComponent: aPath]; // iOS 的 currentDir 应该就是自己的沙盒环境
    }
    if ([mgr fileExistsAtPath: aPath isDirectory: &flag] == YES)
    {
        if ([aPath isAbsolutePath] == NO)
        {
            aPath = [aPath stringByStandardizingPath];
        }
        if (flag == YES && [aPath hasSuffix: @"/"] == NO)
        {
            aPath = [aPath stringByAppendingString: @"/"];
        }
    }
    // 到了这里, aPath 就是一个isAbsolutePath 了/
    self = [self initWithScheme: NSURLFileScheme
                           host: @""
                           path: aPath];
    return self;
}

- (id) initFileURLWithPath: (NSString*)aPath isDirectory: (BOOL)isDir
{
    NSFileManager	*mgr = [NSFileManager defaultManager];
    BOOL		flag = NO;
    
    if (nil == aPath)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@ %@] nil string parameter",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if ([aPath isAbsolutePath] == NO)
    {
        aPath = [[mgr currentDirectoryPath]
                 stringByAppendingPathComponent: aPath];
    }
    if ([mgr fileExistsAtPath: aPath isDirectory: &flag] == YES)
    {
        if ([aPath isAbsolutePath] == NO)
        {
            aPath = [aPath stringByStandardizingPath];
        }
        isDir = flag;
    }
    // isDir 的唯一作用, 就是在后面加一个 /
    if (isDir == YES && [aPath hasSuffix: @"/"] == NO)
    {
        aPath = [aPath stringByAppendingString: @"/"];
    }
    self = [self initWithScheme: NSURLFileScheme
                           host: @""
                           path: aPath];
    return self;
}


// desiganeted init 方法.
- (id) initWithScheme: (NSString*)aScheme
                 host: (NSString*)aHost
                 path: (NSString*)aPath
{
    NSRange	r = NSMakeRange(NSNotFound, 0);
    NSString	*auth = nil;
    NSString	*aUrlString = [NSString alloc];
    
    aPath = [aPath _stringByAddingPercentEscapes]; // 路径, 要百分号化.
    
    r = [aHost rangeOfString: @"@"];
    
    /* Allow for authentication (username:password) before actual host.
     */
    // 这里进行了判断, host 里面要取出 name 和 pwd 的值.
    if (r.length > 0)
    {
        auth = [aHost substringToIndex: r.location];
        aHost = [aHost substringFromIndex: NSMaxRange(r)];
    }
    
    /* Add square brackets around ipv6 address if necessary
     */
    if ([[aHost componentsSeparatedByString: @":"] count] > 2
        && [aHost hasPrefix: @"["] == NO)
    {
        aHost = [NSString stringWithFormat: @"[%@]", aHost];
    }
    
    if (auth != nil)
    {
        aHost = [NSString stringWithFormat: @"%@@%@", auth, aHost];
    }
    
    if ([aPath length] > 0)
    {
        if ([aPath hasPrefix: @"/"] == YES)
        {
            aUrlString = [aUrlString initWithFormat: @"%@://%@%@",
                          aScheme, aHost, aPath];
        }
        else
        {
            aUrlString = [aUrlString initWithFormat: @"%@://%@/%@",
                          aScheme, aHost, aPath];
        }
    }
    else
    {
        aUrlString = [aUrlString initWithFormat: @"%@://%@/",
                      aScheme, aHost];
    }
    // 最后, 根据 scheme, host, 以及 path, 组合出最后的 urlString 出来.
    self = [self initWithString: aUrlString relativeToURL: nil];
    RELEASE(aUrlString);
    return self;
}

- (id) initWithString: (NSString*)aUrlString
{
    self = [self initWithString: aUrlString relativeToURL: nil];
    return self;
}


// 最最核心的方法, 里面有着对于 parseModel 里面所有值得抽取, 所以, 这样的一个数据类, 保存所有的数据, 是一个通用的解决办法.
- (id) initWithString: (NSString*)aUrlString
        relativeToURL: (NSURL*)aBaseUrl
{
    /* RFC 2396 'reserved' characters ...
     * as modified by RFC2732
     * static const char *reserved = ";/?:@&=+$,[]";
     */
    /* Same as reserved set but allow the hash character in a path too.
     */
    static const char *filepath = ";/?:@&=+$,[]#";
    
    if (nil == aUrlString)
    {
        RELEASE(self);
        return nil;       // OSX behavior is to give up.
    }
    ASSIGN(_baseURL, [aBaseUrl absoluteURL]);
    
    parsedURL	*buf;
    parsedURL	*base = baseData;
    unsigned	size = [_urlString length];
    char	*end;
    char	*start;
    char	*ptr;
    BOOL	usesFragments = YES;
    BOOL	usesParameters = YES;
    BOOL	usesQueries = YES;
    BOOL	canBeGeneric = YES;

    size += sizeof(parsedURL) + urlAlign + 1;
    buf = _parseModel = (parsedURL*)NSZoneMalloc(NSDefaultMallocZone(), size);
    memset(buf, '\0', size);
    start = end = ptr = (char*)&buf[1];
    
    [_urlString getCString: start maxLength: size encoding: NSASCIIStringEncoding];

    /*
     * Parse the scheme if possible.
     */
    ptr = start;
    if (isalpha(*ptr))
    {
        ptr++;
        while (isalnum(*ptr) || *ptr == '+' || *ptr == '-' || *ptr == '.')
        {
            ptr++;
        }
        if (*ptr == ':')
        {
            buf->scheme = start;		// Got scheme.
            *ptr = '\0';			// Terminate it.
            end = &ptr[1];
            /*
             * Standardise uppercase to lower.
             */
            while (--ptr > start)
            {
                if (isupper(*ptr))
                {
                    *ptr = tolower(*ptr);
                }
            }
        }
    }
    start = end;

    if (buf->scheme != 0 && base != 0
        && 0 != strcmp(buf->scheme, base->scheme))
    {
        /* The relative URL is of a different scheme to the base ...
         * so it's actually an absolute URL without a base.
         */
        DESTROY(_baseURL);
        base = 0;
    }

    if (buf->scheme == 0 && base != 0)
    {
        buf->scheme = base->scheme;
    }

    /*
     * Set up scheme specific parsing options.
     */
    if (buf->scheme != 0)
    {
        if (strcmp(buf->scheme, "file") == 0)
        {
            buf->isFile = YES;
        }
        else if (strcmp(buf->scheme, "data") == 0)
        {
            canBeGeneric = NO;
            DESTROY(_baseURL);
            base = 0;
        }
        else if (strcmp(buf->scheme, "mailto") == 0)
        {
            usesFragments = NO;
            usesParameters = NO;
            usesQueries = NO;
        }
        else if (strcmp(buf->scheme, "http") == 0
                 || strcmp(buf->scheme, "https") == 0)
        {
            buf->emptyPath = YES;
        }
    }

    if (canBeGeneric == YES)
    {
        /*
         * Parse the 'authority'
         * //user:password@host:port
         */
        if (start[0] == '/' && start[1] == '/')
        {
            buf->isGeneric = YES;
            start = end = &end[2];
            
            /*
             * Set 'end' to point to the start of the path, or just past
             * the 'authority' if there is no path.
             */
            end = strchr(start, '/');
            if (end == 0)
            {
                buf->hasNoPath = YES;
                end = &start[strlen(start)];
            }
            else
            {
                *end++ = '\0';
            }
            
            /*
             * Parser username:password part
             */
            ptr = strchr(start, '@');
            if (ptr != 0)
            {
                buf->user = start;
                *ptr++ = '\0';
                start = ptr;
                if (legal(buf->user, ";:&=+$,") == NO)
                {
                    [NSException raise: NSInvalidArgumentException
                                format: @"[%@ %@](%@, %@) "
                     @"illegal character in user/password part",
                     NSStringFromClass([self class]),
                     NSStringFromSelector(_cmd),
                     aUrlString, aBaseUrl];
                }
                ptr = strchr(buf->user, ':');
                if (ptr != 0)
                {
                    *ptr++ = '\0';
                    buf->password = ptr;
                }
            }
            
            /*
             * Parse host:port part
             */
            buf->host = start;
            if (*start == '[')
            {
                ptr = strchr(buf->host, ']');
                if (ptr == 0)
                {
                    [NSException raise: NSInvalidArgumentException
                                format: @"[%@ %@](%@, %@) "
                     @"illegal ipv6 host address",
                     NSStringFromClass([self class]),
                     NSStringFromSelector(_cmd),
                     aUrlString, aBaseUrl];
                }
                else
                {
                    ptr = start + 1;
                    while (*ptr != ']')
                    {
                        if (*ptr != ':' && *ptr != '.' && !isxdigit(*ptr))
                        {
                            [NSException raise: NSInvalidArgumentException
                                        format: @"[%@ %@](%@, %@) "
                             @"illegal ipv6 host address",
                             NSStringFromClass([self class]),
                             NSStringFromSelector(_cmd),
                             aUrlString, aBaseUrl];
                        }
                        ptr++;
                    }
                }
                ptr = strchr(ptr, ':');
            }
            else
            {
                ptr = strchr(buf->host, ':');
            }
            if (ptr != 0)
            {
                const char	*str;
                
                *ptr++ = '\0';
                buf->port = ptr;
                str = buf->port;
                while (*str != 0)
                {
                    if (*str == '%' && isxdigit(str[1]) && isxdigit(str[2]))
                    {
                        unsigned char	c;
                        
                        str++;
                        if (*str <= '9')
                        {
                            c = *str - '0';
                        }
                        else if (*str <= 'F')
                        {
                            c = *str - 'A' + 10;
                        }
                        else
                        {
                            c = *str - 'a' + 10;
                        }
                        c <<= 4;
                        str++;
                        if (*str <= '9')
                        {
                            c |= *str - '0';
                        }
                        else if (*str <= 'F')
                        {
                            c |= *str - 'A' + 10;
                        }
                        else
                        {
                            c |= *str - 'a' + 10;
                        }
                        
                        if (isdigit(c))
                        {
                            str++;
                        }
                        else
                        {
                            [NSException raise: NSInvalidArgumentException
                                        format: @"[%@ %@](%@, %@) "
                             @"illegal port part",
                             NSStringFromClass([self class]),
                             NSStringFromSelector(_cmd),
                             aUrlString, aBaseUrl];
                        }
                    }
                    else if (isdigit(*str))
                    {
                        str++;
                    }
                    else
                    {
                        [NSException raise: NSInvalidArgumentException
                                    format: @"[%@ %@](%@, %@) "
                         @"illegal character in port part",
                         NSStringFromClass([self class]),
                         NSStringFromSelector(_cmd),
                         aUrlString, aBaseUrl];
                    }
                }
            }
            start = end;
            /* Check for a legal host, unless it's an ipv6 address
             * (which would have been checked earlier).
             */
            if (*buf->host != '[' && legal(buf->host, "-") == NO)
            {
                [NSException raise: NSInvalidArgumentException
                            format: @"[%@ %@](%@, %@) "
                 @"illegal character in host part",
                 NSStringFromClass([self class]),
                 NSStringFromSelector(_cmd),
                 aUrlString, aBaseUrl];
            }
            
            /*
             * If we have an authority component,
             * this must be an absolute URL
             */
            buf->pathIsAbsolute = YES;
            base = 0;
        }
        else
        {
            if (base != 0)
            {
                buf->isGeneric = base->isGeneric;
            }
            if (*start == '/')
            {
                buf->pathIsAbsolute = YES;
                start++;
            }
        }
        
        if (usesFragments == YES)
        {
            /*
             * Strip fragment string from end of url.
             */
            ptr = strchr(start, '#');
            if (ptr != 0)
            {
                *ptr++ = '\0';
                if (*ptr != 0)
                {
                    buf->fragment = ptr;
                }
            }
            if (buf->fragment == 0 && base != 0)
            {
                buf->fragment = base->fragment;
            }
            if (legal(buf->fragment, filepath) == NO)
            {
                [NSException raise: NSInvalidArgumentException
                            format: @"[%@ %@](%@, %@) "
                 @"illegal character in fragment part",
                 NSStringFromClass([self class]),
                 NSStringFromSelector(_cmd),
                 aUrlString, aBaseUrl];
            }
        }
        
        if (usesQueries == YES)
        {
            /*
             * Strip query string from end of url.
             */
            ptr = strchr(start, '?');
            if (ptr != 0)
            {
                *ptr++ = '\0';
                if (*ptr != 0)
                {
                    buf->query = ptr;
                }
            }
            if (buf->query == 0 && base != 0)
            {
                buf->query = base->query;
            }
            if (legal(buf->query, filepath) == NO)
            {
                [NSException raise: NSInvalidArgumentException
                            format: @"[%@ %@](%@, %@) "
                 @"illegal character in query part",
                 NSStringFromClass([self class]),
                 NSStringFromSelector(_cmd),
                 aUrlString, aBaseUrl];
            }
        }
        
        if (usesParameters == YES)
        {
            /*
             * Strip parameters string from end of url.
             */
            ptr = strchr(start, ';');
            if (ptr != 0)
            {
                *ptr++ = '\0';
                if (*ptr != 0)
                {
                    buf->parameters = ptr;
                }
            }
            if (buf->parameters == 0 && base != 0)
            {
                buf->parameters = base->parameters;
            }
            if (legal(buf->parameters, filepath) == NO)
            {
                [NSException raise: NSInvalidArgumentException
                            format: @"[%@ %@](%@, %@) "
                 @"illegal character in parameters part",
                 NSStringFromClass([self class]),
                 NSStringFromSelector(_cmd),
                 aUrlString, aBaseUrl];
            }
        }
        
        if (buf->isFile == YES)
        {
            buf->user = 0;
            buf->password = 0;
            if (base != 0 && base->host != 0)
            {
                buf->host = base->host;
            }
            else if (buf->host != 0 && *buf->host == 0)
            {
                buf->host = 0;
            }
            buf->port = 0;
            buf->isGeneric = YES;
        }
        else if (base != 0
                 && buf->user == 0 && buf->password == 0
                 && buf->host == 0 && buf->port == 0)
        {
            buf->user = base->user;
            buf->password = base->password;
            buf->host = base->host;
            buf->port = base->port;
        }
    }
    /*
     * Store the path.
     */
    buf->path = start;
    if (0 == base && '\0' == *buf->path && NO == buf->pathIsAbsolute)
    {
        buf->hasNoPath = YES;
    }
    if (legal(buf->path, filepath) == NO)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@ %@](%@, %@) "
         @"illegal character in path part",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd),
         aUrlString, aBaseUrl];
    }
    return self;
}

- (NSString*) description
{
    NSString	*dscr = _urlString;
    
    if (_baseURL != nil)
    {
        dscr = [dscr stringByAppendingFormat: @" -- %@", _baseURL];
    }
    return dscr;
}

- (NSUInteger) hash
{
    return [[self absoluteString] hash];
}

- (BOOL) isEqual: (id)other
{
    if (other == nil || [other isKindOfClass: [NSURL class]] == NO)
    {
        return NO;
    }
    return [[self absoluteString] isEqualToString: [other absoluteString]];
}

- (NSString*) absoluteString
{
    NSString	*absString = self->_parseModel->absolute;
    
    if (absString == nil)
    {
        char	*url = buildURL(baseData, myData, NO);
        unsigned	len = strlen(url);
        
        absString = [[NSString alloc] initWithCStringNoCopy: url
                                                     length: len
                                               freeWhenDone: YES];
        self->_parseModel->absolute = absString;
    }
    return absString;
}

- (NSURL*) absoluteURL
{
    if (_baseURL == nil)
    {
        return self;
    }
    else
    {
        return [NSURL URLWithString: [self absoluteString]];
    }
}

- (NSURL*) baseURL
{
    return _baseURL;
}

- (BOOL) checkResourceIsReachableAndReturnError: (NSError **)error
{
    NSString *errorStr = nil;
    
    if ([self isFileURL])
    {
        NSFileManager *mgr = [NSFileManager defaultManager];
        NSString *path = [self path];
        
        if ([mgr fileExistsAtPath: path])
        {
            if (![mgr isReadableFileAtPath: path])
            {
                errorStr = @"File not readable";
            }
        }
        else
        {
            errorStr = @"File does not exist";
        }
    }
    else
    {
        errorStr = @"No file URL";
    }
    
    if ((errorStr != nil) && (error != NULL))
    {
        NSDictionary	*info;
        
        info = [NSDictionary dictionaryWithObjectsAndKeys:
                errorStr, NSLocalizedDescriptionKey, nil];
        *error = [NSError errorWithDomain: @"NSURLError"
                                     code: 0
                                 userInfo: info];
    }
    return nil == errorStr ? YES : NO;
}

- (NSString*) fragment
{
    NSString	*fragment = nil;
    
    if (self->_parseModel->fragment != 0)
    {
        fragment = [NSString stringWithUTF8String: self->_parseModel->fragment];
    }
    return fragment;
}

- (char*) _path: (char*)buf withEscapes: (BOOL)withEscapes
{
    char	*ptr = buf;
    char	*tmp = buf;
    int	l;
    
    if (self->_parseModel->pathIsAbsolute == YES)
    {
        if (self->_parseModel->hasNoPath == NO)
        {
            *tmp++ = '/';
        }
        if (self->_parseModel->path != 0)
        {
            l = strlen(self->_parseModel->path);
            memcpy(tmp, self->_parseModel->path, l + 1);
        }
    }
    else if (nil == _baseURL)
    {
        if (self->_parseModel->path != 0)
        {
            l = strlen(self->_parseModel->path);
            memcpy(tmp, self->_parseModel->path, l + 1);
        }
    }
    else if (0 == self->_parseModel->path || 0 == *self->_parseModel->path)
    {
        if (baseData->hasNoPath == NO)
        {
            *tmp++ = '/';
        }
        if (baseData->path != 0)
        {
            l = strlen(baseData->path);
            memcpy(tmp, baseData->path, l + 1);
        }
    }
    else
    {
        char	*start = baseData->path;
        char	*end = (start == 0) ? 0 : strrchr(start, '/');
        
        if (end != 0)
        {
            *tmp++ = '/';
            strncpy(tmp, start, end - start);
            tmp += end - start;
        }
        *tmp++ = '/';
        if (self->_parseModel->path != 0)
        {
            l = strlen(self->_parseModel->path);
            memcpy(tmp, self->_parseModel->path, l + 1);
        }
    }
    
    if (!withEscapes)
    {
        unescape(buf, buf);
    }
    return ptr;
}

- (NSString*) host
{
    NSString	*host = nil;
    
    if (self->_parseModel->host != 0)
    {
        char	buf[strlen(self->_parseModel->host)+1];
        
        if (*self->_parseModel->host == '[')
        {
            char	*end = unescape(self->_parseModel->host + 1, buf);
            
            if (end[-1] == ']')
            {
                end[-1] = '\0';
            }
        }
        else
        {
            unescape(self->_parseModel->host, buf);
        }
        host = [NSString stringWithUTF8String: buf];
    }
    return host;
}

- (BOOL) isFileURL
{
    return self->_parseModel->isFile;
}

- (NSString*) lastPathComponent
{
    return [[self path] lastPathComponent];
}

- (BOOL) getResourceValue: (id*)value 
                   forKey: (NSString *)key
                    error: (NSError**)error
{
    // TODO: unimplemented
    return NO;
}

- (void) loadResourceDataNotifyingClient: (id)client
                              usingCache: (BOOL)shouldUseCache
{
    NSURLHandle	*handle = [self URLHandleUsingCache: YES];
    NSData	*d;
    
    if (shouldUseCache == YES && (d = [handle availableResourceData]) != nil)
    {
        /*
         * We already have cached data we should use.
         */
        if ([client respondsToSelector:
             @selector(URL:resourceDataDidBecomeAvailable:)])
        {
            [client URL: self resourceDataDidBecomeAvailable: d];
        }
        if ([client respondsToSelector: @selector(URLResourceDidFinishLoading:)])
        {
            [client URLResourceDidFinishLoading: self];
        }
    }
    else
    {
        if (client != nil)
        {
            [clientsLock lock];
            if (_clients == 0)
            {
                _clients = NSCreateMapTable (NSObjectMapKeyCallBacks,
                                             NSNonRetainedObjectMapValueCallBacks, 0);
            }
            NSMapInsert((NSMapTable*)_clients, (void*)handle, (void*)client);
            [clientsLock unlock];
            [handle addClient: self];
        }
        
        /*
         * Kick off the load process.
         */
        [handle loadInBackground];
    }
}

- (NSString*) parameterString
{
    NSString	*parameters = nil;
    
    if (self->_parseModel->parameters != 0)
    {
        parameters = [NSString stringWithUTF8String: self->_parseModel->parameters];
    }
    return parameters;
}

- (NSString*) password
{
    NSString	*password = nil;
    
    if (self->_parseModel->password != 0)
    {
        char	buf[strlen(self->_parseModel->password)+1];
        
        unescape(self->_parseModel->password, buf);
        password = [NSString stringWithUTF8String: buf];
    }
    return password;
}

- (NSString*) _pathWithEscapes: (BOOL)withEscapes
{
    NSString	*path = nil;
    
    if (YES == self->_parseModel->isGeneric || 0 == self->_parseModel->scheme)
    {
        unsigned int	len = 3;
        
        if (_baseURL != nil)
        {
            if (baseData->path && *baseData->path)
            {
                len += strlen(baseData->path);
            }
            else if (baseData->hasNoPath == NO)
            {
                len++;
            }
        }
        if (self->_parseModel->path && *self->_parseModel->path)
        {
            len += strlen(self->_parseModel->path);
        }
        else if (self->_parseModel->hasNoPath == NO)
        {
            len++;
        }
        if (len > 3)
        {
            char		buf[len];
            char		*ptr;
            char		*tmp;
            
            ptr = [self _path: buf withEscapes: withEscapes];
            
            /* Remove any trailing '/' from the path for MacOS-X compatibility.
             */
            tmp = ptr + strlen(ptr) - 1;
            if (tmp > ptr && *tmp == '/')
            {
                *tmp = '\0';
            }
            
            path = [NSString stringWithUTF8String: ptr];
        }
        else if (YES == self->_parseModel->emptyPath)
        {
            /* OSX seems to use an empty string for some schemes,
             * though it normally uses nil.
             */
            path = @"";
        }
    }
    return path;
}

- (NSString*) path
{
    return [self _pathWithEscapes: NO];
}

- (NSArray*) pathComponents 
{
    return [[self path] pathComponents];
}

- (NSString*) pathExtension 
{
    return [[self path] pathExtension];
}

- (NSNumber*) port
{
    NSNumber	*port = nil;
    
    if (self->_parseModel->port != 0)
    {
        char	buf[strlen(self->_parseModel->port)+1];
        
        unescape(self->_parseModel->port, buf);
        port = [NSNumber numberWithUnsignedShort: atol(buf)];
    }
    return port;
}

- (id) propertyForKey: (NSString*)propertyKey
{
    NSURLHandle	*handle = [self URLHandleUsingCache: YES];
    
    return [handle propertyForKey: propertyKey];
}

- (NSString*) query
{
    NSString	*query = nil;
    
    if (self->_parseModel->query != 0)
    {
        query = [NSString stringWithUTF8String: self->_parseModel->query];
    }
    return query;
}

- (NSString*) relativePath
{
    if (nil == _baseURL)
    {
        return [self path];
    }
    else
    {
        NSString	*path = nil;
        
        if (self->_parseModel->path != 0)
        {
            char		buf[strlen(self->_parseModel->path) + 1];
            
            strcpy(buf, self->_parseModel->path);
            unescape(buf, buf);
            path = [NSString stringWithUTF8String: buf];
        }
        return path;
    }
}

- (NSString*) relativeString
{
    return _urlString;
}

/* Encode bycopy unless explicitly requested otherwise.
 */
- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
    if ([aCoder isByref] == NO)
        return self;
    return [super replacementObjectForPortCoder: aCoder];
}

- (NSData*) resourceDataUsingCache: (BOOL)shouldUseCache
{
    NSURLHandle	*handle = [self URLHandleUsingCache: YES];
    NSData	*data = nil;
    
    if ([handle status] == NSURLHandleLoadSucceeded)
    {
        data = [handle availableResourceData];
    }
    if (shouldUseCache == NO || [handle status] != NSURLHandleLoadSucceeded)
    {
        data = [handle loadInForeground];
    }
    if (nil == data)
    {
        data = [handle availableResourceData];
    }
    return data;
}

- (NSString*) resourceSpecifier
{
    if (YES == self->_parseModel->isGeneric)
    {
        NSRange	range = [_urlString rangeOfString: @"://"];
        
        if (range.length > 0)
        {
            NSString *specifier;
            
            /* MacOSX compatibility - in the case where there is no
             * host in the URL, just return the path (without the "//").
             * For all other cases we return the whole specifier.
             */
            if (nil == [self host])
            {
                specifier = [_urlString substringFromIndex: NSMaxRange(range)];
            }
            else
            {
                specifier = [_urlString substringFromIndex: range.location+1];
            }
            return specifier;
        }
        else
        {
            /*
             * Cope with URLs missing net_path info -  <scheme>:/<path>...
             */
            range = [_urlString rangeOfString: @":"];
            if (range.length > 0)
            {
                return [_urlString substringFromIndex: range.location + 1];
            }
            else
            {
                return _urlString;
            }
        }
    }
    else
    {
        return [NSString stringWithUTF8String: self->_parseModel->path];
    }
}

- (NSString*) scheme
{
    NSString	*scheme = nil;
    
    if (self->_parseModel->scheme != 0)
    {
        scheme = [NSString stringWithUTF8String: self->_parseModel->scheme];
    }
    return scheme;
}

- (BOOL) setProperty: (id)property
              forKey: (NSString*)propertyKey
{
    NSURLHandle	*handle = [self URLHandleUsingCache: YES];
    
    return [handle writeProperty: property forKey: propertyKey];
}

- (BOOL) setResourceData: (NSData*)data
{
    NSURLHandle	*handle = [self URLHandleUsingCache: YES];
    
    if (handle == nil)
    {
        return NO;
    }
    if ([handle writeData: data] == NO)
    {
        return NO;
    }
    if ([handle loadInForeground] == nil)
    {
        return NO;
    }
    return YES;
}

- (NSURL*) standardizedURL
{
    char		*url = buildURL(baseData, myData, YES);
    unsigned	len = strlen(url);
    NSString	*str;
    NSURL		*tmp;
    
    str = [[NSString alloc] initWithCStringNoCopy: url
                                           length: len
                                     freeWhenDone: YES];
    tmp = [NSURL URLWithString: str];
    RELEASE(str);
    return tmp;
}

- (NSURLHandle*) URLHandleUsingCache: (BOOL)shouldUseCache
{
    NSURLHandle	*handle = nil;
    
    if (shouldUseCache)
    {
        handle = [NSURLHandle cachedHandleForURL: self];
    }
    if (handle == nil)
    {
        Class	c = [NSURLHandle URLHandleClassForURL: self];
        
        if (c != 0)
        {
            handle = [[c alloc] initWithURL: self cached: shouldUseCache];
            IF_NO_GC([handle autorelease];)
        }
    }
    return handle;
}

- (NSString*) user
{
    NSString	*user = nil;
    
    if (self->_parseModel->user != 0)
    {
        char	buf[strlen(self->_parseModel->user)+1];
        
        unescape(self->_parseModel->user, buf);
        user = [NSString stringWithUTF8String: buf];
    }
    return user;
}

- (NSURL*) URLByAppendingPathComponent: (NSString*)pathComponent 
{
    return [self _URLBySettingPath:
            [[self path] stringByAppendingPathComponent: pathComponent]];
}

- (NSURL*) URLByAppendingPathExtension: (NSString*)pathExtension
{
    return [self _URLBySettingPath:
            [[self path] stringByAppendingPathExtension: pathExtension]];
}

- (NSURL*) URLByDeletingLastPathComponent 
{
    return [self _URLBySettingPath:
            [[self path] stringByDeletingLastPathComponent]];
}

- (NSURL*) URLByDeletingPathExtension 
{
    return [self _URLBySettingPath:
            [[self path] stringByDeletingPathExtension]];
}

- (NSURL*) URLByResolvingSymlinksInPath 
{
    if ([self isFileURL])
    {
        return [NSURL fileURLWithPath:
                [[self path] stringByResolvingSymlinksInPath]];
    }
    return self;
}

- (NSURL*) URLByStandardizingPath 
{
    if ([self isFileURL])
    {
        return [NSURL fileURLWithPath: [[self path] stringByStandardizingPath]];
    }
    return self;
}

- (void) URLHandle: (NSURLHandle*)sender
resourceDataDidBecomeAvailable: (NSData*)newData
{
    id	c = clientForHandle(_clients, sender);
    
    if ([c respondsToSelector: @selector(URL:resourceDataDidBecomeAvailable:)])
    {
        [c URL: self resourceDataDidBecomeAvailable: newData];
    }
}

- (void) URLHandle: (NSURLHandle*)sender
resourceDidFailLoadingWithReason: (NSString*)reason
{
    id	c = clientForHandle(_clients, sender);
    
    if (c != nil)
    {
        if ([c respondsToSelector:
             @selector(URL:resourceDidFailLoadingWithReason:)])
        {
            [c URL: self resourceDidFailLoadingWithReason: reason];
        }
        [clientsLock lock];
        NSMapRemove((NSMapTable*)_clients, (void*)sender);
        [clientsLock unlock];
    }
    [sender removeClient: self];
}

- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender
{
}

- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender
{
    id	c = clientForHandle(_clients, sender);
    
    if (c != nil)
    {
        if ([c respondsToSelector: @selector(URLResourceDidCancelLoading:)])
        {
            [c URLResourceDidCancelLoading: self];
        }
        [clientsLock lock];
        NSMapRemove((NSMapTable*)_clients, (void*)sender);
        [clientsLock unlock];
    }
    [sender removeClient: self];
}

- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender
{
    id	c = clientForHandle(_clients, sender);
    
    IF_NO_GC([self retain];)
    [sender removeClient: self];
    if (c != nil)
    {
        if ([c respondsToSelector: @selector(URLResourceDidFinishLoading:)])
        {
            [c URLResourceDidFinishLoading: self];
        }
        [clientsLock lock];
        NSMapRemove((NSMapTable*)_clients, (void*)sender);
        [clientsLock unlock];
    }
    RELEASE(self);
}

@end



/**
 * An informal protocol to which clients may conform if they wish to be
 * notified of the progress in loading a URL for them.  NSURL conforms to
 * this protocol but all methods are implemented as no-ops.  See also
 * the [(NSURLHandleClient)] protocol.
 */
@implementation NSObject (NSURLClient)

- (void) URL: (NSURL*)sender
resourceDataDidBecomeAvailable: (NSData*)newBytes
{
}

- (void) URL: (NSURL*)sender
resourceDidFailLoadingWithReason: (NSString*)reason
{
}

- (void) URLResourceDidCancelLoading: (NSURL*)sender
{
}

- (void) URLResourceDidFinishLoading: (NSURL*)sender
{
}

@end

@implementation NSURL (GNUstepBase)
- (NSString*) fullPath
{
    NSString	*path = nil;
    
    if (YES == self->_parseModel->isGeneric || 0 == self->_parseModel->scheme)
    {
        unsigned int	len = 3;
        
        if (_baseURL != nil)
        {
            if (baseData->path && *baseData->path)
            {
                len += strlen(baseData->path);
            }
            else if (baseData->hasNoPath == NO)
            {
                len++;
            }
        }
        if (self->_parseModel->path && *self->_parseModel->path)
        {
            len += strlen(self->_parseModel->path);
        }
        else if (self->_parseModel->hasNoPath == NO)
        {
            len++;
        }
        if (len > 3)
        {
            char		buf[len];
            char		*ptr;
            
            ptr = [self _path: buf withEscapes: NO];
            path = [NSString stringWithUTF8String: ptr];
        }
    }
    return path;
}

- (NSString*) pathWithEscapes
{
    return [self _pathWithEscapes: YES];
}
@end

