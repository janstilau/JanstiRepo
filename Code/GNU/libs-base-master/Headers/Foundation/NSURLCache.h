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

/*
 * Specifies the cache storage policy.
 */
typedef enum
{
    NSURLCacheStorageAllowed,	/** Unrestricted caching */
    NSURLCacheStorageAllowedInMemoryOnly,	/** In memory caching only */
    NSURLCacheStorageNotAllowed /** No caching allowed */
} NSURLCacheStoragePolicy;

/*
 这个类仅仅是简单的聚合了 response 和对应的 data 信息.
 他并没有太多其他的方法的操作.
 这个类, 是数据类. 非常纯粹.
 */
@interface NSCachedURLResponse : NSObject <NSCoding, NSCopying>
{
    NSData            *data;
    NSURLResponse            *response;
    NSDictionary            *userInfo;
    NSURLCacheStoragePolicy    storagePolicy;
}

- (NSData *) data;

- (id) initWithResponse: (NSURLResponse *)response data: (NSData *)data;

- (id) initWithResponse: (NSURLResponse *)response
                   data: (NSData *)data
               userInfo: (NSDictionary *)userInfo
          storagePolicy: (NSURLCacheStoragePolicy)storagePolicy;

- (NSURLResponse *) response;

- (NSURLCacheStoragePolicy) storagePolicy;

- (NSDictionary *) userInfo;

@end


@interface NSURLCache : NSObject
{
    unsigned        diskCapacity;
    unsigned        diskUsage;
    
    unsigned        memoryCapacity;
    unsigned        memoryUsage;
    
    NSString        *path;
    NSMutableDictionary    *memory;
}

/**
 * Sets the shared [NSURLCache] used throughout the process.<br />
 * If you are going to call this method to specify an alternative to
 * the default cache, you should do so before the shared cache is used
 * in order to avoid loss of data that was in the old cache.
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
 * or nil if there is no matching response in tthe cache.
 */
- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request;

/**
 * Returns the current size (butes) of the data stored in the on-disk
 * cache.
 */
- (NSUInteger) currentDiskUsage;

/**
 * Returns the current size (butes) of the data stored in the in-memory
 * cache.
 */
- (NSUInteger) currentMemoryUsage;

/**
 * Returns the disk capacity (in bytes) of the cache.
 */
- (NSUInteger) diskCapacity;

/**
 * Returns the receiver initialised with the specified capacities
 * (in bytes) and using the specified location on disk for persistent
 * storage.
 */
- (id) initWithMemoryCapacity: (NSUInteger)memoryCapacity
                 diskCapacity: (NSUInteger)diskCapacity
                     diskPath: (NSString *)path;

/**
 * Returns the memory capacity (in bytes) of the cache.
 */
- (NSUInteger) memoryCapacity;

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
- (void) setDiskCapacity: (NSUInteger)diskCapacity;

/**
 * Sets the memory capacity (in bytes) truncating cache contents if necessary.
 */
- (void) setMemoryCapacity: (NSUInteger)memoryCapacity;

/**
 * Stores cachedResponse in the cache, keyed on request.<br />
 * Replaces any existing response with the same key.
 */
- (void) storeCachedResponse: (NSCachedURLResponse *)cachedResponse
                  forRequest: (NSURLRequest *)request;

@end

#endif

#endif
