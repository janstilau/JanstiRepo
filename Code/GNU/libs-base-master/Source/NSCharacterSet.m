#import "common.h"
#import "GSPThread.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSException.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSIndexSet.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSData.h"

#undef	GNUSTEP_INDEX_CHARSET

#import "NSCharacterSetData.h"

#define GSUNICODE_MAX	1114112
#define GSBITMAP_SIZE	8192
#define GSBITMAP_MAX	139264

#ifndef GSSETBIT
#define GSSETBIT(a,i)     ((a) |= 1<<(i))
#define GSCLRBIT(a,i)     ((a) &= ~(1<<(i)))
#define GSISSET(a,i)      ((a) & (1<<(i)))
#endif

@interface _GSIndexCharSet : NSCharacterSet
{
    NSMutableIndexSet	*indexes;
}
- (NSIndexSet*) _indexes;
- (id) initWithBitmap: (NSData*)d;
@end

@interface _GSMutableIndexCharSet : NSMutableCharacterSet
{
    NSMutableIndexSet	*indexes;
}
@end

@interface	NSDataStatic : NSData	// Help the compiler
@end

/* Private class from NSIndexSet.m
 */
@interface	_GSStaticIndexSet : NSIndexSet
- (id) _initWithBytes: (const void*)bytes length: (NSUInteger)length;
@end

@interface NSBitmapCharSet : NSCharacterSet
{
    const unsigned char	*_data;
    unsigned		_length;
    NSData		*_obj;
    unsigned		_known;
    unsigned		_present;
}
- (id) initWithBitmap: (NSData*)bitmap;
@end

@interface NSMutableBitmapCharSet : NSMutableCharacterSet
{
    unsigned char		*_data;
    unsigned		_length;
    NSMutableData		*_obj;
    unsigned		_known;
    unsigned		_present;
}
- (id) initWithBitmap: (NSData*)bitmap;
@end

@implementation NSBitmapCharSet

- (NSData*) bitmapRepresentation
{
    unsigned	i = 17;
    
    while (i > 0 && [self hasMemberInPlane: i-1] == NO)
    {
        i--;
    }
    i *= GSBITMAP_SIZE;
    if (GSBITMAP_SIZE == i)
    {
        /* In the base plane, find the number of used bytes, so we don't
         * produce a bitmap that is longer than necessary.
         */
        if (_length < i)
        {
            i = _length;
        }
        while (i > 0 && 0 == _data[i - 1])
        {
            i--;
        }
    }
    if (i < _length)
    {
        return [NSData dataWithBytes: _data length: i];
    }
    return _obj;
}

/*
 最最重要的方法, 各个子类, 要实现该方法. 一般来说, 要和自己的内存数据相关比较.
 不太明白, 这个到底是怎么实现的, 不过是和自己的数据进行判断.
 */
- (BOOL) characterIsMember: (unichar)aCharacter
{
    unsigned	byte = aCharacter/8;
    
    if (byte < _length && GSISSET(_data[byte], aCharacter % 8))
    {
        return YES;
    }
    return NO;
}

- (Class) classForCoder
{
    return [self class];
}

- (void) dealloc
{
    DESTROY(_obj);
    [super dealloc];
}

