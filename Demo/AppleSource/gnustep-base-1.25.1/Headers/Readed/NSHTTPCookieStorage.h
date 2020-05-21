#ifndef __NSHTTPCookieStorage_h_GNUSTEP_BASE_INCLUDE
#define __NSHTTPCookieStorage_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>


@class NSArray;
@class NSHTTPCookie;
@class NSURL;

/*
 同源政策 // http://www.ruanyifeng.com/blog/2016/04/same-origin-policy.html
 如果两个页面的1 协议，2 端口（如果有指定）和3 域名都相同，则两个页面具有相同的源
 最初，它的含义是指，A网页设置的 Cookie，B网页不能打开，除非这两个网页"同源"。所谓"同源"指的是"三个相同"。
 同源政策的目的，是为了保证用户信息的安全，防止恶意的网站窃取数据。
 目前，如果非同源，共有三种行为受到限制。
 （1） Cookie、LocalStorage 和 IndexDB 无法读取。
 （2） DOM 无法获得。
 （3） AJAX 请求不能发送。
 浏览器允许通过设置document.domain共享 Cookie。
 举例来说，A网页是http://w1.example.com/a.html，B网页是http://w2.example.com/b.html，那么只要设置相同的document.domain，两个网页就可以共享Cookie。
 */

enum {
    NSHTTPCookieAcceptPolicyAlways,
    NSHTTPCookieAcceptPolicyNever,
    NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain
};
/**
 * NSHTTPCookieAcceptPolicyAlways Accept all cookies
 * NSHTTPCookieAcceptPolicyNever Reject all cookies
 * NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain Accept cookies
 * only from the main document domain
 */
typedef NSUInteger NSHTTPCookieAcceptPolicy;

/**
 * Posted to the distributed notification center when the cookie
 * accept policy is changed.
 */
extern NSString * const NSHTTPCookieManagerAcceptPolicyChangedNotification;

/**
 * Posted when the set of cookies changes
 */
extern NSString * const NSHTTPCookieManagerCookiesChangedNotification;


/**
 * The NSHTTPCookieStorage class provides a shared instance which handles
 * the shared cookie store.<br />
 */

@interface NSHTTPCookieStorage :  NSObject
{
    void	*_NSHTTPCookieStorageInternal;
}

/**
 * Returns the shared instance.
 */
+ (NSHTTPCookieStorage *) sharedHTTPCookieStorage;

/**
 * Returns the current cookie accept policy.
 */
- (NSHTTPCookieAcceptPolicy) cookieAcceptPolicy;

/**
 * Returns an array of all managed cookies.
 */
- (NSArray *) cookies;

/**
 *  Returns an array of all known cookies to send to URL.
 */
- (NSArray *) cookiesForURL: (NSURL *)URL;

/**
 * Deletes cookie from the shared store.
 */
- (void) deleteCookie: (NSHTTPCookie *)cookie;

/**
 * Sets a cookie in the store, replacing any existing cookie with the
 * same name, domain and path.
 */
- (void) setCookie: (NSHTTPCookie *)cookie;

/**
 * Sets the current cookie accept policy.
 */
- (void) setCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy;

/**
 * Adds to the shared store following the policy for
 * NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain
 */
- (void) setCookies: (NSArray *)cookies
             forURL: (NSURL *)URL
    mainDocumentURL: (NSURL *)mainDocumentURL;

@end

#endif	/* 100200 */

#endif	/* __NSHTTPCookieStorage_h_GNUSTEP_BASE_INCLUDE */
