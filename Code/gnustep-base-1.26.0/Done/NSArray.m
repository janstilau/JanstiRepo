#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSData.h"
#import "Foundation/NSRange.h"
#import "Foundation/NSException.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSIndexSet.h"
// For private method _decodeArrayOfObjectsForKey:
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "GSPThread.h"
#import "GSFastEnumeration.h"
#import "GSDispatch.h"
#import "GSSorting.h"

static BOOL GSMacOSXCompatiblePropertyLists(void)
{
    if (GSPrivateDefaultsFlag(NSWriteOldStylePropertyLists) == YES)
        return NO;
    return GSPrivateDefaultsFlag(GSMacOSXCompatible);
}

extern void     GSPropertyListMake(id,NSDictionary*,BOOL,BOOL,unsigned,id*);

@interface NSArrayEnumerator : NSEnumerator
{
    NSArray	*array;
    NSUInteger	pos;
    IMP		get;
    NSUInteger	(*cnt)(NSArray*, SEL);
}
- (id) initWithArray: (NSArray*)anArray;
@end
@interface NSArrayEnumeratorReverse : NSArrayEnumerator
@end



static Class NSArrayClass;
static Class GSArrayClass;
static Class NSMutableArrayClass;
static Class GSMutableArrayClass;
static Class GSPlaceholderArrayClass;

static GSPlaceholderArray	*defaultPlaceholderArray;
static NSMapTable		*placeholderMap;
static pthread_mutex_t          placeholderLock = PTHREAD_MUTEX_INITIALIZER;


/**
 * A simple, low overhead, ordered container for objects.  All the objects
 * in the container are retained by it.  The container may not contain nil
 * (though it may contain [NSNull+null]).
 */
@implementation NSArray

static SEL	addObjectSel;
static SEL	appendStringSel;
static SEL	countSel;
static SEL	isEqualSel;
static SEL	objAtIndexSel;
static SEL	removeObjAtIndexSel;
static SEL	removeLastSel;

+ (void) atExit
{
    DESTROY(defaultPlaceholderArray);
    DESTROY(placeholderMap);
}

+ (void) initialize
{
    if (self == [NSArray class])
    {
        addObjectSel = @selector(addObject:);
        appendStringSel = @selector(appendString:);
        countSel = @selector(count);
        isEqualSel = @selector(isEqual:);
        objAtIndexSel = @selector(objectAtIndex:);
        removeObjAtIndexSel = @selector(removeObjectAtIndex:);
        removeLastSel = @selector(removeLastObject);
        
        NSArrayClass = [NSArray class];
        NSMutableArrayClass = [NSMutableArray class];
        GSArrayClass = [GSArray class];
        GSMutableArrayClass = [GSMutableArray class];
        GSPlaceholderArrayClass = [GSPlaceholderArray class];
        
        /*
         * Set up infrastructure for placeholder arrays.
         */
        defaultPlaceholderArray = (GSPlaceholderArray*) NSAllocateObject(GSPlaceholderArrayClass, 0, NSDefaultMallocZone());
        placeholderMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                          NSNonRetainedObjectMapValueCallBacks, 0);
    }
}

// 类簇模式的实现方式, 返回一个 placeHolder 对象, 然后在这个对象的 init 方法里面, 生成实际的类的对象.
+ (id) allocWithZone: (NSZone*)z
{
    if (self == NSArrayClass)
    {
        /*
         * For a constant array, we return a placeholder object that can
         * be converted to a real object when its initialisation method
         * is called.
         */
        if (z == NSDefaultMallocZone() || z == 0)
        {
            /*
             * As a special case, we can return a placeholder for an array
             * in the default malloc zone extremely efficiently.
             */
            return defaultPlaceholderArray;
        } else
        {
            id	obj;
            
            /*
             * For anything other than the default zone, we need to
             * locate the correct placeholder in the (lock protected)
             * table of placeholders.
             */
            (void)pthread_mutex_lock(&placeholderLock);
            obj = (id)NSMapGet(placeholderMap, (void*)z);
            if (obj == nil)
            {
                /*
                 * There is no placeholder object for this zone, so we
                 * create a new one and use that.
                 */
                obj = (id)NSAllocateObject(GSPlaceholderArrayClass, 0, z);
                NSMapInsert(placeholderMap, (void*)z, (void*)obj);
            }
            (void)pthread_mutex_unlock(&placeholderLock);
            return obj;
        }
    }
    else
    {
        return NSAllocateObject(self, 0, z);
    }
}

/**
 * Returns an empty autoreleased array.
 */
+ (id) array
{
    id	o;
    o = [self allocWithZone: NSDefaultMallocZone()];
    o = [o initWithObjects: (id*)0 count: 0];
    return AUTORELEASE(o);
}

/**
 * Returns a new autoreleased NSArray instance containing all the objects from
 * array, in the same order as the original.
 */
+ (id) arrayWithArray: (NSArray*)array
{
    id	o;
    
    o = [self allocWithZone: NSDefaultMallocZone()];
    o = [o initWithArray: array];
    return AUTORELEASE(o);
}

/**
 * Returns an autoreleased array based upon the file.  The new array is
 * created using [NSObject+allocWithZone:] and initialised using the
 * [NSArray-initWithContentsOfFile:] method. See the documentation for those
 * methods for more detail.
 */
+ (id) arrayWithContentsOfFile: (NSString*)file
{
    id	o;
    
    o = [self allocWithZone: NSDefaultMallocZone()];
    o = [o initWithContentsOfFile: file]; // 具体实现, 也就是数组的简单取值赋值操作, 然后对每一个值进行了 retain 操作.
    return AUTORELEASE(o);
}

/**
 * Returns an autoreleased array from the contents of aURL.  The new array is
 * created using [NSObject+allocWithZone:] and initialised using the
 * -initWithContentsOfURL: method. See the documentation for those
 * methods for more detail.
 */
+ (id) arrayWithContentsOfURL: (NSURL*)aURL
{
    id	o;
    
    o = [self allocWithZone: NSDefaultMallocZone()];
    o = [o initWithContentsOfURL: aURL];
    return AUTORELEASE(o);
}

/**
 * Returns an autoreleased array containing anObject.
 */
+ (id) arrayWithObject: (id)anObject
{
    id	o;
    
    o = [self allocWithZone: NSDefaultMallocZone()];
    o = [o initWithObjects: &anObject count: 1];
    return AUTORELEASE(o);
}

/**
 * Returns an autoreleased array containing the list
 * of objects, preserving order.
 */
+ (id) arrayWithObjects: firstObject, ...
{
    id	a = [self allocWithZone: NSDefaultMallocZone()];
    
    GS_USEIDLIST(firstObject,
                 a = [a initWithObjects: __objects count: __count]);
    return AUTORELEASE(a);
}

/**
 * Returns an autoreleased array containing the specified
 * objects, preserving order.
 */
+ (id) arrayWithObjects: (const id[])objects count: (NSUInteger)count
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithObjects: objects count: count]);
}

/**
  所有, 上面的类方法, 都是调用的实例方法. 仅仅是一层最简单的包装而已. 所有的返回对象, 都进行了 autorelease 的调用.
 */

/**
  生成一个新的对象. 因为 NSArray 是一个不可变类型.
 */
- (NSArray*) arrayByAddingObject: (id)anObject
{
    id na;
    NSUInteger	c = [self count];
    
    if (anObject == nil)
        [NSException raise: NSInvalidArgumentException
                    format: @"Attempt to add nil to an array"];
    if (c == 0) // 如果是空的数组, 直接生成一个新的数组.
    {
        na = [[GSArrayClass allocWithZone: NSDefaultMallocZone()]
              initWithObjects: &anObject count: 1];
    }
    else
    {
        GS_BEGINIDBUF(objects, c+1);
        
        [self getObjects: objects];
        objects[c] = anObject; // 在后面, 添加数据. 然后, 根据这块内存区域, 生成类型. 在 initWithObjects 中, 才会进行 retain 的操作.
        na = [[GSArrayClass allocWithZone: NSDefaultMallocZone()]
              initWithObjects: objects count: c+1];
        
        GS_ENDIDBUF();
    }
    return AUTORELEASE(na);
}

