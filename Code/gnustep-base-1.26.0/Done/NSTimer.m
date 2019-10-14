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

/**
 */
@implementation NSTimer

+ (void) initialize
{
    if (self == [NSTimer class])
    {
        NSDate_class = [NSGDate class];
    }
}

- (NSString*) description
{
    NSString      *s = [super description];
    
    if ([self isValid]) // 只有在还有效的时候, 才输出关键的信息. 这里, 虽然仅仅是字符串的描述值, 也要考虑下功能性.
    {
        if (_selector == 0)
        {
            return [NSString stringWithFormat: @"%@ at %@ invokes %@",
                    s, [self fireDate], _target];
        }
        else
        {
            return [NSString stringWithFormat: @"%@ at %@ sends %@ to (%@)",
                    s, [self fireDate], NSStringFromSelector(_selector), _target];
        }
    }
    else
    {
        return [NSString stringWithFormat: @"%@ (invalidated)", s];
    }
}

/* For MacOS-X compatibility, this returns nil.
 */
- (id) init
{
    DESTROY(self);
    return nil;
}

/** <init />
 * Initialise the receive, a newly allocated NSTimer object.<br />
 * The ti argument specifies the time (in seconds) between the firing.
 * If it is less than or equal to 0.0 then a small interval is chosen
 * automatically.<br />
 * The fd argument specifies an initial fire date copied by the timer... // copied for safety
 * if it is not supplied (a nil object) then the ti argument is used to
 * create a start date relative to the current time.<br />
 * The f argument specifies whether the timer will fire repeatedly
 * or just once.<br />
 * If the selector argument is zero, then then object is an invocation
 * to be used when the timer fires.  otherwise, the object is sent the
 * message specified by the selector and with the timer as an argument.<br />
 * The object and info arguments will be retained until the timer is // 这里, 为什么要 retain 呢. 其实, 这种异步操作, 都是要进行 retain 处理的, 不然无法保证target对象的生命周期.
 * invalidated.
 */
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
    if (fd == nil) // 如果 fireDate 没有指定的话, 就用现在时间加上 interval 来指定. 也就是说, interval 也代表着现在和第一次触发的时间.
    {
        _date = [[NSDate_class allocWithZone: NSDefaultMallocZone()]
                 initWithTimeIntervalSinceNow: ti];
    }
    else
    {
        _date = [fd copyWithZone: NSDefaultMallocZone()];
    }
    _target = RETAIN(object);
    _selector = selector;
    _info = RETAIN(info); // 就和 NSNotification 的 info一样, 作为传值用的.
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

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, invocation will be performed.<br />
 * NB. To make the timer operate, you must add it to a run loop.
 */
+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
                        invocation: (NSInvocation*)invocation // 这里, 感觉这个设计不好啊, 明明 target action 已经很明确的机制了, 为什么要整个 invocation.
                           repeats: (BOOL)f
{
    return AUTORELEASE([[self alloc] initWithFireDate: nil
                                             interval: ti
                                               target: invocation
                                             selector: NULL
                                             userInfo: nil
                                              repeats: f]);
}

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, the target object will be
 * sent a message specified by selector and with the timer as its
 * argument.<br />
 * NB. To make the timer operate, you must add it to a run loop.
 */
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

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, invocation will be performed.<br />
 * This timer will automatically be added to the current run loop and
 * will fire in the default run loop mode.
 *
 */
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
    [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode]; // 这个函数, 只不过是为了方便而添加的. 对于不知道 runloop 的人来说, 这个函数, 可以封装 timer 的使用原理.
    RELEASE(t);
    return t;
}

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, the target object will be
 * sent a message specified by selector and with the timer as its
 * argument.<br />
 * This timer will automatically be added to the current run loop and
 * will fire in the default run loop mode.
 */
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

- (void) dealloc
{
    if (_invalidated == NO)
    {
        [self invalidate];
    }
    RELEASE(_date);
    [super dealloc];
}

/**
 * Fires the timer ... either performs an invocation or sends a message
 * to a target object, depending on how the timer was set up.<br />
 * If the timer is not set to repeat, it is automatically invalidated.<br />
 * Exceptions raised during firing of the timer are caught and logged.
 */
- (void) fire
{
    /* We check that we have not been invalidated before we fire.
     */
    if (NO == _invalidated)
    {
        id	target;
        
        /* We retain the target so it won't be deallocated while we are using it
         * (if this timer gets invalidated while we are firing).
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
        if (_repeats == NO)
        {
            [self invalidate];
        }
    }
}

/**
 * Marks the timer as invalid, causing its target/invocation and user info
 * objects to be released.<br />
 * Invalidated timers are automatically removed from the run loop when it
 * detects them.
 */
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
