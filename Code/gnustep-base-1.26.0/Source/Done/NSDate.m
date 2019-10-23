#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCalendarDate.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSScanner.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSUserDefaults.h"
#import "GNUstepBase/GSObjCRuntime.h"

#import "GSPrivate.h"

#include <math.h>

/* These constants seem to be what MacOS-X uses */
#define DISTANT_FUTURE	63113990400.0
#define DISTANT_PAST	-63113817600.0

/* On older Solaris we don't have NAN nor nan() */
#if defined(__sun) && defined(__SVR4) && !defined(NAN)
#define NAN 0x7fffffffffffffff
#endif

const NSTimeInterval NSTimeIntervalSince1970 = 978307200.0;
NSString *const NSSystemClockDidChangeNotification = @"NSSystemClockDidChangeNotification";

static BOOL	debug = NO;
static Class	abstractClass = nil;
static Class	NSGDateClass = nil;
static Class	calendarClass = nil;

/**
 * Our concrete base class - NSCalendar date must share the ivar layout.
 */
@interface NSGDate : NSDate
{
@public
    NSTimeInterval _seconds_since_ref; // 可以看到, NSDate 里面仅仅只有一个数据, 就是时间戳, 其他只不过是对于这个 double 的计算而已.
}
@end

@interface	GSDateSingle : NSGDate
@end

@interface	GSDatePast : GSDateSingle
@end

@interface	GSDateFuture : GSDateSingle
@end

static id _distantPast = nil;
static id _distantFuture = nil;

static inline NSTimeInterval
timeStamp(NSDate* other)
{
    return [other timeIntervalSinceReferenceDate];
}

@implementation NSDate

+ (void) initialize
{
    if (self == [NSDate class])
    {
        abstractClass = self;
        NSGDateClass = [NSGDate class];
        calendarClass = [NSCalendarDate class];
    }
}

+ (id) date
{
    // 利用当前的系统时间, 生成一个时间对象.
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithTimeIntervalSinceReferenceDate: SystemTimeInterval()]);
}

+ (id) dateWithString: (NSString*)description
{
    return AUTORELEASE([[self alloc] initWithString: description]);
}

+ (id) dateWithTimeInterval: (NSTimeInterval)seconds sinceDate: (NSDate*)date
{
    return AUTORELEASE([[self alloc] initWithTimeInterval: seconds
                                                sinceDate: date]);
}

+ (id) dateWithTimeIntervalSince1970: (NSTimeInterval)seconds
{
    return AUTORELEASE([[self alloc] initWithTimeIntervalSinceReferenceDate:
                        seconds - NSTimeIntervalSince1970]);
}

+ (id) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds
{
    return AUTORELEASE([[self alloc] initWithTimeIntervalSinceNow: seconds]);
}

+ (id) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds
{
    return AUTORELEASE([[self alloc] initWithTimeIntervalSinceReferenceDate:
                        seconds]);
}

+ (id) distantPast
{
    if (_distantPast == nil)
    {
        _distantPast = [GSDatePast allocWithZone: 0];
    }
    return _distantPast;
}

+ (id) distantFuture
{
    if (_distantFuture == nil)
    {
        _distantFuture = [GSDateFuture allocWithZone: 0];
    }
    return _distantFuture;
}

/**
 * Returns the time interval between the current date and the
 * reference date (1 January 2001, GMT).
 */
+ (NSTimeInterval) timeIntervalSinceReferenceDate
{
    return SystemTimeInterval();
}

- (id) addTimeInterval: (NSTimeInterval)seconds
{
    return [self dateByAddingTimeInterval: seconds];
}

- (NSComparisonResult) compare: (NSDate*)otherDate
{
    if (otherDate == self)
    {
        return NSOrderedSame;
    }
    if (timeStamp(self) > timeStamp(otherDate))
    {
        return NSOrderedDescending;
    }
    if (timeStamp(self) < timeStamp(otherDate))
    {
        return NSOrderedAscending;
    }
    return NSOrderedSame;
}

- (id) dateByAddingTimeInterval: (NSTimeInterval)ti
{
    return [[self class] dateWithTimeIntervalSinceReferenceDate:
            timeStamp(self) + ti];
}

- (NSString*) description
{
    // Easiest to just have NSCalendarDate do the work for us
    NSString *s;
    NSCalendarDate *d = [calendarClass alloc];
    
    d = [d initWithTimeIntervalSinceReferenceDate: timeStamp(self)];
    s = [d description];
    RELEASE(d);
    return s;
}

- (NSString*) descriptionWithCalendarFormat: (NSString*)format
                                   timeZone: (NSTimeZone*)aTimeZone
                                     locale: (NSDictionary*)l
{
    // Easiest to just have NSCalendarDate do the work for us
    NSString *s;
    NSCalendarDate *d = [calendarClass alloc];
    id f;
    
    d = [d initWithTimeIntervalSinceReferenceDate: timeStamp(self)];
    if (!format)
    {
        f = [d calendarFormat];
    }
    else
    {
        f = format;
    }
    if (aTimeZone)
    {
        [d setTimeZone: aTimeZone];
    }
    s = [d descriptionWithCalendarFormat: f locale: l];
    RELEASE(d);
    return s;
}

- (NSString *) descriptionWithLocale: (id)locale
{
    // Easiest to just have NSCalendarDate do the work for us
    NSString *s;
    NSCalendarDate *d = [calendarClass alloc];
    
    d = [d initWithTimeIntervalSinceReferenceDate: timeStamp(self)];
    s = [d descriptionWithLocale: locale];
    RELEASE(d);
    return s;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
    if (timeStamp(self) > timeStamp(otherDate))
    {
        return otherDate;
    }
    return self;
}

- (NSUInteger) hash
{
    return (NSUInteger)[self timeIntervalSinceReferenceDate];
}

