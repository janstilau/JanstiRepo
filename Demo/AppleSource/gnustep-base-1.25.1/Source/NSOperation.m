
#import "common.h"

#import "Foundation/NSLock.h"

#define	GS_NSOperation_IVARS \
NSRecursiveLock *lock; \
NSConditionLock *cond; \
NSOperationQueuePriority priority; \
double threadPriority; \
BOOL cancelled; \
BOOL concurrent; \
BOOL executing; \
BOOL finished; \
BOOL blocked; \
BOOL ready; \
NSMutableArray *dependencies; \
GSOperationCompletionBlock completionBlock;

#define	GS_NSOperationQueue_IVARS \
NSRecursiveLock	*lock; \
NSConditionLock	*cond; \
NSMutableArray	*operations; \
NSMutableArray	*waiting; \
NSMutableArray	*starting; \
NSString		*name; \
BOOL			suspended; \
NSInteger		executing; \
NSInteger		threadCount; \
NSInteger		count;

#import "Foundation/NSOperation.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSThread.h"
#import "GNUstepBase/NSArray+GNUstepBase.h"
#import "GSPrivate.h"

#define	GSself	NSOperationself
#include	"GSself.h"

static void     *isFinishedCtxt = (void*)"isFinished";
static void     *isReadyCtxt = (void*)"isReady";
static void     *queuePriorityCtxt = (void*)"queuePriority";

/* The pool of threads for 'non-concurrent' operations in a queue.
 */
#define	POOL	8

static NSArray	*empty = nil;

@interface	NSOperation (Private)
- (void) _finish;
@end

@implementation NSOperation

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
    /* Handle all KVO manually
     */
    return NO;
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        self->priority = NSOperationQueuePriorityNormal;
        self->threadPriority = 0.5;
        self->ready = YES; // 默认就是 ready == yes
        self->lock = [NSRecursiveLock new]; // 递归所
        self->operationCondition = [[NSConditionLock alloc] initWithCondition: 0]; // 这里新创建了一个 conditionLock
        self->dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
        [self addObserver: self
               forKeyPath: @"isFinished"
                  options: NSKeyValueObservingOptionNew
                  context: isFinishedCtxt];
    }
    return self;
}

// 这个方法, 就是向自己维护的数组里面, 添加这个 op, 并且注册这个 op 的 isFinish 的状态改变的回调. 在这个回调里面, 更新自己的 isReady 状态.
- (void) addDependency: (NSOperation *)op
{
    [self->lock lock];
    NS_DURING
    {
        if (-1 == [self->dependencies indexOfObjectIdenticalTo: op]) // 这里避免了重复添加.
        {
            [self willChangeValueForKey: @"dependencies"]; // Handle all KVO manually
            // 所以, KVO 不只是说在 set 方法里面, 一个数组中的值的变化, 是数组内部的值的变化, 而不是这个数组这个值本身.
            // 当这个数组里面的内部值发生变化的时候, 可以手动调用 willChangedValueForKey 和 didChangeValueForKey 这两个方法, 这样外界就可以接收到消息的变化. 而这个时候, 其实这个数组值是没有产生指针的变化的.
            // 也就是说, willChangeValueForKey 和 didChangeValueForKey 这两个事情, 其实可以当做 自定义 通知的机制.
            [self->dependencies addObject: op];
            /* We only need to watch for changes if it's possible for them to
             * happen and make a difference.
             */
            if (NO == [op isFinished] // op 没完成
                && NO == [self isCancelled] // 自己已经取消
                && NO == [self isExecuting] // 自己已经执行
                && NO == [self isFinished]) // 自己已经完成.
            {
                /*
                 自己应该添加对于被依赖对象的监听, 这样被依赖对象更新了之后, 自己更新自己的 isReady 的状态.
                 */
                [op addObserver: self
                     forKeyPath: @"isFinished"
                        options: NSKeyValueObservingOptionNew
                        context: isFinishedCtxt];
                if (self->ready == YES)
                {
                    /* The new dependency stops us being ready ...
                     * change state.
                     */
                    // 当自己处于可运行的状态的时候, 添加了原来, 更新自己的状态为不可运行.
                    [self willChangeValueForKey: @"isReady"];
                    self->ready = NO;
                    [self didChangeValueForKey: @"isReady"];
                }
            }
            [self didChangeValueForKey: @"dependencies"];
        }
    }
    NS_HANDLER
    {
        [self->lock unlock];
        NSLog(@"Problem adding dependency: %@", localException);
        return;
    }
    NS_ENDHANDLER
    [self->lock unlock];
}

