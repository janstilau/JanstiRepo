#import "common.h"
#define	EXPOSE_NSRunLoop_IVARS	1
#define	EXPOSE_NSTimer_IVARS	1
#import "Foundation/NSMapTable.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSPort.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSInvocation.h"
#import "GSRunLoopCtxt.h"
#import "GSRunLoopWatcher.h"
#import "GSStream.h"

#import "GSPrivate.h"

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_POLL_F
#include <poll.h>
#endif
#include <math.h>
#include <time.h>

#if HAVE_DISPATCH_GET_MAIN_QUEUE_HANDLE_NP && HAVE_DISPATCH_MAIN_QUEUE_DRAIN_NP
#  define RL_INTEGRATE_DISPATCH 1
#  ifdef HAVE_DISPATCH_H
#    include <dispatch.h>
#  elif HAVE_DISPATCH_DISPATCH_H
#    include <dispatch/dispatch.h>
#  endif
#endif


NSString * const NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";

static NSDate	*theFuture = nil;

@interface NSObject (OptionalPortRunLoop)
- (void) getFds: (NSInteger*)fds count: (NSInteger*)count;
@end



/*
 *	The GSRunLoopPerformer class is used to hold information about
 *	messages which are due to be sent to objects once each runloop
 *	iteration has passed.
 
 */
@interface GSRunLoopPerformer: NSObject
{
@public
    SEL		selector;
    id		target;
    id		argument;
    unsigned	order;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  order: (NSUInteger)order;
@end

@implementation GSRunLoopPerformer

- (void) dealloc
{
    RELEASE(target);
    RELEASE(argument);
    [super dealloc];
}

- (void) fire
{
    NS_DURING
    {
        [target performSelector: selector withObject: argument];
    }
    NS_HANDLER
    {
        NSLog(@"*** NSRunLoop ignoring exception '%@' (reason '%@') "
              @"raised during performSelector... with target %s(%s) "
              @"and selector '%s'",
              [localException name], [localException reason],
              GSClassNameFromObject(target),
              GSObjCIsInstance(target) ? "instance" : "class",
              sel_getName(selector));
    }
    NS_ENDHANDLER
}

- (id) initWithSelector: (SEL)aSelector
                 target: (id)aTarget
               argument: (id)anArgument
                  order: (NSUInteger)theOrder
{
    self = [super init];
    if (self)
    {
        selector = aSelector;
        target = RETAIN(aTarget);
        argument = RETAIN(anArgument);
        order = theOrder;
    }
    return self;
}

@end



@interface NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers;
@end

@implementation	NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers
{
    return _timedPerformers;
}
@end

/*
 * The GSTimedPerformer class is used to hold information about
 * messages which are due to be sent to objects at a particular time. due to 应归于.
 
 这个对象, 其实是对于延时操作的一个包装体. 之所以要有这么一个东西, 是因为, timer 如果加入到runloop 之后, NSObject 其实是有着权力取消之前添加进入的定时任务的, 所以, 需要对加入 runLoop 的任务做一次包装处理. 因为是我们自己包装的对象, 也就有了更大的操作的空间.
 */
@interface GSTimedPerformer: NSObject
{
@public
    SEL		selector; // 执行函数
    id		target; // 执行对象
    id		argument; // 执行参数
    NSTimer	*timer; // 执行的定时器
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  delay: (NSTimeInterval)delay;
- (void) invalidate;
@end

@implementation GSTimedPerformer

- (void) dealloc
{
    [self finalize]; // 取消定时器
    TEST_RELEASE(timer);
    RELEASE(target);
    RELEASE(argument);
    [super dealloc];
}

- (void) fire
{
    DESTROY(timer);
    [target performSelector: selector withObject: argument];
    [[[NSRunLoop currentRunLoop] _timedPerformers] // 修改存储的容器.
     removeObjectIdenticalTo: self];
}

- (void) finalize
{
    [self invalidate];
}

// 在构造方法的内部, 根据传递过来的参数, 创建所需要的参数.
- (id) initWithSelector: (SEL)aSelector
                 target: (id)aTarget
               argument: (id)anArgument
                  delay: (NSTimeInterval)delay
{
    self = [super init];
    if (self != nil)
    {
        selector = aSelector;
        target = RETAIN(aTarget);
        argument = RETAIN(anArgument);
        timer = [[NSTimer allocWithZone: NSDefaultMallocZone()] // 这里, 直接建立一个定时器, 因为这个定时器在之后, 要加入到 runloop 的内部.
                 initWithFireDate: nil
                 interval: delay
                 target: self
                 selector: @selector(fire)
                 userInfo: nil
                 repeats: NO];
    }
    return self;
}

- (void) invalidate
{
    if (timer != nil)
    {
        [timer invalidate];
        DESTROY(timer);
    }
}

@end



/*
 *      Setup for inline operation of arrays.
 */

#ifndef GSI_ARRAY_TYPES
#define GSI_ARRAY_TYPES       GSUNION_OBJ

#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]

#include "GNUstepBase/GSIArray.h"
#endif

static inline NSDate *timerDate(NSTimer *t)
{
    return t->_date;
}
static inline BOOL timerInvalidated(NSTimer *t)
{
    return t->_invalidated;
}


// 其实我们可以猜想, 在 runloop 的内部, 一定会有着操作 _timedPerformers 的代码, 在人物执行之后, 会对 _timedPerformers 进行更新.
@implementation NSObject (TimedPerformers)

/*
 * Cancels any perform operations set up for the specified target
 * in the current run loop.
 */

/*
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
{
    NSMutableArray	*perf = [[NSRunLoop currentRunLoop] _timedPerformers]; // 首先拿到任务的缓存数组.
    unsigned		count = [perf count];
    
    if (count > 0)
    {
        GSTimedPerformer	*array[count];
        
        IF_NO_GC(RETAIN(target));
        [perf getObjects: array];
        while (count-- > 0)
        {
            GSTimedPerformer	*p = array[count];
            
            if (p->target == target)
            {
                [p invalidate]; // invalidate 做了什么事情呢. 标志位的改变. 所以, 对于一个任务来说, 如果它正在执行, 是不能 invalidate 的. 因为想要让一段代码终止是很难的事情, 除非在代码里面加入控制的逻辑, NSOperation 里面, 就有这样的控制逻辑. 而对于 timer 来说, 它是依托于 runloop 进行执行的, 所以, 一个 timer 进行 invalidate 的话, 只做一个标志位的改变就可以了, 这就需要在 runloop 里面添加, 如果 timer 的标志位invalid, 就不执行定时器的代码.
                [perf removeObjectAtIndex: count];
            }
        }
        RELEASE(target);
    }
}

/*
 * Cancels any perform operations set up for the specified target
 * in the current loop, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
 */
// 从上面的两处代码我们可以看出, _timedPerformers 这个数组的最大的价值, 就是在 runloop 里面, 进行任务的管理操作.
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
                                        selector: (SEL)aSelector
                                          object: (id)arg
{
    NSMutableArray	*perf = [[NSRunLoop currentRunLoop] _timedPerformers];
    unsigned		count = [perf count];
    