- (BOOL) hasMemberInPlane: (uint8_t)aPlane
{
    unsigned	bit;
    
    if (aPlane > 16)
    {
        return NO;
    }
    bit = (1 << aPlane);
    if (_known & bit)
    {
        if (_present & bit)
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    if (aPlane * GSBITMAP_SIZE < _length)
    {
        unsigned	i = GSBITMAP_SIZE * aPlane;
        unsigned	e = GSBITMAP_SIZE * (aPlane + 1);
        
        while (i < e)
        {
            if (_data[i] != 0)
            {
                _present |= bit;
                _known |= bit;
                return YES;
            }
            i++;
        }
    }
    _present &= ~bit;
    _known |= bit;
    return NO;
}

- (id) init
{
    return [self initWithBitmap: nil];
}

- (id) initWithBitmap: (NSData*)bitmap
{
    unsigned	length = [bitmap length];
    
    if (length > GSBITMAP_MAX)
    {
        NSLog(@"attempt to initialize character set with invalid bitmap");
        [self dealloc];
        return nil;
    }
    if (bitmap == nil)
    {
        bitmap = [NSData data];
    }
    ASSIGNCOPY(_obj, bitmap);
    _length = length;
    _data = [_obj bytes];
    return self;
}

/*
 - (BOOL) longCharacterIsMember: (UTF32Char)aCharacter
 {
 unsigned	byte = aCharacter/8;
 
 if (aCharacter >= GSUNICODE_MAX)
 {
 [NSException raise: NSInvalidArgumentException
 format: @"[%@-%@] argument (0x%08x) is too large",
 NSStringFromClass([self class]), NSStringFromSelector(_cmd),
 aCharacter];
 }
 if (byte < _length && GSISSET(_data[byte], aCharacter % 8))
 {
 return YES;
 }
 return NO;
 }
 */
@end

@implementation NSMutableBitmapCharSet

+ (void) initialize
{
    if (self == [NSMutableBitmapCharSet class])
    {
        [self setVersion: 1];
        GSObjCAddClassBehavior(self, [NSBitmapCharSet class]);
    }
}

- (void) addCharactersInRange: (NSRange)aRange
{
    NSUInteger	i;
    NSUInteger	m;
    NSUInteger	b;
    
    m = NSMaxRange(aRange);
    
    /* Make space if needed.
     * Use exact size if we have nothing beyond the base plane,
     * otherwise round up to a plane boundary.
     */
    b = (m - 1) / 8;
    if (b >= _length)
    {
        if (b < GSBITMAP_SIZE)
        {
            _length = b + 1;
        }
        else
        {
            while (b >= _length)
            {
                _length += GSBITMAP_SIZE;
            }
        }
        [_obj setLength: _length];
        _data = [_obj mutableBytes];
    }
    
    /* Fill the first byte in the range.
     */
    i = aRange.location;
    b = i / 8;
    while (i % 8 != 0 && i < m)
    {
        GSSETBIT(_data[b], i % 8);
        i++;
    }
    
    /* Set any complete bytes in the range.
     */
    b = (m - i) / 8;
    if (b > 0)
    {
        memset(&_data[i / 8], 0xff, b);
        i += b * 8;
    }
    
    /* Partial set of any bits needed in the last byte.
     */
    b = i / 8;
    while (i < m)
    {
        GSSETBIT(_data[b], i % 8);
        i++;
    }
    _known = 0;	// Invalidate cache
}

/*
 就是把 aString 里面的数据, 加到 data 里面.
 */
- (void) addCharactersInString: (NSString*)aString
{
    unsigned   length;
    
    length = [aString length];
    if (length > 0)
    {
        NSUInteger i;
        unsigned	max = _length;
        unichar	(*get)(id, SEL, NSUInteger);
        
        get = (unichar (*)(id, SEL, NSUInteger))
        [aString methodForSelector: @selector(characterAtIndex:)];
        
        /* Determine size of bitmap needed.
         */
        for (i = 0; i < length; i++)
        {
            unichar	letter;
            unichar	second;
            unsigned	byte;
            
            letter = (*get)(aString, @selector(characterAtIndex:), i);
            // Convert a surrogate pair if necessary
            if (letter >= 0xd800 && letter <= 0xdbff && i < length-1
                && (second = (*get)(aString, @selector(characterAtIndex:), i+1))
                >= 0xdc00 && second <= 0xdfff)
            {
                i++;
                letter = ((letter - 0xd800) << 10)
                + (second - 0xdc00) + 0x0010000;
            }
            byte = letter/8;
            if (byte >= max)
            {
                max = byte;
            }
        }
        /* Make space if needed.
         * Use exact size if we have nothing beyond the base plane,
         * otherwise round up to a plane boundary.
         */
        if (max >= _length)
        {
            if (max < GSBITMAP_SIZE)
            {
                _length = max + 1;
            }
            else
            {
                while (max >= _length)
                {
                    _length += GSBITMAP_SIZE;
                }
            }
            [_obj setLength: _length];
            _data = [_obj mutableBytes];
        }
        
        for (i = 0; i < length; i++)
        {
            unichar	letter;
            unichar	second;
            unsigned	byte;
            
            letter = (*get)(aString, @selector(characterAtIndex:), i);
            // Convert a surrogate pair if necessary
            if (letter >= 0xd800 && letter <= 0xdbff && i < length-1
                && (second = (*get)(aString, @selector(characterAtIndex:), i+1))
                >= 0xdc00 && second <= 0xdfff)
            {
                i++;
                letter = ((letter - 0xd800) << 10)
                + (second - 0xdc00) + 0x0010000;
            }
            byte = letter/8;
            GSSETBIT(_data[byte], letter % 8);
        }
    }
    _known = 0;	// Invalidate cache
}

- (NSData*) bitmapRepresentation
{
    unsigned	i = 17;
    
    while (i > 0 && [self hasMemberInPlane: i-1] == NO)
    {
        i--;
    }
    i *= GSBITMAP_SIZE;
    if (GSBITMAP_SIZE == i)
    {
        /* In the base plane, find the number of used bytes, so we don't
         * produce a bitmap that is longer than necessary.
         */
        if (_length < i)
        {
            i = _length;
        }
        while (i > 0 && 0 == _data[i - 1])
        {
            i--;
        }
    }
    return [NSData dataWithBytes: _data length: i];
}

- (void) formIntersectionWithCharacterSet: (NSCharacterSet *)otherSet
{
    unsigned		i;
    NSData		*otherData = [otherSet bitmapRepresentation];
    unsigned		other_length = [otherData length];
    const unsigned char	*other_bytes = [otherData bytes];
    
    if (_length > other_length)
    {
        [_obj setLength: other_length];
        _length = other_length;
        _data = [_obj mutableBytes];
    }
    for (i = 0; i < _length; i++)
    {
        _data[i] = (_data[i] & other_bytes[i]);
    }
    _known = 0;	// Invalidate cache
}

- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet
{
    unsigned		i;
    NSData		*otherData = [otherSet bitmapRepresentation];
    unsigned		other_length = [otherData length];
    const unsigned char	*other_bytes = [otherData bytes];
    
    if (other_length > _length)
    {
        [_obj setLength: other_length];
        _length = other_length;
        _data = [_obj mutableBytes];
    }
    for (i = 0; i < other_length; i++)
    {
        _data[i] = (_data[i] | other_bytes[i]);
    }
    _known = 0;	// Invalidate cache
}

- (id) initWithBitmap: (NSData*)bitmap
{
    unsigned	length = [bitmap length];
    id		tmp;
    
    if (length > GSBITMAP_MAX)
    {
        NSLog(@"attempt to initialize character set with invalid bitmap");
        [self dealloc];
        return nil;
    }
    if (bitmap == nil)
    {
        tmp = [NSMutableData new];
    }
    else
    {
        tmp = [bitmap mutableCopy];
    }
    DESTROY(_obj);
    _obj = tmp;
    _length = length;
    _data = [_obj mutableBytes];
    _known = 0;	// Invalidate cache
    return self;
}

/*
 这里可以看到, 效率非常低. 是开辟了一个非常长的数据, 然后把数据进行翻转.
 对于原来是 0 的数据, 全部变成了 1, 这样之后做判断的时候, 就是在这个 set 里面了.
 */
- (void) invert
{
    unsigned	i;
    
    if (_length < GSBITMAP_MAX)
    {
        [_obj setLength: GSBITMAP_MAX];
        _length = GSBITMAP_MAX;
        _data = [_obj mutableBytes];
    }
    for (i = 0; i < _length; i++)
    {
        _data[i] = ~_data[i];
    }
    _known = 0;	// Invalidate cache
}

- (void) removeCharactersInRange: (NSRange)aRange
{
    unsigned	i;
    unsigned	limit = NSMaxRange(aRange);
    
    if (NSMaxRange(aRange) > GSUNICODE_MAX)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"Specified range exceeds character set"];
        /* NOT REACHED */
    }
    
    if (limit > _length * 8)
    {
        limit = _length * 8;
    }
    for (i = aRange.location; i < limit; i++)
    {
        GSCLRBIT(_data[i/8], i % 8);
    }
    _known = 0;	// Invalidate cache
}