/**
 * Returns a new array which is the concatenation of self and
 * otherArray (in this precise order).
 */
- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray
{
    id		na;
    NSUInteger	c;
    NSUInteger	l;
    NSUInteger	e;
    
    c = [self count];
    l = [anotherArray count];
    e = c + l;
    
    {
        GS_BEGINIDBUF(objects, e);
        
        [self getObjects: objects];
        if ([anotherArray isProxy])
        {
            NSUInteger	i = c;
            NSUInteger	j = 0;
            
            while (i < e)
            {
                objects[i++] = [anotherArray objectAtIndex: j++];
            }
        }
        else
        {
            [anotherArray getObjects: &objects[c]];
        }
        na = [NSArrayClass arrayWithObjects: objects count: e];
        
        GS_ENDIDBUF();
    }
    
    return na;
}

/**
 * Returns the abstract class ... arrays are coded as abstract arrays.
 */
- (Class) classForCoder
{
    return NSArrayClass;
}

/**
 
 */
- (BOOL) containsObject: (id)anObject
{
    return ([self indexOfObject: anObject] != NSNotFound);
}

/**
 * Returns a new copy of the receiver.<br />
 * The default abstract implementation of a copy is to use the
 * -initWithArray:copyItems: method with the flag set to YES.<br />
 * Immutable subclasses generally simply retain and return the receiver.
 */
- (id) copyWithZone: (NSZone*)zone
{
    NSArray	*copy = [NSArrayClass allocWithZone: zone];
    
    return [copy initWithArray: self copyItems: YES];
}

- (NSUInteger) count
{
    [self subclassResponsibility: _cmd];
    return 0;
}

/**
    这个函数, 其实就是一个语言内置的切口, 在 for in 的实现里面, 就会调用这个方法. 也就是说, 如果一个类实现了这个方法, 声明实现了这个协议, 它就能直接用 for in 循环.
 */

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (__unsafe_unretained id[])stackbuf
                                     count: (NSUInteger)len
{
    NSInteger count;
    
    /* In a mutable subclass, the mutationsPtr should be set to point to a
     * value (unsigned long) which will be changed (incremented) whenever
     * the container is mutated (content added, removed, re-ordered).
     * This is cached in the caller at the start and compared at each
     * iteration.   If it changes during the iteration then
     * objc_enumerationMutation() will be called, throwing an exception.
     * The abstract base class implementation points to a fixed value
     * (the enumeration state pointer should exist and be unchanged for as
     * long as the enumeration process runs), which is fine for enumerating
     * an immutable array.
     */
    state->mutationsPtr = (unsigned long *)&state->mutationsPtr;
    count = MIN(len, [self count] - state->state);
    /* If a mutation has occurred then it's possible that we are being asked to
     * get objects from after the end of the array.  Don't pass negative values
     * to memcpy.
     */
    if (count > 0)
    {
        IMP	imp = [self methodForSelector: @selector(objectAtIndex:)];
        int	p = state->state;
        int	i;
        
        for (i = 0; i < count; i++, p++)
        {
            stackbuf[i] = (*imp)(self, @selector(objectAtIndex:), p);
        }
        state->state += count;
    }
    else
    {
        count = 0;
    }
    state->itemsPtr = stackbuf;
    return count;
}

/**
 * Encodes the receiver for storing to archive or sending over an
 * [NSConnection].
 */
- (void) encodeWithCoder: (NSCoder*)aCoder
{
    NSUInteger	count = [self count];
    
    if ([aCoder allowsKeyedCoding])
    {
        /* HACK ... MacOS-X seems to code differently if the coder is an
         * actual instance of NSKeyedArchiver
         */
        if ([aCoder class] == [NSKeyedArchiver class])
        {
            [(NSKeyedArchiver*)aCoder _encodeArrayOfObjects: self
                                                     forKey: @"NS.objects"];
        }
        else
        {
            NSUInteger	i;
            
            for (i = 0; i < count; i++)
            {
                NSString	*key;
                
                key = [NSString stringWithFormat: @"NS.object.%lu", (unsigned long)i];
                [(NSKeyedArchiver*)aCoder encodeObject: [self objectAtIndex: i]
                                                forKey: key];
            }
        }
    }
    else
    {
        unsigned  items = (unsigned)count;
        
        [aCoder encodeValueOfObjCType: @encode(unsigned)
                                   at: &items];
        if (count > 0)
        {
            GS_BEGINIDBUF(a, count);
            
            [self getObjects: a];
            [aCoder encodeArrayOfObjCType: @encode(id)
                                    count: count
                                       at: a];
            GS_ENDIDBUF();
        }
    }
}

/**
 
 最核心的方法, 将自己的数据放到提前定义的 buffer 里面. 这里仅仅是简单的数据的赋值操作, 没有内存管理方面的内容.
 
 */
- (void) getObjects: (__unsafe_unretained id[])aBuffer
{
    NSUInteger i, c = [self count];
    IMP	get = [self methodForSelector: objAtIndexSel];
    
    for (i = 0; i < c; i++)
        aBuffer[i] = (*get)(self, objAtIndexSel, i);
}


/**
 直接用的 length 当做 hash 的值.
 */
- (NSUInteger) hash
{
    return [self count];
}

/**
 基于地址的比较, 直接比较的就是地址值
 */
- (NSUInteger) indexOfObjectIdenticalTo: (id)anObject
{
    NSUInteger c = [self count];
    
    if (c > 0)
    {
        IMP	get = [self methodForSelector: objAtIndexSel];
        NSUInteger	i;
        
        for (i = 0; i < c; i++)
            if (anObject == (*get)(self, objAtIndexSel, i))
                return i;
    }
    return NSNotFound;
}

/**
 * Returns the index of the specified object in the range of the receiver,
 * or NSNotFound if the object is not present.
 */
- (NSUInteger) indexOfObjectIdenticalTo: anObject inRange: (NSRange)aRange
{
    NSUInteger i, e = aRange.location + aRange.length, c = [self count];
    IMP	get = [self methodForSelector: objAtIndexSel];
    
    GS_RANGE_CHECK(aRange, c);
    
    for (i = aRange.location; i < e; i++)
        if (anObject == (*get)(self, objAtIndexSel, i))
            return i;
    return NSNotFound;
}

/**
 这里我们可以看到, 数组里面的相等比较, 是基于值属性的比较, 而不是地址的比较
 */
- (NSUInteger) indexOfObject: (id)anObject
{
    NSUInteger	c = [self count];
    
    if (c > 0 && anObject != nil)
    {
        NSUInteger	i;
        IMP	get = [self methodForSelector: objAtIndexSel];
        BOOL	(*eq)(id, SEL, id)
        = (BOOL (*)(id, SEL, id))[anObject methodForSelector: isEqualSel];
        
        for (i = 0; i < c; i++)
            if ((*eq)(anObject, isEqualSel, (*get)(self, objAtIndexSel, i)) == YES)
                return i;
    }
    return NSNotFound;
}

/**
 * Returns the index of the first object found in aRange of receiver
 * which is equal to anObject (using anObject's [NSObject-isEqual:] method).
 * Returns NSNotFound on failure.
 */
- (NSUInteger) indexOfObject: (id)anObject inRange: (NSRange)aRange
{
    NSUInteger i, e = aRange.location + aRange.length, c = [self count];
    IMP	get = [self methodForSelector: objAtIndexSel];
    BOOL	(*eq)(id, SEL, id)
    = (BOOL (*)(id, SEL, id))[anObject methodForSelector: isEqualSel];
    
    GS_RANGE_CHECK(aRange, c);
    
    for (i = aRange.location; i < e; i++)
    {
        if ((*eq)(anObject, isEqualSel, (*get)(self, objAtIndexSel, i)) == YES)
            return i;
    }
    return NSNotFound;
}

