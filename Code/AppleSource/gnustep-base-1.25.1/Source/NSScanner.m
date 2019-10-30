#import "common.h"

#if	defined(HAVE_FLOAT_H)
#include	<float.h>
#endif

#if	!defined(LLONG_MAX)
#  if	defined(__LONG_LONG_MAX__)
#    define LLONG_MAX __LONG_LONG_MAX__
#    define LLONG_MIN	(-LLONG_MAX-1)
#    define ULLONG_MAX	(LLONG_MAX * 2ULL + 1)
#  else
#    error Neither LLONG_MAX nor __LONG_LONG_MAX__ found
#  endif
#endif
#if	!defined(ULLONG_MAX)
#  define ULLONG_MAX	(LLONG_MAX * 2ULL + 1)
#endif

#include <math.h>
#include <ctype.h>    /* FIXME: May go away once I figure out Unicode */

#define	EXPOSE_NSScanner_IVARS	1
#import "GNUstepBase/Unicode.h"
#import "Foundation/NSScanner.h"
#import "Foundation/NSException.h"
#import "Foundation/NSUserDefaults.h"

#import "GSPrivate.h"


@class	GSCString;
@interface GSCString : NSObject	// Help the compiler
@end
@class	GSUnicodeString;
@interface GSUnicodeString : NSObject	// Help the compiler
@end
@class	GSMutableString;
@class	GSPlaceholderString;
@interface GSPlaceholderString : NSObject	// Help the compiler
@end

static Class		NSStringClass;
static Class		GSCStringClass;
static Class		GSUnicodeStringClass;
static Class		GSMutableStringClass;
static Class		GSPlaceholderStringClass;
static id		_holder;
static NSCharacterSet	*defaultSkipSet;
static SEL		characterIsMemSel;
static NSStringEncoding internalEncoding = NSISOLatin1StringEncoding;

static inline unichar myGetC(unsigned char c)
{
    unsigned int  size = 1;
    unichar       u = 0;
    unichar       *dst = &u;
    
    GSToUnicode(&dst, &size, &c, 1, internalEncoding, 0, 0);
    return u;
}
/*
 * Hack for direct access to internals of an concrete string object.
 */
typedef GSString	*ivars;
#define	myLength()	(((ivars)_string)->_count)
#define	myUnicode(I)	(((ivars)_string)->_contents.u[I])
#define	myChar(I)	myGetC((((ivars)_string)->_contents.c[I]))
#define	myCharacter(I)	(_isUnicode ? myUnicode(I) : myChar(I))

/*
 * Scan characters to be skipped.
 * Return YES if there are more characters to be scanned.
 * Return NO if the end of the string is reached.
 * For internal use only.
 */
#define	skipToNextField()	({\
while (_scanLocation < myLength() && _charactersToBeSkipped != nil \
&& (*_skipImp)(_charactersToBeSkipped, memSel, myCharacter(_scanLocation)))\
_scanLocation++;\
(_scanLocation >= myLength()) ? NO : YES;\
})

/**
 * <p>
 *   The <code>NSScanner</code> class cluster (currently a single class in
 *   GNUstep) provides a mechanism to parse the contents of a string into
 *   number and string values by making a sequence of scan operations to
 *   step through the string retrieving successive items.
 * </p>
 * <p>
 *   You can tell the scanner whether its scanning is supposed to be
 *   case sensitive or not, and you can specify a set of characters
 *   to be skipped before each scanning operation (by default,
 *   whitespace and newlines).
 * </p>
 */
@implementation NSScanner

+ (void) initialize
{
    if (self == [NSScanner class])
    {
        NSStringEncoding externalEncoding;
        
        characterIsMemSel = @selector(characterIsMember:);
        defaultSkipSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        IF_NO_GC(RETAIN(defaultSkipSet));
        NSStringClass = [NSString class];
        GSCStringClass = [GSCString class];
        GSUnicodeStringClass = [GSUnicodeString class];
        GSMutableStringClass = [GSMutableString class];
        GSPlaceholderStringClass = [GSPlaceholderString class];
        _holder = (id)NSAllocateObject(GSPlaceholderStringClass, 0, 0);
        externalEncoding = [NSString defaultCStringEncoding];
        if (GSPrivateIsByteEncoding(externalEncoding) == YES)
        {
            internalEncoding = externalEncoding;
        }
    }
}

/**
 * Create and return a scanner that scans aString.<br />
 * Uses -initWithString: and with no locale set.
 类方法, 添加了 autorelease
 */
+ (id) scannerWithString: (NSString *)aString
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithString: aString]);
}

/**
 * Returns an NSScanner instance set up to scan aString
 * (using -initWithString: and with a locale set the default locale
 * (using -setLocale:
 */
