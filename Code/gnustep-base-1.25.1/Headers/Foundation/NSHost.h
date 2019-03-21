#ifndef __NSHost_h_GNUSTEP_BASE_INCLUDE
#define __NSHost_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString, NSArray, NSSet;

/**
 *  Instances of this class encapsulate host information.  Constructors based
 *  on host name or numeric address are provided.
 */
@interface NSHost : NSObject
{
#if	GS_EXPOSE(NSHost)
  @private
  NSSet	*_names;
  NSSet	*_addresses;
#endif
#if     GS_NONFRAGILE
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}

/**
 * Get current host object.
 */
+ (NSHost*) currentHost;

/**
 *  Get info for host with given DNS name.
 */
+ (NSHost*) hostWithName: (NSString*)name;

/**
 *  Get a host object.  Hosts are cached for efficiency.  The address
 *  must be an IPV4 "dotted decimal" string, e.g.
 <example>
  NSHost aHost = [NSHost hostWithAddress:@"192.42.172.1"];
 </example>
 */
+ (NSHost*) hostWithAddress: (NSString*)address;

/**
 * Set host cache management.
 * If enabled, only one object representing each host will be created, and
 * a shared instance will be returned by all methods that return a host.
 */
+ (void) setHostCacheEnabled: (BOOL)flag;

/**
 * Return host cache management.
 * If enabled, only one object representing each host will be created, and
 * a shared instance will be returned by all methods that return a host.
 */
+ (BOOL) isHostCacheEnabled;

/**
 * Clear cache of host info instances.
 */
+ (void) flushHostCache;

/**
 * Compare hosts.
 * Hosts are equal if they share at least one address
 */
- (BOOL) isEqualToHost: (NSHost*) aHost;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST) 
/**
 * If the receiver is the currentHost, returns the default name of the
 * computer, otherwise returns nil.
 */
- (NSString*) localizedName;
#endif

/**
 * Return host name.  Chosen arbitrarily if a host has more than one.
 */
- (NSString*) name;

/**
 * Return all known names for host.
 */
- (NSArray*) names;

/**
 * Return host address in "dotted decimal" notation, e.g. "192.42.172.1".
 * Chosen arbitrarily if a host has more than one.
 */
- (NSString*) address;

/**
 * Return all known addresses for host in "dotted decimal" notation,
 * e.g. "192.42.172.1".
 */
- (NSArray*) addresses;

@end

#if     GS_API_VERSION(GS_API_NONE,011700)

/**
 *  Adds synonym for +currentHost.
 */
@interface NSHost (GNUstep)

/**
 *  Synonym for +currentHost.
 */
+ (NSHost*) localHost;		/* All local IP addresses	*/
@end
#endif

#if	defined(__cplusplus)
}
#endif

#endif

