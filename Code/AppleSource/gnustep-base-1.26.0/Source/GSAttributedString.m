#import "common.h"
#import "GNUstepBase/GSLock.h"
#import "GNUstepBase/NSMutableString+GNUstepBase.h"
#import "Foundation/NSAttributedString.h"
#import "Foundation/NSException.h"
#import "Foundation/NSRange.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSProxy.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSNotification.h"

#define		SANITY_CHECKS	0


@interface GSAttributedString : NSAttributedString
{
    NSString		*_textChars;
    NSMutableArray	*_infoArray;
}

- (id) initWithString: (NSString*)aString
           attributes: (NSDictionary*)attributes;
- (NSString*) string;
- (NSDictionary*) attributesAtIndex: (NSUInteger)index
                     effectiveRange: (NSRange*)aRange;

@end

@interface GSMutableAttributedString : NSMutableAttributedString
{
    NSMutableString	*_textChars;
    NSMutableArray	*_infoArray;
    NSString		*_textProxy;
}

- (id) initWithString: (NSString*)aString
           attributes: (NSDictionary*)attributes;
- (NSString*) string;
- (NSDictionary*) attributesAtIndex: (NSUInteger)index
                     effectiveRange: (NSRange*)aRange;
- (void) setAttributes: (NSDictionary*) attributes
                 range: (NSRange)range;
- (void) replaceCharactersInRange: (NSRange)range
                       withString: (NSString*)aString;

@end



static BOOL     adding;

/* When caching attributes we make a shallow copy of the dictionary cached,
 * so that it is immutable and safe to cache.
 * However, we have a potential problem if the objects within the attributes
 * dictionary are themselves mutable, and something mutates them while they
 * are in the cache.  In this case we could items added while different and
 * then mutated to have the same contents, so we would not know which of
 * the equal dictionaries to remove.
 * The solution is to require dictionaries to be identical for removal.
 */
static inline BOOL
cacheEqual(id A, id B)
{
    if (YES == adding)
        return [A isEqualToDictionary: B];
    else
        return A == B;
}

#define	GSI_MAP_RETAIN_KEY(M, X)	
#define	GSI_MAP_RELEASE_KEY(M, X)	
#define	GSI_MAP_RETAIN_VAL(M, X)	
#define	GSI_MAP_RELEASE_VAL(M, X)	
#define	GSI_MAP_EQUAL(M, X,Y)	cacheEqual((X).obj, (Y).obj)
#define GSI_MAP_KTYPES	GSUNION_OBJ
#define GSI_MAP_VTYPES	GSUNION_NSINT
#define	GSI_MAP_NOCLEAN	1

#include "GNUstepBase/GSIMap.h"

static NSLock		*attrLock = nil;
static GSIMapTable_t	attrMap;
static SEL		lockSel;
static SEL		unlockSel;
static IMP		lockImp;
static IMP		unlockImp;

#define	ALOCK()	if (attrLock != nil) (*lockImp)(attrLock, lockSel)
#define	AUNLOCK() if (attrLock != nil) (*unlockImp)(attrLock, unlockSel)

@class  GSCachedDictionary;
@interface GSCachedDictionary : NSDictionary    // Help the compiler
@end
@protocol       GSCachedDictionary
- (void) _uncache;
@end

/* Add a dictionary to the cache - if it was not already there, return
 * the copy added to the cache, if it was, count it and return retained
 * object that was there.
 */
static NSDictionary*
cacheAttributes(NSDictionary *attrs)
{
    if (nil != attrs)
    {
        GSIMapNode	node;
        
        ALOCK();
        adding = YES;
        node = GSIMapNodeForKey(&attrMap, (GSIMapKey)((id)attrs));
        if (node == 0)
        {
            /* Shallow copy of dictionary, without copying objects ....
             * result in an immutable dictionary that can safely be cached.
             */
            attrs = [(NSDictionary*)[GSCachedDictionary alloc]
                     initWithDictionary: attrs copyItems: NO];
            GSIMapAddPair(&attrMap,
                          (GSIMapKey)((id)attrs), (GSIMapVal)(NSUInteger)1);
        }
        else
        {
            node->value.nsu++;
            attrs = node->key.obj;
        }
        AUNLOCK();
    }
    return attrs;
}

