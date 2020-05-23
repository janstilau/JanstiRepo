#ifndef __NSHTTPCookie_h_GNUSTEP_BASE_INCLUDE
#define __NSHTTPCookie_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

/*
 Cookie（复数形态Cookies），又称为“小甜饼”。类型为“小型文本文件”[1]，指某些网站为了辨别用户身份而储存在用户本地终端（Client Side）上的数据（通常经过加密）
 因为HTTP协议是无状态的，即服务器不知道用户上一次做了什么，这严重阻碍了交互式Web应用程序的实现。
 服务器可以设置或读取Cookies中包含信息，借此维护用户跟服务器会话中的状态。
 在刚才的购物场景中，当用户选购了第一项商品，服务器在向用户发送网页的同时，还发送了一段Cookie，记录着那项商品的信息。当用户访问另一个页面，浏览器会把Cookie发送给服务器，于是服务器知道他之前选购了什么。用户继续选购饮料，服务器就在原来那段Cookie里追加新的商品信息。结帐时，服务器读取发送来的Cookie就行了。
 Cookie另一个典型的应用是当登录一个网站时，网站往往会请求用户输入用户名和密码，并且用户可以勾选“下次自动登录”。如果勾选了，那么下次访问同一网站时，用户会发现没输入用户名和密码就已经登录了。这正是因为前一次登录时，服务器发送了包含登录凭据（用户名加密码的某种加密形式）的Cookie到用户的硬盘上。第二次登录时，如果该Cookie尚未到期，浏览器会发送该Cookie，服务器验证凭据，于是不必输入用户名和密码就让用户登录了。
 Cookie会被附加在每个HTTP请求中，所以无形中增加了流量。
 由于在HTTP请求中的Cookie是明文传递的，所以安全性成问题，除非用HTTPS。
 Cookie的大小限制在4KB左右，对于复杂的存储需求来说是不够用的.
 
 # 前段存储策略
 1. 存储在cookie中的数据，每次都会被浏览器自动放在http请求中，如果这些数据并不是每个请求都需要发给服务端的数据，浏览器这设置自动处理无疑增加了网络开销；但如果这些数据是每个请求都需要发给服务端的数据（比如身份认证信息），浏览器这设置自动处理就大大免去了重复添加操作。所以对于那种设置“每次请求都要携带的信息（最典型的就是身份认证信息）”就特别适合放在cookie中，其他类型的数据就不适合了。
 cookie的存储是以域名形式进行区分的，不同的域下存储的cookie是独立的。
 2. localStorage H5 才出现的东西.
 大小：据说是5M（跟浏览器厂商有关系）
 3. sessionStorage
 
 从前面我们可以知道, 在H5 之前, 一个网页应用很难存储自己的数据到数据库中.
 对于一个 app 来说, 我们可以存储自己的数据到自己的沙盒中, 自己所在的文件夹中, 因为自己可以直接和操作系统接口打交道, 但是, 对于一个网页 app 来说, 没有办法记录自己的信息在哪里, 只能通过浏览器才能存储数据. 所以, cookie 非常重要.
 
 
 http://bubkoo.com/2014/04/21/http-cookies-explained/
 cookie 的详细信息.
 
 这个 cookie 有四个标识符：cookie 的 name，domain，path，secure 标记。要想改变这个 cookie 的值，需要发送另一个具有相同 cookie name，domain，path 的 Set-Cookie 消息头。例如：
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
 *  An instance of the NSHTTPCookie class is a single, immutable http cookie.
 *  It can be initialised with properties from a dictionary and has accessor
 *  methods to obtain the cookie values.<br />
 cookie 天生就是 NSDictionary 的形式.
 *  The class supports unversioned cookies (sometimes referred to as version 0)
 *  as originally produced by netscape, as well as more recent standardised
 *  and versioned cookies.
 */
@interface NSHTTPCookie :  NSObject
{
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
- (int) version;

@end


#endif	/* 100200 */

#endif	/* __NSHTTPCookie_h_GNUSTEP_BASE_INCLUDE */
