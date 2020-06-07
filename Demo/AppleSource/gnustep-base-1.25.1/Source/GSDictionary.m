

#import "common.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSException.h"
// For private method _decodeArrayOfObjectsForKey:
#import "Foundation/NSKeyedArchiver.h"

#import "GNUstepBase/GSObjCRuntime.h"

#import "GSPrivate.h"

/*
 *	The 'Fastmap' stuff provides an inline implementation of a mapping
 *	table - for maximum performance.
 */
#define	GSI_MAP_KTYPES		GSUNION_OBJ
#define	GSI_MAP_VTYPES		GSUNION_OBJ
#define	GSI_MAP_HASH(M, X)		[X.obj hash]
#define	GSI_MAP_EQUAL(M, X,Y)		[X.obj isEqual: Y.obj]
#define	GSI_MAP_RETAIN_KEY(M, X)	((X).obj) = \
[((id)(X).obj) copyWithZone: map->zone]

#include	"GNUstepBase/GSIMap.h"

@interface GSDictionary : NSDictionary // 是 NSDitionary 的子类.
{
@public
    GSIMapTable_t	map;// 底层用的 mapTable
}
@end

@interface GSMutableDictionary : NSMutableDictionary
{
@public
    GSIMapTable_t	map;
    NSUInteger _version; // 每一的 mutate 操作, 都会进行 version 的++操作. 目前来说, version 到底做了什么, 还不是很清楚.
}
@end

@interface GSDictionaryKeyEnumerator : NSEnumerator
{
    GSDictionary		*dictionary;
    GSIMapEnumerator_t	enumerator;
}
- (id) initWithDictionary: (NSDictionary*)d;
@end

@interface GSDictionaryObjectEnumerator : GSDictionaryKeyEnumerator
@end

@implementation GSDictionary

static SEL	nextObjectSel;
static SEL	objectForKeySel;

+ (void) initialize
{
    if (self == [GSDictionary class])
    {
        nextObjectSel = @selector(nextObject);
        objectForKeySel = @selector(objectForKey:);
    }
}

- (id) copyWithZone: (NSZone*)zone
{
    return RETAIN(self); // 不可变对象的通用写法
}

- (int) count
{
    return map.nodeCount;
}

- (int) hash
{
    return map.nodeCount;
}

- (id) init
{
    return [self initWithObjects: 0 forKeys: 0 count: 0];
}

/* Designated initialiser */
/*
 这个方法其实就是从两个数组中取值, 然后一点一点的添加到 hash 表中.
 */
- (id) initWithObjects: (const id[])objs
               forKeys: (const id <NSCopying>[])keys
                 count: (int)c
{
    NSUInteger	i;
    
    GSIMapInitWithZoneAndCapacity(&map, [self zone], c);
    for (i = 0; i < c; i++)
    {
        GSIMapNode	node;
        
        if (keys[i] == nil)
        {
            DESTROY(self);
            [NSException raise: NSInvalidArgumentException
                        format: @"Tried to init dictionary with nil key"];
        }
        if (objs[i] == nil)
        {
            DESTROY(self);
            [NSException raise: NSInvalidArgumentException
                        format: @"Tried to init dictionary with nil value"];
        }
        
        node = GSIMapNodeForKey(&map, (GSIMapKey)(id)keys[i]);
        if (node)
        {
            IF_NO_GC(RETAIN(objs[i]));
            RELEASE(node->value.obj);
            node->value.obj = objs[i];
        }
        else
        {
            GSIMapAddPair(&map, (GSIMapKey)(id)keys[i], (GSIMapVal)objs[i]);
        }
    }
    return self;
}

/*
 *	This avoids using the designated initialiser for performance reasons.
 */
- (id) initWithDictionary: (NSDictionary*)other
                copyItems: (BOOL)shouldCopy
{
    NSZone	*z = [self zone];
    NSUInteger	c = [other count];
    
    GSIMapInitWithZoneAndCapacity(&map, z, c);
    if (c > 0)
    {
        NSEnumerator	*e = [other keyEnumerator];
        IMP		nxtObj = [e methodForSelector: nextObjectSel];
        IMP		otherObj = [other methodForSelector: objectForKeySel];
        BOOL		isProxy = [other isProxy];
        NSUInteger	i;
        
        for (i = 0; i < c; i++)
        {
            GSIMapNode	node;
            id		k;
            id		o;
            
            if (isProxy == YES)
            {
                k = [e nextObject];
                o = [other objectForKey: k];
            }
            else
            {
                k = (*nxtObj)(e, nextObjectSel);
                o = (*otherObj)(other, objectForKeySel, k);
            }
            k = [k copyWithZone: z];
            if (k == nil)
            {
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init dictionary with nil key"];
            }
            if (shouldCopy)
            {
                o = [o copyWithZone: z];
            }
            else
            {
                o = RETAIN(o);
            }
            if (o == nil)
            {
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init dictionary with nil value"];
            }
            
            node = GSIMapNodeForKey(&map, (GSIMapKey)k);
            if (node)
            {
                RELEASE(node->value.obj);
                node->value.obj = o;
            }
            else
            {
                GSIMapAddPairNoRetain(&map, (GSIMapKey)k, (GSIMapVal)o);
            }
        }
    }
    return self;
}

