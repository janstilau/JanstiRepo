#import "common.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSData.h"
#import "Foundation/NSException.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "GSFastEnumeration.h"
#import "GSDispatch.h"

static BOOL GSMacOSXCompatiblePropertyLists(void)
{
    if (GSPrivateDefaultsFlag(NSWriteOldStylePropertyLists) == YES)
        return NO;
    return GSPrivateDefaultsFlag(GSMacOSXCompatible);
}

@class	GSDictionary;
@interface GSDictionary : NSObject	// Help the compiler
@end
@class	GSMutableDictionary;
@interface GSMutableDictionary : NSObject	// Help the compiler
@end

extern void	GSPropertyListMake(id,NSDictionary*,BOOL,BOOL,unsigned,id*);


static Class NSArray_class;
static Class NSDictionaryClass;
static Class NSMutableDictionaryClass;
static Class GSDictionaryClass;
static Class GSMutableDictionaryClass;

static SEL	isEqualSEL;
static SEL	nextObjectSEL;
static SEL	objectForKeySEL;
static SEL	removeObjectForKeySEL;
static SEL	setObjecctForKeySEL;
static SEL	appendStringSEL;

/**
 *  <p>
 *  This class and its subclasses store key-value pairs, where the key and
 *  the value are objects.
 *  A great many utility methods for working with
 *  dictionaries are provided as part of this class, including the ability to
 *  retrieve multiple entries simultaneously, obtain sorted contents, and
 *  read/write from/to a serialized representation.</p>
 *
 *  <p>The keys are copied and values are retained by the implementation,
 *  and both are released when either their entry is dropped or the entire
 *  dictionary is deallocated.<br />
 *  As in the OS X implementation, keys must therefore implement the
 *  [(NSCopying)] protocol.
 *  </p>
 *
 *  <p>Objects of this class are immutable.  For a mutable version, use the
 *  [NSMutableDictionary] subclass.</p>
 *
 *  <p>The basic functionality in <code>NSDictionary</code> is similar to that
 *  in Java's <code>HashMap</code>, and like that class it includes no locking
 *  code and is not thread-safe.  If the contents will be modified and
 *  accessed from multiple threads you should enclose critical operations
 *  within locks (see [NSLock]).</p>
 */
@implementation NSDictionary

+ (void) initialize
{
    if (self == [NSDictionary class])
    {
        isEqualSEL = @selector(isEqual:);
        nextObjectSEL = @selector(nextObject);
        objectForKeySEL = @selector(objectForKey:);
        removeObjectForKeySEL = @selector(removeObjectForKey:);
        setObjecctForKeySEL = @selector(setObject:forKey:);
        appendStringSEL = @selector(appendString:);
        NSArray_class = [NSArray class];
        NSDictionaryClass = self;
        GSDictionaryClass = [GSDictionary class];
        [NSMutableDictionary class];
    }
}

/**
 这里, 生成的是一个 NSDictionary 对象, 这也是 NSMutableDict 的实现方式, 这也就是为什么, 可变对象的 copy 会生成不可变对象
 */
- (id) copyWithZone: (NSZone*)z
{
    NSDictionary	*copy = [NSDictionaryClass allocWithZone: z];
    
    return [copy initWithDictionary: self copyItems: NO];
}

- (void) enumerateKeysAndObjectsUsingBlock:
(GSKeysAndObjectsEnumeratorBlock)aBlock
{
    [self enumerateKeysAndObjectsWithOptions: 0
                                  usingBlock: aBlock];
}

- (void) enumerateKeysAndObjectsWithOptions: (NSEnumerationOptions)opts
                                 usingBlock: (GSKeysAndObjectsEnumeratorBlock)aBlock
{
    /*
     * NOTE: According to the Cocoa documentation, NSEnumerationReverse is
     * undefined for NSDictionary. NSEnumerationConcurrent will be handled through
     * the GS_DISPATCH_* macros if libdispatch is available.
     */
    id<NSFastEnumeration> enumerator = [self keyEnumerator];
    SEL objectForKeySelector = @selector(objectForKey:);
    IMP objectForKey = [self methodForSelector: objectForKeySelector];
    __block BOOL shouldStop = NO;
    id obj;
    
    GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    FOR_IN(id, key, enumerator)
    obj = (*objectForKey)(self, objectForKeySelector, key);
    GS_DISPATCH_SUBMIT_BLOCK(enumQueueGroup, enumQueue, if (shouldStop){return;};, return;, aBlock, key, obj, &shouldStop);
    if (YES == shouldStop)
    {
        break;
    }
    END_FOR_IN(enumerator)
    GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
}

- (id) init
{
    self = [super init];
    return self;
}


- (id) objectForKeyedSubscript: (id)aKey
{
    return [self objectForKey: aKey];
}


/**
 直接就是生成了 NSMutableDictionary 对象.
 */
- (id) mutableCopyWithZone: (NSZone*)z
{
    NSMutableDictionary	*copy = [NSMutableDictionaryClass allocWithZone: z];
    
    return [copy initWithDictionary: self copyItems: NO];
}