/* Decrement the count of a dictionary in the cache and release it.
 * If the count goes to zero, remove it from the cache.
 */
static void
unCacheAttributes(NSDictionary *attrs)
{
    if (nil != attrs)
    {
        GSIMapBucket  bucket;
        id<GSCachedDictionary> removed = nil;
        
        ALOCK();
        adding = NO;
        bucket = GSIMapBucketForKey(&attrMap, (GSIMapKey)((id)attrs));
        if (bucket != 0)
        {
            GSIMapNode     node;
            
            node = GSIMapNodeForKeyInBucket(&attrMap,
                                            bucket, (GSIMapKey)((id)attrs));
            if (node != 0)
            {
                if (--node->value.nsu == 0)
                {
                    removed = node->key.obj;
                    GSIMapRemoveNodeFromMap(&attrMap, bucket, node);
                    GSIMapFreeNode(&attrMap, node);
                }
            }
        }
        AUNLOCK();
        if (nil != removed)
        {
            [removed _uncache];
        }
    }
}



@interface	AttributeItem : NSObject {
@public
    unsigned	loc;
    NSDictionary	*attrs;
}

+ (AttributeItem*) newWithZone: (NSZone*)z value: (NSDictionary*)a at: (unsigned)l;

@end

@implementation	AttributeItem

+ (void) initialize
{
    if (nil == attrLock)
    {
        attrLock = [NSLock new];
        lockSel = @selector(lock);
        unlockSel = @selector(unlock);
        lockImp = [attrLock methodForSelector: lockSel];
        unlockImp = [attrLock methodForSelector: unlockSel];
        GSIMapInitWithZoneAndCapacity(&attrMap, NSDefaultMallocZone(), 32);
    }
}

/*
 * Called to record attributes at a particular location - the given attributes
 * dictionary must have been produced by 'cacheAttributes()' so that it is
 * already copied/retained and this method doesn't need to do it.
 */
+ (AttributeItem*) newWithZone: (NSZone*)z value: (NSDictionary*)a at: (unsigned)l;
{
    AttributeItem	*info = (AttributeItem*)NSAllocateObject(self, 0, z);
    
    info->loc = l;
    info->attrs = cacheAttributes(a);
    return info;
}

- (void) dealloc
{
    [self finalize];
    [super dealloc];
}

- (NSString*) description
{
    return [NSString stringWithFormat: @"Attributes at %u are - %@",
            loc, attrs];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    [aCoder encodeValueOfObjCType: @encode(unsigned) at: &loc];
    [aCoder encodeValueOfObjCType: @encode(id) at: &attrs];
}

- (void) finalize
{
    unCacheAttributes(attrs);
    attrs = nil;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    NSDictionary  *a;
    
    [aCoder decodeValueOfObjCType: @encode(unsigned) at: &loc];
    a = [aCoder decodeObject];
    attrs = cacheAttributes(a);
    return self;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
    return self;
}

@end



@implementation GSAttributedString

static	AttributeItem	*blank;

static Class	AttributeItemClass = 0;

static SEL	newWithValueAtSel;
static SEL	addObjectSel;
static SEL	countSel;
static SEL	insertObjectSel;
static SEL	objectAtSel;
static SEL	removeObjectAtSel;

static IMP	newWithValueAtImp;
static void	(*addObjectImp)(NSMutableArray*,SEL,id);
static unsigned (*countImp)(NSArray*,SEL);
static void	(*insetObjectAtImp)(NSMutableArray*,SEL,id,unsigned);
static IMP	objectAtImp;
static void	(*removeObjectAtImp)(NSMutableArray*,SEL,unsigned);

#define	NEWINFO(Z,O,L)	((*newWithValueAtImp)(AttributeItemClass, newWithValueAtSel, (Z), (O), (L)))
#define	INSOBJECT(O,I)	((*insetObjectAtImp)(_infoArray, insertObjectSel, (O), (I)))
#define	OBJECTAT(I)	((*objectAtImp)(_infoArray, objectAtSel, (I)))
#define	REMOVEAT(I)	((*removeObjectAtImp)(_infoArray, removeObjectAtSel, (I)))