    if (count > 0)
    {
        GSTimedPerformer	*array[count];
        
        IF_NO_GC(RETAIN(target));
        IF_NO_GC(RETAIN(arg));
        [perf getObjects: array];
        while (count-- > 0)
        {
            GSTimedPerformer	*p = array[count];
            
            if (p->target == target && sel_isEqual(p->selector, aSelector)
                && (p->argument == arg || [p->argument isEqual: arg]))
            {
                [p invalidate];
                [perf removeObjectAtIndex: count];
            }
        }
        RELEASE(arg);
        RELEASE(target);
    }
}

/*
 This method sets up a timer to perform the aSelector message on the current thread’s run loop.
 The timer is configured to run in the default mode (NSDefaultRunLoopMode).
 When the timer fires, the thread attempts to dequeue the message from the run loop and perform the selector.
 It succeeds if the run loop is running and in the default mode; otherwise, the timer waits until the run loop is in the default mode.
 */

// 这里, 这个函数是是讲 aSelector 和 self 包装到了 GSTimedPerformer 这样的一个结构中, 然后添加了一个 timer 到 runloop 里面, 也就是说, afterDlay 的这个操作, 是根据定时器实现的.
- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
// 这里, 同时改变了 _timedPerformers 和 timer.
{
    NSRunLoop		*loop = [NSRunLoop currentRunLoop]; // 首先取得 currentRunLoop , 这个函数里面其实会根据当前的 thread 取得对应的 runloop
    GSTimedPerformer	*item;
    
    item = [[GSTimedPerformer alloc] initWithSelector: aSelector
                                               target: self
                                             argument: argument
                                                delay: seconds];
    [[loop _timedPerformers] addObject: item]; // 创建一个管理 timer 和 人物的 performer 对象.
    RELEASE(item); // gnu 里面的代码, 都是 mrc 环境.
    [loop addTimer: item->timer forMode: NSDefaultRunLoopMode]; // 这里, 非常明确的, 是加入了一个定时器.
}

- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
                 inModes: (NSArray*)modes // 只有 mode 有效的时候, 才真正有意义.
{
    unsigned	count = [modes count];
    
    if (count > 0)
    {
        NSRunLoop		*loop = [NSRunLoop currentRunLoop];
        NSString		*marray[count];
        GSTimedPerformer	*item;
        unsigned		i;
        
        item = [[GSTimedPerformer alloc] initWithSelector: aSelector
                                                   target: self
                                                 argument: argument
                                                    delay: seconds];
        [[loop _timedPerformers] addObject: item]; // 这里我们看到, 一个 runloop 只有一个数组存储执行对象, 不会根据 modes 进行改变.
        RELEASE(item);
        
        [modes getObjects: marray];
        for (i = 0; i < count; i++)
        {
            [loop addTimer: item->timer forMode: marray[i]]; // 所有的任务, 都是被加入到 runloop 的定时器里面. 所以, 最终实现为什么会和 mode 关联是在这里完成的.
        }
    }
}

@end

#ifdef RL_INTEGRATE_DISPATCH
@interface GSMainQueueDrainer : NSObject <RunLoopEvents>
+ (void*) mainQueueFileDescriptor;
@end

@implementation GSMainQueueDrainer
+ (void*) mainQueueFileDescriptor
{
    return (void*)(uintptr_t)dispatch_get_main_queue_handle_np();
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
    dispatch_main_queue_drain_np();
}
@end
#endif

@interface NSRunLoop (Private)

- (void) _addWatcher: (GSRunLoopWatcher*)item
             forMode: (NSString*)mode;
- (BOOL) _checkPerformers: (GSRunLoopCtxt*)context;
- (GSRunLoopWatcher*) _getWatcher: (void*)data
                             type: (RunLoopEventType)type
                          forMode: (NSString*)mode;
- (id) _init;
- (void) _removeWatcher: (void*)data
                   type: (RunLoopEventType)type
                forMode: (NSString*)mode;

@end

@implementation NSRunLoop (Private)


/*
 NSMapInsert(_contextMap 这个只在三个地方用到了, 就是 performSelector after delay, addTimer, 还有 addWatcher 里面.
 所以, 其实输入源0, 输入源1, 时间源 都是 runloop 的回调而已.
 runloop 其实就是程序给我们的一个切口而已, 程序为了让程序保持运行, 所以制造了一个死循环. 为了让这个死循环不真的是死循环, 所以在这个死循环里面是用了系统调用的机制, 当需要执行的时候就不执行, 但是就算是这样他还是一个死循环. 因为从程序本身的角度来看, 它并不知道线程切换这回事. 在这个死循环里面, iOS 系统为我们添加了可以在这个死循环里面执行代码的机会, 那就是添加时间源, 因为这个死循环里面会去执行时间源里面的回调, 添加输入源, 延时执行函数, 因为这个死循环里面会去执行这些回调. 添加runloop observer, 因为 runloop 里面有着对于 observer 的回调, 添加 NSNoticiationQueue 的执行, 还是因为 runloop 里面有着对于他们的回调. 一般来说, 有了这些我们就能做很多事情了. 比如, observer 里面可以只是一个分发器, 当检测到 runloop 状态改变的时候, 由这个分发器进行分发, 而这个分发, 就可以无限扩展了.
 比如, 对于手势的回调, 就是从source0 的回调中衍生出来的. 首先衍生到公共API, UIApplicaiton sendevent. 然后继续分发, 最后到达了我们定义的 action 回掉.
 Dispatches an event to the appropriate responder objects in the app.
这个分发机制, 就是通过 hitTest pointInSide 这些东西进行的分发. 而怎么到达的 runloop 呢, 猜测是系统的功劳, 而这些的源头由到了 cpu 中断等事情.
 */

/* Add a watcher to the list for the specified mode.  Keep the list in
 limit-date order. */
- (void) _addWatcher: (GSRunLoopWatcher*) item forMode: (NSString*)mode // 将 watcher, 放到 context 里面, 类似于 CFRunLoopMode 的结构体.
{
    GSRunLoopCtxt	*context;
    GSIArray	watchers;
    unsigned	i;
    
    context = NSMapGet(_contextMap, mode); // 一个 mode 下面有 name, source 0, 1, observer, timer. 这里用 context 代替了.
    if (context == nil)
    {
        context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
        NSMapInsert(_contextMap, context->mode, context);
        RELEASE(context);
    }
    watchers = context->watchers;
    GSIArrayAddItem(watchers, (GSIArrayItem)((id)item));
    i = GSIArrayCount(watchers);
    if (i % 1000 == 0 && i > context->maxWatchers)
    {
        context->maxWatchers = i;
    }
}

- (BOOL) _checkPerformers: (GSRunLoopCtxt*)context
{
    BOOL                  found = NO;
    
    if (!context) { return found; }
    
    GSIArray    performers = context->performers;
    unsigned    count = GSIArrayCount(performers);
    
    if (count <= 0) { return found; }
    
    NSAutoreleasePool    *arp = [NSAutoreleasePool new];
    GSRunLoopPerformer    *array[count];
    NSMapEnumerator    enumerator;
    GSRunLoopCtxt        *original;
    void            *mode;
    unsigned        i;
    
    found = YES;
    
    /* We have to remove the performers before firing, so we copy
     * the pointers without releasing the objects, and then set
     * the performers to be empty.  The copied objects in 'array'
     * will be released later.
     */
    for (i = 0; i < count; i++)
    {
        array[i] = GSIArrayItemAtIndex(performers, i).obj;
    }
    performers->count = 0;
    
    /* Remove the requests that we are about to fire from all modes.
     */
    original = context;
    enumerator = NSEnumerateMapTable(_contextMap);
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil && context != original)
        {
            GSIArray    performers = context->performers;
            unsigned    tmpCount = GSIArrayCount(performers);
            
            while (tmpCount--)
            {
                GSRunLoopPerformer    *p;
                
                p = GSIArrayItemAtIndex(performers, tmpCount).obj;
                for (i = 0; i < count; i++)
                {
                    if (p == array[i])
                    {
                        GSIArrayRemoveItemAtIndex(performers, tmpCount);
                    }
                }
            }
        }
    }
    NSEndMapTableEnumeration(&enumerator);
    