- (Class) classForCoder
{
    return NSDictionaryClass;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    unsigned	count = [self count];
    
    if ([aCoder allowsKeyedCoding])
    {
        id	key;
        unsigned	i;
        
        if ([aCoder class] == [NSKeyedArchiver class])
        {
            NSArray	*keys = [self allKeys];
            id		objects = [NSMutableArray arrayWithCapacity: count];
            
            for (i = 0; i < count; i++)
            {
                key = [keys objectAtIndex: i];
                [objects addObject: [self objectForKey: key]];
            }
            [(NSKeyedArchiver*)aCoder _encodeArrayOfObjects: keys
                                                     forKey: @"NS.keys"];
            [(NSKeyedArchiver*)aCoder _encodeArrayOfObjects: objects
                                                     forKey: @"NS.objects"];
        }
        else if (count > 0)
        {
            NSEnumerator	*enumerator = [self keyEnumerator];
            
            i = 0;
            while ((key = [enumerator nextObject]) != nil)
            {
                NSString	*s;
                
                s = [NSString stringWithFormat: @"NS.key.%u", i];
                [aCoder encodeObject: key forKey: s];
                s = [NSString stringWithFormat: @"NS.object.%u", i];
                [aCoder encodeObject: [self objectForKey: key] forKey: s];
                i++;
            }
        }
    }
    else
    {
        [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
        if (count > 0)
        {
            NSEnumerator	*enumerator = [self keyEnumerator];
            id		key;
            IMP		enc;
            IMP		nxt;
            IMP		ofk;
            
            nxt = [enumerator methodForSelector: @selector(nextObject)];
            enc = [aCoder methodForSelector: @selector(encodeObject:)];
            ofk = [self methodForSelector: @selector(objectForKey:)];
            
            while ((key = (*nxt)(enumerator, @selector(nextObject))) != nil)
            {
                id	val = (*ofk)(self, @selector(objectForKey:), key);
                
                (*enc)(aCoder, @selector(encodeObject:), key);
                (*enc)(aCoder, @selector(encodeObject:), val);
            }
        }
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    if ([aCoder allowsKeyedCoding])
    {
        id keys = nil;
        id objects = nil;
        
        if ([aCoder containsValueForKey: @"NS.keys"])
        {
            keys = [(NSKeyedUnarchiver*)aCoder _decodeArrayOfObjectsForKey:
                    @"NS.keys"];
            objects = [(NSKeyedUnarchiver*)aCoder _decodeArrayOfObjectsForKey:
                       @"NS.objects"];
        }
        else if ([aCoder containsValueForKey: @"dict.sortedKeys"])
        {
            keys = [aCoder decodeObjectForKey: @"dict.sortedKeys"];
            objects = [aCoder decodeObjectForKey: @"dict.values"];
        }
        
        if (keys == nil)
        {
            unsigned	i = 0;
            NSString	*key;
            id		val;
            
            keys = [NSMutableArray arrayWithCapacity: 2];
            objects = [NSMutableArray arrayWithCapacity: 2];
            key = [NSString stringWithFormat: @"NS.object.%u", i];
            val = [(NSKeyedUnarchiver*)aCoder decodeObjectForKey: key];
            
            while (val != nil)
            {
                [objects addObject: val];
                key = [NSString stringWithFormat: @"NS.key.%u", i];
                val = [(NSKeyedUnarchiver*)aCoder decodeObjectForKey: key];
                [keys addObject: val];
                i++;
                key = [NSString stringWithFormat: @"NS.object.%u", i];
                val = [(NSKeyedUnarchiver*)aCoder decodeObjectForKey: key];
            }
        }
        self = [self initWithObjects: objects forKeys: keys];
    }
    else
    {
        unsigned	count;
        
        [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
        if (count > 0)
        {
            id	*keys = NSZoneMalloc(NSDefaultMallocZone(), sizeof(id)*count);
            id	*vals = NSZoneMalloc(NSDefaultMallocZone(), sizeof(id)*count);
            unsigned	i;
            IMP	dec;
            
            dec = [aCoder methodForSelector: @selector(decodeObject)];
            for (i = 0; i < count; i++)
            {
                keys[i] = (*dec)(aCoder, @selector(decodeObject));
                vals[i] = (*dec)(aCoder, @selector(decodeObject));
            }
            self = [self initWithObjects: vals forKeys: keys count: count];
            NSZoneFree(NSDefaultMallocZone(), keys);
            NSZoneFree(NSDefaultMallocZone(), vals);
        }
    }
    return self;
}

/**
 *  Returns a new autoreleased empty dictionary.
 */
+ (id) dictionary
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] init]);
}

/**
 * Returns a newly created dictionary with the keys and objects
 * of otherDictionary.
 * (The keys and objects are not copied.)
 */
+ (id) dictionaryWithDictionary: (NSDictionary*)otherDictionary
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithDictionary: otherDictionary]);
}

/**
 * Returns a dictionary created using the given objects and keys.
 * The two arrays must have the same size.
 * The n th element of the objects array is associated with the n th
 * element of the keys array.
 */
+ (id) dictionaryWithObjects: (const id[])objects
                     forKeys: (const id <NSCopying>[])keys
                       count: (NSUInteger)count
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithObjects: objects forKeys: keys count: count]);
}