+ (id) localizedScannerWithString: (NSString*)aString
{
    NSScanner		*scanner = [self scannerWithString: aString];
    
    if (scanner != nil)
    {
        NSDictionary	*loc;
        
        loc = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
        [scanner setLocale: loc];
    }
    return scanner;
}

/**
 * Initialises the scanner to scan aString.  The GNUstep
 * implementation may make an internal copy of the original
 * string - so it is not safe to assume that if you modify a
 * mutable string that you initialised a scanner with, the changes
 * will be visible to the scanner.
 * <br/>
 * Returns the scanner object.
 这里, 对字符串进行了拷贝.
 aString, 作为 stirng 的参数的命名.
 */
- (id) initWithString: (NSString *)aString
{
    Class	c;
    
    if ((self = [super init]) == nil)
        return nil;
    /*
     * Ensure that we have a known string so we can access its internals directly.
     */
    if (aString == nil)
    {
        aString = @"";
    }
    
    c = object_getClass(aString);
    if (GSObjCIsKindOf(c, GSMutableStringClass) == YES)
    {
        _string = [_holder initWithString: aString];
    }
    else if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES)
    {
        _string = RETAIN(aString);
    }
    else if (GSObjCIsKindOf(c, GSCStringClass) == YES)
    {
        _string = RETAIN(aString);
    }
    else if ([aString isKindOfClass: NSStringClass])
    {
        _string = [_holder initWithString: aString];
    }
    else
    {
        DESTROY(self);
        NSLog(@"Scanner initialised with something not a string");
        return nil;
    }
    c = object_getClass(_string);
    if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES)
    {
        _isUnicode = YES;
    }
    [self setCharactersToBeSkipped: defaultSkipSet];
    _decimal = '.';
    return self;
}

/**
 * Returns YES if no more characters remain to be scanned.<br />
 * Returns YES if all characters remaining to be scanned
 * are to be skipped.<br />
 * Returns NO if there are characters left to scan.
 */
- (BOOL) isAtEnd
{
    unsigned int	save__scanLocation;
    BOOL		ret;
    
    if (_scanLocation >= myLength())
        return YES;
    save__scanLocation = _scanLocation; // 先缓存一下原来的位置
    
    ret = YES;
    ({
        while (_scanLocation < myLength() && _charactersToBeSkipped != nil
               && (*_skipImp)(_charactersToBeSkipped, characterIsMemSel, myCharacter(_scanLocation)))
            _scanLocation++;
        (_scanLocation >= myLength()) ? NO : YES;
    });
    ret = !ret;
    _scanLocation = save__scanLocation; // 复原原来的位置
    return ret;
}

// 这个方法的判断, 和做算法题的时候是一样的.
- (BOOL) _scanInt: (int*)value
{
    unsigned int num = 0;
    BOOL negative = NO;
    BOOL overflow = NO;
    
    /* 首先, 判断一下正负号. 这和算法题里面一样! 所以, 算法题其实是有用的, 只不过是类库封装起来了而已. 实际上, 还是那么多操作. 所以能缓存就缓存.*/
    if (_scanLocation < myLength())
    {
        switch (myCharacter(_scanLocation))
        {
            case '+':
                _scanLocation++;
                break;
            case '-':
                negative = YES;
                _scanLocation++;
                break;
        }
    }
    
    BOOL got_digits = NO;
    const unsigned int limit = INTMAX_MAX / 10; // 把最大值除以10, 作为判断是否越界的标志.
    /* Process digits */
    while (_scanLocation < myLength())
    {
        unichar digit = myCharacter(_scanLocation);
        
        if ((digit < '0') || (digit > '9')) // 已经不是正整数了.
            break;
        if (!overflow)
        {
            if (num >= limit) // 这个时候, 是已经取得下一位的数字了, 如果 num 比 最大值/10 还大, 那就是越界了,
                // error: 这里有问题, 当 num == limit 的时候, 和下面 16 进制的那个判断一样.
                overflow = YES;
            else
                num = num * 10 + (digit - '0'); // 正常的数值相加.
        }
        _scanLocation++;
        got_digits = YES;
    }
    
    /* Save result */
    if (!got_digits) return NO;
    if (value)
    {
        if (overflow ||
            (num > (negative ? (NSUInteger)INT_MIN : (NSUInteger)INT_MAX)))
            *value = negative ? INT_MIN: INT_MAX; // 如果越界了, 返回界限值.
        else if (negative)
            *value = -num;
        else
            *value = num;
    }
    return YES;
}