    /* Finally, fire the requests ands release them.
     */
    for (i = 0; i < count; i++)
    {
        [array[i] fire]; // 这里才进行实际的fire 操作, 之前的是提取操作.
        RELEASE(array[i]);
        IF_NO_GC([arp emptyPool];)
    }
    [arp drain];
    return found;
}

/**
 * Locates a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (GSRunLoopWatcher*) _getWatcher: (void*)data
                             type: (RunLoopEventType)type
                          forMode: (NSString*)mode
{
    GSRunLoopCtxt	*context;
    
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    
    context = NSMapGet(_contextMap, mode);
    if (context != nil)
    {
        GSIArray	watchers = context->watchers;
        unsigned	i = GSIArrayCount(watchers);
        
        while (i-- > 0)
        {
            GSRunLoopWatcher	*info;
            
            info = GSIArrayItemAtIndex(watchers, i).obj;
            if (info->type == type && info->data == data)
            {
                return info;
            }
        }
    }
    return nil;
}

- (id) _init
{
    self = [super init];
    if (self != nil)
    {
        _contextStack = [NSMutableArray new];
        _contextMap = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
                                        NSObjectMapValueCallBacks, 0);
        _timedPerformers = [[NSMutableArray alloc] initWithCapacity: 8];
#ifdef	HAVE_POLL_F
        _extra = NSZoneMalloc(NSDefaultMallocZone(), sizeof(pollextra));
        memset(_extra, '\0', sizeof(pollextra));
#endif
    }
    return self;
}

/**
 * Removes a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (void) _removeWatcher: (void*)data
                   type: (RunLoopEventType)type
                forMode: (NSString*)mode
{
    GSRunLoopCtxt	*context;
    
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    
    context = NSMapGet(_contextMap, mode);
    if (context != nil)
    {
        GSIArray	watchers = context->watchers;
        unsigned	i = GSIArrayCount(watchers);
        
        while (i-- > 0)
        {
            GSRunLoopWatcher	*info;
            
            info = GSIArrayItemAtIndex(watchers, i).obj;
            if (info->type == type && info->data == data)
            {
                info->_invalidated = YES;
                GSIArrayRemoveItemAtIndex(watchers, i);
            }
        }
    }
}

@end


@implementation NSRunLoop(GNUstepExtensions)

// socket 之类的, 都是在这里面. 应该这样说, 这些都是回调.
- (void) addEvent: (void*)event
             type: (RunLoopEventType)type // 事件类型.
          watcher: (id<RunLoopEvents>)watcher // 回调的对象.
          forMode: (NSString*)mode
{
    GSRunLoopWatcher	*loopWatcher;
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    
    loopWatcher = [self _getWatcher: event type: type forMode: mode];
    
    if (loopWatcher != nil && (id)loopWatcher->receiver == (id)watcher)
    {
        /* Increment usage count for this watcher. */
        loopWatcher->count++;
    }
    else
    {
        /* Remove any existing handler for another watcher. */
        [self _removeWatcher: event type: type forMode: mode];
        
        /* Create new object to hold information. */
        loopWatcher = [[GSRunLoopWatcher alloc] initWithType: type
                                             receiver: watcher
                                                 data: event];
        /* Add the object to the array for the mode. */
        [self _addWatcher: loopWatcher forMode: mode];
        RELEASE(loopWatcher);		/* Now held in array.	*/
    }
}