// dict 的 hash 是用 count 表示的.
- (NSUInteger) hash
{
    return [self count];
}

/**
 * Initialises a dictionary created using the given objects and keys.
 * The two arrays must have the same size.
 * The n th element of the objects array is associated with the n th
 * element of the keys array.
 */
- (id) initWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
    unsigned	objectCount = [objects count];
    
    if (objectCount != [keys count])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"init with obj and key arrays of different sizes"];
    }
    else
    {
        // 将 key valus 取出来, 然后调用 initWithObjects:forKeys:count;
        GS_BEGINIDBUF(o, objectCount*2);
        [objects getObjects: o];
        [keys getObjects: o + objectCount];
        self = [self initWithObjects: o
                             forKeys: o + objectCount
                               count: objectCount];
        GS_ENDIDBUF();
    }
    return self;
}

/**
 * Initialises a dictionary created using the list given as argument.
 * The list is alternately composed of objects and keys and
 * terminated by nil.  Thus, the list's length must be even,
 * followed by nil.
 */
- (id) initWithObjectsAndKeys: (id)firstObject, ...
{
    GS_USEIDPAIRLIST(firstObject,
                     self = [self initWithObjects: __objects forKeys: __pairs count: __count/2]);
    return self;
}

/**
 * Returns a dictionary created using the list given as argument.
 * The list is alternately composed of objects and keys and
 * terminated by nil.  Thus, the list's length must be even,
 * followed by nil.
 */
+ (id) dictionaryWithObjectsAndKeys: (id)firstObject, ...
{
    id	o = [self allocWithZone: NSDefaultMallocZone()];
    
    GS_USEIDPAIRLIST(firstObject,
                     o = [o initWithObjects: __objects forKeys: __pairs count: __count/2]);
    return AUTORELEASE(o);
}

/**
 * Returns a dictionary created using the given objects and keys.
 * The two arrays must have the same length.
 * The n th element of the objects array is associated with the n th
 * element of the keys array.
 */
+ (id) dictionaryWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithObjects: objects forKeys: keys]);
}

/**
 * Returns a dictionary containing only one object which is associated
 * with a key.
 */
+ (id) dictionaryWithObject: (id)object forKey: (id)key
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithObjects: &object forKeys: &key count: 1]);
}

/**
 * Initializes with the keys and objects of otherDictionary.
 * (The keys and objects are not copied.)
 */
- (id) initWithDictionary: (NSDictionary*)otherDictionary
{
    return [self initWithDictionary: otherDictionary copyItems: NO];
}

/**
 * Initialise dictionary with the keys and values of otherDictionary.
 * If the shouldCopy flag is YES then the values are copied into the
 * newly initialised dictionary, otherwise they are simply retained,
 * on the assumption that it is safe to retain the keys from another
 * dictionary since that other dictionary mwill have copied the keys
 * originally to ensure that they are immutable.
 */
- (id) initWithDictionary: (NSDictionary*)other
                copyItems: (BOOL)shouldCopy
{
    unsigned	c = [other count];
    
    if (c > 0)
    {
        id		k;
        NSEnumerator	*e = [other keyEnumerator];
        unsigned		i = 0;
        IMP		nxtObj = [e methodForSelector: nextObjectSEL];
        IMP		otherObj = [other methodForSelector: objectForKeySEL];
        GS_BEGINIDBUF(o, c*2);
        
        if (shouldCopy)
        {
            NSZone	*z = [self zone];
            
            while ((k = (*nxtObj)(e, nextObjectSEL)) != nil)
            {
                o[i] = k;
                o[c + i] = [(*otherObj)(other, objectForKeySEL, k) copyWithZone: z]; // 这里, 进行了一次 copy 操作.
                i++;
            }
            self = [self initWithObjects: o + c forKeys: o count: i];
            while (i-- > 0)
            {
                [o[c + i] release];
            }
        }
        else
        {
            while ((k = (*nxtObj)(e, nextObjectSEL)) != nil)
            {
                o[i] = k;
                o[c + i] = (*otherObj)(other, objectForKeySEL, k);
                i++;
            }
            self = [self initWithObjects: o + c forKeys: o count: c];
        }
        GS_ENDIDBUF();
    }
    return self;
}

/**
 * <p>Initialises the dictionary with the contents of the specified file,
 * which must contain a dictionary in property-list format.
 * </p>
 * <p>In GNUstep, the property-list format may be either the OpenStep
 * format (ASCII data), or the MacOS-X format (UTF-8 XML data) ... this
 * method will recognise which it is.
 * </p>
 * <p>If there is a failure to load the file for any reason, the receiver
 * will be released and the method will return nil.
 * </p>
 * <p>Works by invoking [NSString-initWithContentsOfFile:] and
 * [NSString-propertyList] then checking that the result is a dictionary.
 * </p>
 *  在 apple 的系统里面, 是将 propertyList 和 NSDict 联系在一起的.
 */
