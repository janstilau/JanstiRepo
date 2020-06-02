#import "common.h"
#define	EXPOSE_NSIndexSet_IVARS	1
#import "Foundation/NSCoder.h"
#import "Foundation/NSData.h"
#import	"Foundation/NSIndexSet.h"
#import	"Foundation/NSException.h"
#import "GSDispatch.h"

#define	GSI_ARRAY_TYPE	NSRange

#define	GSI_ARRAY_NO_RELEASE	1
#define	GSI_ARRAY_NO_RETAIN	1

#include "GNUstepBase/GSIArray.h"

#define	_array	((GSIArray)(self->_data))
#define	_other	((GSIArray)(aSet->_data))

#ifdef	SANITY_CHECKS
static void sanity(GSIArray array)
{
    if (array != 0)
        
    {
        NSUInteger	c = GSIArrayCount(array);
        NSUInteger	i;
        NSUInteger	last = 0;
        
        for (i = 0; i < c; i++)
        {
            NSRange	r = GSIArrayItemAtIndex(array, i).ext;
            
            if (i > 0)
            {
                NSCAssert(r.location > last, @"Overlap or touching ranges");
            }
            else
            {
                NSCAssert(r.location >= last, @"Overlap ranges");
            }
            NSCAssert(NSMaxRange(r) > r.location, @"Bad range length");
            last = NSMaxRange(r);
        }
    }
}
#define	SANITY()	sanity(_array)
#else
#define	SANITY()
#endif

/*
 * Returns the position in the array at which the index should be inserted.
 * This may be the position of a range containing the index if it is already
 * present, otherwise it is the position of the first range containing an
 * index greater than the argument (or a position beyond the end of the
 * array).
 */
/*
 这个 IndexSet 的类, 应该在之前的地图编辑器的代码里面实现过类似的功能.
 当时也是运用了这里的二分查找的方法.
 */
static NSUInteger posForIndex(GSIArray array, NSUInteger index)
{
    NSUInteger	upper = GSIArrayCount(array);
    NSUInteger	lower = 0;
    NSUInteger	pos;
    
    /*
     *	Binary search for an item equal to the one to be inserted.
     */
    for (pos = upper/2; upper != lower; pos = (upper+lower)/2)
    {
        NSRange	r = GSIArrayItemAtIndex(array, pos).ext;
        
        if (index < r.location)
        {
            upper = pos; // 过大
        }
        else if (index > NSMaxRange(r))
        {
            lower = pos + 1; // 过小.
        }
        else
        {
            break; // 这里就是找到了, post 就是合适的位置.
        }
    }
    /*
     * Now skip past any item containing no values as high as the index.
     */
    while (pos < GSIArrayCount(array)
           && index >= NSMaxRange(GSIArrayItemAtIndex(array, pos).ext))
    {
        pos++;
    }
    return pos;
}

@implementation	NSIndexSet

+ (id) indexSet
{
    id	o = [self allocWithZone: NSDefaultMallocZone()];
    
    o = [o init];
    return AUTORELEASE(o);
}

+ (id) indexSetWithIndex: (NSUInteger)anIndex
{
    id	o = [self allocWithZone: NSDefaultMallocZone()];
    
    o = [o initWithIndex: anIndex];
    return AUTORELEASE(o);
}

+ (id) indexSetWithIndexesInRange: (NSRange)aRange
{
    id	o = [self allocWithZone: NSDefaultMallocZone()];
    
    o = [o initWithIndexesInRange: aRange];
    return AUTORELEASE(o);
}

- (BOOL) containsIndex: (NSUInteger)anIndex
{
    NSUInteger	pos;
    
    if (_array == 0 ||
        GSIArrayCount(_array) == 0
        || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
        return NO;
    }
    NSRange r = GSIArrayItemAtIndex(_array, pos).ext;
    return NSLocationInRange(anIndex, r);
}

- (BOOL) containsIndexes: (NSIndexSet*)aSet
{
    NSUInteger	count = _other ? GSIArrayCount(_other) : 0;
    if (count <= 0) { return NO; }
    
    NSUInteger    i;
    for (i = 0; i < count; i++)
    {
        // 拿出 Other 里面的 range, 遍历调用自己的 containsIndexesInRange 方法. 里面应该有剪枝操作. 如果存在, 最后返回 return YES
        NSRange r = GSIArrayItemAtIndex(_other, i).ext;
        if ([self containsIndexesInRange: r] == NO)
        {
            return NO;
        }
    }
    return YES;
}