- (void) removeCharactersInString: (NSString*)aString
{
    unsigned	length;
    
    if (!aString)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"Removing characters from nil string"];
        /* NOT REACHED */
    }
    
    length = [aString length];
    if (length > 0)
    {
        NSUInteger	i;
        unichar	(*get)(id, SEL, NSUInteger);
        
        get = (unichar (*)(id, SEL, NSUInteger))
        [aString methodForSelector: @selector(characterAtIndex:)];
        
        for (i = 0; i < length; i++)
        {
            unichar	letter;
            unichar	second;
            unsigned	byte;
            
            letter = (*get)(aString, @selector(characterAtIndex:), i);
            // Convert a surrogate pair if necessary
            if (letter >= 0xd800 && letter <= 0xdbff && i < length-1
                && (second = (*get)(aString, @selector(characterAtIndex:), i+1))
                >= 0xdc00 && second <= 0xdfff)
            {
                i++;
                letter = ((letter - 0xd800) << 10)
                + (second - 0xdc00) + 0x0010000;
            }
            byte = letter/8;
            if (byte < _length)
            {
                GSCLRBIT(_data[byte], letter % 8);
            }
        }
    }
    _known = 0;	// Invalidate cache
}

@end



/* A simple array for caching standard bitmap sets */
#define MAX_STANDARD_SETS 21
static NSCharacterSet *cache_set[MAX_STANDARD_SETS];
static Class abstractClass = nil;
static Class abstractMutableClass = nil;
static Class concreteClass = nil;
static Class concreteMutableClass = nil;

#if	defined(GNUSTEP_INDEX_CHARSET)
@interface _GSStaticCharSet : _GSIndexCharSet
{
    int	_index;
}
@end

@implementation	_GSStaticCharSet

- (Class) classForCoder
{
    return abstractClass;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    [aCoder encodeValueOfObjCType: @encode(int) at: &_index];
}

