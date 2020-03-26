#import "common.h"
#import "GNUstepBase/Unicode.h"

#import "Foundation/NSAttributedString.h"
#import "Foundation/NSData.h"
#import "Foundation/NSException.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSRange.h"

@class	GSAttributedString;
@interface GSAttributedString : NSObject	// Help the compiler
@end
@class	GSMutableAttributedString;
@interface GSMutableAttributedString : NSObject	// Help the compiler
@end
@class	GSMutableDictionary;
@interface GSMutableDictionary : NSObject	// Help the compiler
@end
static Class	dictionaryClass = 0;

static SEL	equalSel;
static SEL	setAttributesInRangeSel;
static SEL	getAttriAtIndexWithEffctiveRangeSel;
static SEL	allocDictSel;
static SEL	initDictSel;
static SEL	addDictSel;
static SEL	setDictSel;
static SEL	relDictSel;
static SEL	remDictSel;

static IMP	allocDictImp;
static IMP	initDictImp;
static IMP	addDictImp;
static IMP	setDictImp;
static IMP	relDictImp;
static IMP	remDictImp;

@interface GSMutableAttributedStringTracker : NSMutableString
{
    NSMutableAttributedString	*_owner;
}
+ (NSMutableString*) stringWithOwner: (NSMutableAttributedString*)as;
@end

/**
 *  A string in which name-value pairs represented by an [NSDictionary] may
 *  be associated to ranges of characters.  Used for text rendering by the
 *  GUI/AppKit framework, in which fonts, sizes, etc. are stored under standard
 *  attributes in the dictionaries.
 *
 */
@implementation NSAttributedString

static Class NSAttributedStringClass;
static Class GSAttributedStringClass;
static Class NSMutableAttributedStringClass;
static Class GSMutableAttributedStringClass;

+ (void) initialize
{
    if (self == [NSAttributedString class])
    {
        NSAttributedStringClass = self;
        GSAttributedStringClass = [GSAttributedString class];
        NSMutableAttributedStringClass
        = [NSMutableAttributedString class];
        GSMutableAttributedStringClass
        = [GSMutableAttributedString class];
        dictionaryClass = [GSMutableDictionary class];
        
        equalSel = @selector(isEqual:);
        setAttributesInRangeSel = @selector(setAttributes:range:);
        getAttriAtIndexWithEffctiveRangeSel = @selector(attributesAtIndex:effectiveRange:);
        allocDictSel = @selector(allocWithZone:);
        initDictSel = @selector(initWithDictionary:);
        addDictSel = @selector(addEntriesFromDictionary:);
        setDictSel = @selector(setObject:forKey:);
        relDictSel = @selector(release);
        remDictSel = @selector(removeObjectForKey:);
        
        allocDictImp = [dictionaryClass methodForSelector: allocDictSel];
        initDictImp = [dictionaryClass instanceMethodForSelector: initDictSel];
        addDictImp = [dictionaryClass instanceMethodForSelector: addDictSel];
        setDictImp = [dictionaryClass instanceMethodForSelector: setDictSel];
        remDictImp = [dictionaryClass instanceMethodForSelector: remDictSel];
        relDictImp = [dictionaryClass instanceMethodForSelector: relDictSel];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
    if (self == NSAttributedStringClass)
        return NSAllocateObject(GSAttributedStringClass, 0, z);
    else
        return NSAllocateObject(self, 0, z);
}

//NSCopying protocol
- (id) copyWithZone: (NSZone*)zone
{
    if ([self isKindOfClass: [NSMutableAttributedString class]]
        || NSShouldRetainWithZone(self, zone) == NO)
        return [[GSAttributedStringClass allocWithZone: zone]
                initWithAttributedString: self];
    else
        return RETAIN(self);
}

//NSMutableCopying protocol
- (id) mutableCopyWithZone: (NSZone*)zone
{
    return [[GSMutableAttributedStringClass allocWithZone: zone]
            initWithAttributedString: self];
}

/**
 *  Initialize to aString with no attributes.
 */
- (id) initWithString: (NSString*)aString
{
    return [self initWithString: aString attributes: nil];
}

/**
 *  Initialize to copy of attributedString.
 */
- (id) initWithAttributedString: (NSAttributedString*)attributedString
{
    return [self initWithString: (NSString*)attributedString attributes: nil];
}

//Retrieving character information
/**
 *  Return length of the underlying string.
 */
- (NSUInteger) length
{
    return [[self string] length]; // 通过 stirng 获取到原始的文本, 然后返回文本的 length.
}

/**
 *  Returns attributes and values at index, and, if longestEffectiveRange
 *  is non-nil, this gets filled with the range over which the attribute-value
 *  set is the same as at index, clipped to rangeLimit.
 */
- (NSDictionary*) attributesAtIndex: (NSUInteger)index
              longestEffectiveRange: (NSRange*)outPutRangePointer
                            inRange: (NSRange)rangeLimit
{
    NSDictionary	*attrDictionary, *tmpDictionary;
    NSRange	tmpRange;
    IMP		getImp;
    getImp = [self methodForSelector: getAttriAtIndexWithEffctiveRangeSel];
    attrDictionary = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, index, outPutRangePointer);
    if (outPutRangePointer == 0)
        return attrDictionary;
    
    while (outPutRangePointer->location > rangeLimit.location)
    {
        //Check extend range backwards
        tmpDictionary = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, outPutRangePointer->location-1, &tmpRange);
        if ([tmpDictionary isEqualToDictionary: attrDictionary])
        {
            outPutRangePointer->length = NSMaxRange(*outPutRangePointer) - tmpRange.location;
            outPutRangePointer->location = tmpRange.location;
        }
        else
        {
            break;
        }
    }
    while (NSMaxRange(*outPutRangePointer) < NSMaxRange(rangeLimit))
    {
        //Check extend range forwards
        tmpDictionary = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, NSMaxRange(*outPutRangePointer), &tmpRange);
        if ([tmpDictionary isEqualToDictionary: attrDictionary])
        {
            outPutRangePointer->length = NSMaxRange(tmpRange) - outPutRangePointer->location;
        }
        else
        {
            break;
        }
    }
    *outPutRangePointer = NSIntersectionRange(*outPutRangePointer,rangeLimit);//Clip to rangeLimit
    return attrDictionary;
}

