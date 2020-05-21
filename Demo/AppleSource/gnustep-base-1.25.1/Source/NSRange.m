#import "common.h"

#define	IN_NSRANGE_M 1
#import "Foundation/NSException.h"
#import "Foundation/NSRange.h"
#import "Foundation/NSScanner.h"

@class	NSString;

static Class	NSStringClass = 0;
static Class	NSScannerClass = 0;
static SEL	scanIntegerSel;
static SEL	scanStringSel;
static SEL	scannerSel;
static BOOL	(*scanIntegerImp)(NSScanner*, SEL, NSInteger*);
static BOOL	(*scanStringImp)(NSScanner*, SEL, NSString*, NSString**);
static id 	(*scannerImp)(Class, SEL, NSString*);

static inline void
setupCache(void)
{
  if (NSStringClass == 0)
    {
      NSStringClass = [NSString class];
      NSScannerClass = [NSScanner class];
      scanIntegerSel = @selector(scanInteger:);
      scanStringSel = @selector(scanString:intoString:);
      scannerSel = @selector(scannerWithString:);
      scanIntegerImp = (BOOL (*)(NSScanner*, SEL, NSInteger*))
	[NSScannerClass instanceMethodForSelector: scanIntegerSel];
      scanStringImp = (BOOL (*)(NSScanner*, SEL, NSString*, NSString**))
	[NSScannerClass instanceMethodForSelector: scanStringSel];
      scannerImp = (id (*)(Class, SEL, NSString*))
	[NSScannerClass methodForSelector: scannerSel];
    }
}

NSRange
NSRangeFromString(NSString *aString)
{
  NSScanner	*scanner;
  NSRange	range;

  setupCache(); // 没有问题, 该有的地方进行调用就可以了. 因为没有类的这个机制在, 所以, 需要缓存的地方, 都要显示的进行调用.
  scanner = (*scannerImp)(NSScannerClass, scannerSel, aString);
  if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"location", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanIntegerImp)(scanner, scanIntegerSel, (NSInteger*)&range.location)
    && (*scanStringImp)(scanner, scanStringSel, @",", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"length", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanIntegerImp)(scanner, scanIntegerSel, (NSInteger*)&range.length)
    && (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
    return range;
  else
    return NSMakeRange(0, 0);
}

NSString *
NSStringFromRange(NSRange range)
{
  setupCache(); // 没有问题, 该有的地方进行调用就可以了. 因为没有类的这个机制在, 所以, 需要缓存的地方, 都要显示的进行调用.
  return [NSStringClass
    stringWithFormat: @"{location=%"PRIuPTR", length=%"PRIuPTR"}",
    range.location, range.length];
}

GS_EXPORT void _NSRangeExceptionRaise ()
{
  [NSException raise: NSRangeException
	       format: @"Range location + length too great"];
}
