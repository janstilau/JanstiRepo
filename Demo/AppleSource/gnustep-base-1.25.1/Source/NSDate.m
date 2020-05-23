
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
static Class	concreteClass = nil;
static Class	calendarClass = nil;

/**
 * Our concrete base class - NSCalendar date must share the ivar layout.
 */
@interface NSGDate : NSDate
{
@public
    NSTimeInterval _seconds_since_ref; // 最基本的数据,
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


static NSString*
findInArray(NSArray *array, unsigned pos, NSString *str)
{
    unsigned	index;
    unsigned	limit = [array count];
    
    for (index = pos; index < limit; index++)
    {
        NSString	*item;
        
        item = [array objectAtIndex: index];
        if ([str caseInsensitiveCompare: item] == NSOrderedSame)
            return item;
    }
    return nil;
}

static inline NSTimeInterval
otherTime(NSDate* other)
{
    Class	c;
    
    c = object_getClass(other);
    if (c == concreteClass || c == calendarClass)
        return ((NSGDate*)other)->_seconds_since_ref; // 这里这样写感觉没有必要啊, timeIntervalSinceReferenceDate 是所有的子类都应该重写的方法, 既然 NSGDate 的实现里面, 就是返回 _seconds_since_ref, 那么直接调用不就好了. 这里徒增复杂度.
    else
        return [other timeIntervalSinceReferenceDate];
}

@implementation NSDate

+ (void) initialize
{
    if (self == [NSDate class])
    {
        [self setVersion: 1];
        abstractClass = self;
        concreteClass = [NSGDate class];
        calendarClass = [NSCalendarDate class];
    }
}

// 1. 在 alloc 的阶段, 就生成实际类
// 2. 在 init 阶段, 在生成实际类.
+ (id) alloc
{
    if (self == abstractClass)
    {
        return NSAllocateObject(concreteClass, 0, NSDefaultMallocZone()); // 接口和实体类之间的差别.
    }
    return NSAllocateObject(self, 0, NSDefaultMallocZone());
}

+ (id) allocWithZone: (NSZone*)z
{
    if (self == abstractClass)
    {
        return NSAllocateObject(concreteClass, 0, z);
    }
    return NSAllocateObject(self, 0, z);
}

// GSPrivateTimeNow 是和 2001,1,1 比较的, 所以使用的是 initWithTimeIntervalSinceReferenceDate
// initWithTimeIntervalSinceReferenceDate 的内部, 也就仅仅是记录一下时间戳而已.
+ (id) date
{
    return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
                        initWithTimeIntervalSinceReferenceDate: GSPrivateTimeNow()]);
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

// seconds 加上时间戳.
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
    return GSPrivateTimeNow();
}

- (id) addTimeInterval: (NSTimeInterval)seconds
{
    return [self dateByAddingTimeInterval: seconds];
}

- (int) compare: (NSDate*)otherDate
{
    if (otherDate == self)
    {
        return 0;
    }
    if (otherTime(self) > otherTime(otherDate))
    {
        return 1;
    }
    if (otherTime(self) < otherTime(otherDate))
    {
        return -1;
    }
    return 0;
}

- (id) dateByAddingTimeInterval: (NSTimeInterval)ti
{
    return [[self class] dateWithTimeIntervalSinceReferenceDate:
            otherTime(self) + ti];
}

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
                                   timeZone: (NSTimeZone*)timeZone
{
    NSCalendarDate *d = [calendarClass alloc];
    
    d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
    [d setCalendarFormat: formatString];
    [d setTimeZone: timeZone];
    return AUTORELEASE(d);
}

- (NSString*) description
{
    // Easiest to just have NSCalendarDate do the work for us
    NSString *s;
    NSCalendarDate *d = [calendarClass alloc];
    
    d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
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
    
    d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
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
    
    d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
    s = [d descriptionWithLocale: locale];
    RELEASE(d);
    return s;
}

- (NSDate*) earlierDate: (NSDate*)otherDate // 比较, 取出靠前的时间. 同 self 比较.
{
    if (otherTime(self) > otherTime(otherDate))
    {
        return otherDate;
    }
    return self;
}

// 这里, 存储的也就是一个时间戳而已.
- (void) encodeWithCoder: (NSCoder*)coder
{
    NSTimeInterval	interval = [self timeIntervalSinceReferenceDate];
    
    if ([coder allowsKeyedCoding])
    {
        [coder encodeDouble: interval forKey: @"NS.time"];
    }
    [coder encodeValueOfObjCType: @encode(NSTimeInterval) at: &interval];
}

- (int) hash
{
    return (NSUInteger)[self timeIntervalSinceReferenceDate];
}