/**
 * After initial skipping (if any), this method scans a integer value,
 * placing it in <em>intValue</em> if that is not null.
 * <br/>
 * Returns YES if anything is scanned, NO otherwise.
 * <br/>
 * On overflow, INT_MAX or INT_MIN is put into <em>intValue</em>
 * <br/>
 * Scans past any excess digits
 */
- (BOOL) scanInt: (int*)value
{
    unsigned int saveScanLocation = _scanLocation;
//    skipToNextField() 这个会跳过开头的应该跳过的字符集.
    if (skipToNextField() && [self _scanInt: value])
        return YES;
    _scanLocation = saveScanLocation; // 这里, 会进行一次复原操作. 看来就算是大神的代码, 这种保存复原的操作也经常发生.
    return NO;
}

/* Scan an unsigned long long of the given radix into value.
 * Internal version used by scanHexInt:, scanHexLongLong: etc.
 */
- (BOOL) scanUnsignedLongLong_: (unsigned long long int*)value // container
                         radix: (NSUInteger)radix // 进制
                       maximum: (unsigned long long)max // 最大值.
                     gotDigits: (BOOL)gotDigits
{
    unsigned long long int        num = 0;
    unsigned long long int        numLimit = max / radix; // 这个, 和scanInt中的做法一样
    unsigned long long int        digitLimit = max % radix; // 判断出最大值的余数.
    unsigned long long int        digitValue = 0;
    BOOL                          overflow = NO;
    unsigned int                  saveScanLocation = _scanLocation;
    
    /* Process digits */
    while (_scanLocation < myLength())
    {
        unichar digit = myCharacter(_scanLocation);
        
        switch (digit)
        {
            case '0': digitValue = 0; break;
            case '1': digitValue = 1; break;
            case '2': digitValue = 2; break;
            case '3': digitValue = 3; break;
            case '4': digitValue = 4; break;
            case '5': digitValue = 5; break;
            case '6': digitValue = 6; break;
            case '7': digitValue = 7; break;
            case '8': digitValue = 8; break;
            case '9': digitValue = 9; break;
            case 'a': digitValue = 0xA; break;
            case 'b': digitValue = 0xB; break;
            case 'c': digitValue = 0xC; break;
            case 'd': digitValue = 0xD; break;
            case 'e': digitValue = 0xE; break;
            case 'f': digitValue = 0xF; break;
            case 'A': digitValue = 0xA; break;
            case 'B': digitValue = 0xB; break;
            case 'C': digitValue = 0xC; break;
            case 'D': digitValue = 0xD; break;
            case 'E': digitValue = 0xE; break;
            case 'F': digitValue = 0xF; break;
            default:
                break;
        }
        if (digitValue >= radix)
        {
            break;
        }
        
        if (!overflow)
        {
            if ((num > numLimit)
                || ((num == numLimit) && (digitValue > digitLimit))) // 为什么10进制的没有做这项检查.
            {
                overflow = YES;
            }
            else
            {
                num = num * radix + digitValue;
            }
        }
        _scanLocation++;
        gotDigits = YES;
    }
    
    /* Save result */
    if (!gotDigits) // 如果, 没有取到数值, 那么就是解析失败了
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    if (value)
    {
        if (overflow)
        {
            *value = ULLONG_MAX;
        }
        else
        {
            *value = num;
        }
    }
    return YES;
}

- (BOOL) scanRadixUnsignedInt: (unsigned int*)value
{
    unsigned int	        radix;
    unsigned long long    tmp;
    BOOL		        gotDigits = NO;
    unsigned int	        saveScanLocation = _scanLocation;
    
    /* Skip whitespace */
    if (!skipToNextField())
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    
    // 这里, 首先会提取出 进制的前缀判断字符串的进制.
    // 所以, 如果自己写解析程序, 也是这样的思路, 商业类库还是脱离不了基本的算法
    radix = 10;
    if ((_scanLocation < myLength()) && (myCharacter(_scanLocation) == '0'))
    {
        radix = 8;
        _scanLocation++;
        gotDigits = YES;
        if (_scanLocation < myLength())
        {
            switch (myCharacter(_scanLocation))
            {
                case 'x':
                case 'X':
                    _scanLocation++;
                    radix = 16;
                    gotDigits = NO;
                    break;
            }
        }
    }
    if ([self scanUnsignedLongLong_: &tmp
                              radix: radix
                            maximum: UINT_MAX
                          gotDigits: gotDigits])
    {
        if (tmp > UINT_MAX)
        {
            *value = UINT_MAX;
        }
        else
        {
            *value = (unsigned int)tmp;
        }
        return YES;
    }
    _scanLocation = saveScanLocation;
    return NO;
}