/**
 * <p>In MacOS-X class clusters do not have designated initialisers,
 * and there is a general rule that -init is treated as the designated
 * initialiser of the class cluster, but that other intitialisers
 * may not work s expected an would need to be individually overridden
 * in any subclass.
 * </p>
 * <p>GNUstep tries to make it easier to subclass a class cluster,
 * by making class clusters follow the same convention as normal
 * classes, so the designated initialiser is the <em>richest</em>
 * initialiser.  This means that all other initialisers call the
 * documented designated initialiser (which calls -init only for
 * MacOS-X compatibility), and anyone writing a subclass only needs
 * to override that one initialiser in order to have all the other
 * ones work.
 * </p>
 * <p>For MacOS-X compatibility, you may also need to override various
 * other initialisers.  Exactly which ones, you will need to determine
 * by trial on a MacOS-X system ... and may vary between releases of
 * MacOS-X.  So to be safe, on MacOS-X you probably need to re-implement
 * <em>all</em> the class cluster initialisers you might use in conjunction
 * with your subclass.
 * </p>
 */
- (id) init
{
    self = [super init];
    return self;
}

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * If shouldCopy is YES then the objects are copied
 * rather than simply retained.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy
{
    NSUInteger	c = [array count];
    GS_BEGINIDBUF(objects, c);
    
    if ([array isProxy])
    {
        NSUInteger	i;
        
        for (i = 0; i < c; i++)
        {
            objects[i] = [array objectAtIndex: i];
        }
    }
    else
    {
        [array getObjects: objects];
    }
    if (shouldCopy == YES)
    {
        NSUInteger	i;
        
        for (i = 0; i < c; i++)
        {
            objects[i] = [objects[i] copy];
        }
        self = [self initWithObjects: objects count: c];
        while (i > 0)
        {
            [objects[--i] release];
        }
    }
    else
    {
        self = [self initWithObjects: objects count: c];
    }
    GS_ENDIDBUF();
    return self;
}

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array
{
    NSUInteger	c = [array count];
    GS_BEGINIDBUF(objects, c);
    
    if ([array isProxy])
    {
        NSUInteger	i;
        
        for (i = 0; i < c; i++)
        {
            objects[i] = [array objectAtIndex: i];
        }
    }
    else
    {
        [array getObjects: objects];
    }
    self = [self initWithObjects: objects count: c];
    GS_ENDIDBUF();
    return self;
}

/**
 * Initialize the array by decoding from an archive.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithCoder: (NSCoder*)aCoder
{
    if ([aCoder allowsKeyedCoding])
    {
        id	array;
        
        array = [(NSKeyedUnarchiver*)aCoder _decodeArrayOfObjectsForKey:
                 @"NS.objects"];
        if (array == nil)
        {
            NSUInteger	i = 0;
            NSString	*key;
            id		val;
            
            array = [NSMutableArray arrayWithCapacity: 2];
            key = [NSString stringWithFormat: @"NS.object.%lu", (unsigned long)i];
            val = [(NSKeyedUnarchiver*)aCoder decodeObjectForKey: key];
            
            while (val != nil)
            {
                [array addObject: val];
                i++;
                key = [NSString stringWithFormat: @"NS.object.%lu", (unsigned long)i];
                val = [(NSKeyedUnarchiver*)aCoder decodeObjectForKey: key];
            }
        }
        
        self = [self initWithArray: array];
    }
    else
    {
        unsigned    items;
        
        [aCoder decodeValueOfObjCType: @encode(unsigned)
                                   at: &items];
        if (items > 0)
        {
            GS_BEGINIDBUF(contents, items);
            
            [aCoder decodeArrayOfObjCType: @encode(id)
                                    count: items
                                       at: contents];
            self = [self initWithObjects: contents count: items];
            while (items-- > 0)
            {
                [contents[items] release];
            }
            GS_ENDIDBUF();
        }
        else
        {
            self = [self initWithObjects: 0 count: 0];
        }
    }
    return self;
}

/**
 * <p>Initialises the array with the contents of the specified file,
 * which must contain an array in property-list format.
 * </p>
 * <p>In GNUstep, the property-list format may be either the OpenStep
 * format (ASCII data), or the MacOS-X format (UTF-8 XML data) ... this
 * method will recognise which it is.
 * </p>
 * <p>If there is a failure to load the file for any reason, the receiver
 * will be released, the method will return nil, and a warning may be logged.
 * </p>
 * <p>Works by invoking [NSString-initWithContentsOfFile:] and
 * [NSString-propertyList] then checking that the result is an array.
 * </p>
 */
- (id) initWithContentsOfFile: (NSString*)file
{
    NSString 	*myString;
    // 首先是读取 file 位置的文件的字符串内容, 也就是说, NSArray 是按照文本文件存储的. plist .
    myString = [[NSString allocWithZone: NSDefaultMallocZone()]
                initWithContentsOfFile: file];
    if (myString == nil)
    {
        DESTROY(self);
    }
    else
    {
        id result;
        
        NS_DURING
        {
            result = [myString propertyList]; // 文本文件到底会变成什么样的数据, 是 propertyList 的解析工具的事情.
        }
        NS_HANDLER
        {
            result = nil;
        }
        NS_ENDHANDLER
        RELEASE(myString);
        if ([result isKindOfClass: NSArrayClass])
        {
            //self = [self initWithArray: result];
            /* OSX appears to always return a mutable array rather than
             * the class of the receiver.
             */
            RELEASE(self);
            self = RETAIN(result);
        }
        else
        {
            NSWarnMLog(@"Contents of file '%@' does not contain an array", file);
            DESTROY(self);
        }
    }
    return self;
}

/**
 * <p>Initialises the array with the contents of the specified URL,
 * which must contain an array in property-list format.
 * </p>
 * <p>In GNUstep, the property-list format may be either the OpenStep
 * format (ASCII data), or the MacOS-X format (UTF8 XML data) ... this
 * method will recognise which it is.
 * </p>
 * <p>If there is a failure to load the URL for any reason, the receiver
 * will be released, the method will return nil, and a warning may be logged.
 * </p>
 * <p>Works by invoking [NSString-initWithContentsOfURL:] and
 * [NSString-propertyList] then checking that the result is an array.
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
        if ([result isKindOfClass: NSArrayClass])
        {
            self = [self initWithArray: result];
        }
        else
        {
            NSWarnMLog(@"Contents of URL '%@' does not contain an array", aURL);
            DESTROY(self);
        }
    }
    return self;
}

- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    self = [self init];
    return self;
}

/**
 * Initialize the array the list of objects.
 * <br />May change the value of self before returning it.
 */
- (id) initWithObjects: firstObject, ...
{
    GS_USEIDLIST(firstObject,
                 self = [self initWithObjects: __objects count: __count]);
    return self;
}

/**
 * Returns an NSMutableArray instance containing the same objects as
 * the receiver.<br />
 * The default implementation does this by calling the
 * -initWithArray:copyItems: method on a newly created object,
 * and passing it NO to tell it just to retain the items.
 */
- (id) mutableCopyWithZone: (NSZone*)zone
{
    NSMutableArray	*copy = [NSMutableArrayClass allocWithZone: zone];
    
    return [copy initWithArray: self copyItems: NO];
}

- (id) objectAtIndex: (NSUInteger)index
{
    [self subclassResponsibility: _cmd];
    return nil;
}

- (id) objectAtIndexedSubscript: (NSUInteger)anIndex
{
    return [self objectAtIndex: anIndex];
}

- (NSArray *) objectsAtIndexes: (NSIndexSet *)indexes
{
    //FIXME: probably slow!
    NSMutableArray *group = [NSMutableArray arrayWithCapacity: [indexes count]];
    
    NSUInteger i = [indexes firstIndex];
    while (i != NSNotFound)
    {
        [group addObject: [self objectAtIndex: i]];
        i = [indexes indexGreaterThanIndex: i];
    }
    
    return GS_IMMUTABLE(group);
}

- (BOOL) isEqual: (id)anObject
{
    if (self == anObject)
        return YES;
    if ([anObject isKindOfClass: NSArrayClass])
        return [self isEqualToArray: anObject];
    return NO;
}


/**
 首先比较个数, 然后是各个位置的值得 isEqual 的比较.
 */
