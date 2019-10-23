#ifndef __NSHTTPCookie_h_GNUSTEP_BASE_INCLUDE
#define __NSHTTPCookie_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

/*
 
 https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Cookies
 
 
 HTTP Cookie是服务器发送到用户浏览器并保存在本地的一小块数据，它会在浏览器下次向同一服务器再发起请求时被携带并发送到服务器上。
 通常，它用于告知服务端两个请求是否来自同一浏览器，如保持用户的登录状态。Cookie使基于无状态的HTTP协议记录稳定的状态信息成为了可能。
 会话状态管理（如用户登录状态、购物车、游戏分数或其它需要记录的信息）
 个性化设置（如用户自定义设置、主题等）
 浏览器行为跟踪（如跟踪分析用户行为等）
 Cookie曾一度用于客户端数据的存储，因当时并没有其它合适的存储办法而作为唯一的存储手段，
 但现在随着现代浏览器开始支持各种各样的存储方式，Cookie渐渐被淘汰。
 由于服务器指定Cookie后，浏览器的每次请求都会携带Cookie数据，会带来额外的性能开销（尤其是在移动环境下）。新的浏览器API已经允许开发者直接将数据存储到本地，如使用 Web storage API （本地存储和会话存储）或 IndexedDB 。
 因为浏览器的是一套在规范下开发出来的应用, 所以 H5 的开发者, 其实是不能确认, 除了规范外是否有其他的存储方式, 只有在规范中明确提及了可以这样存储的时候, 并且浏览器支持的情况下才可以.
 所以, cookie 这种东西, 是因为不是专门的系统应用的开发者, 不能直接和系统 API 交互而出现的一种存储数据的一种手段.
 在应用开始里面, 因为可以直接用各种方式, 进行存储和读取工作, 所以, 也就不会使用 cookie 这种很别扭的办法了.
 
 当服务器收到HTTP请求时，服务器可以在响应头里面添加一个Set-Cookie选项。浏览器收到响应后通常会保存下Cookie，之后对该服务器每一次请求中都通过Cookie请求头部将Cookie信息发送给服务器。另外，Cookie的过期时间、域、路径、有效期、适用站点都可以根据需要来指定。
 Set-Cookie: <cookie名>=<cookie值>
 HTTP/1.0 200 OK
 Content-type: text/html
 Set-Cookie: yummy_cookie=choco
 Set-Cookie: tasty_cookie=strawberry // 响应里面, 可以设置多个 Set-Cookie:
 现在，对该服务器发起的每一次新请求，浏览器都会将之前保存的Cookie信息通过Cookie请求头部再发送给服务器。
 GET /sample_page.html HTTP/1.1
 Host: www.example.org
 Cookie: yummy_cookie=choco; tasty_cookie=strawberry
 
 会话期Cookie是最简单的Cookie：浏览器关闭之后它会被自动删除，也就是说它仅在会话期内有效。
 会话期Cookie不需要指定过期时间（Expires）或者有效期（Max-Age）。需要注意的是，有些浏览器提供了会话恢复功能，这种情况下即使关闭了浏览器，会话期Cookie也会被保留下来，就好像浏览器从来没有关闭一样。
 
 和关闭浏览器便失效的会话期Cookie不同，持久性Cookie可以指定一个特定的过期时间（Expires）或有效期（Max-Age）。
 Set-Cookie: id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT;
 在上面, Set-Cookie 中添加了Expires 的属性, 这样, 客户端在判断当前时间之后, 可以判断出是否这个 cookie 已经失效了.
 
 
 标记为 Secure 的Cookie只应通过被HTTPS协议加密过的请求发送给服务端。但即便设置了 Secure 标记，敏感信息也不应该通过Cookie传输，因为Cookie有其固有的不安全性，Secure 标记也无法提供确实的安全保障。
 从 Chrome 52 和 Firefox 52 开始，不安全的站点（http:）无法使用Cookie的 Secure 标记。
 为避免跨域脚本 (XSS) 攻击，通过JavaScript的 Document.cookie API无法访问带有 HttpOnly 标记的Cookie，它们只应该发送给服务端。
 如果包含服务端 Session 信息的 Cookie 不想被客户端 JavaScript 脚本调用，那么就应该为其设置 HttpOnly 标记。
 也就是说, JS 里面的 Document.cookie 不能够拿到某些设置为了 HttpOnly 的 cookie 的值.
 cookie 铁定是在浏览器中进行存储的, 但是怎么进行存储的, 浏览器不一样, 浏览器也不会让你知道.
 H5 以及相应的 JS, 是浏览器的使用者,  只能够使用浏览器暴露出来的接口进行编程. 所以, H5 的编程, 是在浏览器 API 的限制下进行的编程, 是没有办法拿到浏览器的内部数据的.
 
 Domain 和 Path 标识定义了Cookie的作用域：即Cookie应该发送给哪些URL
 Domain 标识指定了哪些主机可以接受Cookie。如果不指定，默认为当前文档的主机（不包含子域名）。如果指定了Domain，则一般包含子域名。
 例如，如果设置 Domain=mozilla.org，则Cookie也包含在子域名中（如developer.mozilla.org）。
 Path 标识指定了主机下的哪些路径可以接受Cookie（该URL路径必须存在于请求URL中）。以字符 %x2F ("/") 作为路径分隔符，子路径也会被匹配。
 例如，设置 Path=/docs，则以下地址都会匹配：
 /docs
 /docs/Web/
 /docs/Web/HTTP
 这里就是一个过滤功能. 所有服务器的 setCookie 都会被记录下载, 但是在和服务器进行交互的时候, 应该发送哪些 cookie 到这个服务器呢, 就是通过 domain 和 path 进行过滤的. 原则是, 子路径会接收到父路径的 cookie 信息.
 
 */

