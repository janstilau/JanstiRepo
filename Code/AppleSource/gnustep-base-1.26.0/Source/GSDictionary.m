#import "common.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"
// For private method _decodeArrayOfObjectsForKey:
#import "Foundation/NSKeyedArchiver.h"

#import "GNUstepBase/GSObjCRuntime.h"

#import "GSPrivate.h"

#define	GSI_MAP_KTYPES		GSUNION_OBJ
#define	GSI_MAP_VTYPES		GSUNION_OBJ
#define	GSI_MAP_HASH(M, X)		[X.obj hash]
#define	GSI_MAP_EQUAL(M, X,Y)		[X.obj isEqual: Y.obj]
#define	GSI_MAP_RETAIN_KEY(M, X)	((X).obj) = \
[((id)(X).obj) copyWithZone: map->zone]

#include	"GNUstepBase/GSIMap.h"

// NSDictionary 只是对于 GSIMapTable_t 的封装, 真正的存储的结构, 还是要用 哈希表进行存储.
@interface GSDictionary : NSDictionary
{
@public
    GSIMapTable_t	map; // 最核心的数据
}
@end

@interface GSMutableDictionary : NSMutableDictionary
{
@public
    GSIMapTable_t	map; // 最核心的数据.
    NSUInteger _version;
}
@end

@interface GSDictionaryKeyEnumerator : NSEnumerator
{
    GSDictionary		*dictionary; // 存储了原始 的 Dictionary 对象.
    GSIMapEnumerator_t	enumerator;
}
- (id) initWithDictionary: (NSDictionary*)d;
@end

@interface GSDictionaryObjectEnumerator : GSDictionaryKeyEnumerator
@end

@implementation GSDictionary

static SEL	nxtSel;
static SEL	objSel;

+ (void) initialize
{
    if (self == [GSDictionary class])
    {
        nxtSel = @selector(nextObject);
        objSel = @selector(objectForKey:);
    }
}

- (id) copyWithZone: (NSZone*)zone
{
    return RETAIN(self);
}

- (NSUInteger) count
{
    return map.nodeCount;
}