- (BOOL) isEqualToArray: (NSArray*)otherArray
{
    NSUInteger i, c;
    
    if (self == (id)otherArray)
        return YES;
    c = [self count];
    if (c != [otherArray count])
        return NO;
    if (c > 0)
    {
        IMP	get0 = [self methodForSelector: objAtIndexSel];
        IMP	get1 = [otherArray methodForSelector: objAtIndexSel];
        
        for (i = 0; i < c; i++)
            if (![(*get0)(self, objAtIndexSel, i) isEqual: (*get1)(otherArray, objAtIndexSel, i)])
                return NO;
    }
    return YES;
}

/**
 
 */
- (id) lastObject
{
    NSUInteger count = [self count];
    if (count == 0)
        return nil;
    return [self objectAtIndex: count-1];
}

/**
 * Returns the first object in the receiver, or nil if the receiver is empty.
 */
- (id) firstObject
{
    NSUInteger count = [self count];
    if (count == 0)
        return nil;
    return [self objectAtIndex: 0];
}

/**
 每一个元素执行 selector.
 */
- (void) makeObjectsPerformSelector: (SEL)aSelector
{
    NSUInteger	c = [self count];
    
    if (c > 0)
    {
        IMP	        get = [self methodForSelector: objAtIndexSel];
        NSUInteger	i = 0;
        
        while (i < c)
        {
            [(*get)(self, objAtIndexSel, i++) performSelector: aSelector];
        }
    }
}

/**
 这个方法, 不如上面的方法清晰, 所以被废除了.
 */
- (void) makeObjectsPerform: (SEL)aSelector
{
    [self makeObjectsPerformSelector: aSelector];
}

/**
 也仅仅是一个简单的包装而已.
 */
- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)arg
{
    NSUInteger    c = [self count];
    
    if (c > 0)
    {
        IMP	        get = [self methodForSelector: objAtIndexSel];
        NSUInteger	i = 0;
        
        while (i < c)
        {
            [(*get)(self, objAtIndexSel, i++) performSelector: aSelector
                                            withObject: arg];
        }
    }
}

/**
 * Obsolete version of -makeObjectsPerformSelector:withObject:
 */
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)argument
{
    [self makeObjectsPerformSelector: aSelector withObject: argument];
}

static NSComparisonResult
compare(id elem1, id elem2, void* context)
{
    NSComparisonResult (*imp)(id, SEL, id);
    
    if (context == 0)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"compare null selector given"];
    }
    
    imp = (NSComparisonResult (*)(id, SEL, id))
    [elem1 methodForSelector: context];
    
    if (imp == NULL)
    {
        [NSException raise: NSGenericException
                    format: @"invalid selector passed to compare"];
    }
    
    return (*imp)(elem1, context, elem2);
}

/**
 * Returns an autoreleased array in which the objects are ordered
 * according to a sort with comparator.
 */
- (NSArray*) sortedArrayUsingSelector: (SEL)comparator
{
    return [self sortedArrayUsingFunction: compare context: (void *)comparator];
}

/**
 * Returns an autoreleased array in which the objects are ordered
 * according to a sort with comparator.  This invokes
 * -sortedArrayUsingFunction:context:hint: with a nil hint.
 */
- (NSArray*) sortedArrayUsingFunction:
(NSComparisonResult(*)(id,id,void*))comparator
                              context: (void*)context
{
    return [self sortedArrayUsingFunction: comparator context: context hint: nil];
}

/**
 * Subclasses may provide a hint for sorting ...  The default GNUstep
 * implementation just returns nil.
 */
- (NSData*) sortedArrayHint
{
    return nil;
}

/**
 * Returns an autoreleased array in which the objects are ordered
 * according to a sort with comparator, where the comparator function
 * is passed two objects to compare, and the context as the third
 * argument.  The hint argument is currently ignored, and may be nil.
 */
- (NSArray*) sortedArrayUsingFunction:
(NSComparisonResult(*)(id,id,void*))comparator
                              context: (void*)context
                                 hint: (NSData*)hint
{
    NSMutableArray	*sortedArray;
    
    sortedArray = AUTORELEASE([[NSMutableArrayClass allocWithZone:
                                NSDefaultMallocZone()] initWithArray: self copyItems: NO]);
    [sortedArray sortUsingFunction: comparator context: context];
    
    return GS_IMMUTABLE(sortedArray);
}


- (NSArray*) sortedArrayWithOptions: (NSSortOptions)options
                    usingComparator: (NSComparator)comparator
{
    NSMutableArray	*sortedArray;
    
    sortedArray = AUTORELEASE([[NSMutableArrayClass allocWithZone:
                                NSDefaultMallocZone()] initWithArray: self copyItems: NO]);
    [sortedArray sortWithOptions: options usingComparator: comparator];
    
    return GS_IMMUTABLE(sortedArray);
}

- (NSArray*) sortedArrayUsingComparator: (NSComparator)comparator
{
    return [self sortedArrayWithOptions: 0 usingComparator: comparator];
}

- (NSUInteger) indexOfObject: (id)key
               inSortedRange: (NSRange)range
                     options: (NSBinarySearchingOptions)options
             usingComparator: (NSComparator)comparator
{
    if (range.length == 0)
    {
        return options & NSBinarySearchingInsertionIndex
        ? range.location : NSNotFound;
    }
    if (range.length == 1)
    {
        switch (CALL_BLOCK(comparator, key, [self objectAtIndex: range.location]))
        {
            case NSOrderedSame:
                return range.location;
            case NSOrderedAscending:
                return options & NSBinarySearchingInsertionIndex
                ? range.location : NSNotFound;
            case NSOrderedDescending:
                return options & NSBinarySearchingInsertionIndex
                ? (range.location + 1) : NSNotFound;
            default:
                // Shouldn't happen
                return NSNotFound;
        }
    }
    else
    {
        NSUInteger index = NSNotFound;
        NSUInteger count = [self count];
        GS_BEGINIDBUF(objects, count);
        
        [self getObjects: objects];
        // We use the timsort galloping to find the insertion index:
        if (options & NSBinarySearchingLastEqual)
        {
            index = GSRightInsertionPointForKeyInSortedRange(key,
                                                             objects, range, comparator);
        }
        else
        {
            // Left insertion is our default
            index = GSLeftInsertionPointForKeyInSortedRange(key,
                                                            objects, range, comparator);
        }
        GS_ENDIDBUF()
        
        // If we were looking for the insertion point, we are done here
        if (options & NSBinarySearchingInsertionIndex)
        {
            return index;
        }
        
        /* Otherwise, we need need another equality check in order to
         * know whether we need return NSNotFound.
         */
        
        if (options & NSBinarySearchingLastEqual)
        {
            /* For search from the right, the equal object would be
             * the one before the index, but only if it's not at the
             * very beginning of the range (though that might not
             * actually be possible, it's better to check nonetheless).
             */
            if (index > range.location)
            {
                index--;
            }
        }
        if (index >= NSMaxRange(range))
        {
            return NSNotFound;
        }
        /*
         * For a search from the left, we'd have the correct index anyways. Check
         * whether it's equal to the key and return NSNotFound otherwise
         */
        return (NSOrderedSame == CALL_BLOCK(comparator,
                                            key, [self objectAtIndex: index]) ? index : NSNotFound);
    }
    // Never reached
    return NSNotFound;
}


/**
 * Returns a string formed by concatenating the objects in the receiver,
 * with the specified separator string inserted between each part.
 */
- (NSString*) componentsJoinedByString: (NSString*)separator
{
    NSUInteger		c = [self count];
    NSMutableString	*s;
    
    s = [NSMutableString stringWithCapacity: c];
    if (c > 0)
    {
        NSUInteger	l = [separator length];
        NSUInteger	i;
        
        [s appendString: [[self objectAtIndex: 0] description]];
        for (i = 1; i < c; i++)
        {
            if (l > 0)
            {
                [s appendString: separator];
            }
            [s appendString: [[self objectAtIndex: i] description]];
        }
    }
    return GS_IMMUTABLE(s);
}

/**
 * Assumes that the receiver is an array of paths, and returns an
 * array formed by selecting the subset of those patch matching
 * the specified array of extensions.
 */
