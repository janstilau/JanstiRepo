
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

static SEL	equalSEL;
static SEL	objectAtIndexSEL;

static Class	GSInlineArrayClass;
/* This class stores objects inline in data beyond the end of the instance.
 * However, when GC is enabled the object data is typed, and all data after
 * the end of the class is ignored by the garbage collector (which would
 * mean that objects in the array could be collected).
 * We therefore do not provide the class when GC is being used.
 */
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

/**
 * In this class. Init method is used for dispatch creation for each array sub class. So It like a factory.
 */
@implementation    GSPlaceholderArray

+ (void) initialize
{
    GSInlineArrayClass = [GSInlineArray class];
}

- (id) autorelease
{
    NSWarnLog(@"-autorelease sent to uninitialised array");
    return self;        // placeholders never get released.
}

- (id) objectAtIndex: (NSUInteger)index
{
    [NSException raise: NSInternalInconsistencyException
                format: @"Attempt to use uninitialised array"];
    return 0;
}

- (void) dealloc
{
    [super dealloc];
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
        unsigned            c;
        GSInlineArray    *a;
        
        [aCoder decodeValueOfObjCType: @encode(unsigned) at: &c];
        a = (id)NSAllocateObject(GSInlineArrayClass,
                                 sizeof(id)*c, [self zone]);
        a->_arrayContents
        = (id*)(((void*)a) + class_getInstanceSize([a class]));
        if (c > 0)
        {
            [aCoder decodeArrayOfObjCType: @encode(id)
                                    count: c
                                       at: a->_arrayContents];
        }
        a->_count = c;
        return (GSPlaceholderArray*)a;
    }
}


// Created a GSInlineArray instance. A sub class for GSArray

- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    self = (id)NSAllocateObject(GSInlineArrayClass, sizeof(id)*count,
                                [self zone]);
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
    return;        // placeholders never get released.
}

- (id) retain
{
    return self;        // placeholders never get retained.
}
@end

@implementation GSArray

// a common method for raiseException.
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
    [exception raise];
}

+ (void) initialize
{
    if (self == [GSArray class])
    {
        [self setVersion: 1];
        equalSEL = @selector(isEqual:);
        objectAtIndexSEL = @selector(objectAtIndex:);
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
    // NSArray is designed for no changed method. So return self and add the retincount.
    return RETAIN(self);	// Optimised version.
}

- (void) dealloc
{
    if (_arrayContents)
    {
        NSUInteger	i;
        
        for (i = 0; i < _count; i++)
        {
            [_arrayContents[i] release]; // release every.
        }
        NSZoneFree([self zone], _arrayContents); // free _arrayContents.
        _arrayContents = 0;
        /**
         *
         NSArray is a container. So inner this class, no memory is alloc automatically.
         Here using alloc and free to get and release memory.
         */
    }
    [super dealloc];
}

- (id) init
{
    return [self initWithObjects: 0 count: 0];
}

/* This is the designated initializer for NSArray. */
- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    if (count > 0)
    {
        NSUInteger i;
        
        _arrayContents = NSZoneMalloc([self zone], sizeof(id)*count); // alloc needed memory for cache items.
        if (_arrayContents == 0)
        {
            DESTROY(self);
            return nil; // always check for init return value. If this sth wrong in it, nil is returned.
        }
        
        for (i = 0; i < count; i++)
        {
            if ((_arrayContents[i] = RETAIN(objects[i])) == nil) // retain every item. and if nil is passed, raise a exception.
            {
                _count = i;
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Tried to init array with nil to object"];
            }
        }
        _count = count;
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
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
                                       at: _arrayContents];
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
            _arrayContents = NSZoneCalloc([self zone], _count, sizeof(id));
            if (_arrayContents == 0)
            {
                [NSException raise: NSMallocException
                            format: @"Unable to make array"];
            }
            [aCoder decodeArrayOfObjCType: @encode(id)
                                    count: _count
                                       at: _arrayContents];
        }
    }
    return self;
}

- (NSUInteger) count
{
    return _count;
}

- (NSUInteger) hash
{
    return _count;
}

// Same as NSArray
- (NSUInteger) indexOfObject: anObject
{
    if (anObject == nil)
        return NSNotFound;
    /*
     *	For large arrays, speed things up a little by caching the method.
     */
    if (_count > 1)
    {
        BOOL		(*imp)(id,SEL,id);
        NSUInteger		i;
        
        imp = (BOOL (*)(id,SEL,id))[anObject methodForSelector: equalSEL];
        
        for (i = 0; i < _count; i++)
        {
            if ((*imp)(anObject, equalSEL, _arrayContents[i]))
            {
                return i;
            }
        }
    }
    else if (_count == 1 && [anObject isEqual: _arrayContents[0]])
    {
        return 0;
    }
    return NSNotFound;
}

- (NSUInteger) indexOfObjectIdenticalTo: anObject
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        if (anObject == _arrayContents[i])
        {
            return i;
        }
    }
    return NSNotFound;
}

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
        IMP	get1 = [otherArray methodForSelector: objectAtIndexSEL];
        
        for (i = 0; i < _count; i++)
        {
            if (![_arrayContents[i] isEqual: (*get1)(otherArray, objectAtIndexSEL, i)])
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
        return _arrayContents[_count-1];
    }
    return nil;
}