- (id) initWithCoder: (NSCoder*)coder
{
    NSTimeInterval	interval;
    id			o;
    
    if ([coder allowsKeyedCoding])
    {
        interval = [coder decodeDoubleForKey: @"NS.time"];
    }
    else
    {
        [coder decodeValueOfObjCType: @encode(NSTimeInterval) at: &interval];
    }
    if (interval == DISTANT_PAST)
    {
        o = RETAIN([abstractClass distantPast]);
    }
    else if (interval == DISTANT_FUTURE)
    {
        o = RETAIN([abstractClass distantFuture]);
    }
    else
    {
        o = [concreteClass allocWithZone: NSDefaultMallocZone()];
        o = [o initWithTimeIntervalSinceReferenceDate: interval];
    }
    DESTROY(self);
    return o;
}

- (id) init
{
    return [self initWithTimeIntervalSinceReferenceDate: GSPrivateTimeNow()];
}

- (id) initWithString: (NSString*)description
{
    // Easiest to just have NSCalendarDate do the work for us
    NSCalendarDate	*d = [calendarClass alloc];
    
    d = [d initWithString: description];
    if (nil == d)
    {
        DESTROY(self);
        return nil;
    }
    else
    {
        self = [self initWithTimeIntervalSinceReferenceDate: otherTime(d)];
        RELEASE(d);
        return self;
    }
}

// 把 anotherDate 的时间戳拿出来, 然后加上 secsToBeAdded, 存储到自己的时间戳里面
- (id) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
                  sinceDate: (NSDate*)anotherDate
{
    if (anotherDate == nil)
    {
        NSLog(@"initWithTimeInterval:sinceDate: given nil date");
        DESTROY(self);
        return nil;
    }
    // Get the other date's time, add the secs and init thyself
    return [self initWithTimeIntervalSinceReferenceDate:
            otherTime(anotherDate) + secsToBeAdded];
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
            GSPrivateTimeNow() + secsToBeAdded];
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
    [self subclassResponsibility: _cmd];
    return self;
}

- (BOOL) isEqual: (id)other
{
    if (other != nil
        && [other isKindOfClass: abstractClass]
        && otherTime(self) == otherTime(other))
    {
        return YES;
    }
    return NO;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
    if (other != nil
        && otherTime(self) == otherTime(other))
    {
        return YES;
    }
    return NO;
}

- (NSDate*) laterDate: (NSDate*)otherDate
{
    if (otherTime(self) < otherTime(otherDate))
    {
        return otherDate;
    }
    return self;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
    if ([aCoder isByref] == NO)
    {
        return self;
    }
    return [super replacementObjectForPortCoder: aCoder];
}

- (NSTimeInterval) timeIntervalSince1970
{
    return otherTime(self) + NSTimeIntervalSince1970;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
    if (nil == otherDate)
    {
#ifndef NAN
        return nan("");
#else
        return NAN;
#endif
    }
    return otherTime(self) - otherTime(otherDate);
}

- (NSTimeInterval) timeIntervalSinceNow
{
    return otherTime(self) - GSPrivateTimeNow();
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
    [self subclassResponsibility: _cmd];
    return 0;
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
    if (_seconds_since_ref > otherTime(otherDate))
    {
        return NSOrderedDescending;
    }
    if (_seconds_since_ref < otherTime(otherDate))
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
    if (_seconds_since_ref > otherTime(otherDate))
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

- (int) hash
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
    
#if	GS_SIZEOF_VOIDP == 4
    if (secs <= DISTANT_PAST)
    {
        secs = DISTANT_PAST;
    }
    else if (secs >= DISTANT_FUTURE)
    {
        secs = DISTANT_FUTURE;
    }
#endif
    _seconds_since_ref = secs;
    return self;
}

- (BOOL) isEqual: (id)other
{
    if (other != nil
        && [other isKindOfClass: abstractClass]
        && _seconds_since_ref == otherTime(other))
    {
        return YES;
    }
    return NO;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
    if (other != nil
        && _seconds_since_ref == otherTime(other)) // 这里为什么用 == , 奇怪.
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
    if (_seconds_since_ref < otherTime(otherDate))
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
    return _seconds_since_ref - otherTime(otherDate);
}

- (NSTimeInterval) timeIntervalSinceNow
{
    return _seconds_since_ref - GSPrivateTimeNow();
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
        [self setVersion: 1];
        GSObjCAddClassBehavior(self, [NSGDate class]);
    }
}

- (id) autorelease
{
    return self;
}

- (oneway void) release
{
}

- (id) retain
{
    return self;
}

+ (id) allocWithZone: (NSZone*)z
{
    [NSException raise: NSInternalInconsistencyException
                format: @"Attempt to allocate fixed date"];
    return nil;
}

- (id) copyWithZone: (NSZone*)z
{
    return self;
}

- (void) dealloc
{
    [NSException raise: NSInternalInconsistencyException
                format: @"Attempt to deallocate fixed date"];
    GSNOSUPERDEALLOC;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
    return self;
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


@implementation GSDateFuture

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


