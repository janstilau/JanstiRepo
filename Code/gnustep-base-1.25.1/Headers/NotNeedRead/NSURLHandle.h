#ifndef __NSURLHandle_h_GNUSTEP_BASE_INCLUDE
#define __NSURLHandle_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSData;
@class NSString;
@class NSMutableArray;
@class NSMutableData;
@class NSURLHandle;
@class NSURL;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain status code.
 */
GS_EXPORT NSString * const NSHTTPPropertyStatusCodeKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain status reason.
 */
GS_EXPORT NSString * const NSHTTPPropertyStatusReasonKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain HTTP version supported by server.
 */
GS_EXPORT NSString * const NSHTTPPropertyServerHTTPVersionKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain redirection headers.
 */
GS_EXPORT NSString * const NSHTTPPropertyRedirectionHeadersKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain error page data.
 */
GS_EXPORT NSString * const NSHTTPPropertyErrorPageDataKey;

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain local host.
 */
GS_EXPORT NSString * const GSHTTPPropertyLocalHostKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain method (GET, POST, etc.).
 */
GS_EXPORT NSString * const GSHTTPPropertyMethodKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain proxy host.
 */
GS_EXPORT NSString * const GSHTTPPropertyProxyHostKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * obtain proxy port.
 */
GS_EXPORT NSString * const GSHTTPPropertyProxyPortKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * specify the location of an SSL certificate file.
 */
GS_EXPORT NSString * const GSHTTPPropertyCertificateFileKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * specify the location of an SSL key file.
 */
GS_EXPORT NSString * const GSHTTPPropertyKeyFileKey;

/**
 * Key for passing to [NSURLHandle]'s <code>propertyForKey..</code> methods to
 * specify the password for an SSL key file.
 */
GS_EXPORT NSString * const GSHTTPPropertyPasswordKey;

#endif

/**
 * Enumerated type returned by [NSURLHandle-status]:
<example>
{
  NSURLHandleNotLoaded
  NSURLHandleLoadSucceeded,
  NSURLHandleLoadInProgress,
  NSURLHandleLoadFailed
}
</example>
 */
enum
{
  NSURLHandleNotLoaded = 0,
  NSURLHandleLoadSucceeded,
  NSURLHandleLoadInProgress,
  NSURLHandleLoadFailed
};
typedef NSUInteger NSURLHandleStatus;

/**
 * A protocol to which clients of a handle must conform in order to
 * receive notification of events on the handle.
 */
@protocol NSURLHandleClient

/**
 * Sent by the NSURLHandle object when some data becomes available
 * from the handle.  Note that this does not mean that all data has become
 * available, only that a chunk of data has arrived.
 */
- (void) URLHandle: (NSURLHandle*)sender
  resourceDataDidBecomeAvailable: (NSData*)newData;

/**
 * Sent by the NSURLHandle object on resource load failure.
 * Supplies a human readable failure reason.
 */
- (void) URLHandle: (NSURLHandle*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason;

/**
 * Sent by the NSURLHandle object when it begins loading
 * resource data.
 */
- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender;

/**
 * Sent by the NSURLHandle object when resource loading is cancelled
 * by programmatic request (rather than by failure).
 */
- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender;

/**
 * Sent by the NSURLHandle object when it completes loading
 * resource data.
 */
- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender;
@end

    
    // MAC OS 专属类
@interface NSURLHandle : NSObject
{
#if	GS_EXPOSE(NSURLHandle)
@protected
  id			_data;
  NSMutableArray	*_clients;
  NSString		*_failure; 
  NSURLHandleStatus	_status;
#endif
}

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)url;
+ (BOOL) canInitWithURL: (NSURL*)url;
+ (void) registerURLHandleClass: (Class)urlHandleSubclass;
+ (Class) URLHandleClassForURL: (NSURL*)url;

- (void) addClient: (id <NSURLHandleClient>)client;
- (NSData*) availableResourceData;
- (void) backgroundLoadDidFailWithReason: (NSString*)reason;
- (void) beginLoadInBackground;
- (void) cancelLoadInBackground;
- (void) didLoadBytes: (NSData*)newData
	 loadComplete: (BOOL)loadComplete;
- (void) endLoadInBackground;
- (NSString*) failureReason;
- (void) flushCachedData;
- (id) initWithURL: (NSURL*)url
	    cached: (BOOL)cached;
- (void) loadInBackground;
- (NSData*) loadInForeground;
- (id) propertyForKey: (NSString*)propertyKey;
- (id) propertyForKeyIfAvailable: (NSString*)propertyKey;
- (void) removeClient: (id <NSURLHandleClient>)client;
- (NSData*) resourceData;
- (NSURLHandleStatus) status;
- (BOOL) writeData: (NSData*)data;
- (BOOL) writeProperty: (id)propertyValue
		forKey: (NSString*)propertyKey;


@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif /* __NSURLHandle_h_GNUSTEP_BASE_INCLUDE */

