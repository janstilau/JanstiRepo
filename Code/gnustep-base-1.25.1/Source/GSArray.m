#import "common.h"
#import "Foundation/NSArray.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSValue.h"
// For private method _decodeArrayOfObjectsForKey:
#import "Foundation/NSKeyedArchiver.h"

#import "GSPrivate.h"
#import "GSSorting.h"

static SEL	equalSel;
static SEL	objectAtIndexSel;

static Class	GSInlineArrayClass;
// 由父类定义公共的接口, 然后子类实现某些特定的逻辑.
@interface GSInlineArray : GSArray
{
}
@end

@class	GSArray;

@interface GSArrayEnumerator : NSEnumerator
{
    GSArray	*array;
    NSUInteger	pos;
}
- (id) initWithArray: (GSArray*)anArray;
@end

@interface GSArrayEnumeratorReverse : GSArrayEnumerator
@end

@interface GSMutableArray (GSArrayBehavior)
- (void) _raiseRangeExceptionWithIndex: (NSUInteger)index from: (SEL)sel;
@end

@implementation GSArray

- (void) _raiseRangeExceptionWithIndex: (NSUInteger)index from: (SEL)sel
{
    NSDictionary *info;
    NSException  *exception;
    NSString     *reason;
    
    info = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger: index], @"Index",
            [NSNumber numberWithUnsignedInteger: _count], @"Count",
            self, @"Array", nil, nil];
    
    reason = [NSString stringWithFormat:
              @"Index %"PRIuPTR" is out of range %d (in '%@')",
              index, _count, NSStringFromSelector(sel)];
    
    exception = [NSException exceptionWithName: NSRangeException
                                        reason: reason
                                      userInfo: info];
    // 在抛出异常的时候, 最好带上一些帮助使用者调试的信息.
    [exception raise];
}

+ (void) initialize
{
    if (self == [GSArray class])
    {
        [self setVersion: 1];
        equalSel = @selector(isEqual:);
        objectAtIndexSel = @selector(objectAtIndex:);
        GSInlineArrayClass = [GSInlineArray class];
    }
}

+ (id) allocWithZone: (NSZone*)zone
{
    GSArray *array = (GSArray*)NSAllocateObject(self, 0, zone);
    
    return (id)array;
}

- (id) copyWithZone: (NSZone*)zone
{
    return RETAIN(self);	// Optimised version // GSArray 是不可变版本, 所以这里仅仅是做一次 retain 操作.
}

- (void) dealloc
{
    if (_contents_array)
    {
        NSUInteger	i;
        
        // 这里, 做了所有的 release 操作. 要知道, 容器类管理了生命周期不是白白来的, 而是在对应的方法里面, 增加了管理内存的方法而已.
        for (i = 0; i < _count; i++)
        {
            [_contents_array[i] release];
        }
        NSZoneFree([self zone], _contents_array);
        _contents_array = 0;
    }
    [super dealloc];
}

- (id) init
{
    return [self initWithObjects: 0 count: 0];
}

