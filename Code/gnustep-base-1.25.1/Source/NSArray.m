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
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "GSFastEnumeration.h"
#import "GSDispatch.h"
#import "GSSorting.h"

/*
 id objects[] = { someObject, @"Hello, World!", @42 };
 NSUInteger count = sizeof(objects) / sizeof(id);
 NSArray *array = [NSArray arrayWithObjects:objects count:count];
 编译器底层做的事情.
 */

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
static NSLock			*placeholderLock;

/**
 * A simple, low overhead, ordered container for objects.  All the objects
 * in the container are retained by it.  The container may not contain nil
 * (though it may contain [NSNull+null]).
 */
@implementation NSArray

static SEL	addSel;
static SEL	appSel;
static SEL	countSel;
static SEL	equalSel;
static SEL	objectAtSel;
static SEL	deleteObjAtSel;
static SEL	removeLastSel;

+ (void) initialize
{
    if (self == [NSArray class])
    {
        addSel = @selector(addObject:);
        appSel = @selector(appendString:);
        countSel = @selector(count);
        equalSel = @selector(isEqual:);
        objectAtSel = @selector(objectAtIndex:);
        deleteObjAtSel = @selector(removeObjectAtIndex:);
        removeLastSel = @selector(removeLastObject);
        
        NSArrayClass = [NSArray class];
        NSMutableArrayClass = [NSMutableArray class];
        GSArrayClass = [GSArray class];
        GSMutableArrayClass = [GSMutableArray class];
        GSPlaceholderArrayClass = [GSPlaceholderArray class];
        
        defaultPlaceholderArray = (GSPlaceholderArray*)
        NSAllocateObject(GSPlaceholderArrayClass, 0, NSDefaultMallocZone());
        placeholderMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, // 这两个值都是全局变量, 里面已经设置好了各个函数指针的值.
                                          NSNonRetainedObjectMapValueCallBacks, 0);
        placeholderLock = [NSLock new];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
    // 如果不是自定义的子类, 就是上面的方法, 如果是自定义的子类, 那么 alloc WithZone 就是正常的分配内存, 返回对象.
    if (self != NSArrayClass) {
        return NSAllocateObject(self, 0, z);
    }
    /*
     在 alloc 里面, 返回一个 placeHolder 类, 在 placeHolder 的 init 方法里面, 返回实际的对象.
     */
   return defaultPlaceholderArray;
}