- (BOOL) makeImmutable
{
    return YES;
}

/**
 *
 subclass need to implement every primitive method.
 So in this method, we can use the memory dirctly.
 */
- (id) objectAtIndex: (NSUInteger)index
{
    if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    return _arrayContents[index];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        [_arrayContents[i] performSelector: aSelector];
    }
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)argument
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        [_arrayContents[i] performSelector: aSelector withObject: argument];
    }
}

- (void) getObjects: (__unsafe_unretained id[])aBuffer
{
    NSUInteger i;
    
    for (i = 0; i < _count; i++)
    {
        aBuffer[i] = _arrayContents[i];
    }
}

- (void) getObjects: (__unsafe_unretained id[])aBuffer range: (NSRange)aRange
{
    NSUInteger i, j = 0, e = aRange.location + aRange.length;
    
    GS_RANGE_CHECK(aRange, _count);
    
    for (i = aRange.location; i < e; i++)
    {
        aBuffer[j++] = _arrayContents[i];
    }
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (__unsafe_unretained id[])stackbuf
                                     count: (NSUInteger)len
{
    /* For immutable arrays we can return the contents pointer directly. */
    NSUInteger count = _count - state->state;
    state->mutationsPtr = (unsigned long *)self;
    state->itemsPtr = _arrayContents + state->state;
    state->state += count;
    return count;
}

@end

@implementation GSMutableArray

+ (void) initialize
{
    if (self == [GSMutableArray class])
    {
        [self setVersion: 1];
        GSObjCAddClassBehavior(self, [GSArray class]);
    }
}

// same as cpp vector. The grow factor is related with current capacity.
- (void) addObject: (id)anObject
{
    _version++;
    if (anObject == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Tried to add nil to array"];
    }
    if (_count >= _capacity) // grow the memory container with algorithm
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
    _contents_array[_count] = RETAIN(anObject);
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
    return [copy initWithObjects: _contents_array count: _count];
}

// change memory array directly.
/**
 *
  immutable and mutable have no different. every class is mutable, cause the memory is mutable. But if you put every change method as private method, the class is seemed as immutable.
 */
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

- (id) initWithCapacity: (NSUInteger)cap
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

// total same as GSArray.
- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    self = [self initWithCapacity: count];
    if (self != nil && count > 0)
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
    if (_count == _capacity)
    {
        id	*ptr;
        size_t	size = (_capacity + _grow_factor)*sizeof(id);
        
        ptr = NSZoneRealloc([self zone], _contents_array, size);
        if (ptr == 0)
        {
            [NSException raise: NSMallocException
                        format: @"Unable to grow"];
        }
        _contents_array = ptr;
        _capacity += _grow_factor;
        _grow_factor = _capacity/2;
    }
    memmove(&_contents_array[index+1], &_contents_array[index],
            (_count - index) * sizeof(id));
    /*
     *	Make sure the array is 'sane' so that it can be deallocated
     *	safely by an autorelease pool if the '[anObject retain]' causes
     *	an exception.
     */
    _contents_array[index] = nil;
    _count++;
    _contents_array[index] = RETAIN(anObject);
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
            
            if (c != last) // this is for, not to get SEL every time.
            {
                last = c;
                rel = [o methodForSelector: @selector(release)];
            }
            (*rel)(o, @selector(release)); // call release for deleted item.
            _contents_array[pos] = nil;
        }
        _version++;
    }
}

- (void) removeLastObject
{
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

// Removes all occurrences in the array of a given object.
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
        
        imp = (BOOL (*)(id,SEL,id))[anObject methodForSelector: equalSEL];
        while (index-- > 0)
        {
            if ((*imp)(anObject, equalSEL, _contents_array[index]) == YES)
            {
                NSUInteger	pos = index;
                id	        obj = _contents_array[index];
                
                if (retained == NO)
                {
                    RETAIN(anObject);
                    retained = YES;
                } // must retain first. If the object is released, we still need it for compare the header items.
                
                while (++pos < _count)
                {
                    _contents_array[pos-1] = _contents_array[pos];
                }
                _count--;
                _contents_array[_count] = 0;
                RELEASE(obj);
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
    while (index-- > 0)
    {
        if (_contents_array[index] == anObject)
        {
            id		obj = _contents_array[index];
            NSUInteger	pos = index;
            
            while (++pos < _count)
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
    obj = _contents_array[index];
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
    _version++;
    if ((1 < _count) && (NULL != comparator))
    {
        if (options & NSSortStable)
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
        else
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

/**
 *
 record the array and position. Enumaerration must know inner infomation in counterpart container class.
 */

@implementation GSArrayEnumerator

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
    return array->_arrayContents[pos++];
}

- (void) dealloc
{
    RELEASE(array);
    [super dealloc];
}

@end

@implementation GSArrayEnumeratorReverse

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
    return array->_arrayContents[--pos];
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
        
        comparison = (*sorter)(item, _arrayContents[index], context);
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
           && (*sorter)(item, _arrayContents[index], context) != NSOrderedAscending)
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
        
        comparison = (*imp)(item, comp, _arrayContents[index]);
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
           && (*imp)(item, comp, _arrayContents[index]) != NSOrderedAscending)
    {
        index++;
    }
    return index;
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