/* This is the designated initializer for NSArray. */
// 子类复写父类的 designated init. 所以会直接调用到这里. NSArray 那里, 应该说没有实现 initWithObjects 这个方法.
- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    if (count > 0)
    {
        NSUInteger i;
        
        _contents_array = NSZoneMalloc([self zone], sizeof(id)*count);// 首先, 是分配内存给 backing stroe.
        if (_contents_array == 0)
        {
            DESTROY(self);
            return nil;
        }
        
        for (i = 0; i < count; i++)
        {
            if ((_contents_array[i] = RETAIN(objects[i])) == nil) // 这里有着 retain 操作.
            {
                _count = i;
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init array with nil to object"]; // 这里就是为什么不能用 nil 的原因, 代码里面写明了.
            }
        }
        _count = count;
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder // 有时间应该把序列化反序列化的操作读一读.
{
    if ([aCoder allowsKeyedCoding])
    {
        [super encodeWithCoder: aCoder];
    }
    else
    {
        /* For performace we encode directly ... must exactly match the
         * superclass implemenation. */
        [aCoder encodeValueOfObjCType: @encode(unsigned)
                                   at: &_count];
        if (_count > 0)
        {
            [aCoder encodeArrayOfObjCType: @encode(id)
                                    count: _count
                                       at: _contents_array];
        }
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    if ([aCoder allowsKeyedCoding])
    {
        self = [super initWithCoder: aCoder];
    }
    else
    {
        /* for performance, we decode directly into memory rather than
         * using the superclass method. Must exactly match superclass. */
        [aCoder decodeValueOfObjCType: @encode(unsigned)
                                   at: &_count];
        if (_count > 0)
        {
            _contents_array = NSZoneCalloc([self zone], _count, sizeof(id));
            if (_contents_array == 0)
            {
                [NSException raise: NSMallocException
                            format: @"Unable to make array"];
            }
            [aCoder decodeArrayOfObjCType: @encode(id)
                                    count: _count
                                       at: _contents_array];
        }
    }
    return self;
}

- (NSUInteger) count
{
    return _count;
}

- (NSUInteger) hash // 这里, hash 只是简单的返回 count, 不过一般来说, NSArray 不会再放入另外容器类里面了.
{
    return _count;
}

- (NSUInteger) indexOfObject: anObject
{
    if (anObject == nil)
        return NSNotFound;
    /*
     *	For large arrays, speed things up a little by caching the method.
     */
    if (_count > 1) // indexOfIndex . 还是用的equalSel 的方法.
    {
        BOOL		(*imp)(id,SEL,id);
        NSUInteger		i;
        
        imp = (BOOL (*)(id,SEL,id))[anObject methodForSelector: equalSel];
        
        for (i = 0; i < _count; i++)
        {
            if ((*imp)(anObject, equalSel, _contents_array[i]))
            {
                return i;
            }
        }
    }
    else if (_count == 1 && [anObject isEqual: _contents_array[0]]) // 这里不明白为什么要做专门的判断, 用上面的逻辑没有问题.
    {
        return 0;
    }
    return NSNotFound;
}

- (NSUInteger) indexOfObjectIdenticalTo: anObject // 这个函数才是真正的内存比较.
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        if (anObject == _contents_array[i])
        {
            return i;
        }
    }
    return NSNotFound;
}

// 先指针, 后数量, 最后是各个比较.
- (BOOL) isEqualToArray: (NSArray*)otherArray
{
    NSUInteger i;
    
    if (self == (id)otherArray)
    {
        return YES;
    }
    if (_count != [otherArray count])
    {
        return NO;
    }
    if (_count > 0)
    {
        IMP	get1 = [otherArray methodForSelector: objectAtIndexSel];
        
        for (i = 0; i < _count; i++)
        {
            if (![_contents_array[i] isEqual: (*get1)(otherArray, objectAtIndexSel, i)])
            {
                return NO;
            }
        }
    }
    return YES;
}

- (id) lastObject
{
    if (_count)
    {
        return _contents_array[_count-1];
    }
    return nil;
}

- (BOOL) makeImmutable
{
    return YES;
}

- (id) objectAtIndex: (NSUInteger)index
{
    if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    return _contents_array[index];
}


// 这些函数, 本来在 NSArray 那里都有实现, 但是作为子类, 可以直接通过指针获取到 对象, 而在NSArray里面, 还需要 objectAtIndex 函数. 所以, 这里这样写的效率要高得多.
- (void) makeObjectsPerformSelector: (SEL)aSelector
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        [_contents_array[i] performSelector: aSelector];
    }
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)argument
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        [_contents_array[i] performSelector: aSelector withObject: argument];
    }
}

- (void) getObjects: (__unsafe_unretained id[])aBuffer
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        aBuffer[i] = _contents_array[i];
    }
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (__unsafe_unretained id[])stackbuf
                                     count: (NSUInteger)len
{
    /* For immutable arrays we can return the contents pointer directly. */
    NSUInteger count = _count - state->state;
    state->mutationsPtr = (unsigned long *)self;
    state->itemsPtr = _contents_array + state->state;
    state->state += count;
    return count;
}

@end


/*
 */