- (BOOL) scanRadixUnsignedLongLong: (unsigned long long*)value
{
    unsigned int	        radix;
    BOOL		        gotDigits = NO;
    unsigned int	        saveScanLocation = _scanLocation;
    
    /* Skip whitespace */
    if (!skipToNextField())
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    
    /* Check radix */
    radix = 10;
    if ((_scanLocation < myLength()) && (myCharacter(_scanLocation) == '0'))
    {
        radix = 8;
        _scanLocation++;
        gotDigits = YES;
        if (_scanLocation < myLength())
        {
            switch (myCharacter(_scanLocation))
            {
                case 'x':
                case 'X':
                    _scanLocation++;
                    radix = 16;
                    gotDigits = NO;
                    break;
            }
        }
    }
    if ([self scanUnsignedLongLong_: value
                              radix: radix
                            maximum: ULLONG_MAX
                          gotDigits: gotDigits])
    {
        return YES;
    }
    _scanLocation = saveScanLocation;
    return NO;
}

- (BOOL) scanHexInt: (unsigned int*)value
{
    unsigned int          saveScanLocation = _scanLocation;
    unsigned long long    tmp;
    
    /* Skip whitespace */
    if (!skipToNextField()) // 后面没东西了
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    // 这里, 控制的是解析指针. 如果是 0x 的, 那么越过, 如果不是, 那么代表这个字符串没有 0x 开头, 那么第一个就是有效的数值.
    if ((_scanLocation < myLength()) && (myCharacter(_scanLocation) == '0'))
    {
        _scanLocation++;
        if (_scanLocation < myLength())
        {
            switch (myCharacter(_scanLocation))
            {
                case 'x':
                case 'X':
                    _scanLocation++;	// Scan beyond the 0x prefix
                    break;
                default:
                    _scanLocation--;	// Scan from the initial digit
                    break;
            }
        }
        else
        {
            _scanLocation--;	// Just scan the zero.
        }
    }
    
    if ([self scanUnsignedLongLong_: &tmp
                              radix: 16
                            maximum: UINT_MAX
                          gotDigits: NO])
    {
        *value = (unsigned int)tmp;
        return YES;
    }
    _scanLocation = saveScanLocation;
    return NO;
}

- (BOOL) scanLongLong: (long long *)value
{
    unsigned long long		num = 0;
    const unsigned long long	limit = ULLONG_MAX / 10;
    BOOL				negative = NO;
    BOOL				overflow = NO;
    BOOL				got_digits = NO;
    unsigned int			saveScanLocation = _scanLocation;
    
    /* Skip whitespace */
    if (!skipToNextField())
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    
    /* Check for sign */
    if (_scanLocation < myLength())
    {
        switch (myCharacter(_scanLocation))
        {
            case '+':
                _scanLocation++;
                break;
            case '-':
                negative = YES;
                _scanLocation++;
                break;
        }
    }
    
    /* Process digits */
    while (_scanLocation < myLength())
    {
        unichar digit = myCharacter(_scanLocation);
        
        if ((digit < '0') || (digit > '9'))
            break;
        if (!overflow) {
            if (num >= limit)
                overflow = YES;
            else
                num = num * 10 + (digit - '0');
        }
        _scanLocation++;
        got_digits = YES;
    }
    
    /* Save result */
    if (!got_digits)
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    if (value)
    {
        if (negative)
        {
            if (overflow || (num > (unsigned long long)LLONG_MIN))
                *value = LLONG_MIN;
            else
                *value = -num;
        }
        else
        {
            if (overflow || (num > (unsigned long long)LLONG_MAX))
                *value = LLONG_MAX;
            else
                *value = num;
        }
    }
    return YES;
}

- (BOOL) scanHexLongLong: (unsigned long long*)value
{
    unsigned int saveScanLocation = _scanLocation;
    
    /* Skip whitespace */
    if (!skipToNextField())
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    
    if ((_scanLocation < myLength()) && (myCharacter(_scanLocation) == '0'))
    {
        _scanLocation++;
        if (_scanLocation < myLength())
        {
            switch (myCharacter(_scanLocation))
            {
                case 'x':
                case 'X':
                    _scanLocation++;        // Scan beyond the 0x prefix
                    break;
                default:
                    _scanLocation--;        // Scan from the initial digit
                    break;
            }
        }
        else
        {
            _scanLocation--;      // Just scan the zero.
        }
    }
    if ([self scanUnsignedLongLong_: value
                              radix: 16
                            maximum: ULLONG_MAX
                          gotDigits: NO])
    {
        return YES;
    }
    _scanLocation = saveScanLocation;
    return NO;
}