static void
_setAttributesFrom(
                   NSAttributedString *attributedString,
                   NSRange aRange,
                   NSMutableArray *_infoArray)
{
    NSZone	*z = [_infoArray zone];
    NSRange	range;
    NSDictionary	*attr;
    AttributeItem	*info;
    unsigned	loc;
    
    [_infoArray removeAllObjects];
    
    if (aRange.length == 0)
    {
        attr = blank->attrs;
        range = aRange; /* Set to satisfy the loop condition below. */
    }
    else
    {
        attr = [attributedString attributesAtIndex: aRange.location
                                    effectiveRange: &range];
    }
    info = NEWINFO(z, attr, 0);
    [_infoArray addObject:info];
    
    while ((loc = NSMaxRange(range)) < NSMaxRange(aRange))
    {
        attr = [attributedString attributesAtIndex: loc
                                    effectiveRange: &range];
        info = NEWINFO(z, attr, loc - aRange.location);
        [_infoArray addObject:info];
        RELEASE(info);
    }
    
    // 上面的循环, 就是通过attributesAtIndex这个方法, 一点点的把属性提取出来, 然后放到 infoArray 中.
}

// 运用二分查找, 查找位置属性的过程.
inline static NSDictionary*
_attributesAtIndexEffectiveRange(
                                 unsigned int targetIndex,
                                 NSRange *effectRangePointer,
                                 unsigned int stringLength,
                                 NSMutableArray *_infoArray,
                                 unsigned int *foundIndex)
{
    unsigned	low, high, attributeItemCount, currentIndex, nextLoc;
    AttributeItem	*found = nil;
    
    attributeItemCount = (*countImp)(_infoArray, countSel);
    high = attributeItemCount - 1; // 所以, infoArray 里面必须要有元素, 在 init 方法里面, 插入了一个代表无属性的空值.
    
    if (targetIndex >= stringLength)
    {
        if (targetIndex == stringLength)
        {
            found = OBJECTAT(high);
            if (foundIndex != 0)
            {
                *foundIndex = high;
            }
            if (effectRangePointer != 0)
            {
                effectRangePointer->location = found->loc;
                effectRangePointer->length = stringLength - found->loc;
            }
            return found->attrs;
        }
        [NSException raise: NSRangeException
                    format: @"index is out of range in function "
         @"_attributesAtIndexEffectiveRange()"];
        // 这里就是一个特殊判断, 如果是要最后一个位置的属性, 就直接找到最后一个位置的属性返回.
    }
    
    /*
     * Binary search for efficiency in huge attributed strings
     */
    low = 0;
    while (low <= high)
    {
        currentIndex = (low + high) / 2;
        found = OBJECTAT(currentIndex);
        if (found->loc > targetIndex)
        {
            high = currentIndex - 1; // 这里还是没找到, 所以上边界-1
        } else {
            if (currentIndex >= attributeItemCount - 1) {
                nextLoc = stringLength;
            } else {
                AttributeItem	*inf = OBJECTAT(currentIndex + 1);
                nextLoc = inf->loc;
            }
            if (found->loc == targetIndex || targetIndex < nextLoc) // 如果, 下一个属性的 location 比 taget大了, 这才算找到了.
            {
                //Found
                if (effectRangePointer != 0)
                {
                    effectRangePointer->location = found->loc;
                    effectRangePointer->length = nextLoc - found->loc;
                }
                if (foundIndex != 0)
                {
                    *foundIndex = currentIndex;
                }
                return found->attrs;
            } else
            {
                low = currentIndex + 1;
            }
        }
    }
    NSCAssert(NO,@"Error in binary search algorithm");
    return nil;
}