- (void) removeEvent: (void*)data
                type: (RunLoopEventType)type
             forMode: (NSString*)mode
                 all: (BOOL)removeAll
{
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    if (removeAll)
    {
        [self _removeWatcher: data type: type forMode: mode];
    }
    else
    {
        GSRunLoopWatcher	*info;
        
        info = [self _getWatcher: data type: type forMode: mode];
        
        if (info)
        {
            if (info->count == 0)
            {
                [self _removeWatcher: data type: type forMode: mode];
            }
            else
            {
                info->count--;
            }
        }
    }
}

@end

/**
 *  <p><code>NSRunLoop</code> instances handle various utility tasks that must
 *  be performed repetitively in an application, such as processing input
 *  events, listening for distributed objects communications, firing
 *  [NSTimer]s, and sending notifications and other messages
 *  asynchronously.</p>
 *
 * <p>There is one run loop per thread in an application, which
 *  may always be obtained through the <code>+currentRunLoop</code> method
 *  (you cannot use -init or +new),
 *  however unless you are using the AppKit and the [NSApplication] class, the
 *  run loop will not be started unless you explicitly send it a
 *  <code>-run</code> message.</p>
 *
 * <p>At any given point, a run loop operates in a single <em>mode</em>, usually
 * <code>NSDefaultRunLoopMode</code>.  Other options include
 * <code>NSConnectionReplyMode</code>, and certain modes used by the AppKit.</p>
 */
@implementation NSRunLoop

+ (void) initialize
{
    if (self == [NSRunLoop class])
    {
        [self currentRunLoop]; //  这个时候, 铁定是主线程, 所以这个其实是为了创造主线程的运行循环.
        theFuture = RETAIN([NSDate distantFuture]);
        RELEASE([NSObject leakAt: &theFuture]);
    }
}

+ (NSRunLoop*) _runLoopForThread: (NSThread*) aThread
{
    GSRunLoopThreadInfo	*info = GSRunLoopInfoForThread(aThread);
    NSRunLoop             *current = info->loop;
    
    if (nil == current)
    {
        current = info->loop = [[self alloc] _init];
        /* If this is the main thread, set up a housekeeping timer.
         */
        if (nil != current && [GSCurrentThread() isMainThread] == YES)
        {
            NSAutoreleasePool		*arp = [NSAutoreleasePool new];
            NSNotificationCenter	        *ctr;
            NSNotification		*not;
            NSInvocation		        *inv;
            NSTimer                       *timer;
            SEL			        sel;
            
            ctr = [NSNotificationCenter defaultCenter];
            not = [NSNotification notificationWithName: @"GSHousekeeping"
                                                object: nil
                                              userInfo: nil];
            sel = @selector(postNotification:);
            inv = [NSInvocation invocationWithMethodSignature:
                   [ctr methodSignatureForSelector: sel]];
            [inv setTarget: ctr];
            [inv setSelector: sel];
            [inv setArgument: &not atIndex: 2];
            [inv retainArguments];
            
            timer = [[NSTimer alloc] initWithFireDate: nil
                                             interval: 30.0
                                               target: inv
                                             selector: NULL
                                             userInfo: nil
                                              repeats: YES];
            [current addTimer: timer forMode: NSDefaultRunLoopMode];
            
#ifdef RL_INTEGRATE_DISPATCH
            // We leak the queue drainer, because it's integral part of RL
            // operations
            GSMainQueueDrainer *drain =
            [NSObject leak: [[GSMainQueueDrainer new] autorelease]];
            [current addEvent: [GSMainQueueDrainer mainQueueFileDescriptor]
                         type: ET_RDESC
                      watcher: drain
                      forMode: NSDefaultRunLoopMode];
            
#endif
            [arp drain];
        }
    }
    return current;
}