/**
 *  Returns value for given attribute at index, and, if effectiveRange is
 *  non-nil, this gets filled with a range over which this value holds.  This
 *  may not be the maximum range, depending on the implementation.
 */
- (id) attribute: (NSString*)attributeName
         atIndex: (NSUInteger)index
  effectiveRange: (NSRange*)aRange
{
    NSDictionary *tmpDictionary;
    id attrValue;
    
    tmpDictionary = [self attributesAtIndex: index effectiveRange: aRange];
    
    if (attributeName == nil)
    {
        if (aRange != 0)
        {
            *aRange = NSMakeRange(0,[self length]);
            /*
             * If attributeName is nil, then the attribute will not exist in the
             * entire text - therefore aRange of the entire text must be correct
             */
        }
        return nil;
    }
    attrValue = [tmpDictionary objectForKey: attributeName];
    return attrValue;
}

/**
 *  Returns value for given attribute at index, and, if longestEffectiveRange
 *  is non-nil, this gets filled with the range over which the attribute
 *  applies, clipped to rangeLimit.
 */
- (id) attribute: (NSString*)attributeName
         atIndex: (NSUInteger)index
longestEffectiveRange: (NSRange*)aRange
         inRange: (NSRange)rangeLimit
{
    NSDictionary	*tmpDictionary;
    id		attrValue;
    id		tmpAttrValue;
    NSRange	tmpRange;
    BOOL		(*eImp)(id,SEL,id);
    IMP		getImp;
    
    if (NSMaxRange(rangeLimit) > [self length])
    {
        [NSException raise: NSRangeException
                    format: @"RangeError in method %@ in class %@",
         NSStringFromSelector(_cmd), NSStringFromClass([self class])];
    }
    
    if (attributeName == nil)
        return nil;
    
    attrValue = [self attribute: attributeName
                        atIndex: index
                 effectiveRange: aRange];
    
    if (aRange == 0)
        return attrValue;
    
    /*
     * If attrValue == nil then eImp will be zero
     */
    eImp = (BOOL(*)(id,SEL,id))[attrValue methodForSelector: equalSel];
    getImp = [self methodForSelector: getAttriAtIndexWithEffctiveRangeSel];
    
    while (aRange->location > rangeLimit.location)
    {
        //Check extend range backwards
        tmpDictionary = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel,  aRange->location-1, &tmpRange);
        tmpAttrValue = [tmpDictionary objectForKey: attributeName];
        if (tmpAttrValue == attrValue
            || (eImp != 0 && (*eImp)(attrValue, equalSel, tmpAttrValue)))
        {
            aRange->length = NSMaxRange(*aRange) - tmpRange.location;
            aRange->location = tmpRange.location;
        }
        else
        {
            break;
        }
    }
    while (NSMaxRange(*aRange) < NSMaxRange(rangeLimit))
    {
        //Check extend range forwards
        tmpDictionary = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel,  NSMaxRange(*aRange), &tmpRange);
        tmpAttrValue = [tmpDictionary objectForKey: attributeName];
        if (tmpAttrValue == attrValue
            || (eImp != 0 && (*eImp)(attrValue, equalSel, tmpAttrValue)))
        {
            aRange->length = NSMaxRange(tmpRange) - aRange->location;
        }
        else
        {
            break;
        }
    }
    *aRange = NSIntersectionRange(*aRange,rangeLimit);//Clip to rangeLimit
    return attrValue;
}