+ (void) initialize
{
    if (AttributeItemClass == 0)
    {
        NSMutableArray	*a;
        NSDictionary	*d;
        
        newWithValueAtSel = @selector(newWithZone:value:at:);
        addObjectSel = @selector(addObject:);
        countSel = @selector(count);
        insertObjectSel = @selector(insertObject:atIndex:);
        objectAtSel = @selector(objectAtIndex:);
        removeObjectAtSel = @selector(removeObjectAtIndex:);
        
        AttributeItemClass = [AttributeItem class];
        newWithValueAtImp = [AttributeItemClass methodForSelector: newWithValueAtSel];
        
        d = [NSDictionary new];
        blank = NEWINFO(NSDefaultMallocZone(), d, 0);
        [[NSObject leakAt: &blank] release];
        RELEASE(d);
        
        a = [NSMutableArray allocWithZone: NSDefaultMallocZone()];
        a = [a initWithCapacity: 1];
        addObjectImp = (void (*)(NSMutableArray*,SEL,id))[a methodForSelector: addObjectSel];
        countImp = (unsigned (*)(NSArray*,SEL))[a methodForSelector: countSel];
        insetObjectAtImp = (void (*)(NSMutableArray*,SEL,id,unsigned))
        [a methodForSelector: insertObjectSel];
        objectAtImp = [a methodForSelector: objectAtSel];
        removeObjectAtImp = (void (*)(NSMutableArray*,SEL,unsigned))
        [a methodForSelector: removeObjectAtSel];
        RELEASE(a);
    }
    [[NSObject leakAt: &attrLock] release];
}

- (id) initWithString: (NSString*)aString
           attributes: (NSDictionary*)attributes
{
    NSZone	*z = [self zone];
    _infoArray = [[NSMutableArray allocWithZone: z] initWithCapacity: 1];
    if (aString != nil && [aString isKindOfClass: [NSAttributedString class]])
    {
        NSAttributedString	*attributeString = (NSAttributedString*)aString;
        unsigned			len;
        aString = [attributeString string];
        len = [aString length];
        _setAttributesFrom(attributeString, NSMakeRange(0, len), _infoArray);
    } else
    {
        AttributeItem	*info;
        
        if (attributes == nil)
        {
            attributes = blank->attrs;
        }
        info = NEWINFO(z, attributes, 0);
        [_infoArray addObject:info];
        RELEASE(info);
    }
    
    // 上面的操作, 就是填充 infoArray, 如果传入的不是一个 attributedString, 就传入空.
    if (aString == nil)
        _textChars = @"";
    else
        _textChars = [aString copyWithZone: z]; // 这里会有一个 copy 的操作. 所以, 原有的类和现在的类是两个字符串.
    return self;
}

- (NSString*)string // 所以, 富文本的 string 就是根据它存储的 string 进行了一份拷贝而已.
{
    return AUTORELEASE([_textChars copyWithZone: NSDefaultMallocZone()]);
}

- (NSDictionary*) attributesAtIndex: (NSUInteger)index
                     effectiveRange: (NSRange*)rangePointer
{
    return _attributesAtIndexEffectiveRange(
                                            index, rangePointer, [_textChars length], _infoArray, NULL);
}

- (void) dealloc
{
    RELEASE(_textChars);
    RELEASE(_infoArray);
    [super dealloc];
}


// The superclass implementation is correct but too slow
- (NSUInteger) length
{
    return [_textChars length];
}

@end


@implementation GSMutableAttributedString

+ (void) initialize
{
    [GSAttributedString class];	// Ensure immutable class is initialised
}

- (id) initWithString: (NSString*)aString
           attributes: (NSDictionary*)attributes
{
    NSZone	*z = [self zone];
    
    _infoArray = [[NSMutableArray allocWithZone: z] initWithCapacity: 1];
    if (aString != nil && [aString isKindOfClass: [NSAttributedString class]])
    {
        NSAttributedString	*as = (NSAttributedString*)aString;
        
        aString = [as string];
        _setAttributesFrom(as, NSMakeRange(0, [aString length]), _infoArray);
    } else {
        AttributeItem	*info;
        
        if (attributes == nil)
        {
            attributes = blank->attrs;
        }
        info = NEWINFO(z, attributes, 0);
        [_infoArray addObject:info];
        RELEASE(info);
    }
    /* WARNING ... NSLayoutManager depends on the fact that we create the
     * _textChars instance variable by copying the aString argument to get
     * its own string subclass into the attributed string.
     */
    if (aString == nil)
        _textChars = [[NSMutableString allocWithZone: z] init];
    else
        _textChars = [aString mutableCopyWithZone: z];
    return self;
}