- (NSArray*) pathsMatchingExtensions: (NSArray*)extensions
{
    NSUInteger i, c = [self count];
    NSMutableArray *a = AUTORELEASE([[NSMutableArray alloc] initWithCapacity: 1]);
    Class	cls = [NSString class];
    IMP	get = [self methodForSelector: objAtIndexSel];
    IMP	add = [a methodForSelector: addObjectSel];
    
    for (i = 0; i < c; i++)
    {
        id o = (*get)(self, objAtIndexSel, i);
        
        if ([o isKindOfClass: cls])
        {
            if ([extensions containsObject: [o pathExtension]])
            {
                (*add)(a, addObjectSel, o);
            }
        }
    }
    return GS_IMMUTABLE(a);
}

/**
 * Returns the first object found in the receiver (starting at index 0)
 * which is present in the otherArray as determined by using the
 * -containsObject: method.
 */
- (id) firstObjectCommonWithArray: (NSArray*)otherArray
{
    NSUInteger i, c = [self count];
    id o;
    
    for (i = 0; i < c; i++)
    {
        if ([otherArray containsObject: (o = [self objectAtIndex: i])])
        {
            return o;
        }
    }
    return nil;
}

/**
 * Returns a subarray of the receiver containing the objects found in
 * the specified range aRange.
 */
- (NSArray*) subarrayWithRange: (NSRange)aRange
{
    id na;
    NSUInteger c = [self count];
    
    GS_RANGE_CHECK(aRange, c);
    
    if (aRange.length == 0)
    {
        na = [NSArray array];
    }
    else
    {
        GS_BEGINIDBUF(objects, aRange.length);
        
        [self getObjects: objects range: aRange];
        na = [NSArray arrayWithObjects: objects count: aRange.length];
        GS_ENDIDBUF();
    }
    return na;
}

/**
 * Returns an enumerator describing the array sequentially
 * from the first to the last element.<br/>
 * If you use a mutable subclass of NSArray,
 * you should not modify the array during enumeration.
 */
- (NSEnumerator*) objectEnumerator
{
    id	e;
    
    e = [NSArrayEnumerator allocWithZone: NSDefaultMallocZone()];
    e = [e initWithArray: self];
    return AUTORELEASE(e);
}

/**
 * Returns an enumerator describing the array sequentially
 * from the last to the first element.<br/>
 * If you use a mutable subclass of NSArray,
 * you should not modify the array during enumeration.
 */
- (NSEnumerator*) reverseObjectEnumerator
{
    id	e;
    
    e = [NSArrayEnumeratorReverse allocWithZone: NSDefaultMallocZone()];
    e = [e initWithArray: self];
    return AUTORELEASE(e);
}

/**
 * Returns the result of invoking -descriptionWithLocale:indent: with a nil
 * locale and zero indent.
 */
- (NSString*) description
{
    return [self descriptionWithLocale: nil];
}

/**
 * Returns the result of invoking -descriptionWithLocale:indent:
 * with a zero indent.
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
 * The items in the property list string appear in the same order as
 * they appear in the receiver.
 */
- (NSString*) descriptionWithLocale: (id)locale
                             indent: (NSUInteger)level
{
    NSString	*result = nil;
    
    GSPropertyListMake(self, locale, NO, YES, level == 1 ? 3 : 2, &result);
    
    return result;
}

/**
 * <p>Writes the contents of the array to the file specified by path.
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
 * necessarily mean that it can be used to reconstruct the array using
 * the -initWithContentsOfFile: method.  If the original array contains
 * non-property-list objects, the descriptions of those objects will
 * have been written, and reading in the file as a property-list will
 * result in a new array containing the string descriptions.
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
 * <p>Writes the contents of the array to the specified url.
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
 * This overrides NSObjects implementation of this method.
 * This method returns an array of objects returned by
 * invoking -valueForKey: for each item in the receiver,
 * substituting NSNull for nil.
 * A special case: the key "count" is not forwarded to each object
 * of the receiver but returns the number of objects of the receiver.<br/>
 */
- (id) valueForKey: (NSString*)key
{
    id result = nil;
    
    if ([key isEqualToString: @"@count"] == YES)
    {
        result = [NSNumber numberWithUnsignedInteger: [self count]];
    }
    else if ([key isEqualToString: @"count"] == YES)
    {
        GSOnceMLog(
                   @"[NSArray-valueForKey:] called with 'count' is deprecated .. use '@count'");
        result = [NSNumber numberWithUnsignedInteger: [self count]];
    }
    else
    {
        NSMutableArray	*results = nil;
        static NSNull	*null = nil;
        NSUInteger	i;
        NSUInteger	count = [self count];
        volatile id	object = nil;
        
        results = [NSMutableArray arrayWithCapacity: count];
        
        for (i = 0; i < count; i++)
        {
            id	result;
            
            object = [self objectAtIndex: i];
            result = [object valueForKey: key];
            if (result == nil)
            {
                if (null == nil)
                {
                    null = RETAIN([NSNull null]);
                }
                result = null;
            }
            
            [results addObject: result];
        }
        
        result = results;
    }
    return result;
}

- (id) valueForKeyPath: (NSString*)path
{
    id	result = nil;
    
    if ([path hasPrefix: @"@"])
    {
        NSRange   r;
        
        r = [path rangeOfString: @"."];
        if (r.length == 0)
        {
            if ([path isEqualToString: @"@count"] == YES)
            {
                result = [NSNumber numberWithUnsignedInteger: [self count]];
            }
            else
            {
                result = [self valueForKey: path];
            }
        }
        else
        {
            NSString      *op = [path substringToIndex: r.location];
            NSString      *rem = [path substringFromIndex: NSMaxRange(r)];
            NSUInteger    count = [self count];
            
            if ([op isEqualToString: @"@count"] == YES)
            {
                result = [NSNumber numberWithUnsignedInteger: count];
            }
            else if ([op isEqualToString: @"@avg"] == YES)
            {
                double        d = 0;
                
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    while ((o = [e nextObject]) != nil)
                    {
                        d += [[o valueForKeyPath: rem] doubleValue];
                    }
                    d /= count;
                }
                result = [NSNumber numberWithDouble: d];
            }
            else if ([op isEqualToString: @"@max"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        if (result == nil
                            || [result compare: o] == NSOrderedAscending)
                        {
                            result = o;
                        }
                    }
                }
            }
            else if ([op isEqualToString: @"@min"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        if (result == nil
                            || [result compare: o] == NSOrderedDescending)
                        {
                            result = o;
                        }
                    }
                }
            }
            else if ([op isEqualToString: @"@sum"] == YES)
            {
                double        d = 0;
                
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    while ((o = [e nextObject]) != nil)
                    {
                        d += [[o valueForKeyPath: rem] doubleValue];
                    }
                }
                result = [NSNumber numberWithDouble: d];
            }
            else if ([op isEqualToString: @"@distinctUnionOfArrays"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    result = [NSMutableSet set];
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        [result addObjectsFromArray: o];
                    }
                    result = [result allObjects];
                }
                else
                {
                    result = [NSArray array];
                }
            }
            else if ([op isEqualToString: @"@distinctUnionOfObjects"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    result = [NSMutableSet set];
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        [result addObject: o];
                    }
                    result = [result allObjects];
                }
                else
                {
                    result = [NSArray array];
                }
            }
            else if ([op isEqualToString: @"@distinctUnionOfSets"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    result = [NSMutableSet set];
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        [result addObjectsFromArray: [o allObjects]];
                    }
                    result = [result allObjects];
                }
                else
                {
                    result = [NSArray array];
                }
            }
            else if ([op isEqualToString: @"@unionOfArrays"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    result = [GSMutableArray array];
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        [result addObjectsFromArray: o];
                    }
                    result = GS_IMMUTABLE(result);
                }
                else
                {
                    result = [NSArray array];
                }
            }
            else if ([op isEqualToString: @"@unionOfObjects"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    result = [GSMutableArray array];
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        [result addObject: o];
                    }
                    result = GS_IMMUTABLE(result);
                }
                else
                {
                    result = [NSArray array];
                }
            }
            else if ([op isEqualToString: @"@unionOfSets"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    result = [GSMutableArray array];
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: rem];
                        [result addObjectsFromArray: [o allObjects]];
                    }
                    result = GS_IMMUTABLE(result);
                }
                else
                {
                    result = [NSArray array];
                }
            }
            else
            {
                result = [super valueForKeyPath: path];
            }
        }
    }
    else
    {
        result = [super valueForKeyPath: path];
    }
    
    return result;
}

