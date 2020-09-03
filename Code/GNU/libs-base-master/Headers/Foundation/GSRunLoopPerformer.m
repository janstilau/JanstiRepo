//
//  GSRunLoopPerformer.m
//  Foundation
//
//  Created by JustinLau on 2020/9/3.
//

#import "GSRunLoopPerformer.h"

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


/*
 这个类, 就是 perform selector after delay 这个函数建造出来的.
 记录一下所有相关的数据, 并且生成出一个定时器, 添加到 currentRunLoop 里面.
 */

@implementation GSTimedPerformer

- (void) dealloc {
    [self finalize];
    TEST_RELEASE(timer);
    RELEASE(target);
    RELEASE(argument);
    [super dealloc];
}

- (void) fire {
    DESTROY(timer);
    [target performSelector: selector withObject: argument];
    [[[NSRunLoop currentRunLoop] _timedPerformers] removeObjectIdenticalTo: self];
}

- (void) finalize
{
    [self invalidate];
}

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
        /*
         注意, 这里 perform selector after 生成的 GSTimedPerformer, 是将自己和 fire 当做了 NSTimer 的参数了.
         所以, 仅仅只会有一次调用 fire, 而 GSTimedPerformer 里面, 再去调用原始的 target 和 SEL 的调用.
         在调用完了之后, 就是 [[NSRunLoop currentRunLoop] _timedPerformers] 的数据操作了.
         */
        timer = [[NSTimer allocWithZone: NSDefaultMallocZone()]
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
 NSObject 关于延时调用的函数, 真正的定义在这里. 这是因为, 这些内容, 其实是和 Runloop 相关的.
 */
@implementation NSObject (TimedPerformers)

/*
 这个函数, 是和 runloop 相关的, 所以, 如果没有设置好 runloop 中的存储, 很有可能造成线程的卡顿.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
{
    NSMutableArray    *perf = [[NSRunLoop currentRunLoop] _timedPerformers];
    unsigned        count = [perf count];
    
    if (count > 0)
    {
        GSTimedPerformer    *array[count];
        IF_NO_GC(RETAIN(target));
        [perf getObjects: array];
        
        while (count-- > 0)
        {
            GSTimedPerformer    *p = array[count];
            
            if (p->target == target) {
                [p invalidate];
                [perf removeObjectAtIndex: count];
            }
        }
        RELEASE(target);
    }
}

+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
                                        selector: (SEL)aSelector
                                          object: (id)arg
{
    NSMutableArray    *perf = [[NSRunLoop currentRunLoop] _timedPerformers];
    unsigned        count = [perf count];
    
    if (count > 0)
    {
        GSTimedPerformer    *array[count];
        
        IF_NO_GC(RETAIN(target));
        IF_NO_GC(RETAIN(arg));
        [perf getObjects: array];
        while (count-- > 0)
        {
            GSTimedPerformer    *p = array[count];
            
            if (p->target == target &&
                sel_isEqual(p->selector, aSelector) &&
                (p->argument == arg || [p->argument isEqual: arg]))
            {
                [p invalidate];
                [perf removeObjectAtIndex: count];
            }
        }
        RELEASE(arg);
        RELEASE(target);
    }
}

- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
{
    NSRunLoop        *loop = [NSRunLoop currentRunLoop];
    GSTimedPerformer    *item;
    
    item = [[GSTimedPerformer alloc] initWithSelector: aSelector
                                               target: self
                                             argument: argument
                                                delay: seconds];
    [[loop _timedPerformers] addObject: item];
    RELEASE(item);
    [loop addTimer: item->timer forMode: NSDefaultRunLoopMode]; // 这是真正的, 为什么会有延时操作的原因所在.
}

- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
                 inModes: (NSArray*)modes
{
    unsigned    count = [modes count];
    
    if (count > 0)
    {
        NSRunLoop        *loop = [NSRunLoop currentRunLoop];
        NSString        *marray[count];
        GSTimedPerformer    *item;
        unsigned        i;
        
        item = [[GSTimedPerformer alloc] initWithSelector: aSelector
                                                   target: self
                                                 argument: argument
                                                    delay: seconds];
        [[loop _timedPerformers] addObject: item];
        RELEASE(item);
        if ([modes isProxy])
        {
            for (i = 0; i < count; i++)
            {
                marray[i] = [modes objectAtIndex: i];
            }
        }
        else
        {
            [modes getObjects: marray];
        }
        for (i = 0; i < count; i++)
        {
            [loop addTimer: item->timer forMode: marray[i]];
        }
    }
}

@end



@implementation GSPerformHolder

+ (GSPerformHolder*) newForReceiver: (id)r
                           argument: (id)a
                           selector: (SEL)s
                              modes: (NSArray*)m
                               lock: (NSConditionLock*)l
{
    GSPerformHolder    *h;
    
    h = (GSPerformHolder*)NSAllocateObject(self, 0, NSDefaultMallocZone());
    h->receiver = RETAIN(r);
    h->argument = RETAIN(a);
    h->selector = s;
    h->modes = RETAIN(m);
    h->lock = l;
    
    return h;
}

- (void) dealloc
{
    DESTROY(exception);
    DESTROY(receiver);
    DESTROY(argument);
    DESTROY(modes);
    if (lock != nil)
    {
        [lock lock];
        [lock unlockWithCondition: 1];
        lock = nil;
    }
    NSDeallocateObject(self);
    GSNOSUPERDEALLOC;
}

- (void) fire
{
    GSRunLoopThreadInfo   *threadInfo;
    
    if (receiver == nil)
    {
        return;
    }
    threadInfo = GSRunLoopInfoForThread(GSCurrentThread());
    [threadInfo->loop cancelPerformSelectorsWithTarget: self];
    NS_DURING
    {
        /*
         做真正的函数调用工作.
         */
        [receiver performSelector: selector withObject: argument];
    }
    NS_HANDLER
    {
        ASSIGN(exception, localException);
        if (nil == lock)
        {
            NSLog(@"*** NSRunLoop ignoring exception '%@' (reason '%@') "
                  @"raised during perform in other thread... with receiver %p (%s) "
                  @"and selector '%s'",
                  [localException name], [localException reason], receiver,
                  class_getName(object_getClass(receiver)),
                  sel_getName(selector));
        }
    }
    NS_ENDHANDLER
    DESTROY(receiver);
    DESTROY(argument);
    DESTROY(modes);
    if (lock != nil)
    {
        /*
         做线程同步的操作.
         */
        NSConditionLock    *l = lock;
        [lock lock];
        lock = nil;
        [l unlockWithCondition: 1];
    }
}

