#ifndef __NSCache_h_GNUSTEP_BASE_INCLUDE
#define __NSCache_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)

#import <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;
@class NSMapTable;
@class GS_GENERIC_CLASS(NSMutableArray, ElementT);

@interface GS_GENERIC_CLASS(NSCache, KeyT, ValT) : NSObject
{
  /** The maximum total cost of all cache objects. */
  NSUInteger _costLimit;
  /** Total cost of currently-stored objects. */
  NSUInteger _totalCost;
  /** The maximum number of objects in the cache. */
  NSUInteger _countLimit;
  /** The delegate object, notified when objects are about to be evicted. */
  id _delegate;
  /** Flag indicating whether discarded objects should be evicted */
  BOOL _evictsObjectsWithDiscardedContent;
  /** Name of this cache. */
  NSString *_name;
  /** The mapping from names to objects in this cache. */
  NSMapTable *_objects;
  /** LRU ordering of all potentially-evictable objects in this cache. */
  GS_GENERIC_CLASS(NSMutableArray, ValT) *_accesses;
  /** Total number of accesses to objects */
  int64_t _totalAccesses;
}
/**
 * Returns the maximum number of objects that are supported by this cache.
 */
- (NSUInteger) countLimit;

/**
 * Returns the total cost of all objects held in the cache.
 */
- (NSUInteger) totalCostLimit;

/**
 * Returns the cache's delegate.
 */
- (id) delegate;

/**
 * Returns whether objects stored in this cache which implement the
 * NSDiscardableContent protocol are removed from the cache when their contents
 * are evicted.
 */
- (BOOL) evictsObjectsWithDiscardedContent;

/**
 * Returns the name associated with this cache.
 */
- (NSString*) name;

/**
 * Returns an object associated with the specified key in this cache.
 */
- (GS_GENERIC_TYPE(ValT)) objectForKey:
    (GS_GENERIC_TYPE(KeyT))key;

/**
 * Removes all objects from this cache.
 */
- (void) removeAllObjects;

/**
 * Removes the object associated with the given key.
 */
- (void) removeObjectForKey: (GS_GENERIC_TYPE(KeyT))key;

/**
 * Sets the maximum number of objects permitted in this cache.  This limit is
 * advisory; caches may choose to disregard it temporarily or permanently.  A
 * limit of 0 is used to indicate no limit; this is the default.
 */
- (void) setCountLimit: (NSUInteger)lim;

/**
 * Sets the delegate for this cache.  The delegate will be notified when an
 * object is being evicted or removed from the cache.
 */
- (void) setDelegate: (id)del;

/**
 * Sets whether this cache will evict objects that conform to the
 * NSDiscardableContent protocol, or simply discard their contents.
 */
- (void) setEvictsObjectsWithDiscardedContent: (BOOL)b;

/**
 * Sets the name for this cache.
 */
- (void) setName: (NSString*)cacheName;

/**
 * Adds an object and its associated cost.  The cache will endeavor to keep the
 * total cost below the value set with -setTotalCostLimit: by discarding the
 * contents of objects which implement the NSDiscardableContent protocol.
 */
- (void) setObject: (GS_GENERIC_TYPE(ValT))obj
            forKey: (GS_GENERIC_TYPE(KeyT))key
              cost: (NSUInteger)num;

/**
 * Adds an object to the cache without associating a cost with it.
 */
- (void) setObject: (GS_GENERIC_TYPE(ValT))obj
            forKey: (GS_GENERIC_TYPE(KeyT))key;

/**
 * Sets the maximum total cost for objects stored in this cache.  This limit is
 * advisory; caches may choose to disregard it temporarily or permanently.  A
 * limit of 0 is used to indicate no limit; this is the default.
 */
- (void) setTotalCostLimit: (NSUInteger)lim;
@end

/**
 * Protocol implemented by NSCache delegate objects.
 */
@protocol NSCacheDelegate
/**
 * Delegate method, called just before the cache removes an object, either as
 * the result of user action or due to the cache becoming full.
 */
- (void) cache: (NSCache*)cache willEvictObject: (id)obj;
@end

#if	defined(__cplusplus)
}
#endif

#endif //OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)

#endif /* __NSCache_h_GNUSTEP_BASE_INCLUDE */