- (id) init
{
    DESTROY(self);
    return nil;
}

- (id) initWithBitmap: (NSData*)bitmap number: (int)number
{
    _index = number;
    indexes = [[_GSStaticIndexSet alloc] _initWithBytes: [bitmap bytes]
                                                 length: [bitmap length]];
    return self;
}

@end

#else	/* GNUSTEP_INDEX_CHARSET */

/*
 _GSStaticCharSet 里面的数据是固定的.
 在类库里面的表现是, 在一个文件里面, 把一个 set 的所有信息确定下来.
 在启动的时候, 读取这些数据, 然后生成 _GSStaticCharSet 对象. 这个 set 代表那些数据, 全部存储在 _data 里面.
 */
@interface _GSStaticCharSet : NSCharacterSet
{
    const unsigned char	*_data;
    unsigned		_length;
    NSData		*_obj;
    unsigned		_known;
    unsigned		_present;
    int			_index;
}
@end

@implementation _GSStaticCharSet

+ (void) initialize
{
    GSObjCAddClassBehavior(self, [NSBitmapCharSet class]);
}

- (id) init
{
    DESTROY(self);
    return nil;
}

- (id) initWithBitmap: (NSData*)bitmap number: (int)number
{
    if ((self = (_GSStaticCharSet*)[(NSBitmapCharSet*)self
                                    initWithBitmap: bitmap]) != nil)
    {
        _index = number;
    }
    return self;
}

@end

#endif	/* GNUSTEP_INDEX_CHARSET */

/*
 NSCharacterSet 也是类簇模式.
 */
@implementation NSCharacterSet

+ (void) initialize
{
    static BOOL beenHere = NO;
    
    if (beenHere == NO)
    {
        abstractClass = [NSCharacterSet class];
        abstractMutableClass = [NSMutableCharacterSet class];
        concreteClass = [NSBitmapCharSet class];
        concreteMutableClass = [NSMutableBitmapCharSet class];
        beenHere = YES;
    }
}

/**
 * Creat and cache (or retrieve from cache) a characterset
 * using static bitmap data.
 * Return nil if no data is supplied and the cache is empty.
 */
+ (NSCharacterSet*) _staticSet: (const void*)bytes
                        length: (unsigned)length
                        number: (int)number
{
    static pthread_mutex_t cache_lock = PTHREAD_MUTEX_INITIALIZER;
    
    pthread_mutex_lock(&cache_lock);
    if (cache_set[number] == nil && bytes != 0)
    {
        NSData	*bitmap;
        
        bitmap = [[NSDataStatic alloc] initWithBytesNoCopy: (void*)bytes
                                                    length: length
                                              freeWhenDone: NO];
        cache_set[number]
        = [[_GSStaticCharSet alloc] initWithBitmap: bitmap number: number];
        [[NSObject leakAt: &cache_set[number]] release];
        RELEASE(bitmap);
    }
    pthread_mutex_unlock(&cache_lock);
    return cache_set[number];
}

/*
 以下的 set, 都是写死在了一个头文件里面.
 因为, 这些 set 到底有什么东西, 不是程序控制的, 而是数据控制的, 所以仅仅是一个数据的读取操作而已.
 每一个 set, 都有着固定的编号, 这是固定下来的.
 */
+ (id) alphanumericCharacterSet
{
    return [self _staticSet: alphanumericCharSet
                     length: sizeof(alphanumericCharSet)
                     number: 0];
}

+ (id) capitalizedLetterCharacterSet
{
    return [self _staticSet: titlecaseLetterCharSet
                     length: sizeof(titlecaseLetterCharSet)
                     number: 13];
}

+ (id) controlCharacterSet
{
    return [self _staticSet: controlCharSet
                     length: sizeof(controlCharSet)
                     number: 1];
}

+ (id) decimalDigitCharacterSet
{
    return [self _staticSet: decimalDigitCharSet
                     length: sizeof(decimalDigitCharSet)
                     number: 2];
}

+ (id) decomposableCharacterSet
{
    return [self _staticSet: decomposableCharSet
                     length: sizeof(decomposableCharSet)
                     number: 3];
}

+ (id) illegalCharacterSet
{
    return [self _staticSet: illegalCharSet
                     length: sizeof(illegalCharSet)
                     number: 4];
}

+ (id) letterCharacterSet
{
    return [self _staticSet: letterCharSet
                     length: sizeof(letterCharSet)
                     number: 5];
}

+ (id) lowercaseLetterCharacterSet
{
    return [self _staticSet: lowercaseLetterCharSet
                     length: sizeof(lowercaseLetterCharSet)
                     number: 6];
}

+ (id) newlineCharacterSet
{
    return [self _staticSet: newlineCharSet
                     length: sizeof(newlineCharSet)
                     number: 14];
}

