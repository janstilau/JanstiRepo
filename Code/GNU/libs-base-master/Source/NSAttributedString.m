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

static SEL	isEqualSel;
static SEL	setAttributesRangeSel;
static SEL	attributesAtIndexRangeSel;
static SEL	allocWithZoneSel;
static SEL	initWithDictionarySel;
static SEL	addEntriesFromDictionarySel;
static SEL	setObjectForKeySel;
static SEL	releaseSel;
static SEL	removeObjectForKeySel;

static IMP	allocWithZoneImp;
static IMP	initWithDictionaryImp;
static IMP	addEntriesFromDictionaryImp;
static IMP	setObjectForKeyImp;
static IMP	releaseImp;
static IMP	removeObjectForKeyImp;

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
        
        isEqualSel = @selector(isEqual:);
        setAttributesRangeSel = @selector(setAttributes:range:);
        attributesAtIndexRangeSel = @selector(attributesAtIndex:effectiveRange:);
        allocWithZoneSel = @selector(allocWithZone:);
        initWithDictionarySel = @selector(initWithDictionary:);
        addEntriesFromDictionarySel = @selector(addEntriesFromDictionary:);
        setObjectForKeySel = @selector(setObject:forKey:);
        releaseSel = @selector(release);
        removeObjectForKeySel = @selector(removeObjectForKey:);
        
        allocWithZoneImp = [dictionaryClass methodForSelector: allocWithZoneSel];
        initWithDictionaryImp = [dictionaryClass instanceMethodForSelector: initWithDictionarySel];
        addEntriesFromDictionaryImp = [dictionaryClass instanceMethodForSelector: addEntriesFromDictionarySel];
        setObjectForKeyImp = [dictionaryClass instanceMethodForSelector: setObjectForKeySel];
        removeObjectForKeyImp = [dictionaryClass instanceMethodForSelector: removeObjectForKeySel];
        releaseImp = [dictionaryClass instanceMethodForSelector: releaseSel];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
    if (self == NSAttributedStringClass)
        return NSAllocateObject(GSAttributedStringClass, 0, z);
    else
        return NSAllocateObject(self, 0, z);
}

- (Class) classForCoder
{
    return NSAttributedStringClass;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
    if ([aCoder isByref] == NO)
        return self;
    return [super replacementObjectForPortCoder: aCoder];
}