+ (id) array // 所以这个方法是一点意义没有的. 但是 NSMutableArray 也可以使用这个
{
    id	o;
    o = [self allocWithZone: NSDefaultMallocZone()];
    o = [o initWithObjects: (id*)0 count: 0];
    return AUTORELEASE(o); // Gnu 的代码里面有很多宏, 而这些宏其实都是简单的代码. 猜想这样做是为了之后可以方便修改.
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
    o = [o initWithContentsOfFile: file];
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

/*
 从上面我们可以看到, 类方法仅仅是 alloc init 的调用而已, 这也是为什么苹果现在推崇 alloc init 这种两部的写法. 在上面的方法里面, 差别就是 init方法的调用.
 类方法, 和 init 方法有什么区别呢, 从上面看是没有什么区别的. 徒增复杂度.
 */

/**
 * Returns an autoreleased array formed from the contents of
 * the receiver and adding anObject as the last item.
 */
/*
 
 */
- (NSArray*) arrayByAddingObject: (id)anObject
{
    id na;
    NSUInteger	c = [self count];
    
    if (anObject == nil)
        [NSException raise: NSInvalidArgumentException
                    format: @"Attempt to add nil to an array"]; // 防卫式编程.
    if (c == 0)
    {
        na = [[GSArrayClass allocWithZone: NSDefaultMallocZone()]
              initWithObjects: &anObject count: 1];
    }
    else
    {
        GS_BEGINIDBUF(objects, c+1);
        // 这个宏 会将分配一块内存空间给 objects, 然后下面的方法会进行这个空间的赋值操作. 所以, NSArray 的 backing 还是需要实际的C++ 的内存分配才能够进行的. GSArrayClass 就是实际的进行内存管理的类, 它是 NSArray 的子类, 代表着它符合NSA rray 的所有接口.
        [self getObjects: objects]; // 执行完这个操作之后, objects 里面, 就已经有了原来类的所有数据了,  并且 objects 里面的长度进行了 +1/
        objects[c] = anObject;
        na = [[GSArrayClass allocWithZone: NSDefaultMallocZone()]
              initWithObjects: objects count: c+1];
        GS_ENDIDBUF();
    }
    return AUTORELEASE(na);
}

/**
 * Returns a new array which is the concatenation of self and
 * otherArray (in this precise order).
 整个实现的思路不复杂, 还是分配空间, 填入数据, 然后 GSArray 进行分配.
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
        if ([anotherArray isProxy]) // 这里, 如果 anotherArray 是一个proxy, 那么其实这个对象不能使用 getObjects 这个方法的, 因为这个方法的内部, 用到了 IMP. 所以, 只能用 objectAtIndex 这样的方法, 因为这样的方法会被传递到 proxy 代理的对象中区.
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
            [anotherArray getObjects: &objects[c]]; // 这里, 它为了提高效率, 直接是传递的指针, 然后操作指针.
        }
        na = [NSArrayClass arrayWithObjects: objects count: e];
        
        GS_ENDIDBUF();
    }
    
    return na;
}

/**
 * Returns the abstract class ... arrays are coded as abstract arrays.
 */
- (Class) classForCoder // 和序列化相关, 先不考虑.
{
    return NSArrayClass;
}

/**
 * Returns YES if anObject belongs to self. No otherwise.<br />
 * The [NSObject-isEqual:] method of anObject is used to test for equality.
 从这个方法, 我们看到,  contains Object 在 array 里面是遍历才能确定的.
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
    直接应用了 init 函数.
 
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

// 没看.
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
    
    if ([aCoder allowsKeyedCoding]) // 当可以用 keyValue Coding 的时候, 就用 key 值存储数据, 相应的读取数据的时候, 就用 key 值读取.
    {
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
    {   // aCoder 里面, 管理到底数据存储在什么地方.
        // 这里, 来到这里, 就是 keyValue 那种方式不能用, 所以就用先序列化某些数据, 在序列化某些数据的方式, 进行序列化.
        // 这有点像是, 用JSON, XML 这种, 可以方便添加字段的序列化方式不能用之后, 用头两个字节放置 count 值, 然后后面一段数据, 放置数组这种, 二进制的固定内存位置的方式进行序列化操作.
        unsigned  items = (unsigned)count;
        
        [aCoder encodeValueOfObjCType: @encode(unsigned)
                                   at: &items]; // 首先, 将数量序列化,
        if (count > 0)
        {
            GS_BEGINIDBUF(a, count);
            
            [self getObjects: a]; // 这里, 进行了一次拷贝, 猜测是防止 aCoder 直接操作原有数据的时候, 会修改原有数据的值. 这是系统类为了安全做的考虑, 如果是自己写代码的话, 为了省事, 或者性能, 就直接让下面的函数传递数组的 backing store 了.
            [aCoder encodeArrayOfObjCType: @encode(id)
                                    count: count
                                       at: a]; // 然后调用将数组序列化的方法, 用的是对象 id 类型. 具体的序列化方法, 在 encodeArrayOfObjCType 内部.
            GS_ENDIDBUF();
        }
    }
}

/**
 * Copies the objects from the receiver to aBuffer, which must be
 * an area of memory large enough to hold them.
 */
/*
 OC 的方法里面, get 一般就是用在这个时候, 将数据放到一个 buf 里面, 这个 buf 是输出参数, 必须实现分配, 由调用者来确保它是有效的.
 这个方法里面, 并没有内存的管理. 内存的管理仅仅是出现在 init 方法里面, 所以这个方法的后面, 一般紧接着的就是 init 方法.
 */
- (void) getObjects: (__unsafe_unretained id[])aBuffer
{
    NSUInteger i, c = [self count];
    IMP	get = [self methodForSelector: objectAtSel];
    
    for (i = 0; i < c; i++)
        aBuffer[i] = (*get)(self, objectAtSel, i);
}

/**
 * Returns the same value as -count
 这里, 让 count 当 hash 值. 感觉太简单了.
 */
- (NSUInteger) hash
{
    return [self count];
}

/**
 * Returns the index of the specified object in the receiver, or
 * NSNotFound if the object is not present.
 */

/*
 数组里面, 想要查询值在不在其中, 都是要用到遍历的方式.
 下面的这两个函数, 一个是判断, 这个值是否就是传入的那个值, 也就是判断的是指针值是否相等. 一个是调用 isEqual 方法, 也就是用 isEqual 进行的判断. 不过, NSObject 的 isEqual 默认就是判断地址值. 所以, 如果一个类没有复写 isEqual 的话, 这两个方法是相同的.
 */
- (NSUInteger) indexOfObjectIdenticalTo: (id)anObject
{
    NSUInteger c = [self count];
    
    if (c > 0)
    {
        IMP	get = [self methodForSelector: objectAtSel];
        NSUInteger	i;
        
        for (i = 0; i < c; i++)
            if (anObject == (*get)(self, objectAtSel, i))
                return i;
    }
    return NSNotFound;
}

/**
 * Returns the index of the first object found in the receiver
 * which is equal to anObject (using anObject's [NSObject-isEqual:] method).
 * Returns NSNotFound on failure.
 这个方法就是遍历操作, 不过是在这里面, 用到其实要使用的是每个方法的Equal 方法, 这里, 系统的类的实现性能优先, 直接用的 Imp
 */
- (NSUInteger) indexOfObject: (id)anObject
{
    NSUInteger	c = [self count];
    
    if (c > 0 && anObject != nil)
    {
        NSUInteger	i;
        IMP	get = [self methodForSelector: objectAtSel];
        BOOL	(*eq)(id, SEL, id)
        = (BOOL (*)(id, SEL, id))[anObject methodForSelector: equalSel];
        
        for (i = 0; i < c; i++)
            if ((*eq)(anObject, equalSel, (*get)(self, objectAtSel, i)) == YES)
                return i;
    }
    return NSNotFound;
}

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
    GS_BEGINIDBUF(objects, c); // 分配存储空间.
    
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
    /*
     initWithObjects:count: 之前, objects 里面, 都是为了拿到实现想要操作的值.
     */
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
/*
 反序列化和序列化是完全相反的做法.
 如果是 keyValue Coding 支持的情况下. 就会去固定的 key 值读取数据.
 这里, 感觉 NS.objects, 和 NS.object.%lu 应该是两个不同版本的序列化的方式.
 而如果不是 keyValueCoding 的话, 首先读取 count 值 ,然后根据 count 值, 读取后面的一串数据.
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

- (id) initWithContentsOfFile: (NSString*)file
{
    NSString 	*myString;
    
    myString = [[NSString allocWithZone: NSDefaultMallocZone()]
                initWithContentsOfFile: file]; // 首先, Plist 文件是一个文本文件. 之所以是文本文件, 好处多多, 序列化的时候在详细记录.
    if (myString == nil)
    {
        DESTROY(self);
        return nil;
    }
    id result;
    
    NS_DURING // 标志异常发生的区间.
    {
        result = [myString propertyList];
        /*
          这里, 将字符串, 转换成为了一个 NSDictionary 对象. 字符串的转换, 本身是一个超级复杂的问题, GNU 将所需要的逻辑, 都封装到了 PropertyList, JSON 相关的一个类中. 这两个类, 感觉虽然算法精妙, 但对实际开发帮助不大, 看完就忘.
         */
    }
    NS_HANDLER // 标志异常处理的区间.
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