- (NSString*) string
{
    /* NB. This method is SUPPOSED to return a proxy to the mutable string!
     * This is a performance feature documented ifor OSX.
     */
    if (_textProxy == nil)
    {
        _textProxy = [[_textChars immutableProxy] retain];
    }
    return _textProxy;
}

- (NSDictionary*) attributesAtIndex: (NSUInteger)index
                     effectiveRange: (NSRange*)aRange
{
    return _attributesAtIndexEffectiveRange(
                                            index, aRange, [_textChars length], _infoArray, nil);
}

/*
 *	Primitive method! Sets attributes and values for a given range of
 *	characters, replacing any previous attributes and values for that
 *	range.
 *
 *	Sets the attributes for the characters in aRange to attributes.
 *	These new attributes replace any attributes previously associated
 *	with the characters in aRange. Raises an NSRangeException if any
 *	part of aRange lies beyond the end of the receiver's characters.
 *	See also: - addAtributes: range: , - removeAttributes: range:
 */
- (void) setAttributes: (NSDictionary*)attributes
                 range: (NSRange)range
{
    unsigned	stringLength;
    unsigned	arrayIndex = 0;
    unsigned	currentAttriItemSize;
    NSRange	effectiveRange = NSMakeRange(0, NSNotFound);
    unsigned	endIndex, beginIndex;
    NSDictionary	*attrs;
    NSZone	*z = [self zone];
    AttributeItem	*info;
    
    if (range.length == 0)
    {
        return;
    }
    if (attributes == nil)
    {
        attributes = blank->attrs; // 如果, 没有 attributes, 就用默认的空属性.
    }
    stringLength = [_textChars length];
    currentAttriItemSize = (*countImp)(_infoArray, countSel);
    beginIndex = range.location;
    endIndex = NSMaxRange(range);
    if (endIndex < stringLength)
    {
        attrs = _attributesAtIndexEffectiveRange(
                                                 endIndex, &effectiveRange, stringLength, _infoArray, &arrayIndex);
        if (attrs == attributes)
        {
            /* The located range has the same attributes as us - so we can
             * extend our range to include it.
             */
            if (effectiveRange.location < beginIndex)
            {
                beginIndex = effectiveRange.location;
            }
            if (NSMaxRange(effectiveRange) > endIndex)
            {
                endIndex = NSMaxRange(effectiveRange);
            }
        }
        else if (effectiveRange.location > beginIndex)
        {
            /*
             * The located range also starts at or after our range.
             */
            info = OBJECTAT(arrayIndex);
            info->loc = endIndex;
            arrayIndex--;
        }
        else if (NSMaxRange(effectiveRange) > endIndex)
        {
            /*
             * The located range ends after our range.
             * Create a subrange to go from our end to the end of the old range.
             */
            info = NEWINFO(z, attrs, endIndex);
            arrayIndex++;
            INSOBJECT(info, arrayIndex);
            RELEASE(info);
            arrayIndex--;
        }
    }
    else
    {
        arrayIndex = currentAttriItemSize - 1;
    }
    
    // 上面的操作, 就是更新 infoArray 的数据, 并且计算出要删除的元素的位置.
    
    /*
     * Remove any ranges completely within ours
     */
    while (arrayIndex > 0)
    {
        info = OBJECTAT(arrayIndex-1);
        if (info->loc < beginIndex)
            break;
        REMOVEAT(arrayIndex);
        arrayIndex--;
    }
    
    /*
     * Use the location/attribute info in the current slot if possible,
     * otherwise, add a new slot and use that.
     */
    // 将新的 attributes 放到 infoArray 中.
    info = OBJECTAT(arrayIndex);
    if (info->loc >= beginIndex)
    {
        info->loc = beginIndex;
        if (info->attrs != attributes)
        {
            unCacheAttributes(info->attrs);
            info->attrs = cacheAttributes(attributes);
        }
    }
    else if (info->attrs != attributes)
    {
        arrayIndex++;
        info = NEWINFO(z, attributes, beginIndex);
        INSOBJECT(info, arrayIndex);
        RELEASE(info);
    }
}

