#ifndef __NSHTTPCookieStorage_h_GNUSTEP_BASE_INCLUDE
#define __NSHTTPCookieStorage_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

@class NSArray;
@class NSHTTPCookie;
@class NSURL;

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
NSHTTPCookieAcceptPolicy    _policy;
NSMutableArray        *_cookies;
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