// http://www.ruanyifeng.com/blog/2010/06/ieee_floating-point_representation.html
// 这里, 没看明白, 没有仔细看.
- (BOOL) scanDouble: (double *)value
{
    unichar	c = 0;
    double	num = 0.0;
    long int	exponent = 0;
    BOOL		negative = NO;
    BOOL		got_dot = NO;
    BOOL		got_digit = NO;
    
    // 还是先记录一下最初的位置.
    unsigned int	saveScanLocation = _scanLocation;
    
    /* Skip whitespace */
    if (!skipToNextField())
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    
    // 还是记录一下正负号.
    if (_scanLocation < myLength())
    {
        switch (myCharacter(_scanLocation))
        {
            case '+':
                _scanLocation++;
                break;
            case '-':
                negative = YES;
                _scanLocation++;
                break;
        }
    }
    
    
    /* Process number */
    while (_scanLocation < myLength())
    {
        c = myCharacter(_scanLocation);
        if ((c >= '0') && (c <= '9'))
        {
            /* Ensure that the number being accumulated will not overflow. */
            if (num >= (DBL_MAX / 10.000000001))
            {
                ++exponent;
            }
            else
            {
                num = (num * 10.0) + (c - '0');
                got_digit = YES;
            }
            /* Keep track of the number of digits after the decimal point.
             If we just divided by 10 here, we would lose precision. */
            if (got_dot)
                --exponent;
        }
        else if (!got_dot && (c == _decimal))
        {
            /* Note that we have found the decimal point. */
            got_dot = YES;
        }
        else
        {
            /* Any other character terminates the number. */
            break;
        }
        _scanLocation++;
    }
    
    if (!got_digit)
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    
    /* Check for trailing exponent */
    if ((_scanLocation < myLength()) && ((c == 'e') || (c == 'E')))
    {
        unsigned int	expScanLocation = _scanLocation;
        int expval;
        
        
        _scanLocation++;
        if ([self _scanInt: &expval])
        {
            /* Check for exponent overflow */
            if (num)
            {
                if ((exponent > 0) && (expval > (LONG_MAX - exponent)))
                    exponent = LONG_MAX;
                else if ((exponent < 0) && (expval < (LONG_MIN - exponent)))
                    exponent = LONG_MIN;
                else
                    exponent += expval;
            }
        }
        else
        {
            /* Numbers like 1.23eFOO are accepted (as 1.23). */
            _scanLocation = expScanLocation;
        }
    }
    
    if (value)
    {
        if (num && exponent)
            num *= pow(10.0, (double) exponent);
        if (negative)
            *value = -num;
        else
            *value = num;
    }
    return YES;
}

- (BOOL) scanFloat: (float*)value
{
    double num;
    
    if (value == NULL)
        return [self scanDouble: NULL];
    if ([self scanDouble: &num])
    {
        *value = num;
        return YES;
    }
    return NO;
}

/**
 * After initial skipping (if any), this method scans any characters
 * from aSet, terminating when a character not in the set
 * is found.<br />
 * Returns YES if any character is scanned, NO otherwise.<br />
 * If value is not null, any character scanned are
 * stored in a string returned in this location.
 */
// 这个函数的意思是, 遍历直到aSet中的字符出现了. 个人感觉命名很烂.
- (BOOL) scanCharactersFromSet: (NSCharacterSet *)aSet
                    intoString: (NSString **)value
{
    unsigned int	saveScanLocation = _scanLocation;
    
    if (!skipToNextField()) { return NO;}
    
    unsigned int    start;
    BOOL        (*memImp)(NSCharacterSet*, SEL, unichar);
    
    if (aSet == _charactersToBeSkipped)
        memImp = _skipImp;
    else
        memImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
        [aSet methodForSelector: memSel];
    
    start = _scanLocation;
    if (_isUnicode)
    {
        while (_scanLocation < myLength())
        {
            if ((*memImp)(aSet, memSel, myUnicode(_scanLocation)) == NO)
                break;
            _scanLocation++;
        }
    }
    else
    {
        while (_scanLocation < myLength())
        {
            if ((*memImp)(aSet, memSel, myChar(_scanLocation)) == NO)
                break;
            _scanLocation++;
        }
    }
    if (_scanLocation != start)
    {
        if (value != 0)
        {
            NSRange    range;
            
            range.location = start;
            range.length = _scanLocation - start;
            *value = [_string substringWithRange: range];
        }
        return YES;
    }
    _scanLocation = saveScanLocation;
    return NO;
}

/**
 * After initial skipping (if any), this method scans characters until
 * it finds one in <em>set</em>.  The scanned characters are placed in
 * <em>stringValue</em> if that is not null.
 * <br/>
 * Returns YES if anything is scanned, NO otherwise.
 这个函数和scanCharactersFromSet应该是一样的逻辑. 难道是之前的命名太差, 重新起了一个名, 那也应该调用原来的函数啊
 */