//Comparing attributed strings
/**
 *  Returns whether all characters and attributes are equal between this
 *  string and otherString.
 */
- (BOOL) isEqualToAttributedString: (NSAttributedString*)otherString
{
    NSRange ownEffectiveRange,otherEffectiveRange;
    unsigned int length;
    NSDictionary *ownDictionary,*otherDictionary;
    BOOL result;
    
    if (!otherString)
        return NO;
    if (![[otherString string] isEqual: [self string]])
        return NO;
    
    length = [otherString length];
    if (length == 0)
        return YES;
    
    ownDictionary = [self attributesAtIndex: 0
                             effectiveRange: &ownEffectiveRange];
    otherDictionary = [otherString attributesAtIndex: 0
                                      effectiveRange: &otherEffectiveRange];
    result = YES;
    
    while (YES)
    {
        if (NSIntersectionRange(ownEffectiveRange, otherEffectiveRange).length > 0
            && ![ownDictionary isEqualToDictionary: otherDictionary])
        {
            result = NO;
            break;
        }
        if (NSMaxRange(ownEffectiveRange) < NSMaxRange(otherEffectiveRange))
        {
            ownDictionary = [self attributesAtIndex: NSMaxRange(ownEffectiveRange)
                                     effectiveRange: &ownEffectiveRange];
        }
        else
        {
            if (NSMaxRange(otherEffectiveRange) >= length)
            {
                break;//End of strings
            }
            otherDictionary = [otherString
                               attributesAtIndex: NSMaxRange(otherEffectiveRange)
                               effectiveRange: &otherEffectiveRange];
        }
    }
    return result;
}

- (BOOL) isEqual: (id)anObject
{
    if (anObject == self)
        return YES;
    if ([anObject isKindOfClass: NSAttributedStringClass])
        return [self isEqualToAttributedString: anObject];
    return NO;
}


//Extracting a substring
/**
 *  Returns substring with attribute information.
 */
- (NSAttributedString*) attributedSubstringFromRange: (NSRange)aRange
{
    NSAttributedString	*result;
    NSString		*newSubstring;
    NSDictionary		*attrs;
    NSRange		range;
    unsigned		len = [self length];
    
    newSubstring = [[self string] substringWithRange: aRange];
    
    attrs = [self attributesAtIndex: aRange.location effectiveRange: &range];
    range = NSIntersectionRange(range, aRange);
    if (NSEqualRanges(range, aRange) == YES)
    {
        result = [GSAttributedStringClass alloc];
        result = [result initWithString: newSubstring
                             attributes: attrs];
    }
    else
    {
        NSMutableAttributedString	*m;
        NSRange			rangeToSet = range;
        
        m = [GSMutableAttributedStringClass alloc];
        m = [m initWithString: newSubstring attributes: nil];
        rangeToSet.location = 0;
        [m setAttributes: attrs range: rangeToSet];
        while (NSMaxRange(range) < NSMaxRange(aRange))
        {
            attrs = [self attributesAtIndex: NSMaxRange(range)
                             effectiveRange: &range];
            rangeToSet = NSIntersectionRange(range, aRange);
            rangeToSet.location -= aRange.location;
            [m setAttributes: attrs range: rangeToSet];
        }
        result = [m copy];
        RELEASE(m);
    }
    
    IF_NO_GC(AUTORELEASE(result));
    return result;
}