+ (id) nonBaseCharacterSet
{
    return [self _staticSet: nonBaseCharSet
                     length: sizeof(nonBaseCharSet)
                     number: 7];
}

+ (id) punctuationCharacterSet
{
    return [self _staticSet: punctuationCharSet
                     length: sizeof(punctuationCharSet)
                     number: 8];
}

+ (id) symbolCharacterSet
{
    return [self _staticSet: symbolAndOperatorCharSet
                     length: sizeof(symbolAndOperatorCharSet)
                     number: 9];
}

// FIXME ... deprecated ... remove after next release.
+ (id) symbolAndOperatorCharacterSet
{
    GSOnceMLog(@"symbolAndOperatorCharacterSet is deprecated ... use symbolCharacterSet");
    return [self _staticSet: symbolAndOperatorCharSet
                     length: sizeof(symbolAndOperatorCharSet)
                     number: 9];
}

+ (id) uppercaseLetterCharacterSet
{
    return [self _staticSet: uppercaseLetterCharSet
                     length: sizeof(uppercaseLetterCharSet)
                     number: 10];
}

+ (id) whitespaceAndNewlineCharacterSet
{
    return [self _staticSet: whitespaceAndNlCharSet
                     length: sizeof(whitespaceAndNlCharSet)
                     number: 11];
}

+ (id) whitespaceCharacterSet
{
    return [self _staticSet: whitespaceCharSet
                     length: sizeof(whitespaceCharSet)
                     number: 12];
}

+ (id) characterSetWithBitmapRepresentation: (NSData*)data
{
    return AUTORELEASE([[concreteClass alloc] initWithBitmap: data]);
}

+ (id) characterSetWithCharactersInString: (NSString*)aString
{
    NSMutableCharacterSet	*ms;
    NSCharacterSet	*cs;
    
    ms = [NSMutableCharacterSet new];
    [ms addCharactersInString: aString];
    cs = [ms copy];
    RELEASE(ms);
    return AUTORELEASE(cs);
}

+ (id) characterSetWithRange: (NSRange)aRange
{
    NSMutableCharacterSet	*ms;
    NSCharacterSet	*cs;
    
    ms = [NSMutableCharacterSet new];
    [ms addCharactersInRange: aRange];
    cs = [ms copy];
    RELEASE(ms);
    return AUTORELEASE(cs);
}

+ (id) characterSetWithContentsOfFile: (NSString*)aFile
{
    if ([@"bitmap" isEqual: [aFile pathExtension]])
    {
        NSData	*bitmap = [NSData dataWithContentsOfFile: aFile];
        return [self characterSetWithBitmapRepresentation: bitmap];
    }
    else
        return nil;
}

+ (id) URLFragmentAllowedCharacterSet
{
    return [self _staticSet: URLFragmentAllowedCharSet
                     length: sizeof(URLFragmentAllowedCharSet)
                     number: 15];
}

+ (id) URLPasswordAllowedCharacterSet
{
    return [self _staticSet: URLPasswordAllowedCharSet
                     length: sizeof(URLPasswordAllowedCharSet)
                     number: 16];
}

+ (id) URLPathAllowedCharacterSet
{
    return [self _staticSet: URLPathAllowedCharSet
                     length: sizeof(URLPathAllowedCharSet)
                     number: 17];
}

+ (id) URLQueryAllowedCharacterSet
{
    return [self _staticSet: URLQueryAllowedCharSet
                     length: sizeof(URLQueryAllowedCharSet)
                     number: 18];
}

+ (id) URLUserAllowedCharacterSet
{
    return [self _staticSet: URLUserAllowedCharSet
                     length: sizeof(URLUserAllowedCharSet)
                     number: 19];
}

+ (id) URLHostAllowedCharacterSet
{
    return [self _staticSet: URLHostAllowedCharSet
                     length: sizeof(URLHostAllowedCharSet)
                     number: 20];
}

- (NSData*) bitmapRepresentation
{
    BOOL		(*imp)(id, SEL, unichar);
    NSMutableData	*m;
    unsigned char	*p;
    unsigned	end;
    unsigned	i;
    
    imp = (BOOL (*)(id,SEL,unichar))
    [self methodForSelector: @selector(characterIsMember:)];
    for (end = 0xffff; end > 0; end--)
    {
        if (imp(self, @selector(characterIsMember:), end) == YES)
        {
            break;
        }
    }
    m = [NSMutableData dataWithLength: end / 8 + 1];
    p = (unsigned char*)[m mutableBytes];
    for (i = 0; i <= end; i++)
    {
        if (imp(self, @selector(characterIsMember:), i) == YES)
        {
            GSSETBIT(p[i/8], i % 8);
        }
    }
    return m;
}