- (id) initWithContentsOfFile: (NSString*)path
{
    NSString 	*myString;
    
    myString = [[NSString allocWithZone: NSDefaultMallocZone()]
                initWithContentsOfFile: path];
    if (myString == nil)
    {
        DESTROY(self);
    }
    else
    {
        id result;
        
        NS_DURING
        {
            result = [myString propertyList];
        }
        NS_HANDLER
        {
            result = nil;
        }
        NS_ENDHANDLER
        RELEASE(myString);
        if ([result isKindOfClass: NSDictionaryClass])
        {
            self = [self initWithDictionary: result];
        }
        else
        {
            NSWarnMLog(@"Contents of file '%@' does not contain a dictionary",
                       path);
            DESTROY(self);
        }
    }
    return self;
}

/**
 * <p>Initialises the dictionary with the contents of the specified URL,
 * which must contain a dictionary in property-list format.
 * </p>
 * <p>In GNUstep, the property-list format may be either the OpenStep
 * format (ASCII data), or the MacOS-X format (UTF-8 XML data) ... this
 * method will recognise which it is.
 * </p>
 * <p>If there is a failure to load the URL for any reason, the receiver
 * will be released and the method will return nil.
 * </p>
 * <p>Works by invoking [NSString-initWithContentsOfURL:] and
 * [NSString-propertyList] then checking that the result is a dictionary.
 * 基本上, 和 contentOfFile 是一样的.
 * </p>
 */
- (id) initWithContentsOfURL: (NSURL*)aURL
{
    NSString 	*myString;
    
    myString = [[NSString allocWithZone: NSDefaultMallocZone()]
                initWithContentsOfURL: aURL];
    if (myString == nil)
    {
        DESTROY(self);
    }
    else
    {
        id result;
        
        NS_DURING
        {
            result = [myString propertyList];
        }
        NS_HANDLER
        {
            result = nil;
        }
        NS_ENDHANDLER
        RELEASE(myString);
        if ([result isKindOfClass: NSDictionaryClass])
        {
            self = [self initWithDictionary: result];
        }
        else
        {
            NSWarnMLog(@"Contents of URL '%@' does not contain a dictionary",
                       aURL);
            DESTROY(self);
        }
    }
    return self;
}

/**
 * Returns a dictionary using the file located at path.
 * The file must be a property list containing a dictionary as its root object.
 */
+ (id) dictionaryWithContentsOfFile: (NSString*)path
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithContentsOfFile: path]);
}

/**
 * Returns a dictionary using the contents of aURL.
 * The URL must be a property list containing a dictionary as its root object.
 */
+ (id) dictionaryWithContentsOfURL: (NSURL*)aURL
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithContentsOfURL: aURL]);
}

- (BOOL) isEqual: other
{
    if (other == self)
        return YES;
    
    if ([other isKindOfClass: NSDictionaryClass])
        return [self isEqualToDictionary: other];
    
    return NO;
}

/**
 * Two dictionaries are equal if they each hold the same number of
 * entries, each key in one <code>isEqual</code> to a key in the other,
 * and, for a given key, the corresponding value objects also satisfy
 * <code>isEqual</code>.
 */
// 如果是 isEqualTo 就是先判断自己, 然后判断类型.
- (BOOL) isEqualToDictionary: (NSDictionary*)other
{
    unsigned	count;
    
    if (other == self) // 先判断自己
    {
        return YES;
    }
    count = [self count];
    if (count == [other count]) // 然后判断基本数据
    {
        if (count > 0) // 然后是逐个的比较操作.
        {
            NSEnumerator	*e = [self keyEnumerator];
            IMP		nxtObj = [e methodForSelector: nextObjectSEL];
            IMP		myObj = [self methodForSelector: objectForKeySEL];
            IMP		otherObj = [other methodForSelector: objectForKeySEL];
            id		k;
            
            while ((k = (*nxtObj)(e, @selector(nextObject))) != nil)
            {
                id o1 = (*myObj)(self, objectForKeySEL, k);
                id o2 = (*otherObj)(other, objectForKeySEL, k);
                
                if (o1 == o2)
                    continue;
                if ([o1 isEqual: o2] == NO)
                    return NO;
            }
        }
        return YES;
    }
    return NO;
}

/**
 * Returns an array containing all the dictionary's keys.\
 *  一个遍历操作, 用 key 值组装一个数组.
 *  这里, 遍历用的是 keyEnumerator, 对应的, 还有 valueEnumerator. 从底层原理来看, 他们的顺序应该就是一样的.
 */
- (NSArray*) allKeys
{
    unsigned	c = [self count];
    
    if (c == 0)
    {
        return [NSArray_class array];
    }
    else
    {
        NSEnumerator	*e = [self keyEnumerator];
        IMP		nxtObj = [e methodForSelector: nextObjectSEL];
        unsigned		i;
        id		result;
        GS_BEGINIDBUF(k, c);
        
        for (i = 0; i < c; i++)
        {
            k[i] = (*nxtObj)(e, nextObjectSEL);
            NSAssert (k[i], NSInternalInconsistencyException);
        }
        result = [[NSArray_class allocWithZone: NSDefaultMallocZone()]
                  initWithObjects: k count: c];
        GS_ENDIDBUF();
        return AUTORELEASE(result);
    }
}

/**
 * Returns an array containing all the dictionary's objects.
 */