+ (NSRunLoop*) currentRunLoop
{
    return [self _runLoopForThread: nil];
}

+ (NSRunLoop*) mainRunLoop
{
    return [self _runLoopForThread: [NSThread mainThread]];
}

- (id) init
{
    DESTROY(self);
    return nil;
}

- (void) dealloc
{
#ifdef	HAVE_POLL_F
    if (_extra != 0)
    {
        pollextra	*e = (pollextra*)_extra;
        if (e->index != 0)
            NSZoneFree(NSDefaultMallocZone(), e->index);
        NSZoneFree(NSDefaultMallocZone(), e);
    }
#endif
    RELEASE(_contextStack);
    if (_contextMap != 0)
    {
        NSFreeMapTable(_contextMap);
    }
    RELEASE(_timedPerformers);
    [super dealloc];
}

/**
 * Returns the current mode of this runloop.  If the runloop is not running
 * then this method returns nil.
 */
- (NSString*) currentMode
{
    return _currentMode;
}


/**
 * Adds a timer to the loop in the specified mode.<br />
 * Timers are removed automatically when they are invalid.<br />
 // 将 timer 加入到时间源里面.
 */
- (void) addTimer: (NSTimer*)timer
          forMode: (NSString*)mode
{
    GSRunLoopCtxt	*context;
    GSIArray	timers;
    unsigned      i;
    context = NSMapGet(_contextMap, mode);
    if (context == nil)
    {
        context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
        NSMapInsert(_contextMap, context->mode, context);
        RELEASE(context);
    }
    timers = context->timers;
    i = GSIArrayCount(timers);
    while (i-- > 0)
    {
        if (timer == GSIArrayItemAtIndex(timers, i).obj)
        {
            return;       /* Timer already present */
        }
    }
    /*
     * NB. A previous version of the timer code maintained an ordered
     * array on the theory that we could improve performance by only
     * checking the first few timers (up to the first one whose fire
     * date is in the future) each time -limitDateForMode: is called.
     * The problem with this was that it's possible for one timer to
     * be added in multiple modes (or to different run loops) and for
     * a repeated timer this could mean that the firing of the timer
     * in one mode/loop adjusts its date ... without changing the
     * ordering of the timers in the other modes/loops which contain
     * the timer.  When the ordering of timers in an array was broken
     * we could get delays in processing timeouts, so we reverted to
     * simply having timers in an unordered array and checking them
     * all each time -limitDateForMode: is called.
     */
    GSIArrayAddItem(timers, (GSIArrayItem)((id)timer));
    i = GSIArrayCount(timers);
    if (i % 1000 == 0 && i > context->maxTimers)
    {
        context->maxTimers = i;
        NSLog(@"WARNING ... there are %u timers scheduled in mode %@ of %@",
              i, mode, self);
    }
}



/* Ensure that the fire date has been updated either by the timeout handler
 * updating it or by incrementing it ourselves.<br />
 * Return YES if it was updated, NO if it was invalidated.
 */
static BOOL
updateTimer(NSTimer *t, NSDate *d, NSTimeInterval now)
{
    if (timerInvalidated(t) == YES)
    {
        return NO;
    }
    if (timerDate(t) == d)
    {
        NSTimeInterval	ti = [d timeIntervalSinceReferenceDate];
        NSTimeInterval	increment = [t timeInterval];
        
        if (increment <= 0.0)
        {
            /* Should never get here ... unless a subclass is returning
             * a bad interval ... we return NO so that the timer gets
             * removed from the loop.
             */
            NSLog(@"WARNING timer %@ had bad interval ... removed", t);
            return NO;
        }
        
        ti += increment;	// Hopefully a single increment will do.
        
        if (ti < now)
        {
            NSTimeInterval	add;
            
            /* Just incrementing the date was insufficieint to bring it to
             * the current time, so we must have missed one or more fire
             * opportunities, or the fire date has been set on the timer.
             * If a fire date long ago has been set and the increment value
             * is really small, we might need to increment very many times
             * to get the new fire date.  To avoid looping for ages, we
             * calculate the number of increments needed and do them in one
             * go.
             */
            add = floor((now - ti) / increment);
            ti += (increment * add);
            if (ti < now)
            {
                ti += increment;
            }
        }
        RELEASE(t->_date);
        t->_date = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: ti];
    }
    return YES;
}