- (void) invalidate
{
    if (invalidated == NO)
    {
        invalidated = YES;
        DESTROY(receiver);
        if (lock != nil)
        {
            NSConditionLock    *l = lock;
            /*
             在相应的地方, 都要做线程同步的操作.
             */
            [lock lock];
            lock = nil;
            [l unlockWithCondition: 1];
        }
    }
}

- (BOOL) isInvalidated
{
    return invalidated;
}

- (NSArray*) modes
{
    return modes;
}
@end


@implementation    NSObject (NSThreadPerformAdditions)

- (void) performSelectorOnMainThread: (SEL)aSelector
                          withObject: (id)anObject
                       waitUntilDone: (BOOL)aFlag
                               modes: (NSArray*)anArray
{
    /* It's possible that this method could be called before the NSThread
     * class is initialised, so we check and make sure it's initiailised
     * if necessary.
     */
    if (defaultThread == nil)
    {
        [NSThread currentThread];
    }
    [self performSelector: aSelector
                 onThread: defaultThread
               withObject: anObject
            waitUntilDone: aFlag
                    modes: anArray];
}

- (void) performSelectorOnMainThread: (SEL)aSelector
                          withObject: (id)anObject
                       waitUntilDone: (BOOL)aFlag
{
    [self performSelectorOnMainThread: aSelector
                           withObject: anObject
                        waitUntilDone: aFlag
                                modes: commonModes()];
}

- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)aFlag
                   modes: (NSArray*)anArray
{
    GSRunLoopThreadInfo   *runloopThreadInfo;
    NSThread            *currentThread;
    
    if ([anArray count] == 0)
    {
        return;
    }
    
    currentThread = GSCurrentThread();
    if (aThread == nil)
    {
        aThread = currentThread;
    }
    /*
     这里获取的, 是 onThread 里面的 thread 的 ThreadInfo. 所以, performer 是添加到了对应的线程的数据里面.
     */
    runloopThreadInfo = GSRunLoopInfoForThread(aThread);
    
    // 如果就是在当前线程
    if (currentThread == aThread)
    {
        /* Perform in current thread.
         */
        if (aFlag == YES || info->loop == nil)
        {
            /*
             如果是同步处理, 那么直接进行方法的调用.
             */
            [self performSelector: aSelector withObject: anObject];
        }
        else
        {
            /*
             如果是异步处理, 那么就包装成为数据, 注册到 runloop 的 performer 里面.
             */
            [info->loop performSelector: aSelector
                                 target: self
                               argument: anObject
                                  order: 0
                                  modes: anArray];
        }
    }
    else
    {
        /*
         如果异步线程的调用, 那么就包装成为 GSPerformHolder 对象, 这个对象, 里面存了一个 conditionLock. 在这个对象 fire 之后, 会进行 conditionLock 的unlock 的调用, 使得当前线程可以解锁.
         */
        GSPerformHolder   *performHolder;
        NSConditionLock    *conditionLock = nil;
        if (aFlag == YES)
        {
            conditionLock = [[NSConditionLock alloc] init];
        }
        performHolder = [GSPerformHolder newForReceiver: self
                                               argument: anObject
                                               selector: aSelector
                                                  modes: anArray
                                                   lock: conditionLock];
        [runloopThreadInfo addPerformer: performHolder];
        if (conditionLock != nil)
        {
            /*
             如果有条件锁, 代表需要进行同步控制.
             */
            [conditionLock lockWhenCondition: 1];
            [conditionLock unlock];
            RELEASE(conditionLock);
        }
        RELEASE(performHolder);
    }
}

- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)aFlag
{
    [self performSelector: aSelector
                 onThread: aThread
               withObject: anObject
            waitUntilDone: aFlag
                    modes: commonModes()];
}

- (void) performSelectorInBackground: (SEL)aSelector
                          withObject: (id)anObject
{
    [NSThread detachNewThreadSelector: aSelector
                             toTarget: self
                           withObject: anObject];
}

@end