- (void) removeDependency: (NSOperation *)op
{
    [self->lock lock];
    NS_DURING
    {
        // 这里用的是, 指针匹配.
        if (-1 != [self->dependencies indexOfObjectIdenticalTo: op])
        {
            [op removeObserver: self
                    forKeyPath: @"isFinished"];
            [self willChangeValueForKey: @"dependencies"];
            [self->dependencies removeObject: op];
            if (NO == self->ready)
            {
                /* The dependency may cause us to become ready ...
                 * fake an observation so we can deal with that.
                 */
                [self observeValueForKeyPath: @"isFinished"
                                    ofObject: op
                                      change: nil
                                     context: isFinishedCtxt];
                // 在去除依赖的时候, 检查更新自己的 ready 状态.
            }
            [self didChangeValueForKey: @"dependencies"];
        }
    }
    NS_HANDLER
    {
        [self->lock unlock];
        NSLog(@"Problem removing dependency: %@", localException);
        return;
    }
    NS_ENDHANDLER
    [self->lock unlock];
}

- (void) cancel
{
    /*
     这里, 读取的时候, 不要加锁了???/
     */
    if (NO == self->cancelled && NO == [self isFinished])
    {
        [self->lock lock]; // 多线程的基本双检测
        if (NO == self->cancelled && NO == [self isFinished])
        {
            NS_DURING
            {
                [self willChangeValueForKey: @"isCancelled"];
                self->cancelled = YES;
                if (NO == self->ready)
                {
                    [self willChangeValueForKey: @"isReady"];
                    self->ready = YES; // 这里, 如果 cancel 的话, ready 的状态也跟着变化了.
                    [self didChangeValueForKey: @"isReady"];
                }
                [self didChangeValueForKey: @"isCancelled"];
            }
            NS_HANDLER
            {
                [self->lock unlock];
                NSLog(@"Problem cancelling operation: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [self->lock unlock];
    }
}

- (GSOperationCompletionBlock) completionBlock
{
    return self->completionBlock;
}

- (void) dealloc
{
    if (self != nil)
    {
        NSOperation	*op;
        
        [self removeObserver: self
                  forKeyPath: @"isFinished"];
        while ((op = [self->dependencies lastObject]) != nil)
        {
            [self removeDependency: op]; // 在释放的时候, 要把依赖关系去除了. 因为, 不移除的话, 会导致 value 的变化还会回调这个已经释放的对象的函数调用, 产生崩溃.
        }
    }
    [super dealloc];
}

- (NSArray *) dependencies // 这里, 是一个拷贝, 而不是把原来的那个可变数组的返回.
{
    NSArray	*a;
    
    if (self->dependencies == nil)
    {
        a = empty;	// OSX return an empty array
    }
    else
    {
        [self->lock lock];
        // 复制一份出来. 因为 dependencies 的值会经常改变, 暴露出去外界改变了, 内部的状态就全乱了.
        a = [NSArray arrayWithArray: self->dependencies];
        [self->lock unlock];
    }
    return a;
}

- (void) main; // main 方法是空的, 这个方法是交给子类去自定义的.
{
    return;	// OSX default implementation does nothing
}


// KVO 的回调.
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    [self->lock lock];
    
    /* We only observe isFinished changes, and we can remove self as an
     * observer once we know the operation has finished since it can never
     * become unfinished.
     */
    // 因为我们只观测 isFinish 的状态改变, 所以, 只要来到这个方法, 我们就取消对于这个对象的监听.
    [object removeObserver: self
                forKeyPath: @"isFinished"];
    
    if (object == self) // 如果自己已经 Finish 了.
    {
        /* We have finished and need to unlock the condition lock so that
         * any waiting thread can continue.
         */
        [self->operationCondition lock];
        [self->operationCondition unlockWithCondition: 1]; // 这里通知之前调用了waitUntil 的线程, 继续操作.
        [self->lock unlock]; //
        return;
    }
    
    // 其他的 operation 已经 Finish 了, 所以, 之所以进行 NSOpertation 这个类要创建出来, 这是因为我们要有一个对象进行任务的依赖管理.
    // 在其他的所有依赖 finished 之后, 自己的状态才能便成为 ready.
    if (NO == self->ready)
    {
        NSEnumerator	*en;
        NSOperation	*op;
        
        /* Some dependency has finished (or been removed) ...
         * so we need to check to see if we are now ready unless we know we are.
         * This is protected by locks so that an update due to an observed
         * change in one thread won't interrupt anything in another thread.
         */
        en = [self->dependencies objectEnumerator];
        while ((op = [en nextObject]) != nil)
        {
            if (NO == [op isFinished])
                break;
        }
        if (op == nil)
        {
            [self willChangeValueForKey: @"isReady"];
            self->ready = YES;
            [self didChangeValueForKey: @"isReady"];
        }
    }
    [self->lock unlock];
}

- (NSOperationQueuePriority) queuePriority
{
    return self->priority;
}

- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock
{
    self->completionBlock = aBlock;
}

// 这里, 仅仅是数值的更改, 还没有进行线程的底层函数的调用.
// 这里, 这些值代表的是, 在 operation 所在 queue 里面调用的优先级变化.
- (void) setQueuePriority: (NSOperationQueuePriority)pri
{
    if (pri <= NSOperationQueuePriorityVeryLow)
        pri = NSOperationQueuePriorityVeryLow;
    else if (pri <= NSOperationQueuePriorityLow)
        pri = NSOperationQueuePriorityLow;
    else if (pri < NSOperationQueuePriorityHigh)
        pri = NSOperationQueuePriorityNormal;
    else if (pri < NSOperationQueuePriorityVeryHigh)
        pri = NSOperationQueuePriorityHigh;
    else
        pri = NSOperationQueuePriorityVeryHigh;
    
    if (pri != self->priority)
    {
        [self->lock lock];
        if (pri != self->priority)
        {
            NS_DURING
            {
                [self willChangeValueForKey: @"queuePriority"];
                self->priority = pri;
                [self didChangeValueForKey: @"queuePriority"];
            }
            NS_HANDLER
            {
                [self->lock unlock];
                NSLog(@"Problem setting priority: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [self->lock unlock];
    }
}

- (void) setThreadPriority: (double)pri
{
    if (pri > 1) pri = 1;
    else if (pri < 0) pri = 0;
    self->threadPriority = pri;
}


// 这个函数会在哪个线程启动??? 这应该是 NSOperationQueue 的事情.
- (void) start
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    double		prio = [NSThread  threadPriority];
    
    AUTORELEASE(RETAIN(self));	// Make sure we exist while running.
    [self->lock lock];
    NS_DURING
    {
        if (YES == [self isConcurrent])
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on concurrent operation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; // 这里会直接报错. 也就是说, NSOperation 不能设置为 concurrent, 应该完全由 queue 进行控制. 这个属性, 现在应该是被放弃了.
        }
        if (YES == [self isExecuting])
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on executing operation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (YES == [self isFinished])
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on finished operation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (NO == [self isReady])
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on operation which is not ready",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (NO == self->executing)
        {
            [self willChangeValueForKey: @"isExecuting"];
            self->executing = YES; // 首先是状态的改变.
            [self didChangeValueForKey: @"isExecuting"];
        }
    }
    NS_HANDLER
    {
        [self->lock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [self->lock unlock];
    
    NS_DURING
    {
        if (NO == [self isCancelled])
        { // 这里, 设置了线程的优先级.
            [NSThread setThreadPriority: self->threadPriority];
            [self main]; // 执行真正的方法.
        }
    }
    NS_HANDLER
    {
        [NSThread setThreadPriority:  prio];
        [localException raise];
    }
    NS_ENDHANDLER;
    
    [self _finish]; // 这里进行私有的 finish 的调用.
    [pool release];
}

- (double) threadPriority
{
    return self->threadPriority;
}


// 这个函数, 是在 queue 里面被调用的.
- (void) waitUntilFinished // 调用这个函数的线程, 和真正执行 main 的线程, 铁定不是一个线程.
{
    [self->operationCondition lockWhenCondition: 1];	// Wait for finish
    [self->operationCondition unlockWithCondition: 1];	// Signal any other watchers
}
@end

@implementation	NSOperation (Private)
- (void) _finish
{
    /* retain while finishing so that we don't get deallocated when our
     * queue removes and releases us.
     */
    [self retain];
    [self->lock lock];
    if (NO == self->finished)
    {
        if (YES == self->executing)
        {
            [self willChangeValueForKey: @"isExecuting"];
            [self willChangeValueForKey: @"isFinished"];
            self->executing = NO; // 通知变化
            self->finished = YES; // 通知变化
            [self didChangeValueForKey: @"isFinished"];
            [self didChangeValueForKey: @"isExecuting"];
        }
        else
        {
            [self willChangeValueForKey: @"isFinished"];
            self->finished = YES;
            [self didChangeValueForKey: @"isFinished"];
        }
        if (NULL != self->completionBlock)
        {
            CALL_BLOCK_NO_ARGS(self->completionBlock); // 调用 completionBlock. 所以, 任何属性暴露出去, 在类的内部都有操作它的函数在. 而注释的意义在于, 表明这个属性在类的内部是怎么使用的.
        }
    }
    [self->lock unlock];
    [self release];
}

@end

#undef	GSself
#define	GSself	NSOperationQueueself
#include	"GSself.h"
GS_PRIVATE_self(NSOperationQueue)


static NSInteger	maxConcurrent = 200;	// Thread pool size

static NSComparisonResult
sortFunc(id o1, id o2, void *ctxt)
{
    NSOperationQueuePriority p1 = [o1 queuePriority];
    NSOperationQueuePriority p2 = [o2 queuePriority];
    
    if (p1 < p2) return NSOrderedDescending;
    if (p1 > p2) return NSOrderedAscending;
    return NSOrderedSame;
}

static NSString	*threadQueueKey = @"NSOperationQueue";
static NSOperationQueue *mainQueue = nil;

@implementation NSOperationQueue

+ (id) currentQueue
{
    if ([NSThread isMainThread])
    {
        return mainQueue;
    }
    return [[[NSThread currentThread] threadDictionary] objectForKey: threadQueueKey]; // 线程里面, 专门存了自己的信息的 key .
}

+ (void) initialize
{
    if (nil == mainQueue)
    {
        mainQueue = [self new]; // 因为, initialize 铁定是在主线程的, 所以在这里进行了主线程Queue 的生成, 所以 mainQueue 其实一点特殊点都没有.
    }
}

+ (id) mainQueue
{
    return mainQueue;
}

- (void) addOperation: (NSOperation *)op
{
    [self->lock lock]; // 因为 operationQueue 可能在多线程环境下进行调用. 这里, 是 addOperation 是在多线程环境下, 而不是说, 已添加的 operation 进行执行的时候的环境.
    if (-1 == [self->operations indexOfObjectIdenticalTo: op] // 如果没有找到,
        && NO == [op isFinished]) // 并且这个 operation 没有执行完.
    {
        [op addObserver: self
             forKeyPath: @"isReady"
                options: NSKeyValueObservingOptionNew
                context: isReadyCtxt]; // queue 也会有 isReady 的概念在.
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [self->operations addObject: op]; // 因为在 h 文件中说明了, operations, 和operationCount 支持KVO, 所以需要在任何改变这两个值的地方, 都要明显的调用这两个值的 kvo 支持.
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
        if (YES == [op isReady])
        {
            [self observeValueForKeyPath: @"isReady"
                                ofObject: op
                                  change: nil
                                 context: isReadyCtxt]; // 这里, 其实是为了调用 execute 方法.
        }
    }
    [self->lock unlock];
}

- (void) addOperations: (NSArray *)ops
     waitUntilFinished: (BOOL)shouldWait // shouldWait, 这个值仅仅在最后的时候, 有一个判断, 加函数调用.
{
    NSUInteger	total;
    NSUInteger	index;
    
    total = [ops count];
    if (total > 0)
    {
        BOOL		invalidArg = NO;
        NSUInteger	toAdd = total;
        GS_BEGINITEMBUF(buf, total, id)
        
        [ops getObjects: buf];
        for (index = 0; index < total; index++) // 这个 for 循环, 做的其实是过滤无效数据.
        {
            NSOperation	*op = buf[index];
            
            if (NO == [op isKindOfClass: [NSOperation class]])
            {
                invalidArg = YES;
                toAdd = 0;
                break;
            }
            if (YES == [op isFinished])
            {
                buf[index] = nil;
                toAdd--;
            }
        }
        
        if (toAdd > 0)
        {
            [self->lock lock];
            [self willChangeValueForKey: @"operationCount"];
            [self willChangeValueForKey: @"operations"];
            
            for (index = 0; index < total; index++)
            {
                NSOperation	*op = buf[index];
                
                if (op == nil)
                {
                    continue;		// Not added
                }
                if (-1
                    != [self->operations indexOfObjectIdenticalTo: op])
                {
                    buf[index] = nil;	// Not added
                    toAdd--;
                    continue;
                }
                [op addObserver: self
                     forKeyPath: @"isReady"
                        options: NSKeyValueObservingOptionNew
                        context: isReadyCtxt]; // 每一个添加进去的 operation 都监听 operationQueue 的 isReady 的状态.
                [self->operations addObject: op];
                if (NO == [op isReady])
                {
                    buf[index] = nil;	// Not yet ready
                }
            }
            
            [self didChangeValueForKey: @"operationCount"];
            [self didChangeValueForKey: @"operations"];
            for (index = 0; index < total; index++)
            {
                NSOperation	*op = buf[index];
                
                if (op != nil)
                {
                    [self observeValueForKeyPath: @"isReady"
                                        ofObject: op
                                          change: nil
                                         context: isReadyCtxt]; // queue 也添加 对于 operation 的 isReady 的监听.
                }
            }
            [self->lock unlock];
        }
        GS_ENDITEMBUF()
        if (YES == invalidArg)
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] object at index %"PRIuPTR" is not an NSOperation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd),
             index];
        }
    }
    if (YES == shouldWait)
    {
        [self waitUntilAllOperationsAreFinished];
    }
}

- (void) cancelAllOperations
{
    [[self operations] makeObjectsPerformSelector: @selector(cancel)]; // 对于所有的 operation 调用 cancel 方法.
}

- (void) dealloc
{
    [self cancelAllOperations];
    DESTROY(self->operations);
    DESTROY(self->starting);
    DESTROY(self->waiting);
    DESTROY(self->name);
    DESTROY(self->cond);
    DESTROY(self->lock);
    GS_DESTROY_self(NSOperationQueue);
    [super dealloc];
}

/*
 通过几个数组的状态的切换, 来达到状态的管理.
 */
- (id) init
{
    if ((self = [super init]) != nil)
    {
        GS_CREATE_self(NSOperationQueue);
        self->suspended = NO;
        self->count = NSOperationQueueDefaultMaxConcurrentOperationCount;
        self->operations = [NSMutableArray new]; // 添加进来的数组
        self->starting = [NSMutableArray new]; // 正在运行的数组
        self->waiting = [NSMutableArray new]; // 正在等待的数组
        self->lock = [NSRecursiveLock new]; // lock
        self->cond = [[NSConditionLock alloc] initWithCondition: 0]; // condition
    }
    return self;
}

- (BOOL) isSuspended
{
    return self->suspended;
}

- (NSInteger) maxConcurrentOperationCount
{
    return self->count;
}

- (int) operationCount
{
    NSUInteger	c;
    
    [self->lock lock]; // 加锁
    c = [self->operations count];
    [self->lock unlock];
    return c;
}

- (NSArray *) operations
{
    NSArray	*a;
    
    [self->lock lock]; // 复制现有的 mutableArray
    a = [NSArray arrayWithArray: self->operations];
    [self->lock unlock];
    return a;
}

- (void) setMaxConcurrentOperationCount: (NSInteger)cnt
{
    [self->lock lock];
    if (cnt != self->count)
    {
        [self willChangeValueForKey: @"maxConcurrentOperationCount"];
        self->count = cnt;
        [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
    [self->lock unlock];
    [self _execute];
}

- (void) setSuspended: (BOOL)flag
{
    [self->lock lock];
    if (flag != self->suspended)
    {
        [self willChangeValueForKey: @"suspended"];
        self->suspended = flag;
        [self didChangeValueForKey: @"suspended"];
    }
    [self->lock unlock];
    [self _execute]; // 当停止状态改变的时候, 执行 _execute, 从这里也能够看出, suspend 这个属性, 是不会影响正在运行的 Operation 的
}

- (void) waitUntilAllOperationsAreFinished
{
    NSOperation	*op;
    
    [self->lock lock];
    while ((op = [self->operations lastObject]) != nil)
    {
        [op retain];
        [self->lock unlock];
        [op waitUntilFinished]; // 最后第一个任务做 wait 操作.
        [op release];
        [self->lock lock];
    }
    [self->lock unlock];
}
@end

@implementation	NSOperationQueue (Private)

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context // 这里, context 作为了区分 keyPath 的标准了.
{
    /* We observe three properties in sequence ...
     * isReady (while we wait for an operation to be ready)
     * queuePriority (when priority of a ready operation may change)
     * isFinished (to see if an executing operation is over).
     */
    if (context == isFinishedCtxt)
    {
        [self->lock lock];
        self->executing--;
        [object removeObserver: self
                    forKeyPath: @"isFinished"];
        [self->lock unlock];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"]; // 因为
        [self->lock lock];
        [self->operations removeObjectIdenticalTo: object];
        [self->lock unlock];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
    }
    else if (context == queuePriorityCtxt || context == isReadyCtxt)
    {
        NSInteger pos;
        
        [self->lock lock];
        // 这里, 会根据 queuePriority 和 ready 对 queue 进行重新的排列工作.
        if (context == queuePriorityCtxt)
        {
            [self->waiting removeObjectIdenticalTo: object];
        }
        if (context == isReadyCtxt)
        {
            [object removeObserver: self forKeyPath: @"isReady"]; // 如果Ready, 才将这个任务加到Wa iting 的 queue 里面.
            [object addObserver: self
                     forKeyPath: @"queuePriority"
                        options: NSKeyValueObservingOptionNew
                        context: queuePriorityCtxt];
        }
        
        
        pos = [self->waiting insertionPosition: object
                                 usingFunction: sortFunc
                                       context: 0]; // 这里, 根据NSO peration 的 queuePriority 对于插入的位置进行了修改, self->waiting 是在queue 对于 operation 的监听里面进行的修改, 现在看来, 优先级高的, 会在插入的时候, 排在优先级底的任务的前面.
        [self->waiting insertObject: object atIndex: pos];
        [self->lock unlock];
    }
    [self _execute]; // 当自己的 Operation 状态改变的时候执行 execute
}

- (void) _thread // 一个线程做的操作.
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    
    [[[NSThread currentThread] threadDictionary] setObject: self
                                                    forKey: threadQueueKey];
    // 可以有好多的线程, 但是他们的threadQueue 是一个 queue.
    for (;;) // 无限循环. 所以这里会一直拿取 starting 里面的数据. 也就是说, 只要线程存在, 他就一直在取 starting 里面的数据. 而这个starting 数据, 会在 execute 里面更细. 也就是说,
    {
        NSOperation	*op;
        NSDate		*when;
        BOOL		found;
        
        when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0]; // 首先会进行等待, 这样就确保了, 下面的操作是被唤醒的.
        found = [self->cond lockWhenCondition: 1 beforeDate: when]; // 等待五秒钟.
        RELEASE(when);
        if (NO == found)
        {
            break;	// Idle for 5 seconds ... exit thread. 如果五秒内, 没有新的任务可以执行, 退出这个线程.
        }
        
        if ([self->starting count] > 0)
        {
            op = RETAIN([self->starting objectAtIndex: 0]); // 这里可以看出, starting 的含义是, 正在等待启动的任务.
            [self->starting removeObjectAtIndex: 0]; // 这一段的操作没有在锁里面啊.
        }
        else
        {
            op = nil;
        }
        
        if ([self->starting count] > 0)
        {
            // Signal any other idle threads,
            [self->cond unlockWithCondition: 1];
        }
        else
        {
            // There are no more operations starting.
            [self->cond unlockWithCondition: 0];
        }
        
        if (nil != op)
        {
            {
                NSAutoreleasePool	*opPool = [NSAutoreleasePool new];
                
                if (NO == [op isCancelled])
                {
                    [NSThread setThreadPriority: [op threadPriority]]; // 这里, NSOperation 里面的线程优先级有了作用.
                    [op main]; // 执行 NSOperation 的方法.
                }
                RELEASE(opPool);
            }
            [op _finish]; // 调用 NSOperation 的 finish 方法
            RELEASE(op);
        }
    }
    
    [[[NSThread currentThread] threadDictionary] removeObjectForKey: threadQueueKey];
    [self->lock lock];
    self->threadCount--;
    [self->lock unlock];
    RELEASE(pool);
    [NSThread exit];
}

/* Check for operations which can be executed and start them.
 */
- (void) _execute
{
    NSInteger	max;
    
    [self->lock lock];
    
    max = [self maxConcurrentOperationCount];
    if (NSOperationQueueDefaultMaxConcurrentOperationCount == max) // 如果 max 的值没有进行设置的话.
    {
        max = maxConcurrent;
    }
    
    while (NO == [self isSuspended] // 没有被停止.
           && max > self->executing // 还有到最大执行量
           && [self->waiting count] > 0) // 有着正在等待的执行的缓存.
    {
        NSOperation	*op;
        
        /* Take the first operation from the queue and start it executing.
         * We set ourselves up as an observer for the operating finishing
         * and we keep track of the count of operations we have started,
         * but the actual startup is left to the NSOperation -start method.
         
         
         // NSOperationQueue 更多的是一个调度的工作.
         */
        /*
         当 Operation ready 只会, 会被状态 Waiting 里面, 然后 execute 里面, 就是操作 Waiting 里面的值了.
         而 execute 里面, 是操作 waiting 里面的值, 到 starting 里面去.
         */
        op = [self->waiting objectAtIndex: 0];
        [self->waiting removeObjectAtIndex: 0];
        [op removeObserver: self forKeyPath: @"queuePriority"]; // 脱离了 waiting 队列,
        [op addObserver: self
             forKeyPath: @"isFinished"
                options: NSKeyValueObservingOptionNew
                context: isFinishedCtxt];
        self->executing++;
        if (YES == [op isConcurrent])
        {
            [op start]; // 该属性已经被放弃, 由 NSOperationQueue 进行控制.
        }
        else
        {
            NSUInteger	pending;
            
            [self->cond lock];
            pending = [self->starting count];
            [self->starting addObject: op];
            
            /* Create a new thread if all existing threads are busy and
             * we haven't reached the pool limit.
             */
            if (0 == self->threadCount
                || (pending > 0 && self->threadCount < POOL))
            {
                self->threadCount++;
                [NSThread detachNewThreadSelector: @selector(_thread)
                                         toTarget: self
                                       withObject: nil];
            }
            /* Tell the thread pool that there is an operation to start.
             */
            [self->cond unlockWithCondition: 1];
        }
    }
    [self->lock unlock];
}

@end