@end //NSAttributedString

/**
 *  Mutable version of [NSAttributedString].
 */
@implementation NSMutableAttributedString

+ (id) allocWithZone: (NSZone*)z
{
    if (self == NSMutableAttributedStringClass)
        return NSAllocateObject(GSMutableAttributedStringClass, 0, z);
    else
        return NSAllocateObject(self, 0, z);
}

- (Class) classForCoder
{
    return NSMutableAttributedStringClass;
}

//Retrieving character information
/**
 *  Returns mutable version of the underlying string.
 */
- (NSMutableString*) mutableString
{
    return [GSMutableAttributedStringTracker stringWithOwner: self];
}

//Changing characters
/**
 *  Removes characters and attributes applying to them.
 */
- (void) deleteCharactersInRange: (NSRange)aRange
{
    [self replaceCharactersInRange: aRange withString: nil];
}

/**
 *  Adds attribute applying to given range.
 */
- (void) addAttribute: (NSString*)name value: (id)value range: (NSRange)aRange
{
    NSRange		effectiveRange;
    NSDictionary		*attrDict;
    NSMutableDictionary	*newDict;
    unsigned int		tmpLength;
    IMP			getImp;
    
    tmpLength = [self length];
    GS_RANGE_CHECK(aRange, tmpLength);
    
    getImp = [self methodForSelector: getAttriAtIndexWithEffctiveRangeSel];
    attrDict = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, aRange.location, &effectiveRange);
    
    if (effectiveRange.location < NSMaxRange(aRange))
    {
        IMP	setImp;
        
        setImp = [self methodForSelector: setAttributesInRangeSel];
        
        while (effectiveRange.location < NSMaxRange(aRange))
        {
            effectiveRange = NSIntersectionRange(aRange, effectiveRange);
            
            newDict = (*allocDictImp)(dictionaryClass, allocDictSel,
                                      NSDefaultMallocZone());
            newDict = (*initDictImp)(newDict, initDictSel, attrDict);
            (*setDictImp)(newDict, setDictSel, value, name);
            (*setImp)(self, setAttributesInRangeSel, newDict, effectiveRange);
            IF_NO_GC((*relDictImp)(newDict, relDictSel));
            
            if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
            {
                effectiveRange.location = NSMaxRange(aRange);// stop the loop...
            }
            else if (NSMaxRange(effectiveRange) < tmpLength)
            {
                attrDict = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, NSMaxRange(effectiveRange),
                                     &effectiveRange);
            }
        }
    }
}

/**
 *  Add attributes to apply over given range.
 */
- (void) addAttributes: (NSDictionary*)attributes range: (NSRange)aRange
{
    NSRange		effectiveRange;
    NSDictionary		*attrDict;
    NSMutableDictionary	*newDict;
    unsigned int		tmpLength;
    IMP			getImp;
    
    if (!attributes)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"attributes is nil in method -addAttributes:range: "
         @"in class NSMutableAtrributedString"];
    }
    tmpLength = [self length];
    if (NSMaxRange(aRange) > tmpLength)
    {
        [NSException raise: NSRangeException
                    format: @"RangeError in method -addAttribute:value:range: "
         @"in class NSMutableAttributedString"];
    }
    
    getImp = [self methodForSelector: getAttriAtIndexWithEffctiveRangeSel];
    attrDict = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, aRange.location, &effectiveRange);
    
    if (effectiveRange.location < NSMaxRange(aRange))
    {
        IMP	setImp;
        
        setImp = [self methodForSelector: setAttributesInRangeSel];
        
        while (effectiveRange.location < NSMaxRange(aRange))
        {
            effectiveRange = NSIntersectionRange(aRange,effectiveRange);
            
            newDict = (*allocDictImp)(dictionaryClass, allocDictSel,
                                      NSDefaultMallocZone());
            newDict = (*initDictImp)(newDict, initDictSel, attrDict);
            (*addDictImp)(newDict, addDictSel, attributes);
            (*setImp)(self, setAttributesInRangeSel, newDict, effectiveRange);
            IF_NO_GC((*relDictImp)(newDict, relDictSel));
            
            if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
            {
                effectiveRange.location = NSMaxRange(aRange);// stop the loop...
            }
            else if (NSMaxRange(effectiveRange) < tmpLength)
            {
                attrDict = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, NSMaxRange(effectiveRange),
                                     &effectiveRange);
            }
        }
    }
}