@implementation	GSInlineArray
- (void) dealloc
{
    if (_contents_array)
    {
        NSUInteger	i;
        
        for (i = 0; i < _count; i++)
        {
            [_contents_array[i] release];
        }
        _contents_array = 0;
    }
    [super dealloc];
}
- (id) init
{
    return [self initWithObjects: 0 count: 0];
}
//
- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    _contents_array
    = (id*)(((void*)self) + class_getInstanceSize([self class]));
    
    if (count > 0)
    {
        NSUInteger	i;
        
        for (i = 0; i < count; i++)
        {
            if ((_contents_array[i] = RETAIN(objects[i])) == nil)
            {
                _count = i;
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init array with nil object"];
            }
        }
        _count = count;
    }
    return self;
}
@end

// 真正的 mutableArray 实现
@implementation GSMutableArray

+ (void) initialize
{
    if (self == [GSMutableArray class])
    {
        [self setVersion: 1];
        GSObjCAddClassBehavior(self, [GSArray class]); // 因为, GSMutableArray 是NSMutableArray 的子类, 所以, 这里它并没有GSArray 的那些实现. 这里需要显示的添加, 这样一来, 也就相当于它进行了继承, 而且, 它自己的内部, 是建立了和GSA rray 一样的成员变量.
    }
}

- (void) addObject: (id)anObject
{
    _version++;
    if (anObject == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Tried to add nil to array"];
    }
    if (_count >= _capacity) // 首先, 这里要进行扩容操作.
    {
        id	*ptr;
        size_t	size = (_capacity + _grow_factor)*sizeof(id);
        
        ptr = NSZoneRealloc([self zone], _contents_array, size);
        if (ptr == 0)
        {
            [NSException raise: NSMallocException
                        format: @"Unable to grow array"];
        }
        _contents_array = ptr;
        _capacity += _grow_factor;
        _grow_factor = _capacity/2;
    }
    _contents_array[_count] = RETAIN(anObject);// 然后, 不要忘记新的对象的 retain 操作.
    _count++;	/* Do this AFTER we have retained the object.	*/
    _version++;
}

/**
 * Optimised code for copying
 */
- (id) copyWithZone: (NSZone*)zone
{
    NSArray       *copy;
    
    copy = (id)NSAllocateObject(GSInlineArrayClass, sizeof(id)*_count, zone);
    return [copy initWithObjects: _contents_array count: _count]; // 新建一个内存空间, 然后直接用初始化方法进行 copy.
}

- (void) exchangeObjectAtIndex: (NSUInteger)i1
             withObjectAtIndex: (NSUInteger)i2
{
    _version++;
    if (i1 >= _count)
    {
        [self _raiseRangeExceptionWithIndex: i1 from: _cmd];
    }
    if (i2 >= _count)
    {
        [self _raiseRangeExceptionWithIndex: i2 from: _cmd];
    }
    if (i1 != i2)
    {
        id	tmp = _contents_array[i1];
        
        _contents_array[i1] = _contents_array[i2];
        _contents_array[i2] = tmp;
    }
    _version++;
}

- (id) init
{
    return [self initWithCapacity: 0];
}

- (id) initWithCapacity: (NSUInteger)cap // 直接创建固定大小的内存, 避免数据的迁移操作.
{
    if (cap == 0)
    {
        cap = 1;
    }
    _contents_array = NSZoneMalloc([self zone], sizeof(id)*cap);
    _capacity = cap;
    _grow_factor = cap > 1 ? cap/2 : 1;
    return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    if ([aCoder allowsKeyedCoding])
    {
        self = [super initWithCoder: aCoder];
    }
    else
    {
        unsigned    count;
        
        [aCoder decodeValueOfObjCType: @encode(unsigned)
                                   at: &count];
        if ((self = [self initWithCapacity: count]) == nil)
        {
            [NSException raise: NSMallocException
                        format: @"Unable to make array while initializing from coder"];
        }
        if (count > 0)
        {
            [aCoder decodeArrayOfObjCType: @encode(id)
                                    count: count
                                       at: _contents_array];
            _count = count;
        }
    }
    return self;
}

- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    self = [self initWithCapacity: count];
    if (self != nil && count > 0)
    {
        NSUInteger	i;
        
        for (i = 0; i < count; i++) // 依次塞入并且 retain
        {
            if ((_contents_array[i] = RETAIN(objects[i])) == nil)
            {
                _count = i;
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init array with nil object"];
            }
        }
        _count = count;
    }
    return self;
}