- (BOOL) hasMemberInPlane: (uint8_t)aPlane
{
    if (aPlane == 0)
    {
        return YES;
    }
    return NO;
}

- (id) init
{
    if (object_getClass(self) == abstractClass)
    {
        id	obj;
        
        obj = [concreteClass allocWithZone: [self zone]];
        obj = [obj initWithBitmap: nil];
        DESTROY(self);
        self = obj;
    }
    return self;
}

- (NSCharacterSet*) invertedSet
{
    NSMutableCharacterSet	*m = [self mutableCopy];
    NSCharacterSet	*c;
    
    [m invert];
    c = [m copy];
    RELEASE(m);
    return AUTORELEASE(c);
}

- (BOOL) isSupersetOfSet: (NSCharacterSet*)aSet
{
    NSMutableCharacterSet	*m = [self mutableCopy];
    BOOL			superset;
    
    [m formUnionWithCharacterSet: aSet];
    superset = [self isEqual: m];
    RELEASE(m);
    return superset;
}

- (BOOL) longCharacterIsMember: (UTF32Char)aCharacter
{
    int	plane = (aCharacter >> 16);
    
    if (aCharacter >= GSUNICODE_MAX)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] argument (0x%08x) is too large",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd),
         aCharacter];
    }
    if (plane == 0)
    {
        unichar	u = (unichar)(aCharacter & 0xffff);
        
        return [self characterIsMember: u];
    }
    else
    {
        return NO;
    }
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
    NSData *bitmap;
    bitmap = [self bitmapRepresentation];
    return [[concreteMutableClass allocWithZone: zone] initWithBitmap: bitmap];
}

@end

@implementation NSMutableCharacterSet

/* Override this from NSCharacterSet to create the correct class */
+ (id) characterSetWithBitmapRepresentation: (NSData*)data
{
    return AUTORELEASE([[concreteMutableClass alloc] initWithBitmap: data]);
}

+ (id) alphanumericCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) capitalizedLetterCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) controlCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) decimalDigitCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) decomposableCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) illegalCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) letterCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) lowercaseLetterCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) newlineCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) nonBaseCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) punctuationCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) symbolCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

