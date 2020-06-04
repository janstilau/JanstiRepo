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

static SEL	equalSel;
static SEL	nextSel;
static SEL	objectForKeySel;
static SEL	removeObjectForKeySel;
static SEL	setObjectForKeySel;
static SEL	appendStringSel;

/**
 *  <p>This class and its subclasses store key-value pairs, where the key and
 *  the value are objects.  A great many utility methods for working with
 *  dictionaries are provided as part of this class, including the ability to
 *  retrieve multiple entries simultaneously, obtain sorted contents, and
 *  read/write from/to a serialized representation.</p> // 这个类主要的职责是定义公共的函数. 和 NSArray 一样.
 *
 *  <p>The keys are copied and values are retained by the implementation,
 *  and both are released when either their entry is dropped or the entire
 *  dictionary is deallocated.<br />
 *  As in the OS X implementation, keys must therefore implement the
 *  [(NSCopying)] protocol. //
 *  <p>Objects of this class are immutable.  For a mutable version, use the
 *  [NSMutableDictionary] subclass.</p>
 *
 *  <p>The basic functionality in <code>NSDictionary</code> is similar to that
 *  in Java's <code>HashMap</code>, and like that class it includes no locking
 *  code and is not thread-safe.  If the contents will be modified and
 *  accessed from multiple threads you should enclose critical operations
 *  within locks (see [NSLock]).</p>
 NSDictionary 是线程不安全的.
 */
@implementation NSDictionary

// 这个类定义了许多字典的方法, 但是实际的内存实现, 要在子类中完成.