@class NSArray;
@class NSDate;
@class NSDictionary;
@class NSString;
@class NSURL;

extern NSString * const NSHTTPCookieComment; /** Obtain text of the comment */
extern NSString * const NSHTTPCookieCommentURL; /** Obtain the comment URL */
extern NSString * const NSHTTPCookieDiscard; /** Obtain the sessions discard setting */
extern NSString * const NSHTTPCookieDomain; /** Obtain cookie domain */
extern NSString * const NSHTTPCookieExpires; /** Obtain cookie expiry date */
extern NSString * const NSHTTPCookieMaximumAge; /** Obtain maximum age (expiry) */
extern NSString * const NSHTTPCookieName; /** Obtain name of cookie */
extern NSString * const NSHTTPCookieOriginURL; /** Obtain cookie origin URL */
extern NSString * const NSHTTPCookiePath; /** Obtain cookie path */
extern NSString * const NSHTTPCookiePort; /** Obtain cookie ports */
extern NSString * const NSHTTPCookieSecure; /** Obtain cookie security */
extern NSString * const NSHTTPCookieValue; /** Obtain value of cookie */
extern NSString * const NSHTTPCookieVersion; /** Obtain cookie version */


/**
 
 HTTPCookie 的内部存储是用一个通用字典保持的, 不同的属性, 其实就是用不同的 key 值取访问更新这个字典.
 
 */
@interface NSHTTPCookie :  NSObject
{
@public
    NSDictionary    *_properties;
@private
    void	*_NSHTTPCookieInternal;
}

/**
 * Allocates and returns an autoreleasd instance using -initWithProperties:
 * to initialise it from properties.
 */
+ (id) cookieWithProperties: (NSDictionary *)properties;

/**
 * Returns an array of cookies parsed from the headerFields and URL
 * (assuming that the headerFields came from a response to a request
 * sent to the URL).<br />
 * The headerFields dictionary must contain at least all the headers
 * relevant to cookie setting ... other headers are ignored.
 */
+ (NSArray *) cookiesWithResponseHeaderFields: (NSDictionary *)headerFields
                                       forURL: (NSURL *)URL;

/**
 * Returns a dictionary of header fields that can be used to add the
 * specified cookies to a request.
 */
+ (NSDictionary *) requestHeaderFieldsWithCookies: (NSArray *)cookies;

/**
 * Returns a string which may be used to describe the cookie to the
 * user, or nil if no comment is set.
 */
- (NSString *) comment;

/**
 * Returns a URL where the user can find out about the cookie, or nil
 * if no comment URL is set.
 */
- (NSURL *) commentURL;

/**
 * Returns the domain to which the cookie should be sent.<br />
 * If there is a leading dot then subdomains should also receive the
 * cookie as specified in RFC 2965.
 */
- (NSString *) domain;

/**
 * Returns the expiry date of the receiver or nil if there is no
 * such date.
 */
- (NSDate *) expiresDate;