// FIXME ... deprecated ... remove after next release.
+ (id) symbolAndOperatorCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) uppercaseLetterCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) whitespaceAndNewlineCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) whitespaceCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) URLFragmentAllowedCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) URLHostAllowedCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) URLPasswordAllowedCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) URLPathAllowedCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) URLQueryAllowedCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) URLUserAllowedCharacterSet
{
    return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (id) characterSetWithCharactersInString: (NSString*)aString
{
    NSMutableCharacterSet	*ms;
    
    ms = [abstractMutableClass new];
    [ms addCharactersInString: aString];
    return AUTORELEASE(ms);
}

+ (id) characterSetWithRange: (NSRange)aRange
{
    NSMutableCharacterSet	*ms;
    
    ms = [abstractMutableClass new];
    [ms addCharactersInRange: aRange];
    return AUTORELEASE(ms);
}

- (id) init
{
    if (object_getClass(self) == abstractMutableClass)
    {
        id	obj;
        
        obj = [concreteMutableClass allocWithZone: [self zone]];
        obj = [obj initWithBitmap: nil];
        DESTROY(self);
        self = obj;
    }
    return self;
}

- (id) initWithBitmap: (NSData*)bitmap
{
    if (object_getClass(self) == abstractMutableClass)
    {
        id	obj;
        
        obj = [concreteMutableClass allocWithZone: [self zone]];
        obj = [obj initWithBitmap: bitmap];
        DESTROY(self);
        self = obj;
    }
    return self;
}

@end


/* Below is an experimental implementation of a mutable character set
 * implemented in terms of an NSMutableIndexSet.  This should be much
 * smaller than a bitmap representation for normal charactersets.
 */

@interface      NSIndexSet (NSCharacterSet)
- (NSUInteger) _gapGreaterThanIndex: (NSUInteger)anIndex;
@end


@implementation _GSIndexCharSet

- (NSData*) bitmapRepresentation
{
    NSMutableBitmapCharSet	*tmp;
    NSData			*result;
    NSUInteger			index = 0;
    
    tmp = [NSMutableBitmapCharSet new];
    while ((index = [indexes indexGreaterThanOrEqualToIndex: index])
           != NSNotFound)
    {
        NSRange	r;
        
        r.location = index;
        index = [indexes _gapGreaterThanIndex: index];
        if (index == NSNotFound)
        {
            r.length = 1;
        }
        else
        {
            r.length = index - r.location;
        }
        [tmp addCharactersInRange: r];
        index = NSMaxRange(r);
    }
    result = AUTORELEASE(RETAIN([tmp bitmapRepresentation]));
    RELEASE(tmp);
    return result;
}

- (BOOL) characterIsMember: (unichar)aCharacter
{
    return [indexes containsIndex: (int)aCharacter];
}

- (Class) classForCoder
{
    return [NSBitmapCharSet class];
}

- (void) dealloc
{
    DESTROY(indexes);
    [super dealloc];
}

- (BOOL) hasMemberInPlane: (uint8_t)aPlane
{
    NSUInteger	found;
    
    found = [indexes indexGreaterThanOrEqualToIndex: 0x10000 * aPlane];
    if (found != NSNotFound && found < 0x10000 * (aPlane + 1))
    {
        return YES;
    }
    return NO;
}

- (NSIndexSet*) _indexes
{
    return indexes;
}

- (id) init
{
    return [self initWithBitmap: nil];
}

- (id) initWithBitmap: (NSData*)bitmap
{
    const unsigned char	*bytes = [bitmap bytes];
    unsigned		length = [bitmap length];
    unsigned		index = 0;
    unsigned		i;
    NSRange		r;
    BOOL			findingLocation = YES;
    
    r.location = 0;
    indexes = [NSMutableIndexSet new];
    for (i = 0; i < length; i++)
    {
        unsigned char	byte = bytes[i];
        
        if (byte == 0)
        {
            if (findingLocation == NO)
            {
                r.length = index - r.location;
                [indexes addIndexesInRange: r];
                findingLocation = YES;
            }
            index += 8;
        }
        else if (byte == 0xff)
        {
            if (findingLocation == YES)
            {
                r.location = index;
                findingLocation = NO;
            }
            index += 8;
        }
        else
        {
            unsigned int	bit;
            
            for (bit = 1; bit & 0xff; bit <<= 1)
            {
                if ((byte & bit) == 0)
                {
                    if (findingLocation == NO)
                    {
                        r.length = index - r.location;
                        [indexes addIndexesInRange: r];
                        findingLocation = YES;
                    }
                }
                else
                {
                    if (findingLocation == YES)
                    {
                        r.location = index;
                        findingLocation = NO;
                    }
                }
                index++;
            }
        }
    }
    if (findingLocation == NO)
    {
        r.length = index - r.location;
        [indexes addIndexesInRange: r];
    }
    return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    NSData	*rep;
    
    rep = [aCoder decodeObject];
    self = [self initWithBitmap: rep];
    return self;
}

- (BOOL) longCharacterIsMember: (UTF32Char)aCharacter
{
    return [indexes containsIndex: (int)aCharacter];
}

@end

@implementation _GSMutableIndexCharSet

+ (void) initialize
{
    if (self == [_GSMutableIndexCharSet class])
    {
        [self setVersion: 1];
        GSObjCAddClassBehavior(self, [_GSIndexCharSet class]);
    }
}

- (void) addCharactersInRange: (NSRange)aRange
{
    if (NSMaxRange(aRange) > GSUNICODE_MAX)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"Specified range exceeds character set"];
        /* NOT REACHED */
    }
    [indexes addIndexesInRange: aRange];
}

- (void) addCharactersInString: (NSString*)aString
{
    unsigned   length;
    
    if (!aString)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"Adding characters from nil string"];
        /* NOT REACHED */
    }
    
    length = [aString length];
    if (length > 0)
    {
        NSUInteger	i;
        unichar	(*get)(id, SEL, NSUInteger);
        
        get = (unichar (*)(id, SEL, NSUInteger))
        [aString methodForSelector: @selector(characterAtIndex:)];
        for (i = 0; i < length; i++)
        {
            unichar	letter;
            unichar	second;
            
            letter = (*get)(aString, @selector(characterAtIndex:), i);
            // Convert a surrogate pair if necessary
            if (letter >= 0xd800 && letter <= 0xdbff && i < length-1
                && (second = (*get)(aString, @selector(characterAtIndex:), i+1))
                >= 0xdc00 && second <= 0xdfff)
            {
                i++;
                letter = ((letter - 0xd800) << 10)
                + (second - 0xdc00) + 0x0010000;
            }
            [indexes addIndexesInRange: NSMakeRange(letter, 1)];
        }
    }
}