- (NSArray*) allValues
{
    unsigned	c = [self count];
    
    if (c == 0)
    {
        return [NSArray_class array];
    }
    else
    {
        NSEnumerator	*e = [self objectEnumerator];
        IMP		nxtObj = [e methodForSelector: nextObjectSEL];
        id		result;
        unsigned		i;
        GS_BEGINIDBUF(k, c);
        
        for (i = 0; i < c; i++)
        {
            k[i] = (*nxtObj)(e, nextObjectSEL);
        }
        result = [[NSArray_class allocWithZone: NSDefaultMallocZone()]
                  initWithObjects: k count: c];
        GS_ENDIDBUF();
        return AUTORELEASE(result);
    }
}

- (void)getObjects: (__unsafe_unretained id[])objects
           andKeys: (__unsafe_unretained id<NSCopying>[])keys
{
    NSUInteger i=0;
    FOR_IN(id, key, self)
    if (keys != NULL) keys[i] = key;
    if (objects != NULL) objects[i] = [self objectForKey: key];
    i++;
    END_FOR_IN(self)
}

/**
 * Returns an array containing all the dictionary's keys that are
 * associated with anObject.
 *
 * 返回所有的 value 是 anObject 的 key 组成的数组.
 */
- (NSArray*) allKeysForObject: (id)anObject
{
    unsigned	c;
    
    if (anObject == nil || (c = [self count]) == 0)
    {
        return nil;
    }
    else
    {
        NSEnumerator	*e = [self keyEnumerator];
        IMP		nxtObj = [e methodForSelector: nextObjectSEL];
        IMP		myObj = [self methodForSelector: objectForKeySEL];
        BOOL		(*eqObj)(id, SEL, id);
        id		k;
        id		result;
        GS_BEGINIDBUF(a, [self count]);
        
        eqObj = (BOOL (*)(id, SEL, id))[anObject methodForSelector: isEqualSEL];
        c = 0;
        while ((k = (*nxtObj)(e, nextObjectSEL)) != nil)
        {
            id	o = (*myObj)(self, objectForKeySEL, k);
            
            if (o == anObject || (*eqObj)(anObject, isEqualSEL, o))
            {
                a[c++] = k;
            }
        }
        if (c == 0)
        {
            result = nil;
        }
        else
        {
            result = [[NSArray_class allocWithZone: NSDefaultMallocZone()]
                      initWithObjects: a count: c];
        }
        GS_ENDIDBUF();
        return AUTORELEASE(result);
    }
}

struct foo { NSDictionary *d; SEL s; IMP i; };

static NSInteger
compareIt(id o1, id o2, void* context)
{
    struct foo	*f = (struct foo*)context;
    o1 = (*f->i)(f->d, @selector(objectForKey:), o1);
    o2 = (*f->i)(f->d, @selector(objectForKey:), o2);
    return (NSInteger)(intptr_t)[o1 performSelector: f->s withObject: o2];
}

/**
 *  Returns ordered array of the keys sorted according to the values they
 *  correspond to.  To sort the values, a message with selector comp is
 *  send to each value with another value as argument, as in
 *  <code>[a comp: b]</code>.  The comp method should return
 *  <code>NSOrderedSame</code>, <code>NSOrderedAscending</code>, or
 *  <code>NSOrderedDescending</code> as appropriate.
 */
- (NSArray*) keysSortedByValueUsingSelector: (SEL)comp
{
    struct foo	info;
    id	k;
    
    info.d = self;
    info.s = comp;
    info.i = [self methodForSelector: objectForKeySEL];
    k = [[self allKeys] sortedArrayUsingFunction: compareIt context: &info];
    return k;
}

/**
 *  Multiple version of [-objectForKey:].  Objects for each key in keys are
 *  looked up and placed into return array in same order.  For each key that
 *  has no corresponding value in this dictionary, marker is put into the
 *  array in its place.
 */
- (NSArray*) objectsForKeys: (NSArray*)keys notFoundMarker: (id)marker
{
    unsigned	c = [keys count];
    
    if (c == 0)
    {
        return [NSArray_class array];
    }
    else
    {
        unsigned	i;
        IMP	myObj = [self methodForSelector: objectForKeySEL];
        id	result;
        GS_BEGINIDBUF(obuf, c);
        
        if ([keys isProxy])
        {
            for (i = 0; i < c; i++)
            {
                obuf[i] = [keys objectAtIndex: i];
            }
        }
        else
        {
            [keys getObjects: obuf];
        }
        for (i = 0; i < c; i++)
        {
            id o = (*myObj)(self, objectForKeySEL, obuf[i]);
            
            if (o == nil)
            {
                obuf[i] = marker;
            }
            else
            {
                obuf[i] = o;
            }
        }
        result = [[NSArray_class allocWithZone: NSDefaultMallocZone()]
                  initWithObjects: obuf count: c];
        GS_ENDIDBUF();
        return AUTORELEASE(result);
    }
}