- (BOOL) containsIndexesInRange: (NSRange)aRange
{
    NSUInteger	pos;
    NSRange	r;
    if (_array == 0 || GSIArrayCount(_array) == 0) { return NO; }
    pos = posForIndex(_array, aRange.location);
    if (pos >= GSIArrayCount(_array))
    {
        return NO;	// Empty ... contains no indexes.
    }
    if (aRange.length == 0)
    {
        return YES;	// No indexes needed.
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    if (NSLocationInRange(aRange.location, r)
        && NSLocationInRange(NSMaxRange(aRange)-1, r))
    {
        return YES;
    }
    return NO;
}

// 遍历, 获取所有的 range 里面的内容.
- (NSUInteger) count
{
    if (_array == 0 || GSIArrayCount(_array) == 0)
    {
        return 0;
    }
    else
    {
        NSUInteger	count = GSIArrayCount(_array);
        NSUInteger	total = 0;
        NSUInteger	i = 0;
        
        while (i < count)
        {
            total += GSIArrayItemAtIndex(_array, i).ext.length;
            i++;
        }
        return total;
    }
}


// 遍历获取 Range, 然后做一个交集的操作.
- (NSUInteger) countOfIndexesInRange: (NSRange)range
{
    if (_array == 0 || GSIArrayCount(_array) == 0)
    {
        return 0;
    }
    else
    {
        NSUInteger	count = GSIArrayCount(_array);
        NSUInteger	total = 0;
        NSUInteger	i = 0;
        
        while (i < count)
        {
            NSRange	r = GSIArrayItemAtIndex(_array, i).ext;
            
            r = NSIntersectionRange(r, range);
            total += r.length;
            i++;
        }
        return total;
    }
}

- (void) dealloc
{
    if (_array != 0)
    {
        GSIArrayClear(_array);
        NSZoneFree([self zone], _array);
        _data = 0;
    }
    [super dealloc];
}

- (NSUInteger) firstIndex
{
    if (_array == 0 || GSIArrayCount(_array) == 0)
    {
        return NSNotFound;
    }
    return GSIArrayItemAtIndex(_array, 0).ext.location;
}

- (NSUInteger) getIndexes: (NSUInteger*)aBuffer
                 maxCount: (NSUInteger)aCount
             inIndexRange: (NSRangePointer)aRange
{
    NSUInteger	pos;
    NSUInteger	i = 0;
    NSRange	r;
    NSRange	fullRange;
    
    if (aBuffer == 0)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@]: nul pointer argument",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (aRange == 0)
    {
        fullRange = (NSRange){0, NSNotFound};
        aRange = &fullRange;
    }
    else if (NSNotFound - aRange->length < aRange->location)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@]: Bad range",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (_array == 0 || GSIArrayCount(_array) == 0
        || (pos = posForIndex(_array, aRange->location)) >= GSIArrayCount(_array))
    {
        *aRange = NSMakeRange(NSMaxRange(*aRange), 0);
        return 0;
    }
    
    while (aRange->length > 0 && i < aCount && pos < GSIArrayCount(_array))
    {
        r = GSIArrayItemAtIndex(_array, pos).ext;
        if (aRange->location < r.location)
        {
            NSUInteger	skip = r.location - aRange->location;
            
            if (skip > aRange->length)
            {
                skip = aRange->length;
            }
            aRange->location += skip;
            aRange->length -= skip;
        }
        if (NSLocationInRange(aRange->location, r))
        {
            while (aRange->length > 0 && i < aCount
                   && aRange->location < NSMaxRange(r))
            {
                aBuffer[i++] = aRange->location++;
                aRange->length--;
            }
        }
        else
        {
        }
        pos++;
    }
    return i;
}

- (NSUInteger) hash
{
    return [self count];
}