- (BOOL) scanUpToCharactersFromSet: (NSCharacterSet *)aSet
                        intoString: (NSString **)value
{
    unsigned int	saveScanLocation = _scanLocation;
    unsigned int	start;
    BOOL		(*memImp)(NSCharacterSet*, SEL, unichar);
    
    if (!skipToNextField())
        return NO;
    
    if (aSet == _charactersToBeSkipped)
        memImp = _skipImp;
    else
        memImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
        [aSet methodForSelector: memSel];
    
    start = _scanLocation;
    if (_isUnicode)
    {
        while (_scanLocation < myLength())
        {
            if ((*memImp)(aSet, memSel, myUnicode(_scanLocation)) == YES)
                break;
            _scanLocation++;
        }
    }
    else
    {
        while (_scanLocation < myLength())
        {
            if ((*memImp)(aSet, memSel, myChar(_scanLocation)) == YES)
                break;
            _scanLocation++;
        }
    }
    
    if (_scanLocation == start)
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    if (value)
    {
        NSRange	range;
        
        range.location = start;
        range.length = _scanLocation - start;
        *value = [_string substringWithRange: range];
    }
    return YES;
}

/**
 * After initial skipping (if any), this method scans for string
 * and places the characters found in value if that is not null.<br/>
 * Returns YES if anything is scanned, NO otherwise.
 */
- (BOOL) scanString: (NSString *)string intoString: (NSString **)value
{
    NSRange	range;
    unsigned int	saveScanLocation = _scanLocation;
    
    if (skipToNextField() == NO)
    {
        return NO;
    }
    range.location = _scanLocation;
    range.length = [string length];
    if (range.location + range.length > myLength())
        return NO;
    range = [_string rangeOfString: string
                           options: _caseSensitive ? 0 : NSCaseInsensitiveSearch
                             range: range];
    if (range.length == 0)
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    if (value)
        *value = [_string substringWithRange: range];
    _scanLocation += range.length;
    return YES;
}

/**
 * <p>After initial skipping (if any), this method scans characters until
 * it finds string.  The scanned characters are placed in
 * value if that is not null.  If string is not found, all the characters
 * up to the end of the scanned string will be returned.
 * </p>
 * Returns YES if anything is scanned, NO otherwise.<br />
 * <p>NB. If the current scanner location points to a copy of string, or
 * points to skippable characters immediately before a copy of string
 * then this method returns NO since it finds no characters to store
 * in value before it finds string.
 * </p>
 * <p>To count the occurrences of string, this should be used in
 * conjunction with the -scanString:intoString: method.
 * </p>
 * <example>
 * NSString *ch = @"[";
 * unsigned total = 0;
 *
 * [scanner scanUpToString: ch intoString: NULL];
 * while ([scanner scanString: ch intoString: NULL] == YES)
 *  {
 *    total++;
 *    [scanner scanUpToString: ch intoString: NULL];
 *  }
 * NSLog(@"total %d", total);
 * </example>
 */
- (BOOL) scanUpToString: (NSString *)string
             intoString: (NSString **)value
{
    NSRange	range;
    NSRange	found;
    unsigned int	saveScanLocation = _scanLocation;
    
    if (skipToNextField() == NO)
    {
        return NO;
    }
    range.location = _scanLocation;
    range.length = myLength() - _scanLocation;
    found = [_string rangeOfString: string
                           options: _caseSensitive ? 0 : NSCaseInsensitiveSearch
                             range: range];
    if (found.length)
        range.length = found.location - _scanLocation;
    if (range.length == 0)
    {
        _scanLocation = saveScanLocation;
        return NO;
    }
    if (value)
        *value = [_string substringWithRange: range];
    _scanLocation += range.length;
    return YES;
}

/**
 * Returns the string being scanned.
 */
- (NSString *) string
{
    return _string;
}

/**
 * Returns the current position that the scanner has reached in
 * scanning the string.  This is the position at which the next scan
 * operation will begin.
 */
- (NSUInteger) scanLocation
{
    return _scanLocation;
}

/**
 * This method sets the location in the scanned string at which the
 * next scan operation begins.
 * Raises an NSRangeException if index is beyond the end of the
 * scanned string.
 */
- (void) setScanLocation: (NSUInteger)anIndex
{
    if (_scanLocation <= myLength())
        _scanLocation = anIndex;
    else
        [NSException raise: NSRangeException
                    format: @"Attempt to set scan location beyond end of string"];
}