- (void) insertObject: (id)anObject atIndex: (NSUInteger)index
{
    _version++;
    if (!anObject)
    {
        NSException  *exception;
        NSDictionary *info;
        
        info = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithUnsignedInteger: index], @"Index",
                self, @"Array", nil, nil];
        
        exception = [NSException exceptionWithName: NSInvalidArgumentException
                                            reason: @"Tried to insert nil to array"
                                          userInfo: info];
        [exception raise];
    }
    if (index > _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    if (_count == _capacity)// 首先会进行扩容操作.
    {
        id	*ptr;
        size_t	size = (_capacity + _grow_factor)*sizeof(id);
        // realloc 会将原来的内存复制过去. 所以这里可以没有.复制的操作
        ptr = NSZoneRealloc([self zone], _contents_array, size);
        if (ptr == 0)
        {
            [NSException raise: NSMallocException
                        format: @"Unable to grow"];
        }
        _contents_array = ptr;
        _capacity += _grow_factor;
        _grow_factor = _capacity/2; // 这里, 一致在更新 growFactor 的值. 看来在 iOS 里面, 更新的频率是 原来的容量 /2
    }
    memmove(&_contents_array[index+1], &_contents_array[index], // memMove 会处理 overlap 的情况, 所以 memCopy 快一点,它不会进行判断.
            (_count - index) * sizeof(id));// 因为这个调用时 insert, 所以这里进行了数据的搬移.
    /*
     *	Make sure the array is 'sane' so that it can be deallocated
     *	safely by an autorelease pool if the '[anObject retain]' causes
     *	an exception.
     */
    _contents_array[index] = nil;
    _count++;
    _contents_array[index] = RETAIN(anObject); // 这里, 数组里面对传过来的对象进行了引用操作.
    _version++;
}

- (BOOL) makeImmutable
{
    GSClassSwizzle(self, [GSArray class]);
    return YES;
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
    GSClassSwizzle(self, [GSArray class]);
    return self;
}

- (void) removeAllObjects
{
    NSUInteger    pos;
    
    if ((pos = _count) > 0)
    {
        IMP       rel = 0;
        Class    last = Nil;
        
        _version++;
        _count = 0;
        while (pos-- > 0)
        {
            id    o = _contents_array[pos];
            Class c = object_getClass(o);
            
            if (c != last)
            {
                last = c;
                rel = [o methodForSelector: @selector(release)]; // 这里, 从来不是 [o release], 这样写, 而是直接用的 IMP, 猜测是为了效率.
            }
            (*rel)(o, @selector(release));// 这里调用了 release 方法.
            _contents_array[pos] = nil;
        }
        _version++;
    }
}

- (void) removeLastObject
{ // 所以我们看, 没有什么内存释放的操作.
    _version++;
    if (_count == 0)
    {
        [NSException raise: NSRangeException
                    format: @"Trying to remove from an empty array."];
    }
    _count--;
    RELEASE(_contents_array[_count]);
    _contents_array[_count] = 0;
    _version++;
}

- (void) removeObject: (id)anObject
{
    NSUInteger	index;
    
    _version++;
    if (anObject == nil)
    {
        NSWarnMLog(@"attempt to remove nil object");
        return;
    }
    index = _count;
    if (index > 0)
    {
        BOOL	(*imp)(id,SEL,id);
        BOOL	retained = NO;
        
        imp = (BOOL (*)(id,SEL,id))[anObject methodForSelector: equalSel];
        while (index-- > 0)
        {
            if ((*imp)(anObject, equalSel, _contents_array[index]) == YES)
            {
                NSUInteger	pos = index;
                id	        obj = _contents_array[index];
                
                if (retained == NO)
                {
                    RETAIN(anObject);
                    retained = YES;
                }
                
                while (++pos < _count)
                {
                    _contents_array[pos-1] = _contents_array[pos];
                }
                _count--;
                _contents_array[_count] = 0;
                RELEASE(obj); // 这一步操作, 是为了抵消 Array 添加的 retain 操作.
            }
        }
        if (retained == YES)
        {
            RELEASE(anObject);
        }
    }
    _version++;
}