/**
 *  Removes given attribute from aRange.
 */
- (void) removeAttribute: (NSString*)name range: (NSRange)aRange
{
    NSRange		effectiveRange;
    NSDictionary		*attrDict;
    NSMutableDictionary	*newDict;
    unsigned int		tmpLength;
    IMP			getImp;
    
    tmpLength = [self length];
    GS_RANGE_CHECK(aRange, tmpLength);
    
    getImp = [self methodForSelector: getAttriAtIndexWithEffctiveRangeSel];
    attrDict = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, aRange.location, &effectiveRange);
    
    if (effectiveRange.location < NSMaxRange(aRange))
    {
        IMP	setImp;
        
        setImp = [self methodForSelector: setAttributesInRangeSel];
        
        while (effectiveRange.location < NSMaxRange(aRange))
        {
            effectiveRange = NSIntersectionRange(aRange,effectiveRange);
            
            newDict = (*allocDictImp)(dictionaryClass, allocDictSel,
                                      NSDefaultMallocZone());
            newDict = (*initDictImp)(newDict, initDictSel, attrDict);
            (*remDictImp)(newDict, remDictSel, name);
            (*setImp)(self, setAttributesInRangeSel, newDict, effectiveRange);
            IF_NO_GC((*relDictImp)(newDict, relDictSel));
            
            if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
            {
                effectiveRange.location = NSMaxRange(aRange);// stop the loop...
            }
            else if (NSMaxRange(effectiveRange) < tmpLength)
            {
                attrDict = (*getImp)(self, getAttriAtIndexWithEffctiveRangeSel, NSMaxRange(effectiveRange),
                                     &effectiveRange);
            }
        }
    }
}

//Changing characters and attributes
/**
 *  Appends attributed string to end of this one, preserving attributes.
 */
- (void) appendAttributedString: (NSAttributedString*)attributedString
{
    [self replaceCharactersInRange: NSMakeRange([self length],0)
              withAttributedString: attributedString];
}

/**
 *  Inserts attributed string within this one, preserving attributes.
 */
- (void) insertAttributedString: (NSAttributedString*)attributedString
                        atIndex: (NSUInteger)index
{
    [self replaceCharactersInRange: NSMakeRange(index,0)
              withAttributedString: attributedString];
}

/**
 *  Replaces substring and attributes.
 */
- (void) replaceCharactersInRange: (NSRange)aRange
             withAttributedString: (NSAttributedString*)attributedString
{
    NSDictionary	*attrDict;
    NSString	*tmpStr;
    unsigned	max;
    
    if (attributedString == nil)
    {
        [self replaceCharactersInRange: aRange withString: nil];
        return;
    }
    
    // 首先, 做的是字符串的替换的工作.
    tmpStr = [attributedString string];
    [self replaceCharactersInRange: aRange withString: tmpStr];
    max = [tmpStr length];
    
    if (max <= 0) { return; }
    unsigned    loc = 0;
    NSRange    effectiveRange = NSMakeRange(0, loc);
    NSRange    clipRange = NSMakeRange(0, max);
    IMP    getImp;
    IMP    setImp;
    getImp = [attributedString methodForSelector: getAttriAtIndexWithEffctiveRangeSel];
    setImp = [self methodForSelector: setAttributesInRangeSel];
    while (loc < max)
    {
        NSRange    ownRange;
        
        attrDict = (*getImp)(attributedString, getAttriAtIndexWithEffctiveRangeSel, loc, &effectiveRange);
        ownRange = NSIntersectionRange(clipRange, effectiveRange);
        ownRange.location += aRange.location;
        (*setImp)(self, setAttributesInRangeSel, attrDict, ownRange);
        loc = NSMaxRange(effectiveRange);
    }
}

/**
 */
- (void) replaceCharactersInRange: (NSRange)aRange
                       withString: (NSString*)aString
{
    [self subclassResponsibility: _cmd];// Primitive method!
}

/**
 *  Replaces entire contents (so this object can be reused).
 */
- (void) setAttributedString: (NSAttributedString*)attributedString
{
    [self replaceCharactersInRange: NSMakeRange(0,[self length])
              withAttributedString: attributedString];
}

@end //NSMutableAttributedString