- (NSDate*) _limitDateForContext: (GSRunLoopCtxt *)context
{
    NSDate		*when = nil;
    NSAutoreleasePool     *arp = [NSAutoreleasePool new];
    GSIArray		timers = context->timers; // 取出注册的定时器.
    NSTimeInterval	now;
    NSDate                *earliest;
    NSDate		*timeFiredate;
    NSTimer		*singleTimer;
    NSTimeInterval	ti;
    NSTimeInterval	ei;
    unsigned              timerCount;
    unsigned              i;
    
    ei = 0.0;	// Only needed to avoid compiler warning
    
    /*
     * Save current time so we don't keep redoing system call to
     * get it and so that we check timer fire dates against a known
     * value at the point when the method was called.
     * If we refetched the date after firing each timer, the time
     * taken in firing the timer could be large enough so we would
     * just keep firing the timer repeatedly and never return from
     * this method.
     */
    now = GSPrivateTimeNow();
    
    /* Fire the oldest/first valid timer whose fire date has passed
     * and fire it.
     * We fire timers in the order in which they were added to the
     * run loop rather than in date order.  This prevents code
     * from blocking other timers by adding timers whose fire date
     * is some time in the past... we guarantee fair handling.
     */
    timerCount = GSIArrayCount(timers);
    for (i = 0; i < timerCount; i++)
    {
        singleTimer = GSIArrayItemAtIndex(timers, i).obj;
        if (timerInvalidated(singleTimer) == NO) // 如果这个 timer 没有取消.
        {
            timeFiredate = timerDate(singleTimer);
            ti = [timeFiredate timeIntervalSinceReferenceDate];
            if (ti < now) // 如果, 过了这个时间点了. 可以进行 fire 了.
            {
                GSIArrayRemoveItemAtIndexNoRelease(timers, i);
                [singleTimer fire];
                GSPrivateNotifyASAP(_currentMode);
                IF_NO_GC([arp emptyPool];)
                if (updateTimer(singleTimer, timeFiredate, now) == YES) // 在执行了一次 timer 的回调之后, 才会计算下一次 timer 的fire 时间, 然后重新加入到 timers 的数组里面.
                {
                    /* Updated ... replace in array.
                     */
                    GSIArrayAddItemNoRetain(timers,
                                            (GSIArrayItem)((id)singleTimer));
                }
                else
                {
                    /* The timer was invalidated, so we can
                     * release it as we aren't putting it back
                     * in the array.
                     */
                    RELEASE(singleTimer);
                }
                break;
            }
        }
    }
    
    /* Now, find the earliest remaining timer date while removing
     * any invalidated timers.  We iterate from the end of the
     * array to minimise the amount of array alteration needed.
     */
    earliest = nil;
    i = GSIArrayCount(timers);
    while (i-- > 0) // 这里, 检查剩余的 timer.
    {
        singleTimer = GSIArrayItemAtIndex(timers, i).obj;
        if (timerInvalidated(singleTimer) == YES)
        {
            GSIArrayRemoveItemAtIndex(timers, i);
        }
        else
        {
            timeFiredate = timerDate(singleTimer);
            ti = [timeFiredate timeIntervalSinceReferenceDate];
            if (earliest == nil || ti < ei)
            {
                earliest = timeFiredate;
                ei = ti;
            }
        }
    }
    [arp drain];
    
    /* The earliest date of a valid timeout is retained in 'when'
     * and used as our limit date.
     */
    if (earliest != nil) // 如果还有剩余的 timer.
    {
        when = AUTORELEASE(RETAIN(earliest));
    }
    else
    {
        GSIArray		watchers = context->watchers;
        unsigned		i = GSIArrayCount(watchers);
        
        while (i-- > 0) // 如果还有 soruce 1 的话,  就不退出 runloop. when 就编程 theFuture. 也就是 distantFuture.
        {
            GSRunLoopWatcher	*w = GSIArrayItemAtIndex(watchers, i).obj;
            
            if (w->_invalidated == YES)
            {
                GSIArrayRemoveItemAtIndex(watchers, i);
            }
        }
        if (GSIArrayCount(context->watchers) > 0)
        {
            when = theFuture;
        }
    }
    
    return when;
}

/**
 定时器的使用. 里面也会检查 source1
 * Fires timers whose fire date has passed, and checks timers and limit dates
 * for input sources, determining the earliest time that any future timeout
 * becomes due.  Returns that date/time.<br />
 * Returns distant future if the loop contains no timers, just input sources
 * without timeouts.<br />
 * Returns nil if the loop contains neither timers nor input sources.
 */
- (NSDate*) limitDateForMode: (NSString*)mode
{
    GSRunLoopCtxt		*context;
    NSDate		*when = nil;
    
    context = NSMapGet(_contextMap, mode);
    if (context != nil)
    {
        NSString		*savedMode = _currentMode;
        
        _currentMode = mode;
        NS_DURING
        {
            when = [self _limitDateForContext: context];
            _currentMode = savedMode;
        }
        NS_HANDLER
        {
            _currentMode = savedMode;
            [localException raise];
        }
        NS_ENDHANDLER
        
        NSDebugMLLog(@"NSRunLoop", @"limit date %f in %@",
                     nil == when ? 0.0 : [when timeIntervalSinceReferenceDate], mode);
    }
    return when;
}

/**
 * Listen for events from input sources.<br /> // 只监听输入源的信息.
 * If limit_date is nil or in the past, then don't wait;
 * just fire timers, poll inputs and return, otherwise block // poll inputs
 * (firing timers when they are due) until input is available
 * or until the earliest limit date has passed (whichever comes first).<br />
 * If the supplied mode is nil, uses NSDefaultRunLoopMode.<br />
 * If there are no input sources or timers in the mode, returns immediately.
 
 Runs the loop once or until the specified date, accepting input only for the specified mode.
 这里面的东西太复杂了, 没看, 不过就是处理 source 1 的东西.
 */
- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)limit_date
{
    GSRunLoopCtxt		*context;
    NSTimeInterval	ti = 0;
    int			timeout_ms;
    NSString		*savedMode = _currentMode;
    NSAutoreleasePool	*arp = [NSAutoreleasePool new];
    
    NSAssert(mode, NSInvalidArgumentException);
    if (mode == nil)
    {
        mode = NSDefaultRunLoopMode;
    }
    context = NSMapGet(_contextMap, mode);
    if (nil == context)
    {
        return;
    }
    _currentMode = mode;
    
    [self _checkPerformers: context];
    
    NS_DURING
    {
        BOOL      done = NO;
        NSDate    *when;
        
        while (NO == done)
        {
            [arp emptyPool];
            when = [self _limitDateForContext: context];
            if (nil == when)
            {
                NSDebugMLLog(@"NSRunLoop",
                             @"no inputs or timers in mode %@", mode);
                GSPrivateNotifyASAP(_currentMode);
                GSPrivateNotifyIdle(_currentMode); // 可以看到,GSPrivateNotifyASAP 的调用, 要比 GSPrivateNotifyIdle 的调用要多的多, 这也就是为什么 ASAP 的通知要比 GSPrivateNotifyIdle 要快.
                /* Pause until the limit date or until we might have
                 * a method to perform in this thread.
                 这里, 线程切换的没有写.
                 __CFRunLoopSetSleeping(rl);
                 */
                [GSRunLoopCtxt awakenedBefore: nil];
                [self _checkPerformers: context];
                GSPrivateNotifyASAP(_currentMode);
                [_contextStack removeObjectIdenticalTo: context];
                _currentMode = savedMode;
                [arp drain];
                NS_VOIDRETURN;
            }
            else
            {
                if (nil == limit_date)
                {
                    when = nil;
                }
                else
                {
                    when = [when earlierDate: limit_date];
                }
            }
            
            /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
            if (nil == when || (ti = [when timeIntervalSinceNow]) <= 0.0)
            {
                /* Don't wait at all. */
                timeout_ms = 0;
            }
            else
            {
                /* Wait until the LIMIT_DATE. */
                if (ti >= INT_MAX / 1000)
                {
                    timeout_ms = INT_MAX;	// Far future.
                }
                else
                {
                    timeout_ms = (ti * 1000.0);
                }
            }
            
            NSDebugMLLog(@"NSRunLoop",
                         @"accept I/P before %d millisec from now in %@",
                         timeout_ms, mode);
            
            if ([_contextStack indexOfObjectIdenticalTo: context] == NSNotFound)
            {
                [_contextStack addObject: context];
            }
            done = [context pollUntil: timeout_ms within: _contextStack];
            if (NO == done)
            {
                GSPrivateNotifyIdle(_currentMode);
                if (nil == limit_date || [limit_date timeIntervalSinceNow] <= 0.0)
                {
                    done = YES;
                }
            }
            [self _checkPerformers: context];
            GSPrivateNotifyASAP(_currentMode);
            [context endPoll];
            
            /* Once a poll has been completed on a context, we can remove that
             * context from the stack even if it is actually polling at an outer
             * level of re-entrancy ... since the poll we have just done will
             * have handled any events that the outer levels would have wanted
             * to handle, and the polling for this context will be marked as
             * ended.
             */
            [_contextStack removeObjectIdenticalTo: context];
        }
        
        _currentMode = savedMode;
    }
    NS_HANDLER
    {
        _currentMode = savedMode;
        [context endPoll];
        [_contextStack removeObjectIdenticalTo: context];
        [localException raise];
    }
    NS_ENDHANDLER
    NSDebugMLLog(@"NSRunLoop", @"accept I/P completed in %@", mode);
    [arp drain];
}

- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)date // 这个方法很简单, 是因为大量的操作被封装到别的类了.
{
    NSAutoreleasePool	*arp = [NSAutoreleasePool new]; // 首先, 是创建一个自动释放池.
    NSString              *savedMode = _currentMode; // 保存之前的 mode
    GSRunLoopCtxt		*context;
    NSDate		*d;
    
    /* Process any pending notifications.
     */
    GSPrivateNotifyASAP(mode); // 将之前注册给 NSNotificationQueue 的进行通知.
    
    /* And process any performers scheduled in the loop (eg something from
     * another thread.
     */
    _currentMode = mode;
    context = NSMapGet(_contextMap, mode); // 拿到
    [self _checkPerformers: context]; // 执行任务, 首先执行的是之前添加了 performSelector 的回调.
    _currentMode = savedMode;
    
    /* Find out how long we can wait before first limit date.
     * If there are no input sources or timers, return immediately.
     */
    d = [self limitDateForMode: mode]; // 定时器的调用, 检查 source1 和 timers. 如果这个时候, 没有了输入源和时间源, 就直接退出了.
    if (nil == d)
    {
        [arp drain];
        return NO;
    }
    
    /* Use the earlier of the two dates we have (nil date is like distant past).
     */
    if (nil == date)
    {
        [self acceptInputForMode: mode beforeDate: nil]; // 在这里, 会进行睡眠的操作.
    }
    else
    {
        /* Retain the date in case the firing of a timer (or some other event)
         * releases it.
         */
        d = [[d earlierDate: date] copy];
        [self acceptInputForMode: mode beforeDate: d];
        RELEASE(d);
    }
    
    [arp drain];
    return YES;
}

/**
 * Runs the loop in <code>NSDefaultRunLoopMode</code> by repeated calls to
 * -runMode:beforeDate: while there are still input sources.  Exits when no
 * more input sources remain.
 */
- (void) run
{
    [self runUntilDate: theFuture]; //
    /*
     run 这个函数就是不断地 runMode beforeDate 这个函数, 如果我们自己去写控制 runloop 的函数, 应该是
     while (控制条件) {
     [self runMode: NSDefaultRunLoopMode beforeDate: date];
     }
     然后我们就根据这个控制条件就可以控制这个死循环了. 而 run 这个函数, 就是想要让 runLoop 一直跑下去, 所以, 就直接是 runUntilFutureDate 了.
     */
}

/**
 * Runs the loop in <code>NSDefaultRunLoopMode</code> by repeated calls to
 * -runMode:beforeDate: while there are still input sources.  Exits when no
 * more input sources remain, or date is reached, whichever occurs first.
 */