//Creating an NSAttributedString
- (id) init
{
    return [self initWithString: @"" attributes: nil];
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

/**
 *  Initialize to aString with given attributes applying over full range of
 *  string.
 */
- (id) initWithString: (NSString*)aString attributes: (NSDictionary*)attributes
{
    //This is the designated initializer
    [self subclassResponsibility: _cmd];/* Primitive method! */
    return nil;
}

//Retrieving character information
/**
 *  Return length of the underlying string.
 */
- (NSUInteger) length
{
    return [[self string] length];
}

/*
 *  Returns attributes and values at index, and, if longestEffectiveRange
 *  is non-nil, this gets filled with the range over which the attribute-value
 *  set is the same as at index, clipped to rangeLimit.
 */
- (NSDictionary*) attributesAtIndex: (NSUInteger)index
              longestEffectiveRange: (NSRange*)aRange
                            inRange: (NSRange)rangeLimit
{
    NSDictionary	*attrDictionary, *tmpDictionary;
    NSRange	tmpRange;
    IMP		getImp;
    
    getImp = [self methodForSelector: attributesAtIndexRangeSel];
    attrDictionary = (*getImp)(self, attributesAtIndexRangeSel, index, aRange);
    if (aRange == 0) return attrDictionary;
    
    while (aRange->location > rangeLimit.location)
    {
        //Check extend range backwards
        tmpDictionary = (*getImp)(self, attributesAtIndexRangeSel, aRange->location-1, &tmpRange);
        if ([tmpDictionary isEqualToDictionary: attrDictionary])
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
        tmpDictionary = (*getImp)(self, attributesAtIndexRangeSel, NSMaxRange(*aRange), &tmpRange);
        if ([tmpDictionary isEqualToDictionary: attrDictionary])
        {
            aRange->length = NSMaxRange(tmpRange) - aRange->location;
        }
        else
        {
            break;
        }
    }
    *aRange = NSIntersectionRange(*aRange,rangeLimit);//Clip to rangeLimit
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
    eImp = (BOOL(*)(id,SEL,id))[attrValue methodForSelector: isEqualSel];
    getImp = [self methodForSelector: attributesAtIndexRangeSel];
    
    while (aRange->location > rangeLimit.location)
    {
        //Check extend range backwards
        tmpDictionary = (*getImp)(self, attributesAtIndexRangeSel,  aRange->location-1, &tmpRange);
        tmpAttrValue = [tmpDictionary objectForKey: attributeName];
        if (tmpAttrValue == attrValue
            || (eImp != 0 && (*eImp)(attrValue, isEqualSel, tmpAttrValue)))
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
        tmpDictionary = (*getImp)(self, attributesAtIndexRangeSel,  NSMaxRange(*aRange), &tmpRange);
        tmpAttrValue = [tmpDictionary objectForKey: attributeName];
        if (tmpAttrValue == attrValue
            || (eImp != 0 && (*eImp)(attrValue, isEqualSel, tmpAttrValue)))
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


/*
 富文本的相等判断非常苛刻, 是 字符串判断相等后, 属性判断相等, 属性的范围判断相等.
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


/*
 Subrange 的获取会有代价, 获取 subrange 字符串本身很简单, 但是, 将属性提取出来, 一点点设置到 subrange 字符串上需要.
 */
- (NSAttributedString*) attributedSubstringFromRange: (NSRange)aRange
{
    NSAttributedString	*newAttrString;
    NSString		*newSubstring;
    NSDictionary		*attrs;
    NSRange		range;
    unsigned		len = [self length];
    
    GS_RANGE_CHECK(aRange, len);
    
    newSubstring = [[self string] substringWithRange: aRange];
    
    attrs = [self attributesAtIndex: aRange.location effectiveRange: &range];
    range = NSIntersectionRange(range, aRange);
    if (NSEqualRanges(range, aRange) == YES)
    {
        newAttrString = [GSAttributedStringClass alloc];
        newAttrString = [newAttrString initWithString: newSubstring
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
        newAttrString = [m copy];
        RELEASE(m);
    }
    
    IF_NO_GC(AUTORELEASE(newAttrString));
    return newAttrString;
}

@end //NSAttributedString

/**
 *  Mutable version of [NSAttributedString].
 */
@implementation NSMutableAttributedString

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
    
    getImp = [self methodForSelector: attributesAtIndexRangeSel];
    attrDict = (*getImp)(self, attributesAtIndexRangeSel, aRange.location, &effectiveRange);
    
    if (effectiveRange.location < NSMaxRange(aRange))
    {
        IMP	setImp;
        
        setImp = [self methodForSelector: setAttributesRangeSel];
        
        [self beginEditing];
        while (effectiveRange.location < NSMaxRange(aRange))
        {
            effectiveRange = NSIntersectionRange(aRange, effectiveRange);
            
            newDict = (*allocWithZoneImp)(dictionaryClass, allocWithZoneSel,
                                      NSDefaultMallocZone());
            newDict = (*initWithDictionaryImp)(newDict, initWithDictionarySel, attrDict);
            (*setObjectForKeyImp)(newDict, setObjectForKeySel, value, name);
            (*setImp)(self, setAttributesRangeSel, newDict, effectiveRange);
            IF_NO_GC((*releaseImp)(newDict, releaseSel));
            
            if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
            {
                effectiveRange.location = NSMaxRange(aRange);// stop the loop...
            }
            else if (NSMaxRange(effectiveRange) < tmpLength)
            {
                attrDict = (*getImp)(self, attributesAtIndexRangeSel, NSMaxRange(effectiveRange),
                                     &effectiveRange);
            }
        }
        [self endEditing];
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
    
    getImp = [self methodForSelector: attributesAtIndexRangeSel];
    attrDict = (*getImp)(self, attributesAtIndexRangeSel, aRange.location, &effectiveRange);
    
    if (effectiveRange.location < NSMaxRange(aRange))
    {
        IMP	setImp;
        
        setImp = [self methodForSelector: setAttributesRangeSel];
        
        [self beginEditing];
        while (effectiveRange.location < NSMaxRange(aRange))
        {
            effectiveRange = NSIntersectionRange(aRange,effectiveRange);
            
            newDict = (*allocWithZoneImp)(dictionaryClass, allocWithZoneSel,
                                      NSDefaultMallocZone());
            newDict = (*initWithDictionaryImp)(newDict, initWithDictionarySel, attrDict);
            (*addEntriesFromDictionaryImp)(newDict, addEntriesFromDictionarySel, attributes);
            (*setImp)(self, setAttributesRangeSel, newDict, effectiveRange);
            IF_NO_GC((*releaseImp)(newDict, releaseSel));
            
            if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
            {
                effectiveRange.location = NSMaxRange(aRange);// stop the loop...
            }
            else if (NSMaxRange(effectiveRange) < tmpLength)
            {
                attrDict = (*getImp)(self, attributesAtIndexRangeSel, NSMaxRange(effectiveRange),
                                     &effectiveRange);
            }
        }
        [self endEditing];
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
    
    getImp = [self methodForSelector: attributesAtIndexRangeSel];
    attrDict = (*getImp)(self, attributesAtIndexRangeSel, aRange.location, &effectiveRange);
    
    if (effectiveRange.location < NSMaxRange(aRange))
    {
        IMP	setImp;
        
        setImp = [self methodForSelector: setAttributesRangeSel];
        
        [self beginEditing];
        while (effectiveRange.location < NSMaxRange(aRange))
        {
            effectiveRange = NSIntersectionRange(aRange,effectiveRange);
            
            newDict = (*allocWithZoneImp)(dictionaryClass, allocWithZoneSel,
                                      NSDefaultMallocZone());
            newDict = (*initWithDictionaryImp)(newDict, initWithDictionarySel, attrDict);
            (*removeObjectForKeyImp)(newDict, removeObjectForKeySel, name);
            (*setImp)(self, setAttributesRangeSel, newDict, effectiveRange);
            IF_NO_GC((*releaseImp)(newDict, releaseSel));
            
            if (NSMaxRange(effectiveRange) >= NSMaxRange(aRange))
            {
                effectiveRange.location = NSMaxRange(aRange);// stop the loop...
            }
            else if (NSMaxRange(effectiveRange) < tmpLength)
            {
                attrDict = (*getImp)(self, attributesAtIndexRangeSel, NSMaxRange(effectiveRange),
                                     &effectiveRange);
            }
        }
        [self endEditing];
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

- (void) replaceCharactersInRange: (NSRange)aRange
             withAttributedString: (NSAttributedString*)attributedString
{
    NSDictionary	*attrDict;
    NSString	*txtLength;
    unsigned	max;
    
    if (attributedString == nil)
    {
        [self replaceCharactersInRange: aRange withString: nil];
        return;
    }
    
    txtLength = [attributedString string];
    [self replaceCharactersInRange: aRange withString: txtLength];
    max = [txtLength length];
    
    if (max > 0) {
        unsigned	loc = 0;
        NSRange	effectiveRange = NSMakeRange(0, loc);
        NSRange	clipRange = NSMakeRange(0, max);
        IMP	getImp;
        IMP	setImp;
        
        getImp = [attributedString methodForSelector: attributesAtIndexRangeSel];
        setImp = [self methodForSelector: setAttributesRangeSel];
        /*
         一点点的把新的 attributes 设置上去.
         */
        while (loc < max) {
            NSRange	ownRange;
            attrDict = (*getImp)(attributedString, attributesAtIndexRangeSel, loc, &effectiveRange);
            ownRange = NSIntersectionRange(clipRange, effectiveRange);
            ownRange.location += aRange.location;
            (*setImp)(self, setAttributesRangeSel, attrDict, ownRange);
            loc = NSMaxRange(effectiveRange);
        }
    }
}


/**
 *  Replaces entire contents (so this object can be reused).
 */
- (void) setAttributedString: (NSAttributedString*)attributedString
{
    [self replaceCharactersInRange: NSMakeRange(0,[self length])
              withAttributedString: attributedString];
}

/** <override-dummy />
 *  Call before executing a collection of changes, for optimization.
 */
- (void) beginEditing
{
}

/** <override-dummy />
 *  Call after executing a collection of changes, for optimization.
 */
- (void) endEditing
{
}

@end //NSMutableAttributedString




/*
 * The GSMutableAttributedStringTracker class is a concrete subclass of
 * NSMutableString which keeps it's owner informed of any changes made
 * to it.
 */
@implementation GSMutableAttributedStringTracker

+ (NSMutableString*) stringWithOwner: (NSMutableAttributedString*)as
{
    GSMutableAttributedStringTracker	*str;
    NSZone	*z = NSDefaultMallocZone();
    
    str = (GSMutableAttributedStringTracker*) NSAllocateObject(self, 0, z);
    
    str->_owner = RETAIN(as);
    return AUTORELEASE(str);
}

- (void) dealloc
{
    RELEASE(_owner);
    [super dealloc];
}

- (NSUInteger) length
{
    return [[_owner string] length];
}

- (unichar) characterAtIndex: (NSUInteger)index
{
    return [[_owner string] characterAtIndex: index];
}

- (void)getCharacters: (unichar*)buffer
{
    [[_owner string] getCharacters: buffer];
}

- (void)getCharacters: (unichar*)buffer range: (NSRange)aRange
{
    [[_owner string] getCharacters: buffer range: aRange];
}

- (const char*) cString
{
    return [[_owner string] cString];
}

- (NSUInteger) cStringLength
{
    return [[_owner string] cStringLength];
}

- (NSStringEncoding) fastestEncoding
{
    return [[_owner string] fastestEncoding];
}

- (NSStringEncoding) smallestEncoding
{
    return [[_owner string] smallestEncoding];
}

- (int) _baseLength
{
    return [[_owner string] _baseLength];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    [[_owner string] encodeWithCoder: aCoder];
}

- (Class) classForCoder
{
    return [[_owner string] classForCoder];
}

- (void) replaceCharactersInRange: (NSRange)aRange
                       withString: (NSString*)aString
{
    [_owner replaceCharactersInRange: aRange withString: aString];
}

@end