- (NSSet*) keysOfEntriesWithOptions: (NSEnumerationOptions)opts
                        passingTest: (GSKeysAndObjectsPredicateBlock)aPredicate
{
    /*
     * See -enumerateKeysAndObjectsWithOptions:usingBlock: for note about
     * NSEnumerationOptions.
     */
    id<NSFastEnumeration> enumerator = [self keyEnumerator];
    SEL objectForKeySelector = @selector(objectForKey:);
    IMP objectForKey = [self methodForSelector: objectForKeySelector];
    BLOCK_SCOPE BOOL shouldStop = NO;
    NSMutableSet *buildSet = [NSMutableSet new];
    SEL addObjectSelector = @selector(addObject:);
    IMP addObject = [buildSet methodForSelector: addObjectSelector];
    NSSet *resultSet = nil;
    id obj = nil;
    BLOCK_SCOPE NSLock *setLock = nil;
    
    if (opts & NSEnumerationConcurrent)
    {
        setLock = [NSLock new];
    }
    GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    FOR_IN(id, key, enumerator)
    obj = (*objectForKey)(self, objectForKeySelector, key);
#if (__has_feature(blocks) && (GS_USE_LIBDISPATCH == 1))
    dispatch_group_async(enumQueueGroup, enumQueue, ^(void){
        if (shouldStop)
        {
            return;
        }
        if (aPredicate(key, obj, &shouldStop))
        {
            [setLock lock];
            addObject(buildSet, addObjectSelector, key);
            [setLock unlock];
        }
    });
#else
    if (CALL_BLOCK(aPredicate, key, obj, &shouldStop))
    {
        addObject(buildSet, addObjectSelector, key);
    }
#endif
    
    if (YES == shouldStop)
    {
        break;
    }
    END_FOR_IN(enumerator)
    GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    [setLock release];
    resultSet = [NSSet setWithSet: buildSet];
    [buildSet release];
    return resultSet;
}

- (NSSet*) keysOfEntriesPassingTest: (GSKeysAndObjectsPredicateBlock)aPredicate
{
    return [self keysOfEntriesWithOptions: 0
                              passingTest: aPredicate];
}

/**
 * <p>Writes the contents of the dictionary to the file specified by path.
 * The file contents will be in property-list format ... under GNUstep
 * this is either OpenStep style (ASCII characters using \U hexadecimal
 * escape sequences for unicode), or MacOS-X style (XML in the UTF8
 * character set).
 * </p>
 * <p>If the useAuxiliaryFile flag is YES, the file write operation is
 * atomic ... the data is written to a temporary file, which is then
 * renamed to the actual file name.
 * </p>
 * <p>If the conversion of data into the correct property-list format fails
 * or the write operation fails, the method returns NO, otherwise it
 * returns YES.
 * </p>
 * <p>NB. The fact that the file is in property-list format does not
 * necessarily mean that it can be used to reconstruct the dictionary using
 * the -initWithContentsOfFile: method.  If the original dictionary contains
 * non-property-list objects, the descriptions of those objects will
 * have been written, and reading in the file as a property-list will
 * result in a new dictionary containing the string descriptions.
 * </p>
 */
- (BOOL) writeToFile: (NSString *)path atomically: (BOOL)useAuxiliaryFile
{
    NSDictionary	*loc;
    NSString	*desc = nil;
    NSData	*data;
    
    loc = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    if (GSMacOSXCompatiblePropertyLists() == YES)
    {
        GSPropertyListMake(self, loc, YES, NO, 2, &desc);
        data = [desc dataUsingEncoding: NSUTF8StringEncoding];
    }
    else
    {
        GSPropertyListMake(self, loc, NO, NO, 2, &desc);
        data = [desc dataUsingEncoding: NSASCIIStringEncoding];
    }
    return [data writeToFile: path atomically: useAuxiliaryFile];
}

/**
 * <p>Writes the contents of the dictionary to the specified url.
 * This functions just like -writeToFile:atomically: except that the
 * output may be written to any URL, not just a local file.
 * </p>
 */
- (BOOL) writeToURL: (NSURL *)url atomically: (BOOL)useAuxiliaryFile
{
    NSDictionary	*loc;
    NSString	*desc = nil;
    NSData	*data;
    
    loc = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    if (GSMacOSXCompatiblePropertyLists() == YES)
    {
        GSPropertyListMake(self, loc, YES, NO, 2, &desc);
        data = [desc dataUsingEncoding: NSUTF8StringEncoding];
    }
    else
    {
        GSPropertyListMake(self, loc, NO, NO, 2, &desc);
        data = [desc dataUsingEncoding: NSASCIIStringEncoding];
    }
    
    return [data writeToURL: url atomically: useAuxiliaryFile];
}

/**
 * Returns the result of invoking -descriptionWithLocale:indent: with a nil
 * locale and zero indent.
 */
- (NSString*) description
{
    return [self descriptionWithLocale: nil indent: 0];
}

/**
 * Returns the receiver as a text property list strings file format.<br />
 * See [NSString-propertyListFromStringsFileFormat] for details.<br />
 * The order of the items is undefined.
 */
