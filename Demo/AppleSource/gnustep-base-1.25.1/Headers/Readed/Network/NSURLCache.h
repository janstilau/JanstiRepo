#ifndef __NSURLCache_h_GNUSTEP_BASE_INCLUDE
#define __NSURLCache_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

@class NSData;
@class NSDictionary;
@class NSURLRequest;
@class NSURLRequest;
@class NSURLResponse;

/**
 * Specifies the cache storage policy.
 */
typedef enum
{
    NSURLCacheStorageAllowed,	/** Unrestricted caching */
    NSURLCacheStorageAllowedInMemoryOnly,	/** In memory caching only */
    NSURLCacheStorageNotAllowed /** No caching allowed */
} NSURLCacheStoragePolicy;

/*
 这个类的逻辑很简单, 就是一个缓存的作用.
 */

/**
 * Encapsulates a cached response to a URL load request.
 */
@interface NSCachedURLResponse : NSObject <NSCoding, NSCopying> // 这个类并没有返回 request 的信息, 也就是对应的关系, 其实是由NSURLCache 管理的.
{
    NSData            *data;
    NSURLResponse            *response;
    NSDictionary            *userInfo;
    NSURLCacheStoragePolicy    storagePolicy;
}

/**
 * Returns the data with which the receiver was initialised.
 */
- (NSData *) data; // 真正原始的数据.

/**
 * Uses the NSURLCacheStorageAllowed policy to cache the specified
 * response and data.<br />
 * Returns the cached response.
 */
- (id) initWithResponse: (NSURLResponse *)response data: (NSData *)data;

/**
 * Returns the receiver initialized with the provided parameters.
 */
- (id) initWithResponse: (NSURLResponse *)response
                   data: (NSData *)data
               userInfo: (NSDictionary *)userInfo // 这个东西, 就是 app 的一个切口, 可以在这里面存储任何和 app 相关的内容, 如果有必要的话.
          storagePolicy: (NSURLCacheStoragePolicy)storagePolicy;

/**
 * Returns the response with which the receiver was initialised.
 */
- (NSURLResponse *) response;

/**
 * Returns the storage policy with which the receiver was initialised.
 */
- (NSURLCacheStoragePolicy) storagePolicy;

/**
 * Returns the user info dictionary with which the receiver was initialised
 * (if any).
 */
- (NSDictionary *) userInfo;

@end


@interface NSURLCache : NSObject
{
    unsigned        diskCapacity;
    unsigned        memoryCapacity;
    unsigned        diskUsage;
    unsigned        memoryUsage;
    NSString        *path;
    NSMutableDictionary    *memory;
}

/**
 * Sets the shared [NSURLCache] used throughout the process.<br />
 * If you are going to call this method to specify an alternative to
 * the default cache, you should do so before the shared cache is used
 * in order to avoid loss of data that was in the old cache.
 
 这个函数可以替换 cache, 不过需要在这个类没有使用之前使用, 因为可能丢失数据.
 
 */
+ (void) setSharedURLCache: (NSURLCache *)cache;

/**
 * Returns the shared cache instance set by +setSharedURLCache: or,
 * if none has been set, returns an instance initialised with<br />
 * <deflist>
 *   <term>Memory capacity</term>
 *   <desc>4 megabytes</desc>
 *   <term>Disk capacity</term>
 *   <desc>20 megabytes</desc>
 *   <term>Disk path</term>
 *   <desc>user-library-path/Caches/current-app-name</desc>
 * </deflist>
 */
+ (NSURLCache *) sharedURLCache;

/**
 * Returns the [NSCachedURLResponse] cached for the specified request
 * or nil if there is no matching response in the cache.
 */
- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request;

/**
 * Returns the current size (butes) of the data stored in the on-disk
 * cache.
 */
- (int) currentDiskUsage;

/**
 * Returns the current size (butes) of the data stored in the in-memory
 * cache.
 */
- (int) currentMemoryUsage;

/**
 * Returns the disk capacity (in bytes) of the cache.
 */
- (int) diskCapacity;

/**
 * Returns the receiver initialised with the specified capacities
 * (in bytes) and using the specified location on disk for persistent
 * storage.
 */
- (id) initWithMemoryCapacity: (int)memoryCapacity
                 diskCapacity: (int)diskCapacity
                     diskPath: (NSString *)path;

/**
 * Returns the memory capacity (in bytes) of the cache.
 */
- (int) memoryCapacity;

/**
 * Empties the cache.
 */
- (void) removeAllCachedResponses;

/**
 * Removes from the cache (if present) the [NSCachedURLResponse]
 * which was stored using the specified request.
 */
- (void) removeCachedResponseForRequest: (NSURLRequest *)request;

/**
 * Sets the disk capacity (in bytes) truncating cache contents if necessary.
 */
- (void) setDiskCapacity: (int)diskCapacity;

/**
 * Sets the memory capacity (in bytes) truncating cache contents if necessary.
 */
- (void) setMemoryCapacity: (int)memoryCapacity;

/**
 * Stores cachedResponse in the cache, keyed on request.<br />
 * Replaces any existing response with the same key.
 */
- (void) storeCachedResponse: (NSCachedURLResponse *)cachedResponse
                  forRequest: (NSURLRequest *)request;

@end

#endif

#endif
