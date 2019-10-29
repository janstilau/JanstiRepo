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
    id object; // 被存储的对象
    NSString *key; // 存储的 key 值
    int accessCount; // 访问的次数
    NSUInteger cost; // 占据的消耗
    BOOL isEvictable; // 是不是可以驱逐.
}
@end


// 这个类, 做了线程的保护处理.
/*
 
 这个类, 其实是对 NSMapTable 的一层封装, 在类的内部, 设置了一种机制, 可以记录现在的消耗大小, 以及进行清空缓存的机制.
 
 */
@interface NSCache (EvictionPolicy)
/** The method controlling eviction policy in an NSCache. */
- (void) _evictObjectsToMakeSpaceForObjectWithCost: (NSUInteger)cost;
@end


// 这个类里面, 用的是 NSMapTable 做的数据的缓存, 而且是 strong, strong 的关系.
@implementation NSCache
- (id) init
{
    if (nil == (self = [super init]))
    {
        return nil;
    }
    ASSIGN(_objects,[NSMapTable strongToStrongObjectsMapTable]);
    _accesses = [NSMutableArray new];
    _evictsObjectsWithDiscardedContent = YES;// 这个值, default YES
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
    // 虽然, 我们认为数据结构是 key - value 这种方式存的的, 但是 value 里面的值, 其实是包含了很多的数据, 我们最关心的原始的 value, 可能仅仅是物理内存里面 value 的一小部分. 在这里, 物理内存里面的 value, 有着 key, 原始 value, count 信息, 可不可以 evict 信息.
    _GSCachedObject *obj = [_objects objectForKey: key];
    
    if (nil == obj)
    {
        return nil;
    }
    if (obj->isEvictable)
    {
        // 这个东西, 其实是按照最后访问顺序, 进行管理, 随后应该在释放内存的时候用到.
        [_accesses removeObjectIdenticalTo: obj];
        [_accesses addObject: obj];
    }
    obj->accessCount++; // 更新相应的的数据.
    _totalAccesses++;
    return obj->object;
}

- (void) removeAllObjects
{
    NSEnumerator *e = [_objects objectEnumerator];
    _GSCachedObject *obj;
    
    while (nil != (obj = [e nextObject]))
    {
        // cache 里面的 delegate, 仅仅在这两个地方用到了.
        [_delegate cache: self willEvictObject: obj->object];
    }
    [_objects removeAllObjects];
    [_accesses removeAllObjects];
    _totalAccesses = 0;
}

- (void) removeObjectForKey: (id)key
{
    _GSCachedObject *obj = [_objects objectForKey: key];
    
    if (nil != obj)
    {
        [_delegate cache: self willEvictObject: obj->object];
        _totalAccesses -= obj->accessCount;
        [_objects removeObjectForKey: key];
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
    _GSCachedObject *oldObject = [_objects objectForKey: key];
    _GSCachedObject *newObject;
    
    if (nil != oldObject)
    {
        [self removeObjectForKey: oldObject->key]; // NSCache 不允许重复 key 值.
    }
    [self _evictObjectsToMakeSpaceForObjectWithCost: num]; // 先进行空间的释放工作. 这里, GS 写死了一种方案, 苹果的文档说这个可能会有变化.
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
    [_objects setObject: newObject forKey: key];
    RELEASE(newObject);
    _totalCost += num;
}

- (void) setObject: (id)obj forKey: (id)key // 普通的, 没有加入 cost 的值.
{
    [self setObject: obj forKey: key cost: 0];
}

- (void) setTotalCostLimit: (NSUInteger)lim
{
    _costLimit = lim;
}

- (NSUInteger)totalCostLimit
{
    return _costLimit;
}

/**
 * This method is the one that handles the eviction policy.  This
 * implementation uses a relatively simple LRU/LFU hybrid.  The NSCache
 * documentation from Apple makes it clear that the policy may change, so we
 * could in future have a class cluster with pluggable policies for different
 * caches or some other mechanism.
 
 NSDiscardableContent 这个协议, 就是在这个地方被统一使用的.
 
 */
- (void)_evictObjectsToMakeSpaceForObjectWithCost: (NSUInteger)cost
{
    NSUInteger spaceNeeded = 0;
    NSUInteger count = [_objects count];
    
    if (_costLimit > 0 && _totalCost + cost > _costLimit) //超了, 所以 cost 为0一定没有问题
    {
        spaceNeeded = _totalCost + cost - _costLimit;
    }
    
    // Only evict if we need the space.
    if (count > 0 && (spaceNeeded > 0 || count >= _countLimit))
    {
        NSMutableArray *evictedKeys = nil;
        // Round up slightly.
        NSUInteger averageAccesses = (_totalAccesses / count * 0.2) + 1;
        NSEnumerator *e = [_accesses objectEnumerator];
        _GSCachedObject *obj;
        
        if (_evictsObjectsWithDiscardedContent)
        {
            evictedKeys = [[NSMutableArray alloc] init];
        }
        // 按照访问的频率释放对象, 当空间够了以后就进行退出.
        while (nil != (obj = [e nextObject])) // 这里, 收集需要释放的所有的对象.
        {
            // Don't evict frequently accessed objects.
            if (obj->accessCount < averageAccesses && obj->isEvictable) // 如果访问的凭此太少了.
            {
                [obj->object discardContentIfPossible];
                if ([obj->object isContentDiscarded]) // 如果已经释放过了.
                {
                    NSUInteger cost = obj->cost;
                    
                    // Evicted objects have no cost.
                    obj->cost = 0;
                    // Don't try evicting this again in future; it's gone already.
                    obj->isEvictable = NO;
                    // Remove this object as well as its contents if required
                    if (_evictsObjectsWithDiscardedContent)
                    {
                        [evictedKeys addObject: obj->key];
                    }
                    _totalCost -= cost;
                    // If we've freed enough space, give up
                    if (cost > spaceNeeded) // 当空间够了,  就直接退出.
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
}

- (void) dealloc
{
    [_name release];
    [_objects release];
    [_accesses release];
    [super dealloc];
}
@end

@implementation _GSCachedObject
- (void)dealloc
{
    [object release];
    [key release];
    [super dealloc];
}
@end