- (NSString*) descriptionInStringsFileFormat
{
    NSMutableString	*result = nil;
    NSEnumerator		*enumerator = [self keyEnumerator];
    IMP			nxtObj = [enumerator methodForSelector: nextObjectSEL];
    IMP			myObj = [self methodForSelector: objectForKeySEL];
    id                    key;
    
    while ((key = (*nxtObj)(enumerator, nextObjectSEL)) != nil)
    {
        id val = (*myObj)(self, objectForKeySEL, key);
        
        GSPropertyListMake(key, nil, NO, YES, 0, &result);
        if (val != nil && [val isEqualToString: @""] == NO)
        {
            [result appendString: @" = "];
            GSPropertyListMake(val, nil, NO, YES, 0, &result);
        }
        [result appendString: @";\n"];
    }
    
    return result;
}

/**
 * Returns the result of invoking -descriptionWithLocale:indent: with
 * a zero indent.
 */
- (NSString*) descriptionWithLocale: (id)locale
{
    return [self descriptionWithLocale: locale indent: 0];
}

/**
 * Returns the receiver as a text property list in the traditional format.<br />
 * See [NSString-propertyList] for details.<br />
 * If locale is nil, no formatting is done, otherwise entries are formatted
 * according to the locale, and indented according to level.<br />
 * Unless locale is nil, a level of zero indents items by four spaces,
 * while a level of one indents them by a tab.<br />
 * If the keys in the dictionary respond to [NSObject-compare:], the items are
 * listed by key in ascending order.  If not, the order in which the
 * items are listed is undefined.
 */
- (NSString*) descriptionWithLocale: (id)locale
                             indent: (NSUInteger)level
{
    NSMutableString	*result = nil;
    
    GSPropertyListMake(self, locale, NO, YES, level == 1 ? 3 : 2, &result);
    return result;
}

/**
 * Default implementation for this class is to return the value stored in
 * the dictionary under the specified key, or nil if there is no value.<br />
 * However, if the key begins with '@' that character is stripped from
 * it and the superclass implementation of the method is used.
 */
- (id) valueForKey: (NSString*)key
{
    id	o;
    
    if ([key hasPrefix: @"@"] == YES)
    {
        o = [super valueForKey: [key substringFromIndex: 1]];
    }
    else
    {
        o = [self objectForKey: key];
    }
    return o;
}
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (__unsafe_unretained id[])stackbuf
                                     count: (NSUInteger)len
{
    [self subclassResponsibility: _cmd];
    return 0;
}

- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
    NSUInteger	size = [super sizeInBytesExcluding: exclude];
    
    if (size > 0)
    {
        NSUInteger	count = [self count];
        
        size += 3 * sizeof(void*) * count;
        if (count > 0)
        {
            NSEnumerator  *enumerator = [self keyEnumerator];
            NSObject<NSCopying>	*k = nil;
            
            while ((k = [enumerator nextObject]) != nil)
            {
                NSObject	*o = [self objectForKey: k];
                
                size += [k sizeInBytesExcluding: exclude];
                size += [o sizeInBytesExcluding: exclude];
            }
        }
    }
    return size;
}
@end


/**
 *  Mutable version of [NSDictionary].
 */
@implementation NSMutableDictionary

+ (void) initialize
{
    if (self == [NSMutableDictionary class])
    {
        NSMutableDictionaryClass = self;
        GSMutableDictionaryClass = [GSMutableDictionary class];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
    if (self == NSMutableDictionaryClass)
    {
        return NSAllocateObject(GSMutableDictionaryClass, 0, z);
    }
    else
    {
        return NSAllocateObject(self, 0, z);
    }
}

- (id) copyWithZone: (NSZone*)z
{
    /* a deep copy */
    unsigned	count = [self count];
    NSDictionary	*newDictionary;
    unsigned	i;
    id		key;
    NSEnumerator	*enumerator = [self keyEnumerator];
    IMP		nxtImp = [enumerator methodForSelector: nextObjectSEL];
    IMP		objImp = [self methodForSelector: objectForKeySEL];
    GS_BEGINIDBUF(o, count*2);
    
    for (i = 0; (key = (*nxtImp)(enumerator, nextObjectSEL)); i++)
    {
        o[i] = key;
        o[count + i] = (*objImp)(self, objectForKeySEL, key);
        o[count + i] = [o[count + i] copyWithZone: z];
    }
    newDictionary = [[GSDictionaryClass allocWithZone: z]
                     initWithObjects: o + count
                     forKeys: o
                     count: count];
    while (i-- > 0)
    {
        [o[count + i] release];
    }
    GS_ENDIDBUF();
    
    return newDictionary;
}

- (Class) classForCoder
{
    return NSMutableDictionaryClass;
}

/** <init /> <override-subclass />
 * Initializes an empty dictionary with memory preallocated for given number
 * of entries.  Although memory space will be grown as needed when entries
 * are added, this can avoid the reallocate-and-copy process if the size of
 * the ultimate contents is known in advance.<br />
 * Calls -init (which does nothing but maintain MacOS-X compatibility),
 * and needs to be re-implemented in subclasses in order to have all
 * other initialisers work.
 */
- (id) initWithCapacity: (NSUInteger)numItems
{
    self = [self init];
    return self;
}

/**
 *  Adds entry for aKey, mapping to anObject.  If either is nil, an exception
 *  is raised.  If aKey already in dictionary, the value it maps to is
 *  silently replaced.  The value anObject is retained, but aKey is copied
 *  (because a dictionary key must be immutable) and must therefore implement
 *  the [(NSCopying)] protocol.)
 */
- (void) setObject: anObject forKey: (id)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) setObject: (id)anObject forKeyedSubscript: (id)aKey
{
    [self setObject: anObject forKey: aKey];
}