/**
 * Call setValue:forKey: on each of the receiver's items
 * with the value and key.
 */
- (void) setValue: (id)value forKey: (NSString*)key
{
    NSUInteger    i;
    NSUInteger	count = [self count];
    volatile id	object = nil;
    
    for (i = 0; i < count; i++)
    {
        object = [self objectAtIndex: i];
        [object setValue: value
                  forKey: key];
    }
}

- (void) enumerateObjectsUsingBlock: (GSEnumeratorBlock)aBlock
{
    [self enumerateObjectsWithOptions: 0 usingBlock: aBlock];
}

- (void) enumerateObjectsWithOptions: (NSEnumerationOptions)opts
                          usingBlock: (GSEnumeratorBlock)aBlock
{
    NSUInteger count = 0;
    BLOCK_SCOPE BOOL shouldStop = NO;
    BOOL isReverse = (opts & NSEnumerationReverse);
    id<NSFastEnumeration> enumerator = self;
    
    /* If we are enumerating in reverse, use the reverse enumerator for fast
     * enumeration. */
    if (isReverse)
    {
        enumerator = [self reverseObjectEnumerator];
        count = ([self count] - 1);
    }
    
    {
        GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
        FOR_IN (id, obj, enumerator)
        GS_DISPATCH_SUBMIT_BLOCK(enumQueueGroup, enumQueue, if (YES == shouldStop) {return;}, return, aBlock, obj, count, &shouldStop);
        if (isReverse)
        {
            count--;
        }
        else
        {
            count++;
        }
        
        if (shouldStop)
        {
            break;
        }
        END_FOR_IN(enumerator)
        GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    }
}

- (void) enumerateObjectsAtIndexes: (NSIndexSet*)indexSet
                           options: (NSEnumerationOptions)opts
                        usingBlock: (GSEnumeratorBlock)block
{
    [[self objectsAtIndexes: indexSet] enumerateObjectsWithOptions: opts
                                                        usingBlock: block];
}

- (NSIndexSet *) indexesOfObjectsWithOptions: (NSEnumerationOptions)opts
                                 passingTest: (GSPredicateBlock)predicate
{
    /* TODO: Concurrency. */
    NSMutableIndexSet     *set = [NSMutableIndexSet indexSet];
    BLOCK_SCOPE BOOL      shouldStop = NO;
    id<NSFastEnumeration> enumerator = self;
    NSUInteger            count = 0;
    BLOCK_SCOPE NSLock    *setLock = nil;
    
    /* If we are enumerating in reverse, use the reverse enumerator for fast
     * enumeration. */
    if (opts & NSEnumerationReverse)
    {
        enumerator = [self reverseObjectEnumerator];
    }
    if (opts & NSEnumerationConcurrent)
    {
        setLock = [NSLock new];
    }
    {
        GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
        FOR_IN (id, obj, enumerator)
#     if __has_feature(blocks) && (GS_USE_LIBDISPATCH == 1)
        
        dispatch_group_async(enumQueueGroup, enumQueue, ^(void){
            if (shouldStop)
            {
                return;
            }
            if (predicate(obj, count, &shouldStop))
            {
                [setLock lock];
                [set addIndex: count];
                [setLock unlock];
            }
        });
#     else
        if (CALL_BLOCK(predicate, obj, count, &shouldStop))
        {
            /* TODO: It would be more efficient to collect an NSRange and only
             * pass it to the index set when CALL_BLOCK returned NO. */
            [set addIndex: count];
        }
#     endif
        if (shouldStop)
        {
            break;
        }
        count++;
        END_FOR_IN(enumerator)
        GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts);
    }
    RELEASE(setLock);
    return set;
}

- (NSIndexSet*) indexesOfObjectsPassingTest: (GSPredicateBlock)predicate
{
    return [self indexesOfObjectsWithOptions: 0 passingTest: predicate];
}

- (NSIndexSet*) indexesOfObjectsAtIndexes: (NSIndexSet*)indexSet
                                  options: (NSEnumerationOptions)opts
                              passingTest: (GSPredicateBlock)predicate
{
    return [[self objectsAtIndexes: indexSet]
            indexesOfObjectsWithOptions: opts
            passingTest: predicate];
}

- (NSUInteger) indexOfObjectWithOptions: (NSEnumerationOptions)opts
                            passingTest: (GSPredicateBlock)predicate
{
    /* TODO: Concurrency. */
    id<NSFastEnumeration> enumerator = self;
    BLOCK_SCOPE BOOL      shouldStop = NO;
    NSUInteger            count = 0;
    BLOCK_SCOPE NSUInteger index = NSNotFound;
    BLOCK_SCOPE NSLock    *indexLock = nil;
    
    /* If we are enumerating in reverse, use the reverse enumerator for fast
     * enumeration. */
    if (opts & NSEnumerationReverse)
    {
        enumerator = [self reverseObjectEnumerator];
    }
    
    if (opts & NSEnumerationConcurrent)
    {
        indexLock = [NSLock new];
    }
    {
        GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
        FOR_IN (id, obj, enumerator)
#     if __has_feature(blocks) && (GS_USE_LIBDISPATCH == 1)
        dispatch_group_async(enumQueueGroup, enumQueue, ^(void){
            if (shouldStop)
            {
                return;
            }
            if (predicate(obj, count, &shouldStop))
            {
                // FIXME: atomic operation on the shouldStop variable would be nicer,
                // but we don't expose the GSAtomic* primitives anywhere.
                [indexLock lock];
                index =  count;
                // Cancel all other predicate evaluations:
                shouldStop = YES;
                [indexLock unlock];
            }
        });
#     else
        if (CALL_BLOCK(predicate, obj, count, &shouldStop))
        {
            
            index = count;
            shouldStop = YES;
        }
#     endif
        if (shouldStop)
        {
            break;
        }
        count++;
        END_FOR_IN(enumerator)
        GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts);
    }
    RELEASE(indexLock);
    return index;
}

- (NSUInteger) indexOfObjectPassingTest: (GSPredicateBlock)predicate
{
    return [self indexOfObjectWithOptions: 0 passingTest: predicate];
}

- (NSUInteger) indexOfObjectAtIndexes: (NSIndexSet*)indexSet
                              options: (NSEnumerationOptions)opts
                          passingTest: (GSPredicateBlock)predicate
{
    return [[self objectsAtIndexes: indexSet]
            indexOfObjectWithOptions: 0
            passingTest: predicate];
}

- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
    NSUInteger	size = [super sizeInBytesExcluding: exclude];
    
    if (size > 0)
    {
        NSUInteger	count = [self count];
        GS_BEGINIDBUF(objects, count);
        
        size += count*sizeof(void*);
        [self getObjects: objects];
        while (count-- > 0)
        {
            size += [objects[count] sizeInBytesExcluding: exclude];
        }
        GS_ENDIDBUF();
    }
    return size;
}
@end


/**
 *  <code>NSMutableArray</code> is the mutable version of [NSArray].  It
 *  provides methods for altering the contents of the array.
 */
@implementation NSMutableArray

+ (void) initialize
{
    if (self == [NSMutableArray class])
    {
    }
}

+ (id) allocWithZone: (NSZone*)z
{
    if (self == NSMutableArrayClass)
    {
        return NSAllocateObject(GSMutableArrayClass, 0, z);
    }
    else
    {
        return NSAllocateObject(self, 0, z);
    }
}

+ (id) arrayWithObject: (id)anObject
{
    NSMutableArray	*obj = [self allocWithZone: NSDefaultMallocZone()];
    
    obj = [obj initWithObjects: &anObject count: 1];
    return AUTORELEASE(obj);
}

- (Class) classForCoder
{
    return NSMutableArrayClass;
}

- (id) initWithCapacity: (NSUInteger)numItems
{
    self = [self init];
    return self;
}

- (void) addObject: (id)anObject
{
    [self subclassResponsibility: _cmd];
}

/**
 * Swaps the positions of two objects in the array.  Raises an exception
 * if either array index is out of bounds.
 */