- (void) runUntilDate: (NSDate*)date // 如果没有输入源了, 或者如果到达了时间, 就退出循环.
{
    BOOL		mayDoMore = YES;
    while (YES == mayDoMore)
    {
        mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date]; // 这里, 返回值如果是 NO, 应该就是没有 inputSource 了.
        if (nil == date || [date timeIntervalSinceNow] <= 0.0) // 如果时间不允许的, 就将控制条件置为 NO.
        {
            mayDoMore = NO;
        }
    }
}

@end



/**
 * OpenStep-compatibility methods for [NSRunLoop].  These methods are also
 * all in OS X.
 */
@implementation	NSRunLoop (OPENSTEP)

/**
 * Adds port to be monitored in given mode.
 */
- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode
{
    [self addEvent: (void*)port
              type: ET_RPORT
           watcher: (id<RunLoopEvents>)port
           forMode: (NSString*)mode];
}

/**
 * Cancels any perform operations set up for the specified target
 * in the receiver.
 */
- (void) cancelPerformSelectorsWithTarget: (id) target
{
    NSMapEnumerator	enumerator;
    GSRunLoopCtxt		*context;
    void			*mode;
    
    enumerator = NSEnumerateMapTable(_contextMap);
    
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil)
        {
            GSIArray	performers = context->performers;
            unsigned	count = GSIArrayCount(performers);
            
            while (count--)
            {
                GSRunLoopPerformer	*p;
                
                p = GSIArrayItemAtIndex(performers, count).obj;
                if (p->target == target)
                {
                    GSIArrayRemoveItemAtIndex(performers, count);
                }
            }
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

/**
 * Cancels any perform operations set up for the specified target
 * in the receiver, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
 */
- (void) cancelPerformSelector: (SEL)aSelector
                        target: (id) target
                      argument: (id) argument
{
    NSMapEnumerator	enumerator;
    GSRunLoopCtxt		*context;
    void			*mode;
    
    enumerator = NSEnumerateMapTable(_contextMap);
    
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil)
        {
            GSIArray	performers = context->performers;
            unsigned	count = GSIArrayCount(performers);
            
            while (count--)
            {
                GSRunLoopPerformer	*p;
                
                p = GSIArrayItemAtIndex(performers, count).obj;
                if (p->target == target && sel_isEqual(p->selector, aSelector)
                    && (p->argument == argument || [p->argument isEqual: argument]))
                {
                    GSIArrayRemoveItemAtIndex(performers, count);
                }
            }
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

/**
 *  Configure event processing for acting as a server process for distributed
 *  objects.  (In the current implementation this is a no-op.)
 */
- (void) configureAsServer
{
    return;	/* Nothing to do here */
}

/**
 * Sets up sending of aSelector to target with argument.<br />
 * The selector is sent before the next runloop iteration (unless
 * cancelled before then) in any of the specified modes.<br />
 * The target and argument objects are retained.<br />
 * The order value is used to determine the order in which messages
 * are sent if multiple messages have been set up. Messages with a lower
 * order value are sent first.<br />
 * If the modes array is empty, this method has no effect.
 */

/*
 
 注意, 这里建立的就不是 timedPerformer 了.
 
 */
- (void) performSelector: (SEL)aSelector
                  target: (id)target
                argument: (id)argument
                   order: (NSUInteger)order
                   modes: (NSArray*)modes
{
    unsigned		count = [modes count];
    
    if (count > 0)
    {
        NSString			*array[count];
        GSRunLoopPerformer	*item;
        
        item = [[GSRunLoopPerformer alloc] initWithSelector: aSelector
                                                     target: target
                                                   argument: argument
                                                      order: order];
        
        [modes getObjects: array];
        while (count-- > 0)
        {
            NSString	*mode = array[count];
            unsigned	end;
            unsigned	i;
            GSRunLoopCtxt	*context;
            GSIArray	performers;
            
            context = NSMapGet(_contextMap, mode); // 首先, 拿到 mode 的包装体. GNU 里面, 是创造了 context 这样的一个类, 作用和CFRunloopMode 是一样的.
            if (context == nil)
            {
                context = [[GSRunLoopCtxt alloc] initWithMode: mode
                                                        extra: _extra];
                NSMapInsert(_contextMap, context->mode, context);
                RELEASE(context);
            }
            performers = context->performers;
            
            end = GSIArrayCount(performers);
            for (i = 0; i < end; i++)
            {
                GSRunLoopPerformer	*p;
                
                p = GSIArrayItemAtIndex(performers, i).obj;
                if (p->order > order)
                {
                    GSIArrayInsertItem(performers, (GSIArrayItem)((id)item), i);
                    break;
                }
            }
            if (i == end)
            {
                GSIArrayInsertItem(performers, (GSIArrayItem)((id)item), i);
            }
            // 然后就是把这个塞进去.
            i = GSIArrayCount(performers);
            if (i % 1000 == 0 && i > context->maxPerformers)
            {
                context->maxPerformers = i;
                NSLog(@"WARNING ... there are %u performers scheduled"
                      @" in mode %@ of %@\n(Latest: [%@ %@])",
                      i, mode, self, NSStringFromClass([target class]),
                      NSStringFromSelector(aSelector));
            }
        }
        RELEASE(item);
    }
}

/**
 * Removes port to be monitored from given mode.
 * Ports are also removed if they are detected to be invalid.
 */
- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
    [self removeEvent: (void*)port type: ET_RPORT forMode: mode all: NO];
}

@end