- (NSUInteger) indexGreaterThanIndex: (NSUInteger)anIndex
{
    NSUInteger	pos;
    NSRange	r;
    
    if (anIndex++ == NSNotFound)
    {
        return NSNotFound;
    }
    if (_array == 0 || GSIArrayCount(_array) == 0
        || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
        return NSNotFound;
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    if (NSLocationInRange(anIndex, r))
    {
        return anIndex;
    }
    return r.location;
}

- (NSUInteger) indexGreaterThanOrEqualToIndex: (NSUInteger)anIndex
{
    NSUInteger	pos;
    NSRange	r;
    
    if (anIndex == NSNotFound)
    {
        return NSNotFound;
    }
    if (_array == 0 || GSIArrayCount(_array) == 0
        || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
        return NSNotFound;
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    if (NSLocationInRange(anIndex, r))
    {
        return anIndex;
    }
    return r.location;
}

- (NSUInteger) indexLessThanIndex: (NSUInteger)anIndex
{
    NSUInteger	pos;
    NSRange	r;
    
    if (anIndex-- == 0)
    {
        return NSNotFound;
    }
    if (_array == 0 || GSIArrayCount(_array) == 0
        || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
        return NSNotFound;
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    if (NSLocationInRange(anIndex, r))
    {
        return anIndex;
    }
    if (pos-- == 0)
    {
        return NSNotFound;
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    return NSMaxRange(r) - 1;
}

- (NSUInteger) indexLessThanOrEqualToIndex: (NSUInteger)anIndex
{
    NSUInteger	pos;
    NSRange	r;
    
    if (_array == 0 || GSIArrayCount(_array) == 0
        || (pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
        return NSNotFound;
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    if (NSLocationInRange(anIndex, r))
    {
        return anIndex;
    }
    if (pos-- == 0)
    {
        return NSNotFound;
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    return NSMaxRange(r) - 1;
}

- (id) init
{
    return self;
}

- (id) initWithIndex: (NSUInteger)anIndex
{
    if (anIndex == NSNotFound)
    {
        DESTROY(self);	// NSNotFound is not legal
    }
    else
    {
        self = [self initWithIndexesInRange: NSMakeRange(anIndex, 1)];
    }
    return self;
}

- (id) initWithIndexesInRange: (NSRange)aRange
{
    if (aRange.length > 0)
    {
        if (NSMaxRange(aRange) == NSNotFound)
        {
            DESTROY(self);	// NSNotFound is not legal
        }
        else
        {
            _data = (GSIArray)NSZoneMalloc([self zone], sizeof(GSIArray_t));
            GSIArrayInitWithZoneAndCapacity(_array, [self zone], 1);
            GSIArrayAddItem(_array, (GSIArrayItem)aRange);
        }
    }
    return self;
}

- (id) initWithIndexSet: (NSIndexSet*)aSet
{
    if (aSet == nil || [aSet isKindOfClass: [NSIndexSet class]] == NO)
    {
        DESTROY(self);
    }
    else
    {
        NSUInteger count = _other ? GSIArrayCount(_other) : 0;
        
        if (count > 0)
        {
            NSUInteger i;
            
            _data = (GSIArray)NSZoneMalloc([self zone], sizeof(GSIArray_t));
            GSIArrayInitWithZoneAndCapacity(_array, [self zone], count);
            for (i = 0; i < count; i++)
            {
                GSIArrayAddItem(_array, GSIArrayItemAtIndex(_other, i));
            }
        }
    }
    return self;
}

- (BOOL) intersectsIndexesInRange: (NSRange)aRange
{
    NSUInteger	p1;
    NSUInteger	p2;
    
    if (NSNotFound - aRange.length < aRange.location)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@]: Bad range",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (aRange.length == 0 || _array == 0 || GSIArrayCount(_array) == 0)
    {
        return NO;	// Empty
    }
    p1 = posForIndex(_array, aRange.location);
    p2 = posForIndex(_array, NSMaxRange(aRange) - 1);
    if (p1 != p2)
    {
        return YES;
    }
    if (p1 >= GSIArrayCount(_array))
    {
        return NO;
    }
    if (NSLocationInRange(aRange.location, GSIArrayItemAtIndex(_array, p1).ext))
    {
        return YES;
    }
    if (NSLocationInRange(NSMaxRange(aRange)-1,
                          GSIArrayItemAtIndex(_array, p1).ext))
    {
        return YES;
    }
    return NO;
}

- (BOOL) isEqual: (id)aSet
{
    if ([aSet isKindOfClass: [NSIndexSet class]] == YES)
    {
        return [self isEqualToIndexSet: aSet];
    }
    return NO;
}

- (BOOL) isEqualToIndexSet: (NSIndexSet*)aSet
{
    NSUInteger	count = _other ? GSIArrayCount(_other) : 0;
    
    if (count != (_array ? GSIArrayCount(_array) : 0))
    {
        return NO;
    }
    if (count > 0)
    {
        NSUInteger	i;
        
        for (i = 0; i < count; i++)
        {
            NSRange	rself = GSIArrayItemAtIndex(_array, i).ext;
            NSRange	rother = GSIArrayItemAtIndex(_other, i).ext;
            
            if (NSEqualRanges(rself, rother) == NO)
            {
                return NO;
            }
        }
    }
    return YES;
}

- (NSUInteger) lastIndex
{
    if (_array == 0 || GSIArrayCount(_array) == 0)
    {
        return NSNotFound;
    }
    return NSMaxRange(GSIArrayItemAtIndex(_array, GSIArrayCount(_array)-1).ext)-1;
}

- (id) mutableCopyWithZone: (NSZone*)aZone
{
    NSMutableIndexSet	*c = [NSMutableIndexSet allocWithZone: aZone];
    
    return [c initWithIndexSet: self];
}


- (void) enumerateIndexesInRange: (NSRange)range
                         options: (NSEnumerationOptions)opts
                      usingBlock: (GSIndexSetEnumerationBlock)aBlock
{
    NSUInteger    lastInRange;
    NSUInteger    startArrayIndex;
    NSUInteger    endArrayIndex;
    NSUInteger    i;
    NSUInteger    c;
    BOOL          isReverse = opts & NSEnumerationReverse;
    BLOCK_SCOPE BOOL      shouldStop = NO;
    
    if ((0 == [self count]) || (NSNotFound == range.location))
    {
        return;
    }
    
    startArrayIndex = posForIndex(_array, range.location);
    if (NSNotFound == startArrayIndex)
    {
        startArrayIndex = 0;
    }
    
    lastInRange = (NSMaxRange(range) - 1);
    endArrayIndex = MIN(posForIndex(_array, lastInRange),
                        (GSIArrayCount(_array) - 1));
    if (NSNotFound == endArrayIndex)
    {
        endArrayIndex = GSIArrayCount(_array) - 1;
    }
    
    if (isReverse)
    {
        i = endArrayIndex;
        c = startArrayIndex;
    }
    else
    {
        i = startArrayIndex;
        c = endArrayIndex;
    }
    
    GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    while (isReverse ? i >= c : i <= c)
    {
        NSRange r = GSIArrayItemAtIndex(_array, i).ext;
        NSUInteger innerI;
        NSUInteger innerC;
        
        if (isReverse)
        {
            innerI = NSMaxRange(r) - 1;
            innerC = r.location;
        }
        else
        {
            innerI = r.location;
            innerC = NSMaxRange(r) - 1;
        }
        while (isReverse ? innerI >= innerC : innerI <= innerC)
        {
            if ((innerI <= lastInRange) && (innerI >= range.location))
            {
                GS_DISPATCH_SUBMIT_BLOCK(enumQueueGroup, enumQueue,
                                         if (shouldStop) {return;}, return;,
                                         aBlock, innerI, &shouldStop);
            }
            if (shouldStop)
            {
                break;
            }
            if (isReverse)
            {
                if (0 == innerI)
                {
                    break;
                }
                innerI--;
            }
            else
            {
                innerI++;
            }
        }
        
        if (shouldStop)
        {
            break;
        }
        if (isReverse)
        {
            if (0 == i)
            {
                break;
            }
            i--;
        }
        else
        {
            i++;
        }
    }
    GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    
}

- (void) enumerateIndexesWithOptions: (NSEnumerationOptions)opts
                          usingBlock: (GSIndexSetEnumerationBlock)aBlock
{
    NSUInteger    firstIndex;
    NSUInteger    lastIndex;
    NSRange       range;
    
    firstIndex = [self firstIndex];
    if (NSNotFound == firstIndex)
    {
        return;
    }
    
    lastIndex = [self lastIndex];
    range = NSMakeRange(firstIndex, ((lastIndex - firstIndex) + 1));
    
    [self enumerateIndexesInRange: range
                          options: opts
                       usingBlock: aBlock];
}

- (void) enumerateIndexesUsingBlock: (GSIndexSetEnumerationBlock)aBlock
{
    [self enumerateIndexesWithOptions: 0
                           usingBlock: aBlock];
}
@end


@implementation	NSMutableIndexSet

#undef	_other
#define	_other	((GSIArray)(((NSMutableIndexSet*)aSet)->_data))

- (void) addIndex: (NSUInteger)anIndex
{
    [self addIndexesInRange: NSMakeRange(anIndex, 1)];
}

- (void) addIndexes: (NSIndexSet*)aSet
{
    NSUInteger	count = _other ? GSIArrayCount(_other) : 0;
    
    if (count > 0)
    {
        NSUInteger	i;
        
        for (i = 0; i < count; i++)
        {
            NSRange	r = GSIArrayItemAtIndex(_other, i).ext;
            
            [self addIndexesInRange: r];
        }
    }
}

- (void) addIndexesInRange: (NSRange)aRange
{
    NSUInteger	pos;
    
    if (NSNotFound - aRange.length < aRange.location)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@]: Bad range",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (aRange.length == 0)
    {
        return;
    }
    if (_array == 0)
    {
        _data = (GSIArray)NSZoneMalloc([self zone], sizeof(GSIArray_t));
        GSIArrayInitWithZoneAndCapacity(_array, [self zone], 1);
    }
    
    pos = posForIndex(_array, aRange.location);
    if (pos >= GSIArrayCount(_array))
    {
        /*
         * The start of the range to add lies beyond the existing
         * ranges, so we can simply append it.
         */
        GSIArrayAddItem(_array, (GSIArrayItem)aRange);
    }
    else
    {
        NSRange	r = GSIArrayItemAtIndex(_array, pos).ext;
        
        if (NSLocationInRange(aRange.location, r))
        {
            pos++;
        }
        GSIArrayInsertItem(_array, (GSIArrayItem)aRange, pos);
    }
    
    /*
     * Combine with the preceding ranges if possible.
     */
    while (pos > 0)
    {
        NSRange	r = GSIArrayItemAtIndex(_array, pos-1).ext;
        
        if (NSMaxRange(r) < aRange.location)
        {
            break;
        }
        if (NSMaxRange(r) >= NSMaxRange(aRange))
        {
            GSIArrayRemoveItemAtIndex(_array, pos--);
        }
        else
        {
            r.length += (NSMaxRange(aRange) - NSMaxRange(r));
            GSIArrayRemoveItemAtIndex(_array, pos--);
            GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
        }
    }
    
    /*
     * Combine with any following ranges where possible.
     */
    while (pos + 1 < GSIArrayCount(_array))
    {
        NSRange	r = GSIArrayItemAtIndex(_array, pos+1).ext;
        
        if (NSMaxRange(aRange) < r.location)
        {
            break;
        }
        GSIArrayRemoveItemAtIndex(_array, pos + 1);
        if (NSMaxRange(r) > NSMaxRange(aRange))
        {
            int	offset = NSMaxRange(r) - NSMaxRange(aRange);
            
            r = GSIArrayItemAtIndex(_array, pos).ext;
            r.length += offset;
            GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
        }
    }
    SANITY();
}

- (id) copyWithZone: (NSZone*)aZone
{
    NSIndexSet	*c = [NSIndexSet allocWithZone: aZone];
    
    return [c initWithIndexSet: self];
}

- (void) removeAllIndexes
{
    if (_array != 0)
    {
        GSIArrayRemoveAllItems(_array);
    }
}

- (void) removeIndex: (NSUInteger)anIndex
{
    [self removeIndexesInRange: NSMakeRange(anIndex, 1)];
}

- (void) removeIndexes: (NSIndexSet*)aSet
{
    NSUInteger	count = _other ? GSIArrayCount(_other) : 0;
    
    if (count > 0)
    {
        NSUInteger	i;
        
        for (i = 0; i < count; i++)
        {
            NSRange	r = GSIArrayItemAtIndex(_other, i).ext;
            
            [self removeIndexesInRange: r];
        }
    }
}

- (void) removeIndexesInRange: (NSRange)aRange
{
    NSUInteger	pos;
    NSRange	r;
    
    if (NSNotFound - aRange.length < aRange.location)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@]: Bad range",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (aRange.length == 0 || _array == 0
        || (pos = posForIndex(_array, aRange.location)) >= GSIArrayCount(_array))
    {
        return;	// Already empty
    }
    
    r = GSIArrayItemAtIndex(_array, pos).ext;
    if (r.location <= aRange.location)
    {
        if (r.location == aRange.location)
        {
            if (NSMaxRange(r) <= NSMaxRange(aRange))
            {
                /*
                 * Found range is entirely within range to remove,
                 * leaving next range to check at current position.
                 */
                GSIArrayRemoveItemAtIndex(_array, pos);
            }
            else
            {
                /*
                 * Range to remove is entirely within found range and
                 * overlaps the start of the found range ... shrink it
                 * and then we are finished.
                 */
                r.location += aRange.length;
                r.length -= aRange.length;
                GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
                pos++;
            }
        }
        else
        {
            if (NSMaxRange(r) <= NSMaxRange(aRange))
            {
                /*
                 * Range to remove overlaps the end of the found range.
                 * May also overlap next range ... so shorten found
                 * range and move on.
                 */
                r.length = aRange.location - r.location;
                GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
                pos++;
            }
            else
            {
                NSRange	next = r;
                
                /*
                 * Range to remove is entirely within found range and
                 * overlaps the middle of the found range ... split it.
                 * Then we are finished.
                 */
                next.location = NSMaxRange(aRange);
                next.length = NSMaxRange(r) - next.location;
                r.length = aRange.location - r.location;
                GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
                pos++;
                GSIArrayInsertItem(_array, (GSIArrayItem)next, pos);
                pos++;
            }
        }
    }
    
    /*
     * At this point we are guaranteed that, if there is a range at pos,
     * it does not start before aRange.location
     */
    while (pos < GSIArrayCount(_array))
    {
        NSRange	r = GSIArrayItemAtIndex(_array, pos).ext;
        
        if (NSMaxRange(r) <= NSMaxRange(aRange))
        {
            /*
             * Found range is entirely within range to remove ...
             * delete it.
             */
            GSIArrayRemoveItemAtIndex(_array, pos);
        }
        else
        {
            if (r.location < NSMaxRange(aRange))
            {
                /*
                 * Range to remove overlaps start of found range ...
                 * shorten it.
                 */
                r.length = NSMaxRange(r) - NSMaxRange(aRange);
                r.location = NSMaxRange(aRange);
                GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, pos);
            }
            /*
             * Found range extends beyond range to remove ... finished.
             */
            break;
        }
    }
    SANITY();
}

- (void) shiftIndexesStartingAtIndex: (NSUInteger)anIndex by: (NSInteger)amount
{
    if (amount != 0 && _array != 0 && GSIArrayCount(_array) > 0)
    {
        NSUInteger	c;
        NSUInteger	pos;
        
        if (amount > 0)
        {
            c = GSIArrayCount(_array);
            pos = posForIndex(_array, anIndex);
            
            if (pos < c)
            {
                NSRange	r = GSIArrayItemAtIndex(_array, pos).ext;
                
                /*
                 * If anIndex is within an existing range, we split
                 * that range so we have one starting at anIndex.
                 */
                if (r.location < anIndex)
                {
                    NSRange	t;
                    
                    /*
                     * Split the range.
                     */
                    t = NSMakeRange(r.location, anIndex - r.location);
                    GSIArrayInsertItem(_array, (GSIArrayItem)t, pos);
                    c++;
                    r.length = NSMaxRange(r) - anIndex;
                    r.location = anIndex;
                    GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, ++pos);
                }
                
                /*
                 * Shift all higher ranges to the right.
                 */
                while (c > pos)
                {
                    NSRange	r = GSIArrayItemAtIndex(_array, --c).ext;
                    
                    if (NSNotFound - amount <= r.location)
                    {
                        GSIArrayRemoveItemAtIndex(_array, c);
                    }
                    else if (NSNotFound - amount < NSMaxRange(r))
                    {
                        r.location += amount;
                        r.length = NSNotFound - r.location;
                        GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
                    }
                    else
                    {
                        r.location += amount;
                        GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
                    }
                }
            }
        }
        else
        {
            amount = -amount;
            
            /*
             * Delete range which will be overwritten.
             */
            if (amount >= anIndex)
            {
                [self removeIndexesInRange: NSMakeRange(0, anIndex)];
            }
            else
            {
                [self removeIndexesInRange:
                 NSMakeRange(anIndex - amount, amount)];
            }
            pos = posForIndex(_array, anIndex);
            
            /*
             * Now shift everything left into the hole we made.
             */
            c = GSIArrayCount(_array);
            while (c > pos)
            {
                NSRange	r = GSIArrayItemAtIndex(_array, --c).ext;
                
                if (NSMaxRange(r) <= amount)
                {
                    GSIArrayRemoveItemAtIndex(_array, c);
                }
                else if (r.location <= amount)
                {
                    r.length += (r.location - amount);
                    r.location = 0;
                    GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
                }
                else
                {
                    r.location -= amount;
                    GSIArraySetItemAtIndex(_array, (GSIArrayItem)r, c);
                }
            }
            if (pos > 0)
            {
                c = GSIArrayCount(_array);
                if (pos < c)
                {
                    NSRange	r0 = GSIArrayItemAtIndex(_array, pos - 1).ext;
                    NSRange	r1 = GSIArrayItemAtIndex(_array, pos).ext;
                    
                    if (NSMaxRange(r0) == r1.location)
                    {
                        r0.length += r1.length;
                        GSIArraySetItemAtIndex(_array, (GSIArrayItem)r0, pos - 1);
                        GSIArrayRemoveItemAtIndex(_array, pos);
                    }
                }
            }
        }
    }
    SANITY();
}

@end

@implementation	NSIndexSet (NSCharacterSet)
/* Extra method to let NSCharacterSet play with index sets more efficiently.
 */
- (NSUInteger) _gapGreaterThanIndex: (NSUInteger)anIndex
{
    NSUInteger	pos;
    NSRange	r;
    
    if (anIndex++ == NSNotFound)
    {
        return NSNotFound;
    }
    if (_array == 0 || GSIArrayCount(_array) == 0)
    {
        return NSNotFound;
    }
    
    if ((pos = posForIndex(_array, anIndex)) >= GSIArrayCount(_array))
    {
        r = GSIArrayItemAtIndex(_array, pos-1).ext;
        if (anIndex > NSMaxRange(r))
        {
            return NSNotFound;
        }
        return anIndex;	// anIndex is the gap after the last index.
    }
    r = GSIArrayItemAtIndex(_array, pos).ext;
    if (r.location > anIndex)
    {
        return anIndex;	// anIndex is in a gap between index ranges.
    }
    return NSMaxRange(r);	// Return start of gap after the index range.
}

@end

/* A subclass used to access a pre-generated table of information on the
 * stack or in other non-heap allocated memory.
 */
@interface	_GSStaticIndexSet : NSIndexSet
@end

@implementation	_GSStaticIndexSet
- (void) dealloc
{
    if (_array != 0)
    {
        /* Free the array without freeing its static content.
         */
        NSZoneFree([self zone], _array);
        _data = 0;
    }
    [super dealloc];
}

- (id) _initWithBytes: (const void*)bytes length: (NSUInteger)length
{
    NSAssert(length % sizeof(GSIArrayItem) == 0, NSInvalidArgumentException);
    NSAssert(length % __alignof__(GSIArrayItem) == 0, NSInvalidArgumentException);
    length /= sizeof(NSRange);
    _data = NSZoneMalloc([self zone], sizeof(GSIArray_t));
    _array->ptr = (GSIArrayItem*)bytes;
    _array->count = length;
    _array->cap = length;
    _array->old = length;
    _array->zone = 0;
    return self;
}

- (id) init
{
    return [self _initWithBytes: 0 length: 0];
}
@end