- (id) init
{
    return [self initWithTimeIntervalSinceReferenceDate: SystemTimeInterval()];
}

- (id) initWithString: (NSString*)description
{
    NSCalendarDate	*d = [calendarClass alloc];
    d = [d initWithString: description];
    if (nil == d)
    {
        DESTROY(self);
        return nil;
    }
    else
    {
        self = [self initWithTimeIntervalSinceReferenceDate: timeStamp(d)];
        RELEASE(d);
        return self;
    }
}

// 所有的初始化方法, 都会归到一个地方.
- (id) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
                  sinceDate: (NSDate*)anotherDate
{
    return [self initWithTimeIntervalSinceReferenceDate:
            timeStamp(anotherDate) + secsToBeAdded];
}

- (id) initWithTimeIntervalSince1970: (NSTimeInterval)seconds
{
    return [self initWithTimeIntervalSinceReferenceDate:
            seconds - NSTimeIntervalSince1970];
}

- (id) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded
{
    // Get the current time, add the secs and init thyself
    return [self initWithTimeIntervalSinceReferenceDate:
            SystemTimeInterval() + secsToBeAdded];
}

- (BOOL) isEqual: (id)other
{
    if (other != nil
        && [other isKindOfClass: abstractClass]
        && timeStamp(self) == timeStamp(other))
    {
        return YES;
    }
    return NO;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
    if (other != nil
        && timeStamp(self) == timeStamp(other))
    {
        return YES;
    }
    return NO;
}

- (NSDate*) laterDate: (NSDate*)otherDate
{
    if (timeStamp(self) < timeStamp(otherDate))
    {
        return otherDate;
    }
    return self;
}

- (NSTimeInterval) timeIntervalSince1970
{
    return timeStamp(self) + NSTimeIntervalSince1970;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
    if (nil == otherDate)
    {
        return NAN;
    }
    return timeStamp(self) - timeStamp(otherDate);
}

- (NSTimeInterval) timeIntervalSinceNow
{
    return timeStamp(self) - SystemTimeInterval();
}

@end

@implementation NSGDate

+ (void) initialize
{
    if (self == [NSDate class])
    {
        [self setVersion: 1];
    }
}

- (NSComparisonResult) compare: (NSDate*)otherDate
{
    if (otherDate == self)
    {
        return NSOrderedSame;
    }
    if (otherDate == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"nil argument for compare:"];
    }
    if (_seconds_since_ref > timeStamp(otherDate))
    {
        return NSOrderedDescending;
    }
    if (_seconds_since_ref < timeStamp(otherDate))
    {
        return NSOrderedAscending;
    }
    return NSOrderedSame;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
    if (otherDate == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"nil argument for earlierDate:"];
    }
    if (_seconds_since_ref > timeStamp(otherDate))
    {
        return otherDate;
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
    if ([coder allowsKeyedCoding])
    {
        [coder encodeDouble:_seconds_since_ref forKey:@"NS.time"];
    }
    else
    {
        [coder encodeValueOfObjCType: @encode(NSTimeInterval)
                                  at: &_seconds_since_ref];
    }
}

- (NSUInteger) hash
{
    return (unsigned)_seconds_since_ref;
}

- (id) initWithCoder: (NSCoder*)coder
{
    if ([coder allowsKeyedCoding])
    {
        _seconds_since_ref = [coder decodeDoubleForKey: @"NS.time"];
    }
    else
    {
        [coder decodeValueOfObjCType: @encode(NSTimeInterval)
                                  at: &_seconds_since_ref];
    }
    return self;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
    if (isnan(secs))
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] interval is not a number",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    _seconds_since_ref = secs;
    return self;
}

- (BOOL) isEqual: (id)other
{
    if (other != nil
        && [other isKindOfClass: abstractClass]
        && _seconds_since_ref == timeStamp(other))
    {
        return YES;
    }
    return NO;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
    if (other != nil
        && _seconds_since_ref == timeStamp(other))
    {
        return YES;
    }
    return NO;
}

- (NSDate*) laterDate: (NSDate*)otherDate
{
    if (otherDate == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"nil argument for laterDate:"];
    }
    if (_seconds_since_ref < timeStamp(otherDate))
    {
        return otherDate;
    }
    return self;
}

- (NSTimeInterval) timeIntervalSince1970
{
    return _seconds_since_ref + NSTimeIntervalSince1970;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
    if (otherDate == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"nil argument for timeIntervalSinceDate:"];
    }
    return _seconds_since_ref - timeStamp(otherDate);
}

- (NSTimeInterval) timeIntervalSinceNow
{
    return _seconds_since_ref - SystemTimeInterval();
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
    return _seconds_since_ref;
}

@end

/*
 *	This abstract class represents a date of which there can be only
 *	one instance.
 */
@implementation GSDateSingle

+ (void) initialize
{
    if (self == [GSDateSingle class])
    {
        GSObjCAddClassBehavior(self, [NSGDate class]);
    }
}

@end

@implementation GSDatePast

+ (id) allocWithZone: (NSZone*)z
{
    if (_distantPast == nil)
    {
        id	obj = NSAllocateObject(self, 0, NSDefaultMallocZone());
        
        _distantPast = [obj init];
    }
    return _distantPast;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
    _seconds_since_ref = DISTANT_PAST;
    return self;
}

@end


@implementation GSDateFuture // 专门的一个类, 这个类的时间戳是固定的.

+ (id) allocWithZone: (NSZone*)z
{
    if (_distantFuture == nil)
    {
        id	obj = NSAllocateObject(self, 0, NSDefaultMallocZone());
        
        _distantFuture = [obj init];
    }
    return _distantFuture;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
    _seconds_since_ref = DISTANT_FUTURE;
    return self;
}

@end