- (void) removeObjectAtIndex: (NSUInteger)index
{
    id	obj;
    
    _version++;
    if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    obj = _contents_array[index];
    _count--;
    while (index < _count)
    {
        _contents_array[index] = _contents_array[index+1];
        index++;
    }
    _contents_array[_count] = 0;
    [obj release];	/* Adjust array BEFORE releasing object.	*/
    _version++;
}

- (void) removeObjectIdenticalTo: (id)anObject
{
    NSUInteger	index;
    
    _version++;
    if (anObject == nil)
    {
        NSWarnMLog(@"attempt to remove nil object");
        return;
    }
    index = _count;
    while (index-- > 0) // 这里, 编码是显得代码少, 但是从效率的角度上来说, 应该先删除元素, 然后进行内存的搬移操作.
    {
        if (_contents_array[index] == anObject)
        {
            id		obj = _contents_array[index];
            NSUInteger	pos = index;
            
            while (++pos < _count) // 这里, 可能会有内存的多次搬移, 这样增加了时间复杂度.
            {
                _contents_array[pos-1] = _contents_array[pos];
            }
            _count--;
            _contents_array[_count] = 0;
            RELEASE(obj);
        }
    }
    _version++;
}

- (void) removeObjectsInRange: (NSRange)aRange
{
    GS_RANGE_CHECK(aRange, _count);
    
    if (aRange.length > 0)
    {
        NSUInteger        index;
        NSUInteger        tail;
        NSUInteger        end;
        IMP       rel = 0;
        Class    last = Nil;
        
        _version++;
        index = aRange.location;
        
        /* Release all the objects we are removing.
         */
        end = NSMaxRange(aRange);
        while (end-- > index)
        {
            id    o = _contents_array[end];
            Class c = object_getClass(o);
            
            if (c != last)
            {
                last = c;
                rel = [o methodForSelector: @selector(release)];
            }
            (*rel)(o, @selector(release));
            _contents_array[end] = nil;
        }
        
        /* Move any trailing objects to fill the hole we made.
         */
        end = NSMaxRange(aRange);
        tail = _count - end;
        if (tail > 0)
        {
            memmove(_contents_array + index, _contents_array + end,
                    tail * sizeof(id));
            index += tail;
        }
        _count = index;
        
        /* Clear emptied part of buffer.
         */
        memset(_contents_array + _count, 0, aRange.length * sizeof(id));
        _version++;
    }
}

- (void) replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
    id	obj;
    
    _version++;
    if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    if (!anObject)
    {
        NSException  *exception;
        NSDictionary *info;
        
        info = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithUnsignedInteger: index], @"Index",
                _contents_array[index], @"OldObject",
                self, @"Array", nil, nil];
        
        exception = [NSException exceptionWithName: NSInvalidArgumentException
                                            reason: @"Tried to replace object in array with nil"
                                          userInfo: info];
        [exception raise];
    }
    /*
     *	Swap objects in order so that there is always a valid object in the
     *	array in case a retain or release causes an exception.
     */
    obj = _contents_array[index];  // 一个 retain, 一个 release. 注意, 先 retain. 后 release
    [anObject retain];
    _contents_array[index] = anObject;
    [obj release];
    _version++;
}

- (void) sortUsingFunction: (NSComparisonResult (*)(id,id,void*))compare
                   context: (void*)context
{
    _version++;
    if ((1 < _count) && (NULL != compare))
    {
        GSSortUnstable(_contents_array, NSMakeRange(0,_count), (id)compare,
                       GSComparisonTypeFunction, context);
    }
    _version++;
}