/**
 *  Remove key-value mapping for given key aKey.  No error if there is no
 *  mapping for the key.  A warning will be generated if aKey is nil.
 */
- (void) removeObjectForKey: (id)aKey
{
    [self subclassResponsibility: _cmd];
}

/**
 *  Returns an empty dictionary with memory preallocated for given number of
 *  entries.  Although memory space will be grown as needed when entries are
 *  added, this can avoid the reallocate-and-copy process if the size of the
 *  ultimate contents is known in advance.
 */
+ (id) dictionaryWithCapacity: (NSUInteger)numItems
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithCapacity: numItems]);
}

/* Override superclass's designated initializer */
/**
 * Initializes contents to the given objects and keys.
 * The two arrays must have the same size.
 * The n th element of the objects array is associated with the n th
 * element of the keys array.
 */
- (id) initWithObjects: (const id[])objects
               forKeys: (const id <NSCopying>[])keys
                 count: (NSUInteger)count
{
    self = [self initWithCapacity: count];
    if (self != nil)
    {
        IMP	setObj;
        
        setObj = [self methodForSelector: setObjecctForKeySEL];
        while (count--)
        {
            (*setObj)(self, setObjecctForKeySEL, objects[count], keys[count]);
        }
    }
    return self;
}

/**
 *  Clears out this dictionary by removing all entries.
 */
- (void) removeAllObjects
{
    id		k;
    NSEnumerator	*e = [self keyEnumerator];
    IMP		nxtObj = [e methodForSelector: nextObjectSEL];
    IMP		remObj = [self methodForSelector: removeObjectForKeySEL];
    
    while ((k = (*nxtObj)(e, nextObjectSEL)) != nil)
    {
        (*remObj)(self, removeObjectForKeySEL, k);
    }
}

/**
 *  Remove entries specified by the given keyArray.  No error is generated if
 *  no mapping exists for a key or one is nil, although a console warning is
 *  produced in the latter case.
 */
- (void) removeObjectsForKeys: (NSArray*)keyArray
{
    unsigned	c = [keyArray count];
    
    if (c > 0)
    {
        IMP	remObj = [self methodForSelector: removeObjectForKeySEL];
        GS_BEGINIDBUF(keys, c);
        
        if ([keyArray isProxy])
        {
            unsigned	i;
            
            for (i = 0; i < c; i++)
            {
                keys[i] = [keyArray objectAtIndex: i];
            }
        }
        else
        {
            [keyArray getObjects: keys];
        }
        while (c--)
        {
            (*remObj)(self, removeObjectForKeySEL, keys[c]);
        }
        GS_ENDIDBUF();
    }
}

/**
 * Merges information from otherDictionary into the receiver.
 * If a key exists in both dictionaries, the value from otherDictionary
 * replaces that which was originally in the receiver.
 */
- (void) addEntriesFromDictionary: (NSDictionary*)otherDictionary
{
    if (otherDictionary != nil && otherDictionary != self)
    {
        id		k;
        NSEnumerator	*e = [otherDictionary keyEnumerator];
        IMP		nxtObj = [e methodForSelector: nextObjectSEL];
        IMP		getObj = [otherDictionary methodForSelector: objectForKeySEL];
        IMP		setObj = [self methodForSelector: setObjecctForKeySEL];
        
        while ((k = (*nxtObj)(e, nextObjectSEL)) != nil)
        {
            (*setObj)(self, setObjecctForKeySEL, (*getObj)(otherDictionary, objectForKeySEL, k), k);
        }
    }
}

/**
 *  Remove all entries, then add all entries from otherDictionary.
 */
- (void) setDictionary: (NSDictionary*)otherDictionary
{
    [self removeAllObjects];
    [self addEntriesFromDictionary: otherDictionary];
}

/**
 * Default implementation for this class is equivalent to the
 * -setObject:forKey: method unless value is nil, in which case
 * it is equivalent to -removeObjectForKey:
 */
- (void) takeStoredValue: (id)value forKey: (NSString*)key
{
    if (value == nil)
    {
        [self removeObjectForKey: key];
    }
    else
    {
        [self setObject: value forKey: key];
    }
}

/**
 * Default implementation for this class is equivalent to the
 * -setObject:forKey: method unless value is nil, in which case
 * it is equivalent to -removeObjectForKey:
 */
- (void) takeValue: (id)value forKey: (NSString*)key
{
    if (value == nil)
    {
        [self removeObjectForKey: key];
    }
    else
    {
        [self setObject: value forKey: key];
    }
}

/**
 * Default implementation for this class is equivalent to the
 * -setObject:forKey: method unless value is nil, in which case
 * it is equivalent to -removeObjectForKey:
 */
- (void) setValue: (id)value forKey: (NSString*)key
{
    if (value == nil)
    {
        [self removeObjectForKey: key];
    }
    else
    {
        [self setObject: value forKey: key];
    }
}
@end