- (void) formIntersectionWithCharacterSet: (NSCharacterSet *)otherSet
{
    NSIndexSet		*otherIndexes;
    NSUInteger		index = 0;
    NSUInteger		i0;
    NSUInteger		i1;
    
    if ([otherSet isKindOfClass: [_GSIndexCharSet class]] == YES)
    {
        otherIndexes = [(_GSIndexCharSet*)otherSet _indexes];
    }
    else
    {
        _GSIndexCharSet	*tmp;
        
        tmp = [[_GSIndexCharSet alloc] initWithBitmap:
               [otherSet bitmapRepresentation]];
        otherIndexes = AUTORELEASE(RETAIN([tmp _indexes]));
        RELEASE(tmp);
    }
    
    /* Find first index in each set.
     */
    i0 = [indexes indexGreaterThanOrEqualToIndex: 0];
    i1 = [otherIndexes indexGreaterThanOrEqualToIndex: 0];
    
    /* Loop until there are no more indexes to process in the set and
     * the intersection operation has therefore completed.
     */
    while (i0 != NSNotFound)
    {
        if (i1 == NSNotFound)
        {
            /* No more indexes in other set ... remove everything from the
             * last gap onwards, and finish.
             */
            [indexes removeIndexesInRange: NSMakeRange(index, NSNotFound-index)];
            break;
        }
        if (i1 > i0)
        {
            /* Indexes in other set start after this set ... so remove any
             * from the last gap to the index in the other set.
             */
            [indexes removeIndexesInRange: NSMakeRange(index, i1 - index)];
            index = i1;
        }
        else
        {
            index = i0;
        }
        
        /* Find the next gap in each set, and set our gap index to the
         * lower of the two.
         */
        i0 = [indexes _gapGreaterThanIndex: index];
        i1 = [otherIndexes _gapGreaterThanIndex: index];
        index = i0;
        if (i1 < i0)
        {
            index = i1;
        }
        
        /* Find the next index in each set so wer can loop round and
         * do it all again.
         */
        i0 = [indexes indexGreaterThanIndex: i0];
        i1 = [otherIndexes indexGreaterThanIndex: i1];
    }
}

- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet
{
    NSIndexSet		*otherIndexes;
    NSUInteger		index;
    
    if ([otherSet isKindOfClass: [_GSIndexCharSet class]] == YES)
    {
        otherIndexes = [(_GSIndexCharSet*)otherSet _indexes];
    }
    else
    {
        _GSIndexCharSet	*tmp;
        
        tmp = [[_GSIndexCharSet alloc] initWithBitmap:
               [otherSet bitmapRepresentation]];
        otherIndexes = AUTORELEASE(RETAIN([tmp _indexes]));
        RELEASE(tmp);
    }
    
    index = [otherIndexes indexGreaterThanOrEqualToIndex: 0];
    while (index != NSNotFound)
    {
        NSRange	r;
        
        r.location = index;
        index = [otherIndexes _gapGreaterThanIndex: index];
        r.length = index - r.location;
        [indexes addIndexesInRange: r];
        index = [otherIndexes indexGreaterThanOrEqualToIndex: index];
    }
}

- (void) invert
{
    NSMutableIndexSet	*tmp;
    NSUInteger		index;
    
    tmp = [NSMutableIndexSet new];
    
    /* Locate the start of the first gap
     */
    if ([indexes containsIndex: 0] == YES)
    {
        index = [indexes _gapGreaterThanIndex: 0];
    }
    else
    {
        index = 0;
    }
    
    while (index != NSNotFound)
    {
        NSRange	r;
        
        r.location = index;
        index = [indexes indexGreaterThanIndex: index];
        if (index == NSNotFound)
        {
            /* No more indexes, so we have a gap to the end of all
             * unicode characters which we can invert.
             */
            index = GSUNICODE_MAX;
        }
        r.length = index - r.location;
        [tmp addIndexesInRange: r];
        index = [indexes _gapGreaterThanIndex: NSMaxRange(r) - 1];
    }
    ASSIGN(indexes, tmp);
    RELEASE(tmp);
}

- (void) removeCharactersInRange: (NSRange)aRange
{
    if (NSMaxRange(aRange) > GSUNICODE_MAX)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"Specified range exceeds character set"];
        /* NOT REACHED */
    }
    [indexes removeIndexesInRange: aRange];
}

- (void) removeCharactersInString: (NSString*)aString
{
    unsigned	length;
    
    if (!aString)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"Removing characters from nil string"];
        /* NOT REACHED */
    }
    
    length = [aString length];
    if (length > 0)
    {
        NSUInteger	i;
        unichar	(*get)(id, SEL, NSUInteger);
        
        get = (unichar (*)(id, SEL, NSUInteger))
        [aString methodForSelector: @selector(characterAtIndex:)];
        
        for (i = 0; i < length; i++)
        {
            unichar	letter;
            unichar	second;
            
            letter = (*get)(aString, @selector(characterAtIndex:), i);
            // Convert a surrogate pair if necessary
            if (letter >= 0xd800 && letter <= 0xdbff && i < length-1
                && (second = (*get)(aString, @selector(characterAtIndex:), i+1))
                >= 0xdc00 && second <= 0xdfff)
            {
                i++;
                letter = ((letter - 0xd800) << 10)
                + (second - 0xdc00) + 0x0010000;
            }
            [indexes removeIndexesInRange: NSMakeRange(letter, 1)];
        }
    }
}

@end