- (void) exchangeObjectAtIndex: (NSUInteger)i1
             withObjectAtIndex: (NSUInteger)i2
{
    id	tmp = [self objectAtIndex: i1];
    
    RETAIN(tmp);
    [self replaceObjectAtIndex: i1 withObject: [self objectAtIndex: i2]];
    [self replaceObjectAtIndex: i2 withObject: tmp];
    RELEASE(tmp);
}

- (void) replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
    [self subclassResponsibility: _cmd];
}

- (void) setObject: (id)anObject atIndexedSubscript: (NSUInteger)anIndex
{
    if ([self count] == anIndex)
    {
        [self addObject: anObject];
    }
    else
    {
        [self replaceObjectAtIndex: anIndex withObject: anObject];
    }
}

/** Replaces the values in the receiver at the locations given by the
 * indexes set with values from the objects array.
 */
- (void) replaceObjectsAtIndexes: (NSIndexSet *)indexes
                     withObjects: (NSArray *)objects
{
    NSUInteger	index = [indexes firstIndex];
    NSEnumerator	*enumerator = [objects objectEnumerator];
    id		object = [enumerator nextObject];
    
    while (object != nil && index != NSNotFound)
    {
        [self replaceObjectAtIndex: index withObject: object];
        object = [enumerator nextObject];
        index = [indexes indexGreaterThanIndex: index];
    }
}

/**
 * Replaces objects in the receiver with those from anArray.<br />
 * Raises an exception if given a range extending beyond the array.<br />
 */
- (void) replaceObjectsInRange: (NSRange)aRange
          withObjectsFromArray: (NSArray*)anArray
{
    id e, o;
    
    if ([self count] < (aRange.location + aRange.length))
        [NSException raise: NSRangeException
                    format: @"Replacing objects beyond end of array."];
    [self removeObjectsInRange: aRange];
    e = [anArray reverseObjectEnumerator];
    while ((o = [e nextObject]))
        [self insertObject: o atIndex: aRange.location];
}

/**
 * Replaces objects in the receiver with some of those from anArray.<br />
 * Raises an exception if given a range extending beyond the array.<br />
 */
- (void) replaceObjectsInRange: (NSRange)aRange
          withObjectsFromArray: (NSArray*)anArray
                         range: (NSRange)anotherRange
{
    [self replaceObjectsInRange: aRange
           withObjectsFromArray: [anArray subarrayWithRange: anotherRange]];
}

- (void) insertObject: anObject atIndex: (NSUInteger)index
{
    [self subclassResponsibility: _cmd];
}

/** Inserts the values from the objects array into the receiver at the
 * locations given by the indexes set.<br />
 * The values are inserted in the same order that they appear in the
 * array.
 */
- (void) insertObjects: (NSArray *)objects atIndexes: (NSIndexSet *)indexes
{
    NSUInteger	index = [indexes firstIndex];
    NSEnumerator	*enumerator = [objects objectEnumerator];
    id		object = [enumerator nextObject];
    
    while (object != nil && index != NSNotFound)
    {
        [self insertObject: object atIndex: index];
        object = [enumerator nextObject];
        index = [indexes indexGreaterThanIndex: index];
    }
}

- (void) removeObjectAtIndex: (NSUInteger)index
{
    [self subclassResponsibility: _cmd];
}

/**
 * Creates an autoreleased mutable array able to store at least numItems.
 * See the -initWithCapacity: method.
 */
+ (id) arrayWithCapacity: (NSUInteger)numItems
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithCapacity: numItems]);
}

/**
 * Override our superclass's designated initializer to go our's
 */
- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    self = [self initWithCapacity: count];
    if (count > 0)
    {
        NSUInteger	i;
        IMP	add = [self methodForSelector: addObjectSel];
        
        for (i = 0; i < count; i++)
            (*add)(self, addObjectSel, objects[i]);
    }
    return self;
}

/**
 * Removes the last object in the array.  Raises an exception if the array
 * is already empty.
 */
- (void) removeLastObject
{
    NSUInteger	count = [self count];
    
    if (count == 0)
        [NSException raise: NSRangeException
                    format: @"Trying to remove from an empty array."];
    [self removeObjectAtIndex: count-1];
}

/**
 * Removes all occurrences of anObject (found by pointer equality)
 * from the receiver.
 */
- (void) removeObjectIdenticalTo: (id)anObject
{
    NSUInteger	i;
    
    if (anObject == nil)
    {
        NSWarnMLog(@"attempt to remove nil object");
        return;
    }
    i = [self count];
    if (i > 0)
    {
        IMP	rem = 0;
        IMP	get = [self methodForSelector: objAtIndexSel];
        
        while (i-- > 0)
        {
            id	o = (*get)(self, objAtIndexSel, i);
            
            if (o == anObject)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: removeObjAtIndexSel];
                }
                (*rem)(self, removeObjAtIndexSel, i);
            }
        }
    }
}

/**
 * Removes all occurrences of anObject (found by the [NSObject-isEqual:] method
 * of anObject) aRange in the receiver.
 */
- (void) removeObject: (id)anObject inRange: (NSRange)aRange
{
    NSUInteger	c;
    NSUInteger	s;
    NSUInteger	i;
    
    if (anObject == nil)
    {
        NSWarnMLog(@"attempt to remove nil object");
        return;
    }
    c = [self count];
    s = aRange.location;
    i = aRange.location + aRange.length;
    if (i > c)
    {
        i = c;
    }
    if (i > s)
    {
        IMP	rem = 0;
        IMP	get = [self methodForSelector: objAtIndexSel];
        BOOL	(*eq)(id, SEL, id)
        = (BOOL (*)(id, SEL, id))[anObject methodForSelector: isEqualSel];
        
        while (i-- > s)
        {
            id	o = (*get)(self, objAtIndexSel, i);
            
            if (o == anObject || (*eq)(anObject, isEqualSel, o) == YES)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: removeObjAtIndexSel];
                    /*
                     * We need to retain the object so that when we remove the
                     * first equal object we don't get left with a bad object
                     * pointer for later comparisons.
                     */
                    RETAIN(anObject);
                }
                (*rem)(self, removeObjAtIndexSel, i);
            }
        }
        if (rem != 0)
        {
            RELEASE(anObject);
        }
    }
}

/**
 * Removes all occurrences of anObject (found by pointer equality)
 * from aRange in the receiver.
 */
- (void) removeObjectIdenticalTo: (id)anObject inRange: (NSRange)aRange
{
    NSUInteger	c;
    NSUInteger	s;
    NSUInteger	i;
    
    if (anObject == nil)
    {
        NSWarnMLog(@"attempt to remove nil object");
        return;
    }
    c = [self count];
    s = aRange.location;
    i = aRange.location + aRange.length;
    if (i > c)
    {
        i = c;
    }
    if (i > s)
    {
        IMP	rem = 0;
        IMP	get = [self methodForSelector: objAtIndexSel];
        
        while (i-- > s)
        {
            id	o = (*get)(self, objAtIndexSel, i);
            
            if (o == anObject)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: removeObjAtIndexSel];
                }
                (*rem)(self, removeObjAtIndexSel, i);
            }
        }
    }
}

/**
 * Removes all occurrences of anObject (found by anObject's
 * [NSObject-isEqual:] method) from the receiver.
 */
- (void) removeObject: (id)anObject
{
    NSUInteger	i;
    
    if (anObject == nil)
    {
        NSWarnMLog(@"attempt to remove nil object");
        return;
    }
    i = [self count];
    if (i > 0)
    {
        IMP	rem = 0;
        IMP	get = [self methodForSelector: objAtIndexSel];
        BOOL	(*eq)(id, SEL, id)
        = (BOOL (*)(id, SEL, id))[anObject methodForSelector: isEqualSel];
        
        while (i-- > 0)
        {
            id	o = (*get)(self, objAtIndexSel, i);
            
            if (o == anObject || (*eq)(anObject, isEqualSel, o) == YES)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: removeObjAtIndexSel];
                    /*
                     * We need to retain the object so that when we remove the
                     * first equal object we don't get left with a bad object
                     * pointer for later comparisons.
                     */
                    RETAIN(anObject);
                }
                (*rem)(self, removeObjAtIndexSel, i);
            }
        }
        if (rem != 0)
        {
            RELEASE(anObject);
        }
    }
}