// 就是对于一些操作的封装.
- (NSArray *) objectsAtIndexes: (NSIndexSet *)indexes
{
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

// 可以看到, 其他的所有操作, 都是建立在 objectAtIndex 和 count 的基础上的, 接口类中, 将这些操作都写好, 子类仅仅重写 objectAtIndex 和 count 就能实现自定义. 缺点是, 子类用父类的代码, 就不能利用自己已知的数据结构, 直接访问数据, 还是要使用 objectAtIndex 和 count 的才可以.

/*
 
 这种判断 equal 的方法都很类似, 显示判断指针, 然后是主要的属性值, 然后如果是容器类, 就会判断各个数据是否相等, 这里, 其实是调用数据的 isEqual 方法, 这样数据也可以按照, 指针, 关键属性这种方式判断相等与否, 而不是直接判断指针.
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
        IMP	get0 = [self methodForSelector: objectAtSel];
        IMP	get1 = [otherArray methodForSelector: objectAtSel];
        for (i = 0; i < c; i++)
            if (![(*get0)(self, objectAtSel, i) isEqual: (*get1)(otherArray, objectAtSel, i)])
                return NO;
    }
    return YES;
}

/**
 * Returns the last object in the receiver, or nil if the receiver is empty.
 简单的封装, 完全符合自己想法
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
 简单的封装, 完全符合自己想法
 */
- (id) firstObject
{
    NSUInteger count = [self count];
    if (count == 0)
        return nil;
    return [self objectAtIndex: 0];
}

/**
 * Makes each object in the array perform aSelector.<br />
 * This is done sequentially from the first to the last object.
 简单的封装, 完全符合自己想法
 */
- (void) makeObjectsPerformSelector: (SEL)aSelector
{
    NSUInteger	c = [self count];
    
    if (c > 0)
    {
        IMP	        get = [self methodForSelector: objectAtSel];
        NSUInteger	i = 0;
        while (i < c)
        {
            [(*get)(self, objectAtSel, i++) performSelector: aSelector];
        }
    }
}

/**
 * Obsolete version of -makeObjectsPerformSelector:
 */
- (void) makeObjectsPerform: (SEL)aSelector
{
    [self makeObjectsPerformSelector: aSelector];
}

/**
 * Makes each object in the array perform aSelector with arg.<br />
 * This is done sequentially from the first to the last object.
 */
- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)arg
{
    NSUInteger    c = [self count];
    
    if (c > 0)
    {
        IMP	        get = [self methodForSelector: objectAtSel];
        NSUInteger	i = 0;
        
        while (i < c)
        {
            [(*get)(self, objectAtSel, i++) performSelector: aSelector
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
compare(id elem1, id elem2, void* context) // 在这里, 这个 context 是一个 selector.
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
 sort 这个方法, 其实是需要两个函数, 一个是如何排序的函数, 一个是如何比大小的函数.
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
    /*
        这里, 是利用的 NSMutableArray 的 sort 函数. 所以, 在 NSMutableArray 的 sort 函数的内部, 一定有排序算法. 这个排序算法, 根据 comparator, context 决定元素的比较.
     */
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

/**
 * Returns a string formed by concatenating the objects in the receiver,
 * with the specified separator string inserted between each part.
 实现, 符合自己的想法.
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
        
        [s appendString: [[self objectAtIndex: 0] description]]; // 这里, 平时我们都是存储的 NSString, 这里看来, 也可以是对象, 只要自定义了对象的 description 就可以了.
        // 先写出跳出循环的逻辑, 然后用循环.
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
 这个函数没用过, 按效果, 应用途径很少, 并且, 如果真的想要达到效果, 也会自己实现, 明显的 extensions 在这里就应该用 set.
 系统给的库, 有的时候太过度设计了. 所以, 类的文档, 很多时候可以不读的.
 */
- (NSArray*) pathsMatchingExtensions: (NSArray*)extensions
{
    NSUInteger i, c = [self count];
    NSMutableArray *a = AUTORELEASE([[NSMutableArray alloc] initWithCapacity: 1]);
    Class	cls = [NSString class];
    IMP	get = [self methodForSelector: objectAtSel];
    IMP	add = [a methodForSelector: addSel];
    
    for (i = 0; i < c; i++)
    {
        id o = (*get)(self, objectAtSel, i);
        
        if ([o isKindOfClass: cls])
        {
            if ([extensions containsObject: [o pathExtension]]) // 这里其实也有一遍循环操作. 所以, 如果量特别大, 可以先替换 set, 然后用 set 进行比较.
            {
                (*add)(a, addSel, o);
            }
        }
    }
    return GS_IMMUTABLE(a);
}

/**
 * Returns the first object found in the receiver (starting at index 0)
 * which is present in the otherArray as determined by using the
 * -containsObject: method.
 这破函数谁会用... 过度设计/
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
    
    GS_RANGE_CHECK(aRange, c); // 这里, 如果 range 无效, 应该会抛出异常.
    
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
        // 这两个宏必须同时调用, 因为如果上面的宏, 是分配的堆空间的数据, 这里不调用 end 宏, 会有内存释放的.
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
    e = [e initWithArray: self]; // 这里, 一定是 NSArrayEnumerator 的内部, 可以拿到 Array 的内部数据结构.
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
    e = [e initWithArray: self]; // 这里, 一定是 NSArrayEnumeratorReverse 的内部, 可以拿到 Array 的内部数据结构.
    return AUTORELEASE(e);
}

/**
 * Returns the result of invoking -descriptionWithLocale:indent: with a nil
 * locale and zero indent.
 */
- (NSString*) description // 所以, 这里其实是个函数调用的关系.
{
    return [self descriptionWithLocale: nil]; // 国际化的代码应该看一下. 万一用到了呢. 不过, 应该和 QT 国际化的思路差不多才对.
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

// 用 propertyList 的方式, 写入到一个文件的路径中.
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

/*
 Array 对于 kvc 的特殊处理, 如果是 count, 那么直接返回 count 的值, 否则就返回数组中各个元素进行 valueForKey 的值, 如果没有就插入 NSNull null. 这里, NSNull NULL 就是一个单例, 目的就是插入一个对象到 Array 中用来表示 NSNull null.
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
                    null = RETAIN([NSNull null]); // 如果这里是 nil, 返回 NSNull null. 其实, 这就是一个单例而已.
                }
                result = null;
            }
            
            [results addObject: result];
        }
        
        result = results;
    }
    return result;
}

/*
 这一段没看, 因为基本没有用到过. 而且, 专门记忆这些细节, 需要记忆的就太多了. 能够知道类的实现原理更重要.
 */
- (id) valueForKeyPath: (NSString*)path
{
    id	result = nil;
    
    if ([path hasPrefix: @"@"])
    {
        NSRange   r;
        
        r = [path rangeOfString: @"."];// 首先, 判断一下有没有 . 的链接. 如果有话,就要按照路径进行一层层的查找.
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
            NSString      *remains = [path substringFromIndex: NSMaxRange(r)];
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
                        d += [[o valueForKeyPath: remains] doubleValue];
                    }
                    d /= count;
                }
                result = [NSNumber numberWithDouble: d]; // 这里通过迭代器, 实现了递归操作.
            }
            else if ([op isEqualToString: @"@max"] == YES)
            {
                if (count > 0)
                {
                    NSEnumerator  *e = [self objectEnumerator];
                    id            o;
                    
                    while ((o = [e nextObject]) != nil)
                    {
                        o = [o valueForKeyPath: remains];
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
                        o = [o valueForKeyPath: remains];
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
                        d += [[o valueForKeyPath: remains] doubleValue];
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
                        o = [o valueForKeyPath: remains];
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
                        o = [o valueForKeyPath: remains];
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
                        o = [o valueForKeyPath: remains];
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
                        o = [o valueForKeyPath: remains];
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
                        o = [o valueForKeyPath: remains];
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
                        o = [o valueForKeyPath: remains];
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
 数组对于 kvc 的特殊实现.
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

/*
  这里的实现, 和自己的想法差不多. 太多 options 的细节东西不看.
 */
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
        
        /*
         #define FOR_IN(type, var, collection) \
         for (type var in collection)\
         {
         #define END_FOR_IN(collection) }
         有的时候, 宏就是函数. 它能起到很好的提示作用.
         如果, 是 concurrent 就是一个并发队列, 如果是 serial, 就是一个串行队列.
         */
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
    // 可以看到, 所谓的 options 都要在代码里一个个的拆解出来.
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

// 这个函数, 没有在类中找到的.
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

/**
    这是一个 primitive method, 其他的方法通过调用这个函数, 可以达到自己的目的.
    自己编写代码的时候, 很少写出这种全局都使用的 primitive 的函数, 因为直接操作内存做某些事的诱惑实在太大了, 如果习惯于这种写法, 那么之后, 修改primitive 函数, 就能达到修改所有的函数的目的, 通过函数的组装, 能够达到逻辑的统一. 这种便利性, 要比直接操作内存那小小的效率要高得多.
 */
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
        index = [indexes indexGreaterThanIndex: index]; // 这样写感觉有点问题.
    }
}

/**
 * Replaces objects in the receiver with those from anArray.<br />
 * Raises an exception if given a range extending beyond the array.<br />
 */

/*
 这样写铁定效率特别低, 因为明显应该一次多移动一块内存才好. 但是不要忘记了, 这里的是NSA rray, 它并不知道底部的实现. 万一是用的链表实现的呢.
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
 这里, NSMutableArray 复写了父类了的指定构造函数, 在 alloc 的时候, 返回的就是 NSMutableArray 对象了
 */
- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    self = [self initWithCapacity: count];
    if (count > 0)
    {
        NSUInteger	i;
        IMP	add = [self methodForSelector: addSel];
        
        for (i = 0; i < count; i++)
            (*add)(self, addSel, objects[i]);
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
        IMP	get = [self methodForSelector: objectAtSel];
        
        while (i-- > 0)
        {
            id	o = (*get)(self, objectAtSel, i);
            
            if (o == anObject)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: deleteObjAtSel];
                }
                (*rem)(self, deleteObjAtSel, i);
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
        IMP	get = [self methodForSelector: objectAtSel];
        BOOL	(*eq)(id, SEL, id)
        = (BOOL (*)(id, SEL, id))[anObject methodForSelector: equalSel];
        
        while (i-- > s)
        {
            id	o = (*get)(self, objectAtSel, i);
            
            if (o == anObject || (*eq)(anObject, equalSel, o) == YES)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: deleteObjAtSel];
                    /*
                     * We need to retain the object so that when we remove the
                     * first equal object we don't get left with a bad object
                     * pointer for later comparisons.
                     */
                    RETAIN(anObject);
                }
                (*rem)(self, deleteObjAtSel, i);
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
        IMP	get = [self methodForSelector: objectAtSel];
        
        while (i-- > s)
        {
            id	o = (*get)(self, objectAtSel, i);
            
            if (o == anObject)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: deleteObjAtSel];
                }
                (*rem)(self, deleteObjAtSel, i);
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
        IMP	get = [self methodForSelector: objectAtSel];
        BOOL	(*eq)(id, SEL, id)
        = (BOOL (*)(id, SEL, id))[anObject methodForSelector: equalSel];
        
        while (i-- > 0)
        {
            id	o = (*get)(self, objectAtSel, i);
            
            if (o == anObject || (*eq)(anObject, equalSel, o) == YES)
            {
                if (rem == 0)
                {
                    rem = [self methodForSelector: deleteObjAtSel];
                    /*
                     * We need to retain the object so that when we remove the
                     * first equal object we don't get left with a bad object
                     * pointer for later comparisons.
                     */
                    RETAIN(anObject);
                }
                (*rem)(self, deleteObjAtSel, i);
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
        IMP	get = [otherArray methodForSelector: objectAtSel];
        IMP	add = [self methodForSelector: addSel];
        
        for (i = 0; i < c; i++)
            (*add)(self, addSel,  (*get)(otherArray, objectAtSel, i));
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
    // 这里其实是全删和全加的操作.
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
            IMP	rem = [self methodForSelector: deleteObjAtSel];
            
            while (to--)
            {
                (*rem)(self, deleteObjAtSel, sorted[to]);
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
        IMP	get = [otherArray methodForSelector: objectAtSel];
        IMP	rem = [self methodForSelector: @selector(removeObject:)];
        
        for (i = 0; i < c; i++)
            (*rem)(self, @selector(removeObject:), (*get)(otherArray, objectAtSel, i));
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
        IMP	rem = [self methodForSelector: deleteObjAtSel];
        
        while (i-- > s)
        {
            (*rem)(self, deleteObjAtSel, i);
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
 * Sorts the array according to the supplied compare function
 * with the context information.
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


// 这里实现的都是最通用的版本, 在实际的子类中, 可以写出更加适合自己数据结构的版本. 比如, GSArray 中, 就是直接能够访问内存的版本.
@implementation NSArrayEnumerator

- (id) initWithArray: (NSArray*)anArray
{
    self = [super init];
    if (self != nil)
    {
        array = anArray;
        IF_NO_GC(RETAIN(array));
        pos = 0;
        get = [array methodForSelector: objectAtSel];
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
    return (*get)(array, objectAtSel, pos++);
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
    return (*get)(array, objectAtSel, --pos);
}
@end