// 具体的实现没看, 但是做了两件事情, 1 是字符串的替换, 2 是属性的设置, 现在的思路是, 被替换的位置的前面一个字符的 attributes 是什么, 就会延续到新插入字符中.
- (void) replaceCharactersInRange: (NSRange)range
                       withString: (NSString*)aString
{
    unsigned	tmpLength;
    unsigned	arrayIndex = 0;
    unsigned	arraySize;
    NSRange	effectiveRange = NSMakeRange(0, NSNotFound);
    AttributeItem	*info;
    int		moveLocations;
    unsigned	start;
    
    if (aString == nil)
    {
        aString = @"";
    }
    tmpLength = [_textChars length];
    if (range.location == tmpLength)
    {
        /*
         * Special case - replacing a zero length string at the end
         * simply appends the new string and attributes are inherited.
         */
        [_textChars appendString: aString];
        goto finish;
    }
    
    arraySize = (*countImp)(_infoArray, countSel);
    if (arraySize == 1)
    {
        /*
         * Special case - if the string has only one set of attributes
         * then the replacement characters will get them too.
         */
        [_textChars replaceCharactersInRange: range withString: aString];
        goto finish;
    }
    
    /*
     * Get the attributes to associate with our replacement string.
     * Should be those of the first character replaced.
     * If the range replaced is empty, we use the attributes of the
     * previous character (if possible).
     */
    if (range.length == 0 && range.location > 0)
        start = range.location - 1;
    else
        start = range.location;
    _attributesAtIndexEffectiveRange(start, &effectiveRange,
                                     tmpLength, _infoArray, &arrayIndex);
    
    moveLocations = [aString length] - range.length;
    
    arrayIndex++;
    if (NSMaxRange(effectiveRange) < NSMaxRange(range))
    {
        /*
         * Remove all range info for ranges enclosed within the one
         * we are replacing.  Adjust the start point of a range that
         * extends beyond ours.
         */
        info = OBJECTAT(arrayIndex);
        if (info->loc < NSMaxRange(range))
        {
            unsigned int	next = arrayIndex + 1;
            
            while (next < arraySize)
            {
                AttributeItem	*n = OBJECTAT(next);
                
                if (n->loc <= NSMaxRange(range))
                {
                    REMOVEAT(arrayIndex);
                    arraySize--;
                    info = n;
                }
                else
                {
                    break;
                }
            }
        }
        if (NSMaxRange(range) < [_textChars length])
        {
            info->loc = NSMaxRange(range);
        }
        else
        {
            REMOVEAT(arrayIndex);
            arraySize--;
        }
    }
    
    /*
     * If we are replacing a range with a zero length string and the
     * range we are using matches the range replaced, then we must
     * remove it from the array to avoid getting a zero length range.
     */
    if ((moveLocations + range.length) == 0)
    {
        _attributesAtIndexEffectiveRange(start, &effectiveRange,
                                         tmpLength, _infoArray, &arrayIndex);
        arrayIndex++;
        
        if (effectiveRange.location == range.location
            && effectiveRange.length == range.length)
        {
            arrayIndex--;
            if (arrayIndex != 0 || arraySize > 1)
            {
                REMOVEAT(arrayIndex);
                arraySize--;
            }
            else
            {
                info = OBJECTAT(0);
                unCacheAttributes(info->attrs);
                info->attrs = cacheAttributes(blank->attrs);
                info->loc = NSMaxRange(range);
            }
        }
    }
    
    /*
     * Now adjust the positions of the ranges following the one we are using.
     */
    while (arrayIndex < arraySize)
    {
        info = OBJECTAT(arrayIndex);
        info->loc += moveLocations;
        arrayIndex++;
    }
    [_textChars replaceCharactersInRange: range withString: aString];
finish:
    
}

- (void) dealloc
{
    [_textProxy release];
    RELEASE(_textChars);
    RELEASE(_infoArray);
    [super dealloc];
}

// The superclass implementation is correct but too slow
- (NSUInteger) length
{
    return [_textChars length];
}

@end