/**
 * If the scanner is set to be case-sensitive in its scanning of
 * the string (other than characters to be skipped), this method
 * returns YES, otherwise it returns NO.
 * <br/>
 * The default is for a scanner to <em>not</em> be case sensitive.
 */
- (BOOL) caseSensitive
{
    return _caseSensitive;
}

/**
 * Sets the case sensitivity of the scanner.
 * <br/>
 * Case sensitivity governs matching of characters being scanned,
 * but does not effect the characters in the set to be skipped.
 * <br/>
 * The default is for a scanner to <em>not</em> be case sensitive.
 */
- (void) setCaseSensitive: (BOOL)flag
{
    _caseSensitive = flag;
}

/**
 * Returns a set of characters containing those characters that the
 * scanner ignores when starting any scan operation.  Once a character
 * not in this set has been encountered during an operation, skipping
 * is finished, and any further characters from this set that are
 * found are scanned normally.
 * <br/>
 * The default for this is the whitespaceAndNewlineCharacterSet.
 */
- (NSCharacterSet *) charactersToBeSkipped
{
    return _charactersToBeSkipped;
}

/**
 * Sets the set of characters that the scanner will skip over at the
 * start of each scanning operation to be <em>skipSet</em>.
 * Skipping is performed by literal character matching - the case
 * sensitivity of the scanner does not effect it.
 * If this is set to nil, no skipping is done.
 * <br/>
 * The default for this is the whitespaceAndNewlineCharacterSet.
 */
- (void) setCharactersToBeSkipped: (NSCharacterSet *)aSet
{
    ASSIGNCOPY(_charactersToBeSkipped, aSet);
    _skipImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
    [_charactersToBeSkipped methodForSelector: characterIsMemSel];
}

/**
 * Returns the locale set for the scanner, or nil if no locale has
 * been set.  A scanner uses it's locale to alter the way it handles
 * scanning - it uses the NSDecimalSeparator value for scanning
 * numbers.
 */
- (NSDictionary *) locale
{
    return _locale;
}

/**
 * This method sets the locale used by the scanner to <em>aLocale</em>.
 * The locale may be set to nil.
 */
- (void) setLocale: (NSDictionary *)localeDictionary
{
    ASSIGN(_locale, localeDictionary);
    /*
     * Get decimal point character from locale if necessary.
     */
    if (_locale == nil)
    {
        _decimal = '.';
    }
    else
    {
        NSString	*pointString;
        
        pointString = [_locale objectForKey: NSDecimalSeparator];
        if ([pointString length] > 0)
            _decimal = [pointString characterAtIndex: 0];
        else
            _decimal = '.';
    }
}

/*
 * NSCopying protocol
 */
- (id) copyWithZone: (NSZone *)zone
{
    NSScanner	*n = [[self class] allocWithZone: zone];
    
    n = [n initWithString: _string];
    [n setCharactersToBeSkipped: _charactersToBeSkipped];
    [n setLocale: _locale];
    [n setScanLocation: _scanLocation];
    [n setCaseSensitive: _caseSensitive];
    return n;
}

- (BOOL) scanHexDouble: (double *)result
{
    return NO;    // FIXME
}
- (BOOL) scanHexFloat: (float *)result
{
    return NO;    // FIXME
}
- (BOOL) scanInteger: (NSInteger *)value
{
#if GS_SIZEOF_VOIDP == GS_SIZEOF_INT
    return [self scanInt: (int *)value];
#else
    return [self scanLongLong: (long long *)value];
#endif
}
@end

/*
 * Some utilities
 */
BOOL
GSScanInt(unichar *buf, unsigned length, int *result)
{
    unsigned int num = 0;
    const unsigned int limit = UINT_MAX / 10;
    BOOL negative = NO;
    BOOL overflow = NO;
    BOOL got_digits = NO;
    unsigned int pos = 0;
    
    /* Check for sign */
    if (pos < length)
    {
        switch (buf[pos])
        {
            case '+':
                pos++;
                break;
            case '-':
                negative = YES;
                pos++;
                break;
        }
    }
    
    /* Process digits */
    while (pos < length)
    {
        unichar digit = buf[pos];
        
        if ((digit < '0') || (digit > '9'))
            break;
        if (!overflow)
        {
            if (num >= limit)
                overflow = YES;
            else
                num = num * 10 + (digit - '0');
        }
        pos++;
        got_digits = YES;
    }
    
    /* Save result */
    if (!got_digits)
    {
        return NO;
    }
    if (result)
    {
        if (overflow
            || (num > (negative ? (NSUInteger)INT_MIN : (NSUInteger)INT_MAX)))
            *result = negative ? INT_MIN: INT_MAX;
        else if (negative)
            *result = -num;
        else
            *result = num;
    }
    return YES;
}