+ (void) initialize
{
    if (self == [NSDictionary class])
    {
        equalSel = @selector(isEqual:);
        nextSel = @selector(nextObject);
        objectForKeySel = @selector(objectForKey:);
        removeObjectForKeySel = @selector(removeObjectForKey:);
        setObjectForKeySel = @selector(setObject:forKey:);
        appendStringSel = @selector(appendString:);
        NSArray_class = [NSArray class];
        NSDictionaryClass = self;
        GSDictionaryClass = [GSDictionary class];
        [NSMutableDictionary class];
    }
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
    BLOCK_SCOPE BOOL shouldStop = NO;
    id obj;
    
    // 我们看到, 这里还是通过迭代器取得值, 这样子类只要实现迭代器接口就可以了. 因为字典的遍历, 其实是和字典的内部数据结构相关的. 而迭代器的作用, 就是想每个子类的内部实现, 包装到自己的接口之下.
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

/** <init /> <override-subclass />
 * Initializes contents to the given objects and keys.
 * The two arrays must have the same size.
 * The n th element of the objects array is associated with the n th
 * element of the keys array.<br />
 * Calls -init (which does nothing but maintain MacOS-X compatibility),
 * and needs to be re-implemented in subclasses in order to have all
 * other initialisers work.
 */
- (id) initWithObjects: (const id[])objects
               forKeys: (const id <NSCopying>[])keys
                 count: (int)count
{
    self = [self init];
    return self;
}

/**
 * Return an enumerator object containing all the keys of the dictionary.
 *
 * 这些都应该由具体的类实现出来, 其他所有的方法, 都是根据这几个基本方法创建出来的.
 */
- (NSEnumerator*) keyEnumerator
{
    return [self subclassResponsibility: _cmd];
}

/**
 * Returns the object in the dictionary corresponding to aKey, or nil if
 * the key is not present.
 */
- (id) objectForKey: (id)aKey
{
    return [self subclassResponsibility: _cmd];
}

- (id) objectForKeyedSubscript: (id)aKey
{
    return [self objectForKey: aKey];
}

/**
 * Return an enumerator object containing all the objects of the dictionary.
 */
- (NSEnumerator*) objectEnumerator
{
    return [self subclassResponsibility: _cmd];
}

- (int) hash
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
        GS_BEGINIDBUF(o, objectCount*2);
        
        // 将 key 和 obj 的数据, 都放到一个数组里面, 然后通过这个数据进行初始化.
        
        if ([objects isProxy])
        {
            unsigned	i;
            
            for (i = 0; i < objectCount; i++)
            {
                o[i] = [objects objectAtIndex: i];
            }
        }
        else
        {
            [objects getObjects: o];
        }
        if ([keys isProxy])
        {
            unsigned	i;
            
            for (i = 0; i < objectCount; i++)
            {
                o[objectCount + i] = [keys objectAtIndex: i];
            }
        }
        else
        {
            [keys getObjects: o + objectCount];
        }
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
        IMP		nxtObj = [e methodForSelector: nextSel];
        IMP		otherObj = [other methodForSelector: objectForKeySel];
        GS_BEGINIDBUF(o, c*2); // 这里就有一个数组, 前面装 key, 后面装 value
        
        if (shouldCopy)
        {
            NSZone	*z = [self zone];
            
            while ((k = (*nxtObj)(e, nextSel)) != nil)
            {
                o[i] = k;
                o[c + i] = [(*otherObj)(other, objectForKeySel, k) copyWithZone: z];
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
            while ((k = (*nxtObj)(e, nextSel)) != nil)
            {
                o[i] = k;
                o[c + i] = (*otherObj)(other, objectForKeySel, k);
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
 */
- (id) initWithContentsOfFile: (NSString*)path
{
    // 先是文本, 然后解析成为字典, 最后通过 initWithDict 达到结果.
    // 这里, 是用 Plist 文件解析的方式, 所以, NSDict 写入的时候, 也应该用 plist 的这种方式.
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

- (BOOL) isEqual: other
{
    if (other == self)
        return YES;
    
    if ([other isKindOfClass: NSDictionaryClass])
        return [self isEqualToDictionary: other];
    
    return NO;
}

/**
 这里面的所有的操作, 都是根据迭代器这种方式.
 */
- (BOOL) isEqualToDictionary: (NSDictionary*)other
{
    unsigned	count;
    
    if (other == self)
    {
        return YES;
    }
    count = [self count];
    if (count == [other count])
    {
        if (count > 0)
        {
            NSEnumerator	*e = [self keyEnumerator];
            IMP		nxtObj = [e methodForSelector: nextSel];
            IMP		myObj = [self methodForSelector: objectForKeySel];
            IMP		otherObj = [other methodForSelector: objectForKeySel];
            id		k;
            
            while ((k = (*nxtObj)(e, @selector(nextObject))) != nil)
            {
                id o1 = (*myObj)(self, objectForKeySel, k);
                id o2 = (*otherObj)(other, objectForKeySel, k);
                
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
 * Returns an array containing all the dictionary's keys.
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
        IMP		nxtObj = [e methodForSelector: nextSel];
        unsigned		i;
        id		result;
        GS_BEGINIDBUF(k, c);
        
        for (i = 0; i < c; i++)
        {
            k[i] = (*nxtObj)(e, nextSel);
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
        IMP		nxtObj = [e methodForSelector: nextSel];
        id		result;
        unsigned		i;
        GS_BEGINIDBUF(k, c);
        
        for (i = 0; i < c; i++)
        {
            k[i] = (*nxtObj)(e, nextSel);
        }
        result = [[NSArray_class allocWithZone: NSDefaultMallocZone()]
                  initWithObjects: k count: c];
        GS_ENDIDBUF();
        return AUTORELEASE(result);
    }
}

/*
 比较底层的方法, 用到了直接的内存操作.
 */
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
        IMP		nxtObj = [e methodForSelector: nextSel];
        IMP		myObj = [self methodForSelector: objectForKeySel];
        BOOL		(*eqObj)(id, SEL, id);
        id		k;
        id		result;
        GS_BEGINIDBUF(a, [self count]);
        
        eqObj = (BOOL (*)(id, SEL, id))[anObject methodForSelector: equalSel];
        c = 0;
        while ((k = (*nxtObj)(e, nextSel)) != nil)
        {
            id	o = (*myObj)(self, objectForKeySel, k);
            
            if (o == anObject || (*eqObj)(anObject, equalSel, o))
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
    info.i = [self methodForSelector: objectForKeySel];
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
        IMP	myObj = [self methodForSelector: objectForKeySel];
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
            id o = (*myObj)(self, objectForKeySel, obuf[i]);
            
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
    
    /*
     都是利用的 Plist 文件的方式进行的写入.
     */
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

- (int) sizeInBytesExcluding: (NSHashTable*)exclude
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

- (id) copyWithZone: (NSZone*)z
{
    /* a deep copy */
    unsigned	count = [self count];
    NSDictionary	*newDictionary;
    unsigned	i;
    id		key;
    NSEnumerator	*enumerator = [self keyEnumerator];
    IMP		nxtImp = [enumerator methodForSelector: nextSel];
    IMP		objImp = [self methodForSelector: objectForKeySel];
    GS_BEGINIDBUF(o, count*2);
    
    for (i = 0; (key = (*nxtImp)(enumerator, nextSel)); i++)
    {
        o[i] = key;
        o[count + i] = (*objImp)(self, objectForKeySel, key);
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

/** <init /> <override-subclass />
 * Initializes an empty dictionary with memory preallocated for given number
 * of entries.  Although memory space will be grown as needed when entries
 * are added, this can avoid the reallocate-and-copy process if the size of
 * the ultimate contents is known in advance.<br />
 * Calls -init (which does nothing but maintain MacOS-X compatibility),
 * and needs to be re-implemented in subclasses in order to have all
 * other initialisers work.
 */
- (id) initWithCapacity: (int)numItems
{
    self = [self init];
    return self;
}

/**
    这些基本方法, 都需要子类进行实现. 因为这涉及到了内存的操作.
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
+ (id) dictionaryWithCapacity: (int)numItems
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
                 count: (int)count
{
    self = [self initWithCapacity: count];
    if (self != nil)
    {
        IMP	setObj;
        
        setObj = [self methodForSelector: setObjectForKeySel];
        while (count--)
        {
            (*setObj)(self, setObjectForKeySel, objects[count], keys[count]);
        }
    }
    return self;
}

/**
 这个方法, 是完全建立在了 iterator 的. 而没有使用自己的存储结构. 这样, 在存储结构修改了之后, 可以不用修改代码.
 */
- (void) removeAllObjects
{
    id		k;
    NSEnumerator	*iterator = [self keyEnumerator];
    IMP		nxtObj = [iterator methodForSelector: nextSel];
    IMP		remObj = [self methodForSelector: removeObjectForKeySel];
    
    while ((k = (*nxtObj)(iterator, nextSel)) != nil)
    {
        (*remObj)(self, removeObjectForKeySel, k);
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
        IMP	remObj = [self methodForSelector: removeObjectForKeySel];
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
            (*remObj)(self, removeObjectForKeySel, keys[c]);
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
        IMP		nxtObj = [e methodForSelector: nextSel];
        IMP		getObj = [otherDictionary methodForSelector: objectForKeySel];
        IMP		setObj = [self methodForSelector: setObjectForKeySel];
        
        while ((k = (*nxtObj)(e, nextSel)) != nil)
        {
            (*setObj)(self, setObjectForKeySel, (*getObj)(otherDictionary, objectForKeySel, k), k);
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

- (void) setValue: (id)value forKey: (NSString*)key
{
    // 这已经是一个常用的模式了, nil 做删除操作.
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