- (void) dealloc
{
    GSIMapEmptyMap(&map);
    [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    if ([aCoder allowsKeyedCoding])
    {
        [super encodeWithCoder: aCoder];
    }
    else
    {
        unsigned	count = map.nodeCount;
        SEL		sel = @selector(encodeObject:);
        IMP		imp = [aCoder methodForSelector: sel];
        GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
        GSIMapNode	node = GSIMapEnumeratorNextNode(&enumerator);
        
        [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
        while (node != 0)
        {
            (*imp)(aCoder, sel, node->key.obj);
            (*imp)(aCoder, sel, node->value.obj);
            node = GSIMapEnumeratorNextNode(&enumerator);
        }
        GSIMapEndEnumerator(&enumerator);
    }
}

- (NSUInteger) hash
{
    return map.nodeCount;
}

- (id) init
{
    return [self initWithObjects: 0 forKeys: 0 count: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    if ([aCoder allowsKeyedCoding])
    {
        self = [super initWithCoder: aCoder];
    }
    else
    {
        unsigned	count;
        id		key;
        id		value;
        SEL		sel = @selector(decodeValueOfObjCType:at:);
        IMP		imp = [aCoder methodForSelector: sel];
        const char	*type = @encode(id);
        
        [aCoder decodeValueOfObjCType: @encode(unsigned)
                                   at: &count];
        
        GSIMapInitWithZoneAndCapacity(&map, [self zone], count);
        while (count-- > 0)
        {
            (*imp)(aCoder, sel, type, &key);
            (*imp)(aCoder, sel, type, &value);
            GSIMapAddPairNoRetain(&map, (GSIMapKey)key, (GSIMapVal)value);
        }
    }
    return self;
}

/* Designated initialiser */
- (id) initWithObjects: (const id[])objs
               forKeys: (const id <NSCopying>[])keys
                 count: (NSUInteger)c
{
    NSUInteger	i;
    
    GSIMapInitWithZoneAndCapacity(&map, [self zone], c);
    for (i = 0; i < c; i++)
    {
        GSIMapNode	node;
        node = GSIMapNodeForKey(&map, (GSIMapKey)(id)keys[i]); // 取得相应位置的 node .
        if (node) // 如果, 原来已经有 node 了
        {
            RELEASE(node->value.obj); // 放弃原来的 node 的 value 值
            node->value.obj = objs[i]; // 替换现在的 node 的 value 值.
        }
        else
        {
            GSIMapAddPair(&map, (GSIMapKey)(id)keys[i], (GSIMapVal)objs[i]); // 将新生成的 node 插入到 map 中.
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
        IMP		nxtObj = [e methodForSelector: nxtSel];
        IMP		otherObj = [other methodForSelector: objSel];
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
                k = (*nxtObj)(e, nxtSel);
                o = (*otherObj)(other, objSel, k);
            }
            k = [k copyWithZone: z]; // key 必然是要进行 copy 的
            if (k == nil)
            {
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init dictionary with nil key"];
            }
            if (shouldCopy)
            {
                o = [o copyWithZone: z]; // value, 要么进行 copy
            }
            else
            {
                o = RETAIN(o); // 要么进行 retain 操作.
            }
            if (o == nil)
            {
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init dictionary with nil value"];
            }
            
            node = GSIMapNodeForKey(&map, (GSIMapKey)k); // 然后生成 key, value 对应的node, 然后放入到 map 中.
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

// 思路和 NSDict 是一样的.
- (BOOL) isEqualToDictionary: (NSDictionary*)other
{
    NSUInteger	count;
    
    if (other == self)
    {
        return YES;
    }
    count = map.nodeCount;
    if (count == [other count])
    {
        if (count > 0)
        {
            GSIMapEnumerator_t	enumerator;
            GSIMapNode		node;
            IMP			otherObj = [other methodForSelector: objSel];
            
            enumerator = GSIMapEnumeratorForMap(&map);
            while ((node = GSIMapEnumeratorNextNode(&enumerator)) != 0)
            {
                id o1 = node->value.obj;
                id o2 = (*otherObj)(other, objSel, node->key.obj);
                
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

- (BOOL) makeImmutable
{
    return YES;
}

- (NSEnumerator*) objectEnumerator
{
    return AUTORELEASE([[GSDictionaryObjectEnumerator allocWithZone:
                         NSDefaultMallocZone()] initWithDictionary: self]);
}

// 最核心的方法了, 就是通过 key 找到 node, 然后通过 node 找到 value.
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

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
                                   objects: (__unsafe_unretained id[])stackbuf
                                     count: (NSUInteger)len
{
    state->mutationsPtr = (unsigned long *)self;
    return GSIMapCountByEnumeratingWithStateObjectsCount
    (&map, state, stackbuf, len);
}

- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
    NSUInteger	size = GSPrivateMemorySize(self, exclude);
    
    if (size > 0)
    {
        GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
        GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);
        
        size += GSIMapSize(&map) - sizeof(map);
        while (node != 0)
        {
            size += [node->key.obj sizeInBytesExcluding: exclude];
            size += [node->value.obj sizeInBytesExcluding: exclude];
            node = GSIMapEnumeratorNextNode(&enumerator);
        }
        GSIMapEndEnumerator(&enumerator);
    }
    return size;
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

- (id) copyWithZone: (NSZone*)zone
{
    NSDictionary	*copy = [GSDictionary allocWithZone: zone];
    
    return [copy initWithDictionary: self copyItems: NO];
}

- (id) init
{
    return [self initWithCapacity: 0];
}

/* Designated initialiser */
- (id) initWithCapacity: (NSUInteger)cap
{
    GSIMapInitWithZoneAndCapacity(&map, [self zone], cap); // map 设置 capacity
    return self;
}

- (BOOL) makeImmutable // 直接把自己的 isa 进行替换.
{
    GSClassSwizzle(self, [GSDictionary class]);
    return YES;
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
    GSClassSwizzle(self, [GSDictionary class]);
    return self;
}

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
    if (node) // set 方法就是操作 map, 添加 node, 或者设置 node 的 value 的过程.
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

- (void) removeObjectForKey: (id)aKey // 每一次对于 map 的修改, 都有着对于 version 的改变.
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

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
                                   objects: (__unsafe_unretained id[])stackbuf
                                     count: (NSUInteger)len
{
    state->mutationsPtr = (unsigned long *)&_version;
    return GSIMapCountByEnumeratingWithStateObjectsCount
    (&map, state, stackbuf, len);
}
@end

@implementation GSDictionaryKeyEnumerator

- (id) initWithDictionary: (NSDictionary*)d
{
    [super init];
    dictionary = (GSDictionary*)RETAIN(d);
    enumerator = GSIMapEnumeratorForMap(&dictionary->map);
    return self;
}

- (id) nextObject
{
    
    // 在这个方法里面, 取得下一个 node
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


// enumerator 中, 是存储了当前的位置的, 所以可以根据自己当前的位置, 寻找下一个 node 的位置.
- (id) nextObject
{
    GSIMapNode	node = GSIMapEnumeratorNextNode(&enumerator);
    
    if (node == 0)
    {
        return nil;
    }
    return node->value.obj;
}

@end



@interface	NSGDictionary : NSDictionary
@end
@implementation	NSGDictionary
- (id) initWithCoder: (NSCoder*)aCoder
{
    NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
    DESTROY(self);
    self = (id)NSAllocateObject([GSDictionary class], 0, NSDefaultMallocZone());
    self = [self initWithCoder: aCoder];
    return self;
}
@end

@interface	NSGMutableDictionary : NSMutableDictionary
@end
@implementation	NSGMutableDictionary
- (id) initWithCoder: (NSCoder*)aCoder
{
    NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
    DESTROY(self);
    self = (id)NSAllocateObject([GSMutableDictionary class], 0, NSDefaultMallocZone());
    self = [self initWithCoder: aCoder];
    return self;
}
@end

@interface	GSCachedDictionary : GSDictionary
{
    BOOL  _uncached;
}
@end
@implementation	GSCachedDictionary
- (void) dealloc
{
    if (NO == _uncached)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Deallocating attributes which are still cached"];
    }
    [super dealloc];
}
- (void) _uncache
{
    _uncached = YES;
    RELEASE(self);
}
@end