- (void) sortWithOptions: (NSSortOptions)options
         usingComparator: (NSComparator)comparator
{
    // 所以, oc 里面也有算法库, 只不过传过去的都是 id 类型的数据而已.
    _version++;
    if ((1 < _count) && (NULL != comparator))
    {
        if (options & NSSortStable) // 稳定性
        {
            if (options & NSSortConcurrent)
            {
                GSSortStableConcurrent(_contents_array, NSMakeRange(0,_count),
                                       (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
            else
            {
                GSSortStable(_contents_array, NSMakeRange(0,_count),
                             (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
        }
        else // 不稳定性.
        {
            if (options & NSSortConcurrent)
            {
                GSSortUnstableConcurrent(_contents_array, NSMakeRange(0,_count),
                                         (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
            else
            {
                GSSortUnstable(_contents_array, NSMakeRange(0,_count),
                               (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
        }
    }
    _version++;
}

- (NSEnumerator*) objectEnumerator
{
    GSArrayEnumerator	*enumerator;
    
    enumerator = [GSArrayEnumerator allocWithZone: NSDefaultMallocZone()];
    return AUTORELEASE([enumerator initWithArray: (GSArray*)self]);
}

- (NSEnumerator*) reverseObjectEnumerator
{
    GSArrayEnumeratorReverse	*enumerator;
    
    enumerator = [GSArrayEnumeratorReverse allocWithZone: NSDefaultMallocZone()];
    return AUTORELEASE([enumerator initWithArray: (GSArray*)self]);
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (__unsafe_unretained id[])stackbuf
                                     count: (NSUInteger)len
{
    NSInteger count;
    
    /* This is cached in the caller at the start and compared at each
     * iteration.   If it changes during the iteration then
     * objc_enumerationMutation() will be called, throwing an exception.
     */
    state->mutationsPtr = &_version;
    count = MIN(len, _count - state->state);
    /* If a mutation has occurred then it's possible that we are being asked to
     * get objects from after the end of the array.  Don't pass negative values
     * to memcpy.
     */
    if (count > 0)
    {
        memcpy(stackbuf, _contents_array + state->state, count * sizeof(id));
        state->state += count;
    }
    else
    {
        count = 0;
    }
    state->itemsPtr = stackbuf;
    return count;
}

- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
    NSUInteger	size = GSPrivateMemorySize(self, exclude);
    
    if (size > 0)
    {
        NSUInteger	count = _count;
        
        size += _capacity*sizeof(void*);
        while (count-- > 0)
        {
            size += [_contents_array[count] sizeInBytesExcluding: exclude];
        }
    }
    return size;
}
@end



@implementation GSArrayEnumerator

// 迭代器必然是和容器类写在一起的, 它必须知道容器类的真正的存储数据结构, 才能进行便利操作.

- (id) initWithArray: (GSArray*)anArray
{
    if ((self = [super init]) != nil)
    {
        array = anArray;
        IF_NO_GC(RETAIN(array));
        pos = 0;
    }
    return self;
}

- (id) nextObject
{
    if (pos >= array->_count)
        return nil;
    return array->_contents_array[pos++];
}

- (void) dealloc
{
    RELEASE(array);
    [super dealloc];
}

@end

@implementation GSArrayEnumeratorReverse

// 这里, reverse 只不过遍历的起点进行了变化.

- (id) initWithArray: (GSArray*)anArray
{
    [super initWithArray: anArray];
    pos = array->_count;
    return self;
}

- (id) nextObject
{
    if (pos == 0)
        return nil;
    return array->_contents_array[--pos];
}
@end

@implementation	GSArray (GNUstep)
/*
 *	The comparator function takes two items as arguments, the first is the
 *	item to be added, the second is the item already in the array.
 *      The function should return NSOrderedAscending if the item to be
 *      added is 'less than' the item in the array, NSOrderedDescending
 *      if it is greater, and NSOrderedSame if it is equal.
 */
- (NSUInteger) insertionPosition: (id)item
                   usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
                         context: (void *)context
{
    NSUInteger	upper = _count;
    NSUInteger	lower = 0;
    NSUInteger	index;
    
    if (item == nil)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position for nil object in array"];
    }
    if (sorter == 0)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position with null comparator"];
    }
    
    /*
     *	Binary search for an item equal to the one to be inserted.
     */
    for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
        NSComparisonResult comparison;
        
        comparison = (*sorter)(item, _contents_array[index], context);
        if (comparison == NSOrderedAscending)
        {
            upper = index;
        }
        else if (comparison == NSOrderedDescending)
        {
            lower = index + 1;
        }
        else
        {
            break;
        }
    }
    /*
     *	Now skip past any equal items so the insertion point is AFTER any
     *	items that are equal to the new one.
     */
    while (index < _count
           && (*sorter)(item, _contents_array[index], context) != NSOrderedAscending)
    {
        index++;
    }
    return index;
}

- (NSUInteger) insertionPosition: (id)item
                   usingSelector: (SEL)comp
{
    NSUInteger	upper = _count;
    NSUInteger	lower = 0;
    NSUInteger	index;
    NSComparisonResult	(*imp)(id, SEL, id);
    
    if (item == nil)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position for nil object in array"];
    }
    if (comp == 0)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position with null comparator"];
    }
    imp = (NSComparisonResult (*)(id, SEL, id))[item methodForSelector: comp];
    if (imp == 0)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position with unknown method"];
    }
    
    /*
     *	Binary search for an item equal to the one to be inserted.
     */
    for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
        NSComparisonResult comparison;
        
        comparison = (*imp)(item, comp, _contents_array[index]);
        if (comparison == NSOrderedAscending)
        {
            upper = index;
        }
        else if (comparison == NSOrderedDescending)
        {
            lower = index + 1;
        }
        else
        {
            break;
        }
    }
    /*
     *	Now skip past any equal items so the insertion point is AFTER any
     *	items that are equal to the new one.
     */
    while (index < _count
           && (*imp)(item, comp, _contents_array[index]) != NSOrderedAscending)
    {
        index++;
    }
    return index;
}

@end


// 这个类会在NSArray 的 allocWithZone 中返回. 然后在 init 方法中, 返回实际的对象.
@implementation	GSPlaceholderArray

+ (void) initialize
{
    GSInlineArrayClass = [GSInlineArray class];
}

- (id) autorelease
{
    NSWarnLog(@"-autorelease sent to uninitialised array");
    return self;		// placeholders never get released.
}

- (id) objectAtIndex: (NSUInteger)index
{
    [NSException raise: NSInternalInconsistencyException
                format: @"Attempt to use uninitialised array"];
    return 0;
}

- (void) dealloc
{
    GSNOSUPERDEALLOC;	// placeholders never get deallocated.
}

- (id) init
{
    return [self initWithObjects: 0 count: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    if ([aCoder allowsKeyedCoding])
    {
        NSArray *array = [(NSKeyedUnarchiver*)aCoder _decodeArrayOfObjectsForKey:
                          @"NS.objects"];
        if (array != nil)
        {
            return (GSPlaceholderArray*)RETAIN(array);
        }
        else
        {
            return [super initWithCoder: aCoder];
        }
    }
    else
    {
        unsigned	        c;
        GSInlineArray	*a;
        
        [aCoder decodeValueOfObjCType: @encode(unsigned) at: &c];
        a = (id)NSAllocateObject(GSInlineArrayClass,
                                 sizeof(id)*c, [self zone]);
        a->_contents_array
        = (id*)(((void*)a) + class_getInstanceSize([a class]));
        if (c > 0)
        {
            [aCoder decodeArrayOfObjCType: @encode(id)
                                    count: c
                                       at: a->_contents_array];
        }
        a->_count = c;
        return (GSPlaceholderArray*)a;
    }
}

- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{ // GSInlineArrayClass == [GSInlineArray class]
    self = (id)NSAllocateObject(GSInlineArrayClass, sizeof(id)*count,
                                [self zone]);
    // 注意, 这个里面, 将 self 进行了替换, 原来的 self 是 placeHolderArray, 现在变成了 GSInlineArray. 而 GSInlineArray, 基本就是 GSArray. 也就是有着真正内存管理的A rray.
    return [self initWithObjects: objects count: count];
}

- (NSUInteger) count
{
    [NSException raise: NSInternalInconsistencyException
                format: @"Attempt to use uninitialised array"];
    return 0;
}

- (oneway void) release
{
    return;		// placeholders never get released.
}

- (id) retain
{
    return self;		// placeholders never get retained.
}
@end

@interface	NSGArray : NSArray
@end
@implementation	NSGArray
- (id) initWithCoder: (NSCoder*)aCoder
{
    NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
    DESTROY(self);
    self = (id)NSAllocateObject([GSArray class], 0, NSDefaultMallocZone());
    self = [self initWithCoder: aCoder];
    return self;
}
@end

@interface	NSGMutableArray : NSMutableArray
@end
@implementation	NSGMutableArray
- (id) initWithCoder: (NSCoder*)aCoder
{
    NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
    DESTROY(self);
    self = (id)NSAllocateObject([GSMutableArray class], 0, NSDefaultMallocZone());
    self = [self initWithCoder: aCoder];
    return self;
}
@end