/** <init />
 *  Initialises the receiver with a dictionary of properties.<br />
 *  Unrecognised keys are ignored.<br />
 *  Returns nil if a required key is missing or if an illegal
 *  value is specified for a key.
 *  <deflist>
 *    <term>NSHTTPCookieComment</term>
 *    <desc>
 *      The [NSString] comment for the cookie (if any).<br />
 *      This is nil by default and for unversioned cookies.
 *    </desc>
 *    <term>NSHTTPCookieCommentURL</term>
 *    <desc>
 *      The [NSString] or [NSURL] URL to get the comment for the cookie.<br />
 *      This is nil by default and for unversioned cookies.
 *    </desc>
 *    <term>NSHTTPCookieDomain</term>
 *    <desc>
 *      The [NSString] specified the domain to which the cookie applies.<br />
 *      This is extracted from NSHTTPCookieOriginURL if not specified.
 *    </desc>
 *    <term>NSHTTPCookieDiscard</term>
 *    <desc>
 *      A [NSString] (either TRUE or FALSE) saying whether the cookie
 *      is to be discarded when the session ends.<br />
 *      Defaults to FALSE except for versioned cookies where
 *      NSHTTPCookieMaximumAge is unspecified.
 *    </desc>
 *    <term>NSHTTPCookieExpires</term>
 *    <desc>
 *      The [NSDate] or [NSString] (format Wdy, DD-Mon-YYYY HH:MM:SS GMT)
 *      specifying when an unversioned cookie expires and ignored for
 *      versioned cookies.
 *    </desc>
 *    <term>NSHTTPCookieMaximumAge</term>
 *    <desc>
 *      An [NSString] containing an integer value specifying the longest time
 *      (in seconds) for which the cookie is valid.<br />
 *      This defaults to zero and is only meaningful for versioned cookies.
 *    </desc>
 *    <term>NSHTTPCookieName</term>
 *    <desc>
 *      An [NSString] ... obvious ... no default value.
 *    </desc>
 *    <term>NSHTTPCookieOriginURL</term>
 *    <desc>
 *      An [NSString] or [NSURL] specifying the URL which set the cookie.<br />
 *      Must be supplied if NSHTTPCookieDomain is not.
 *    </desc>
 *    <term>NSHTTPCookiePath</term>
 *    <desc>
 *      An [NSString] specifying the path from the cookie.<br />
 *      If unspecified this value is determined from NSHTTPCookieOriginURL
 *      or defaults to '/'.
 *    </desc>
 *    <term>NSHTTPCookiePort</term>
 *    <desc>
 *      An [NSString] containing a comma separated list of integer port
 *      numbers.  This is valid for versioned cookies and defaults to
 *      an empty string.
 *    </desc>
 *    <term>NSHTTPCookieSecure</term>
 *    <desc>
 *      An [NSString] saying whether the cookie may be sent over
 *      insecure connections.<br />
 *      The default is FALSE meaning that it may be sent insecurely.
 *    </desc>
 *    <term>NSHTTPCookieValue</term>
 *    <desc>
 *      An [NSString] containing the whole value of the cooke.<br />
 *      This parameter <strong>must</strong> be provided.
 *    </desc>
 *    <term>NSHTTPCookieVersion</term>
 *    <desc>
 *      An [NSString] specifying the cookie version ... for an
 *      unversioned cookie (the default) this is '0'.<br />
 *      Also supports version '1'.
 *    </desc>
 *  </deflist>
 */
- (id) initWithProperties: (NSDictionary *)properties;

/**
 * Returns whether the receiver should only be sent over
 * secure connections.
 */
#if GS_HAS_DECLARED_PROPERTIES
@property (readonly, getter=isSecure) BOOL secure;
#else
- (BOOL) isSecure;
#endif

/**
 * Returns whether the receiver should be destroyed at the end of the
 * session.
 */
#if GS_HAS_DECLARED_PROPERTIES
@property (readonly, getter=isSessionOnly) BOOL sessionOnly;
#else
- (BOOL) isSessionOnly;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST)
#if GS_HAS_DECLARED_PROPERTIES
@property (readonly, getter=isHTTPOnly) BOOL HTTPOnly;
#else
- (BOOL) isHTTPOnly;
#endif
#endif

/**
 * Returns the name of the receiver.
 */
- (NSString *) name;

/**
 * Returns the URL path within the cookie's domain for which
 * this cookie must be sent.
 */
- (NSString *) path;

/**
 * Returns the list of ports to which the receiver should be sent,
 * or nil if the cookie can be used for any port.
 */
- (NSArray *) portList;

/**
 * Returns a dictionary representation of the receiver which could be
 * used as the argument for -initWithProperties: to recreate a copy
 * of the receiver.
 */
- (NSDictionary *) properties;

/**
 * Returns the value of the receiver.
 */
- (NSString *) value;

/**
 * Returns 0 for an unversioned Netscape style cookie or a
 * positive integer for a versioned cookie.
 */
- (NSUInteger) version;

@end

#endif	/* 100200 */

#endif	/* __NSHTTPCookie_h_GNUSTEP_BASE_INCLUDE */
