#import "common.h"
#define	EXPOSE_NSTimer_IVARS	1
#import "Foundation/NSTimer.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSException.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSInvocation.h"

@class	NSGDate;
@interface NSGDate : NSObject	// Help the compiler
@end
static Class	NSDate_class;

@implementation NSTimer

+ (void) initialize
{
    if (self == [NSTimer class])
    {
        NSDate_class = [NSGDate class];
    }
}


/* For MacOS-X compatibility, this returns nil.
 */
- (id) init
{
    DESTROY(self);
    return nil;
}

- (id) initWithFireDate: (NSDate*)fd
               interval: (NSTimeInterval)ti
                 target: (id)object
               selector: (SEL)selector
               userInfo: (id)info
                repeats: (BOOL)f
{
    if (ti <= 0.0)
    {
        ti = 0.0001;
    }
    /*
     这些重要的数据, 一定要有错误修正处理.
     */
    if (fd == nil)
    {
        _date = [[NSDate_class allocWithZone: NSDefaultMallocZone()]
                 initWithTimeIntervalSinceNow: ti];
    } else {
        _date = [fd copyWithZone: NSDefaultMallocZone()];
    }
    // Timer 的内存管理需要注意的事情.
    _target = RETAIN(object);
    _info = RETAIN(info);
    _selector = selector;
    if (f == YES)
    {
        _repeats = YES;
        _interval = ti;
    }
    else
    {
        _repeats = NO;
        _interval = 0.0;
    }
    return self;
}

- (instancetype) initWithFireDate: (NSDate *)date
                         interval: (NSTimeInterval)interval
                          repeats: (BOOL)repeats
                            block: (GSTimerBlock)block
{
    ASSIGN(_block, block);
    return [self initWithFireDate: date
                         interval: interval
                           target: nil
                         selector: NULL
                         userInfo: nil
                          repeats: repeats];
}

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
                        invocation: (NSInvocation*)invocation
                           repeats: (BOOL)f
{
    return AUTORELEASE([[self alloc] initWithFireDate: nil
                                             interval: ti
                                               target: invocation
                                             selector: NULL
                                             userInfo: nil
                                              repeats: f]);
}

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
                            target: (id)object
                          selector: (SEL)selector
                          userInfo: (id)info
                           repeats: (BOOL)f
{
    return AUTORELEASE([[self alloc] initWithFireDate: nil
                                             interval: ti
                                               target: object
                                             selector: selector
                                             userInfo: info
                                              repeats: f]);
}

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
                                 invocation: (NSInvocation*)invocation
                                    repeats: (BOOL)f
{
    id t = [[self alloc] initWithFireDate: nil
                                 interval: ti
                                   target: invocation
                                 selector: NULL
                                 userInfo: nil
                                  repeats: f];
    [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
    RELEASE(t);
    return t;
}

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
                                     target: (id)object
                                   selector: (SEL)selector
                                   userInfo: (id)info
                                    repeats: (BOOL)f
{
    id t = [[self alloc] initWithFireDate: nil
                                 interval: ti
                                   target: object
                                 selector: selector
                                 userInfo: info
                                  repeats: f];
    [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
    RELEASE(t);
    return t;
}

+ (NSTimer *) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
                                     repeats: (BOOL)f
                                       block: (GSTimerBlock)block
{
    id t = [[self alloc] initWithFireDate: nil
                                 interval: ti
                                  repeats: f
                                    block: block];
    [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
    RELEASE(t);
    return t;
}

- (void) dealloc
{
    if (_invalidated == NO)
    {
        [self invalidate];
    }
    RELEASE(_date);
    [super dealloc];
}

- (void) fire
{
    if (NO == _invalidated)
    {
        if ((id)_block != nil)
        {
            CALL_BLOCK(_block, self);
        }
        else
        {
            id	target;
            
            /* We retain the target so it won't be deallocated while we are using
             * it (if this timer gets invalidated while we are firing).
             */
            target = RETAIN(_target);
            
            if (_selector == 0)
            {
                NS_DURING
                {
                    [(NSInvocation*)target invoke];
                }
                NS_HANDLER
                {
                    NSLog(@"*** NSTimer ignoring exception '%@' (reason '%@') "
                          @"raised during posting of timer with target %s(%s) "
                          @"and selector '%@'",
                          [localException name], [localException reason],
                          GSClassNameFromObject(target),
                          GSObjCIsInstance(target) ? "instance" : "class",
                          NSStringFromSelector([target selector]));
                }
                NS_ENDHANDLER
            }
            else
            {
                NS_DURING
                {
                    [target performSelector: _selector withObject: self];
                }
                NS_HANDLER
                {
                    NSLog(@"*** NSTimer ignoring exception '%@' (reason '%@') "
                          @"raised during posting of timer with target %p and "
                          @"selector '%@'",
                          [localException name], [localException reason], target,
                          NSStringFromSelector(_selector));
                }
                NS_ENDHANDLER
            }
            RELEASE(target);
        }
        
        if (_repeats == NO)
        {
            [self invalidate];
        }
    }
}

- (void) invalidate
{
    /* OPENSTEP allows this method to be called multiple times. */
    _invalidated = YES;
    if (_target != nil)
    {
        DESTROY(_target);
    }
    if (_info != nil)
    {
        DESTROY(_info);
    }
}

/**
 * Checks to see if the timer has been invalidated.
 */
- (BOOL) isValid
{
    if (_invalidated == NO)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

/**
 * Returns the date/time at which the timer is next due to fire.
 */
- (NSDate*) fireDate
{
    return _date;
}

/**
 * Change the fire date for the receiver.<br />
 * NB. You should <em>NOT</em> use this method for a timer which has
 * been added to a run loop.  The only time when it is safe to modify
 * the fire date of a timer in a run loop is for a repeating timer
 * when the timer is actually in the process of firing.
 */
- (void) setFireDate: (NSDate*)fireDate
{
    ASSIGN(_date, fireDate);
}

/**
 * Returns the interval between firings, or zero if the timer
 * does not repeat.
 */
- (NSTimeInterval) timeInterval
{
    return _interval;
}

/**
 * Returns the user info which was set for the timer when it was created,
 * or nil if none was set or the timer is invalid.
 */
- (id) userInfo
{
    return _info;
}

/**
 * Compares timers based on the date at which they should next fire.
 */
- (NSComparisonResult) compare: (id)anotherTimer
{
    if (anotherTimer == self)
    {
        return NSOrderedSame;
    }
    else if (anotherTimer == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"nil argument for compare:"];
    }
    else
    {
        return [_date compare: ((NSTimer*)anotherTimer)->_date];
    }
    return 0;
}

@end