/* Table of binary powers of 10 represented by bits in a byte.
 * Used to convert decimal integer exponents to doubles.
 */
static double powersOf10[] = {
    1.0e1, 1.0e2, 1.0e4, 1.0e8, 1.0e16, 1.0e32, 1.0e64, 1.0e128, 1.0e256
};

/**
 * Scan in a double value in the standard locale ('.' as decimal point).<br />
 * Return YES on success, NO on failure.<br />
 * The value pointed to by result is unmodified on failure.<br />
 * No value is returned in result if it is a null pointer.
 */
BOOL
GSScanDouble(unichar *buf, unsigned length, double *result)
{
    unichar	c = 0;
    char          mantissa[20];
    const char    *ptr;
    double        *d;
    double        value;
    double        e;
    int	        exponent = 0;
    BOOL	        negativeMantissa = NO;
    BOOL		negativeExponent = NO;
    unsigned	pos = 0;
    int           mantissaLength;
    int           dotPos = -1;
    int           hi = 0;
    int           lo = 0;
    
    /* Skip whitespace */
    while (pos < length && isspace((int)buf[pos]))
    {
        pos++;
    }
    if (pos >= length)
    {
        return NO;
    }
    
    /* Check for sign */
    switch (buf[pos])
    {
        case '+':
            pos++;
            break;
        case '-':
            negativeMantissa = YES;
            pos++;
            break;
    }
    if (pos >= length)
    {
        return NO;
    }
    
    /* Scan the mantissa ... at most 18 digits and a decimal point.
     */
    for (mantissaLength = 0; pos < length && mantissaLength < 19; pos++)
    {
        mantissa[mantissaLength] = c = buf[pos];
        if (!isdigit(c))
        {
            if ('.' != c || dotPos >= 0)
            {
                break;    // End of mantissa
            }
            dotPos = mantissaLength;
        }
        else
        {
            mantissaLength++;
        }
    }
    if (0 == mantissaLength)
    {
        return NO;        // No mantissa ... not a double
    }
    if (mantissaLength > 18)
    {
        /* Mantissa too long ... ignore excess.
         */
        mantissaLength = 18;
    }
    if (dotPos < 0)
    {
        dotPos = mantissaLength;
    }
    dotPos -= mantissaLength;      // Exponent offset for decimal point
    
    /* Convert mantissa characters to a double value
     */
    for (ptr = mantissa; mantissaLength > 9; mantissaLength -= 1)
    {
        c = *ptr;
        ptr += 1;
        hi = hi * 10 + (c - '0');
    }
    for (; mantissaLength > 0; mantissaLength -= 1)
    {
        c = *ptr;
        ptr += 1;
        lo = lo * 10 + (c - '0');
    }
    value = (1.0e9 * hi) + lo;
    
    /* Scan the exponent (if any)
     */
    if (pos < length && ('E' == (c = buf[pos]) || 'e' == c))
    {
        if (++pos >= length)
        {
            return NO;    // Missing exponent
        }
        c = buf[pos];
        if ('-' == c)
        {
            negativeExponent = YES;
            if (++pos >= length)
            {
                return NO;    // Missing exponent
            }
            c = buf[pos];
        }
        else if ('+' == c)
        {
            if (++pos >= length)
            {
                return NO;    // Missing exponent
            }
            c = buf[pos];
        }
        while (isdigit(c))
        {
            exponent = exponent * 10 + (c - '0');
            if (++pos >= length)
            {
                break;
            }
            c = buf[pos];
        }
    }
    
    /* Add in the amount to shift the exponent depending on the position
     * of the decimal point in the mantissa and check the adjusted sign
     * of the exponent.
     */
    if (YES == negativeExponent)
    {
        exponent = dotPos - exponent;
    }
    else
    {
        exponent = dotPos + exponent;
    }
    if (exponent < 0)
    {
        negativeExponent = YES;
        exponent = -exponent;
    }
    else
    {
        negativeExponent = NO;
    }
    if (exponent > 511)
    {
        return NO;        // Maximum exponent exceeded
    }
    
    /* Convert the exponent to a double then apply it to the value from
     * the mantissa.
     */
    e = 1.0;
    for (d = powersOf10; exponent != 0; exponent >>= 1, d += 1)
    {
        if (exponent & 1)
        {
            e *= *d;
        }
    }
    if (YES == negativeExponent)
    {
        value /= e;
    }
    else
    {
        value *= e;
    }
    
    if (0 != result)
    {
        if (YES == negativeMantissa)
        {
            *result = -value;
        }
        else
        {
            *result = value;
        }
    }
    return YES;
}