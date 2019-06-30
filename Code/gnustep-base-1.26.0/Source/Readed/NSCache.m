#import "common.h"

#define	EXPOSE_NSCache_IVARS	1

#import "Foundation/NSArray.h"
#import "Foundation/NSCache.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSEnumerator.h"

/**
 * _GSCachedObject is effectively used as a structure containing the various
 * things that need to be associated with objects stored in an NSCache.  It is
 * an NSObject subclass so that it can be used with OpenStep collection
 * classes.
 */
@interface _GSCachedObject : NSObject
{
@public
    id object;
    NSString *key;
    
    int accessCount;
    NSUInteger cost;
    BOOL isEvictable;
}
@end

/**
 * Just like a NSMutableDictionary. Add some property to control the cache policy. 
 */

@interface NSCache (EvictionPolicy)
/** The method controlling eviction policy in an NSCache. */
- (void) _evictObjectsToMakeSpaceForObjectWithCost: (NSUInteger)cost;
@end

@implementation NSCache
- (id) init
{
    if (nil == (self = [super init]))
    {
        return nil;
    }
    /**
     * Here, the cache Dictionary is a strong to strong. So it will not copy the key.
     */
    ASSIGN(cacheMap,[NSMapTable strongToStrongObjectsMapTable]);
    _accesses = [NSMutableArray new];
    return self;
}

- (NSUInteger) countLimit
{
    return _countLimit;
}

- (id) delegate
{
    return _delegate;
}

- (BOOL) evictsObjectsWithDiscardedContent
{
    return _evictsObjectsWithDiscardedContent;
}

- (NSString*) name
{
    return _name;
}

- (id) objectForKey: (id)key
{
    _GSCachedObject *obj = [cacheMap objectForKey: key];
    
    if (nil == obj)
    {
        return nil;
    }
    if (obj->isEvictable)
    {
        // Move the object to the end of the access list.
        [_accesses removeObjectIdenticalTo: obj];
        [_accesses addObject: obj];
    }
    obj->accessCount++;
    _totalAccesses++;
    return obj->object;
}

- (void) removeAllObjects
{
    NSEnumerator *e = [cacheMap objectEnumerator];
    _GSCachedObject *obj;
    
    while (nil != (obj = [e nextObject]))
    {
        [_delegate cache: self willEvictObject: obj->object];
    }
    [cacheMap removeAllObjects];
    [_accesses removeAllObjects];
    _totalAccesses = 0;
}

- (void) removeObjectForKey: (id)key
{
    _GSCachedObject *obj = [cacheMap objectForKey: key];
    
    if (nil != obj)
    {
        [_delegate cache: self willEvictObject: obj->object];
        _totalAccesses -= obj->accessCount;
        [cacheMap removeObjectForKey: key];
        [_accesses removeObjectIdenticalTo: obj];
    }
}

- (void) setCountLimit: (NSUInteger)lim
{
    _countLimit = lim;
}

- (void) setDelegate:(id)del
{
    _delegate = del;
}

- (void) setEvictsObjectsWithDiscardedContent:(BOOL)b
{
    _evictsObjectsWithDiscardedContent = b;
}

- (void) setName: (NSString*)cacheName
{
    ASSIGN(_name, cacheName);
}

- (void) setObject: (id)obj forKey: (id)key cost: (NSUInteger)num
{
    _GSCachedObject *oldObject = [cacheMap objectForKey: key];
    _GSCachedObject *newObject;
    
    if (nil != oldObject)
    {
        [self removeObjectForKey: oldObject->key];
    }
    [self _evictObjectsToMakeSpaceForObjectWithCost: num];
    newObject = [_GSCachedObject new];
    // Retained here, released when obj is dealloc'd
    newObject->object = RETAIN(obj);
    newObject->key = RETAIN(key);
    newObject->cost = num;
    if ([obj conformsToProtocol: @protocol(NSDiscardableContent)])
    {
        newObject->isEvictable = YES;
        [_accesses addObject: newObject];
    }
    [cacheMap setObject: newObject forKey: key];
    RELEASE(newObject);
    _totalCost += num;
}

/**
 * If we dont set cost, cost will be 0, which will not run the eviction code as the code showing here.
 */
- (void) setObject: (id)obj forKey: (id)key
{
    [self setObject: obj forKey: key cost: 0];
}

- (void) setTotalCostLimit: (NSUInteger)lim
{
    _costLimit = lim;
}

- (NSUInteger) totalCostLimit
{
    return _costLimit;
}

/**
 * This method is the one that handles the eviction policy.  This
 * implementation uses a relatively simple LRU/LFU hybrid.
 
 The NSCache documentation from Apple makes it clear that the policy may change, so we
 * could in future have a class cluster with pluggable policies for different
 * caches or some other mechanism.
 */
- (void)_evictObjectsToMakeSpaceForObjectWithCost: (NSUInteger)cost
{
    NSUInteger spaceNeeded = 0;
    NSUInteger count = [cacheMap count];
    
    // Get the spaceNeeded
    if (_costLimit > 0 && _totalCost + cost > _costLimit)
    {
        spaceNeeded = _totalCost + cost - _costLimit;
    }
    
    // Only evict if we need the space.
    if (!count) { return; }
    if (spaceNeeded == 0 || count < _countLimit) { return; }
    
    NSMutableArray *evictedKeys = nil;
    NSUInteger averageAccesses = ((_totalAccesses / (double)count) * 0.2) + 1;
    NSEnumerator *e = [_accesses objectEnumerator];
    _GSCachedObject *obj;
    
    if (_evictsObjectsWithDiscardedContent)
    {
        evictedKeys = [[NSMutableArray alloc] init];
    }
    while (nil != (obj = [e nextObject]))
    {
        // Don't evict frequently accessed objects.
        if (obj->accessCount < averageAccesses && obj->isEvictable)
        {
            [obj->object discardContentIfPossible];
            if ([obj->object isContentDiscarded])
            {
                NSUInteger cost = obj->cost;
                obj->cost = 0;
                obj->isEvictable = NO;
                // Remove this object as well as its contents if required
                if (_evictsObjectsWithDiscardedContent)
                {
                    [evictedKeys addObject: obj->key];
                }
                _totalCost -= cost;
                if (cost > spaceNeeded)
                {
                    break;
                }
                spaceNeeded -= cost;
            }
        }
    }
    // Evict all of the objects whose content we have discarded if required
    if (_evictsObjectsWithDiscardedContent)
    {
        NSString *key;
        
        e = [evictedKeys objectEnumerator];
        while (nil != (key = [e nextObject]))
        {
            [self removeObjectForKey: key];
        }
    }
    [evictedKeys release];
}

- (void) dealloc
{
    [_name release];
    [cacheMap release];
    [_accesses release];
    [super dealloc];
}
@end

@implementation _GSCachedObject
- (void) dealloc
{
    [object release];
    [key release];
    [super dealloc];
}
@end