- (BOOL) isEqualToDictionary: (NSDictionary*)other
{
    NSUInteger	count;
    
    if (other == self)
    {
        return YES;
    }
    count = map.nodeCount;
    // 首先比较 node 的数量.
    if (count == [other count])
    {
        // 然后根据迭代器, 一点点的比较.j
        if (count > 0)
        {
            GSIMapEnumerator_t	enumerator;
            GSIMapNode		node;
            IMP			otherObj = [other methodForSelector: objectForKeySel];
            
            enumerator = GSIMapEnumeratorForMap(&map);
            while ((node = GSIMapEnumeratorNextNode(&enumerator)) != 0)
            {
                id o1 = node->value.obj;
                id o2 = (*otherObj)(other, objectForKeySel, node->key.obj);
                
                if (o1 != o2 && [o1 isEqual: o2] == NO)
                {
                    GSIMapEndEnumerator(&enumerator);
                    return NO;
                }
            }
            GSIMapEndEnumerator(&enumerator);
        }
        return YES;
    }
    return NO;
}

- (NSEnumerator*) keyEnumerator
{
    return AUTORELEASE([[GSDictionaryKeyEnumerator allocWithZone:
                         NSDefaultMallocZone()] initWithDictionary: self]);
}

- (NSEnumerator*) objectEnumerator
{
    return AUTORELEASE([[GSDictionaryObjectEnumerator allocWithZone:
                         NSDefaultMallocZone()] initWithDictionary: self]);
}

- (id) objectForKey: aKey
{
    if (aKey != nil)
    {
        GSIMapNode	node  = GSIMapNodeForKey(&map, (GSIMapKey)aKey);
        
        if (node)
        {
            return node->value.obj;
        }
    }
    return nil;
}

@end

@implementation GSMutableDictionary

+ (void) initialize
{
    if (self == [GSMutableDictionary class])
    {
        GSObjCAddClassBehavior(self, [GSDictionary class]);
    }
}

/* Designated initialiser */
- (id) initWithCapacity: (int)cap
{
    GSIMapInitWithZoneAndCapacity(&map, [self zone], cap);
    return self;
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
    GSClassSwizzle(self, [GSDictionary class]);
    return self;
}

/*
 找到相应的 Node. 要么添加值, 要么修改 value 值.
 */
- (void) setObject: (id)anObject forKey: (id)aKey
{
    GSIMapNode	node;
    
    _version++;
    if (aKey == nil)
    {
        NSException	*e;
        
        e = [NSException exceptionWithName: NSInvalidArgumentException
                                    reason: @"Tried to add nil key to dictionary"
                                  userInfo: self];
        [e raise];
    }
    if (anObject == nil)
    {
        NSException	*e;
        NSString		*s;
        
        s = [NSString stringWithFormat:
             @"Tried to add nil value for key '%@' to dictionary", aKey];
        e = [NSException exceptionWithName: NSInvalidArgumentException
                                    reason: s
                                  userInfo: self];
        [e raise];
    }
    node = GSIMapNodeForKey(&map, (GSIMapKey)aKey);
    if (node)
    {
        IF_NO_GC(RETAIN(anObject));
        RELEASE(node->value.obj);
        node->value.obj = anObject;
    }
    else
    {
        GSIMapAddPair(&map, (GSIMapKey)aKey, (GSIMapVal)anObject);
    }
    _version++;
}

- (void) removeAllObjects
{
    _version++;
    GSIMapCleanMap(&map);
    _version++;
}

/*
 
 */
- (void) removeObjectForKey: (id)aKey
{
    if (aKey == nil)
    {
        NSWarnMLog(@"attempt to remove nil key from dictionary %@", self);
        return;
    }
    _version++;
    GSIMapRemoveKey(&map, (GSIMapKey)aKey);
    _version++;
}

@end

@implementation GSDictionaryKeyEnumerator

- (id) initWithDictionary: (NSDictionary*)d
{
    [super init];
    dictionary = (GSDictionary*)RETAIN(d);
    enumerator = GSIMapEnumeratorForMap(&dictionary->map); // 这里, 直接将底层的数据结构传递给了 enumerator
    return self;
}

/*
 这里, 就是 NSDictory 能够进行迭代的原因. 直接利用的 GIMap 的迭代器.
 */
- (id) nextObject
{
    GSIMapNode	node = GSIMapEnumeratorNextNode(&enumerator);
    
    if (node == 0)
    {
        return nil;
    }
    return node->key.obj;
}

- (void) dealloc
{
    GSIMapEndEnumerator(&enumerator);
    RELEASE(dictionary);
    [super dealloc];
}

@end

@implementation GSDictionaryObjectEnumerator

- (id) nextObject
{
    GSIMapNode	node = GSIMapEnumeratorNextNode(&enumerator);
    
    if (node == 0)
    {
        return nil;
    }
    return node->value.obj; // 这里可以看出, 其实 key, object 的 enumeration 是没有区别的, 都是迭代器从数据结构里面取值的一个过程.
}

@end