/**
 * Removes all objects from the receiver, leaving an empty array.
 */
- (void) removeAllObjects
{
    NSUInteger	c = [self count];
    
    if (c > 0)
    {
        IMP	remLast = [self methodForSelector: removeLastSel];
        
        while (c--)
        {
            (*remLast)(self, removeLastSel);
        }
    }
}

/**
 * Adds each object from otherArray to the receiver, in first to last order.
 */
- (void) addObjectsFromArray: (NSArray*)otherArray
{
    NSUInteger c = [otherArray count];
    
    if (c > 0)
    {
        NSUInteger	i;
        IMP	get = [otherArray methodForSelector: objAtIndexSel];
        IMP	add = [self methodForSelector: addObjectSel];
        
        for (i = 0; i < c; i++)
            (*add)(self, addObjectSel,  (*get)(otherArray, objAtIndexSel, i));
    }
}

/**
 * Sets the contents of the receiver to be identical to the contents
 * of otherArray.
 */
- (void) setArray: (NSArray *)otherArray
{
    [self removeAllObjects];
    [self addObjectsFromArray: otherArray];
}

/**
 * Removes objects from the receiver at the indices supplied by an NSIndexSet
 */
- (void) removeObjectsAtIndexes: (NSIndexSet *)indexes
{
    NSUInteger count = [indexes count];
    NSUInteger indexArray[count];
    
    [indexes getIndexes: indexArray
               maxCount: count
           inIndexRange: NULL];
    
    [self removeObjectsFromIndices: indexArray
                        numIndices: count];
}

/**
 * Supplied with a C array of indices containing count values, this method
 * removes all corresponding objects from the receiver.  The objects are
 * removed in such a way that the removal is <em>safe</em> irrespective
 * of the order in which they are specified in the indices array.
 */
- (void) removeObjectsFromIndices: (NSUInteger*)indices
                       numIndices: (NSUInteger)count
{
    if (count > 0)
    {
        NSUInteger	to = 0;
        NSUInteger	from = 0;
        NSUInteger	i;
        GS_BEGINITEMBUF(sorted, count, NSUInteger);
        
        while (from < count)
        {
            NSUInteger	val = indices[from++];
            
            i = to;
            while (i > 0 && sorted[i-1] > val)
            {
                i--;
            }
            if (i == to)
            {
                sorted[to++] = val;
            }
            else if (sorted[i] != val)
            {
                NSUInteger	j = to++;
                
                if (sorted[i] < val)
                {
                    i++;
                }
                while (j > i)
                {
                    sorted[j] = sorted[j-1];
                    j--;
                }
                sorted[i] = val;
            }
        }
        
        if (to > 0)
        {
            IMP	rem = [self methodForSelector: removeObjAtIndexSel];
            
            while (to--)
            {
                (*rem)(self, removeObjAtIndexSel, sorted[to]);
            }
        }
        GS_ENDITEMBUF();
    }
}

/**
 * Removes from the receiver, all the objects present in otherArray,
 * as determined by using the [NSObject-isEqual:] method.
 */
- (void) removeObjectsInArray: (NSArray*)otherArray
{
    NSUInteger	c = [otherArray count];
    
    if (c > 0)
    {
        NSUInteger	i;
        IMP	get = [otherArray methodForSelector: objAtIndexSel];
        IMP	rem = [self methodForSelector: @selector(removeObject:)];
        
        for (i = 0; i < c; i++)
            (*rem)(self, @selector(removeObject:), (*get)(otherArray, objAtIndexSel, i));
    }
}

/**
 * Removes all the objects in aRange from the receiver.
 */
- (void) removeObjectsInRange: (NSRange)aRange
{
    NSUInteger	i;
    NSUInteger	s = aRange.location;
    NSUInteger	c = [self count];
    
    i = aRange.location + aRange.length;
    
    if (c < i)
        i = c;
    
    if (i > s)
    {
        IMP	rem = [self methodForSelector: removeObjAtIndexSel];
        
        while (i-- > s)
        {
            (*rem)(self, removeObjAtIndexSel, i);
        }
    }
}

/**
 * Sorts the array according to the supplied comparator.
 */
- (void) sortUsingSelector: (SEL)comparator
{
    [self sortUsingFunction: compare context: (void *)comparator];
}

/**
 
 void* 就是任何类型, 在 C 时代的时候, 为了传递环境, 经常用 void * 进行传递. 这在有了闭包之后 ,有了很好的改善.
 sort 最终会调用到基础的 快排等算法. 这些算法是固定下来的. 而各个类, 仅仅是对于这个算法调用的包装而已.
 */
- (void) sortUsingFunction: (NSComparisonResult (*)(id,id,void*))compare
                   context: (void*)context
{
    NSUInteger count = [self count];
    
    if ((1 < count) && (NULL != compare))
    {
        NSArray *res = nil;
        GS_BEGINIDBUF(objects, count);
        [self getObjects: objects];
        
        GSSortUnstable(objects,
                       NSMakeRange(0,count), (id)compare, GSComparisonTypeFunction, context);
        
        res = [[NSArray alloc] initWithObjects: objects count: count];
        [self setArray: res];
        RELEASE(res);
        GS_ENDIDBUF();
    }
}

- (void) sortWithOptions: (NSSortOptions)options
         usingComparator: (NSComparator)comparator
{
    NSUInteger count = [self count];
    
    if ((1 < count) && (NULL != comparator))
    {
        NSArray *res = nil;
        GS_BEGINIDBUF(objects, count);
        [self getObjects: objects];
        
        if (options & NSSortStable)
        {
            if (options & NSSortConcurrent)
            {
                GSSortStableConcurrent(objects, NSMakeRange(0,count),
                                       (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
            else
            {
                GSSortStable(objects, NSMakeRange(0,count),
                             (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
        }
        else
        {
            if (options & NSSortConcurrent)
            {
                GSSortUnstableConcurrent(objects, NSMakeRange(0,count),
                                         (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
            else
            {
                GSSortUnstable(objects, NSMakeRange(0,count),
                               (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
        }
        res = [[NSArray alloc] initWithObjects: objects count: count];
        [self setArray: res];
        RELEASE(res);
        GS_ENDIDBUF();
    }
}

- (void) sortUsingComparator: (NSComparator)comparator
{
    [self sortWithOptions: 0 usingComparator: comparator];
}
@end

/**
 NSArrayEnumerator 仅仅是一个包装类, 它和容器类一定是联系非常紧密的. 他可以获取到容器里面的数据, 然后将这些数据暴露给使用者. 它更多的是一个协议的概念, 让使用者可以稳定的用一个接口来进行.
 在其他语言里面, 已经用这个接口做循环的替换了.
 */

@implementation NSArrayEnumerator

- (id) initWithArray: (NSArray*)anArray
{
    self = [super init];
    if (self != nil)
    {
        array = anArray;
        IF_NO_GC(RETAIN(array));
        pos = 0;
        get = [array methodForSelector: objAtIndexSel];
        cnt = (NSUInteger (*)(NSArray*, SEL))[array methodForSelector: countSel];
    }
    return self;
}

/**
 * Returns the next object in the enumeration or nil if there are no more
 * objects.<br />
 * NB. modifying a mutable array during an enumeration can break things ...
 * don't do it.
 */
- (id) nextObject
{
    if (pos >= (*cnt)(array, countSel))
        return nil;
    return (*get)(array, objAtIndexSel, pos++);
}

- (void) dealloc
{
    RELEASE(array);
    [super dealloc];
}

@end

@implementation NSArrayEnumeratorReverse

- (id) initWithArray: (NSArray*)anArray
{
    self = [super initWithArray: anArray];
    if (self != nil)
    {
        pos = (*cnt)(array, countSel);
    }
    return self;
}

/**
 * Returns the next object in the enumeration or nil if there are no more
 * objects.<br />
 * NB. modifying a mutable array during an enumeration can break things ...
 * don't do it.
 */
- (id) nextObject
{
    if (pos == 0)
        return nil;
    return (*get)(array, objAtIndexSel, --pos);
}
@end

