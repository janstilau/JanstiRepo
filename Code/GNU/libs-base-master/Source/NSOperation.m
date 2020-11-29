#import "common.h"

#import "Foundation/NSLock.h"
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
#include	"GSInternal.h"

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
    return NO;
}

+ (void) initialize
{
    empty = [NSArray new];
}

- (void) addDependency: (NSOperation *)op
{
    /*
     首先是一些防卫式的检测.
     */
    if (NO == [op isKindOfClass: [NSOperation class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] dependency is not an NSOperation",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (op == self)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] attempt to add dependency on self",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    
    if (self->dependencies == nil)
    {
        self->dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
    }
    
    [self->lock lock];
    /*
     任何对于自身值的修改的地方, 都增加了 lock.
     因为执行自己 main 的地方, 不一定在创建线程, 所以, 加锁是必备的.
     addDependency 应该是创建的时候进行的, 在 addDependency 之后, 才会进行真正 main 的调用, 不过这里也加锁也没有问题, 安全.
     */
    NS_DURING
    {
        /*
         只有, 没有添加过依赖, 才会进行添加.
         */
        if (NSNotFound == [self->dependencies indexOfObjectIdenticalTo: op])
        {
            [self willChangeValueForKey: @"dependencies"];
            [self->dependencies addObject: op];
            /* We only need to watch for changes if it's possible for them to
             * happen and make a difference.
             */
            if (NO == [op isFinished]
                && NO == [self isCancelled]
                && NO == [self isExecuting]
                && NO == [self isFinished])
            {
                /*
                 当前的 Operation, 要监听依赖的 Operation 的 finished 状态, 以便修改自己的 ready 状态.
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

/*
 Advises the operation object that it should stop executing its task.
 */
- (void) cancel
{
    if (NO == self->cancelled && NO == [self isFinished])
    {
        [self->lock lock];
        if (NO == self->cancelled && NO == [self isFinished])
        {
            NS_DURING
            {
                /*
                 Cancel 也会导致 ready 的值的变化.
                 */
                [self willChangeValueForKey: @"isCancelled"];
                self->cancelled = YES;
                if (NO == self->ready)
                {
                    [self willChangeValueForKey: @"isReady"];
                    self->ready = YES;
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

/*
 The completion block takes no parameters and has no return value.

 The exact execution context for your completion block is not guaranteed but is typically a secondary thread.
 Therefore, you should not use this block to do any work that requires a very specific execution context.

 The completion block you provide is executed when the value in the finished property changes to YES.
 Because the completion block executes after the operation indicates it has finished its task, you must not use a completion block to queue additional work considered to be part of that task.
 An operation object whose finished property contains the value YES must be done with all of its task-related work by definition.
 The completion block should be used to notify interested objects that the work is complete or perform other tasks that might be related to, but not part of, the operation’s actual task.

 A finished operation may finish either because it was cancelled or because it successfully completed its task.
 You should take that fact into account when writing your block code.
 Similarly, you should not make any assumptions about the successful completion of dependent operations, which may themselves have been cancelled.
 
 completionBlock 就是在 Operation 执行完自己的任务之后的收尾工作.
 需要注意的是, cancel 的也算作是执行完自己的任务了.
 因为, cancel 本质上来说, 仅仅是一个状态量, main 里面根据这个状态量提前进行了退出, 也算作是 main 执行完毕了.
 main 执行完毕了, 就可以认为是 NSOperation 执行完毕了.
 */

- (void*) completionBlock
{
    return self->completionBlock;
}

/*
 Get 函数加锁.
 */
- (NSArray *) dependencies
{
    NSArray	*a;
    
    if (self->dependencies == nil)
    {
        a = empty;	// OSX return an empty array
    }
    else
    {
        [self->lock lock];
        a = [NSArray arrayWithArray: self->dependencies];
        [self->lock unlock];
    }
    return a;
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        self->priority = NSOperationQueuePriorityNormal;
        self->threadPriority = 0.5;
        self->ready = YES;
        self->lock = [NSRecursiveLock new];
        [self->lock setName:
         [NSString stringWithFormat: @"lock-for-opqueue-%p", self]];
        self->operationConditionLock = [[NSConditionLock alloc] initWithCondition: 0];
        [self->operationConditionLock setName:
         [NSString stringWithFormat: @"cond-for-opqueue-%p", self]];
        /*
         自己监听自己的 isFinished 的状态.
         */
        [self addObserver: self
               forKeyPath: @"isFinished"
                  options: NSKeyValueObservingOptionNew
                  context: isFinishedCtxt];
    }
    return self;
}

- (BOOL) isCancelled
{
    return self->cancelled;
}

- (BOOL) isExecuting
{
    return self->executing;
}

- (BOOL) isFinished
{
    return self->finished;
}

- (BOOL) isConcurrent
{
    return self->concurrent;
}

- (BOOL) isReady
{
    return self->ready;
}

/*
 Start 是 Operation 的入口.
 NSOpertaion 中有着一些状态, 在运行前后要进行校验, 之后符合 NSOpertation 逻辑之后, 才会调用 main 方法.
 main 方法, 作为命令模式的主要承担着, 存储着所有的业务代码, 但是, 各个状态, 还是要符合 NSOperation 的管理的.
 */

- (void)start{
    
    // 在每一个 operation 里面, 都新建了一个自动释放吃
    ENTER_POOL
    
    double    prio = [NSThread  threadPriority];
    
    AUTORELEASE(RETAIN(self));    // Make sure we exist while running.
    
    /*
     在真正执行之前, 要进行一些状态的检查操作.
     */
    [self->lock lock];
    NS_DURING
    {
        /*
         如果是由 OperationQueue 去管理, 那么一般不会出现状态不合适就进去 start 的状态.
         但是 start 可以由手动进行触发, 所以里面的各个检查, 都是有必要的.
         */
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
            self->executing = YES;
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
        {
            /*
             NSOperation 里面的 threadPriority, 直接是影响到了当前的 NSThread 的 priority 的值.
             */
            [NSThread setThreadPriority: self->threadPriority];
            [self main];
        }
    }
    NS_HANDLER
    {
        [NSThread setThreadPriority:  prio];
        [localException raise];
    }
    NS_ENDHANDLER;
    
    [self _finish];
    LEAVE_POOL
}


/*
 The default implementation of this method does nothing. You should override this method to perform the desired task.
 In your implementation, do not invoke super.
 This method will automatically execute within an autorelease pool provided by NSOperation, so you do not need to create your own autorelease pool block in your implementation.

 If you are implementing a concurrent operation, you are not required to override this method but may do so if you plan to call it from your custom start method.
 */
- (void) main;
{
    return;	// OSX default implementation does nothing
}


/*
 Self 通过监听 denpency 的 isFinished 的状态, 来修改自身的 ready 状态.
 */
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    [self->lock lock];
    
    /*
     Operation 内部, 仅仅监听的就是 isFinished 的状态. 所以, 只要来到了, 剔除监听者就可以了.
     */
    [object removeObserver: self forKeyPath: @"isFinished"];
    
    if (object == self)
    {
        /*
         当前自己的任务完成了, self->cond unlockWithCondition 可以唤醒, 当前的 Operation 在其他线程执行的 wait 操作.
         */
        [self->operationConditionLock lock];
        [self->operationConditionLock unlockWithCondition: 1];
        [self->lock unlock];
        return;
    }
    
    /*
     根据依赖的 operation 的状态, 改变一下自己的 ready 状态
     */
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

- (void) removeDependency: (NSOperation *)op
{
    [self->lock lock];
    NS_DURING
    {
        if (NSNotFound != [self->dependencies indexOfObjectIdenticalTo: op])
        {
            [op removeObserver: self forKeyPath: @"isFinished"];
            [self willChangeValueForKey: @"dependencies"];
            [self->dependencies removeObject: op];
            if (NO == self->ready)
            {
                /*
                 主动调用一些 observeValueForKeyPath 方法, 在里面, 修改 self 的 ready 状态
                 */
                [self observeValueForKeyPath: @"isFinished"
                                    ofObject: op
                                      change: nil
                                     context: isFinishedCtxt];
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


- (double) threadPriority
{
    return self->threadPriority;
}

- (void) waitUntilFinished
{
    [self->operationConditionLock lockWhenCondition: 1];	// Wait for finish
    [self->operationConditionLock unlockWithCondition: 1];	// Signal any other watchers
}

@end

@implementation	NSOperation (Private)

- (void) _finish
{
    /*
     _finish 可以被调用, 就是 operation 的任务执行完了, 在这里, 进行一些状态值的改变.
     */
    RETAIN(self);
    [self->lock lock];
    if (NO == self->finished)
    {
        if (YES == self->executing)
        {
            [self willChangeValueForKey: @"isExecuting"];
            [self willChangeValueForKey: @"isFinished"];
            self->executing = NO;
            self->finished = YES;
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
            CALL_BLOCK_NO_ARGS(self->completionBlock);
        }
    }
    [self->lock unlock];
    RELEASE(self);
}

@end


/*
 Block Opertation, 就是简简单单的, 将 Block 当做参数存储起来, main 里面调用就得了.
 */
@implementation NSBlockOperation

+ (instancetype) blockOperationWithBlock: (GSBlockOperationBlock)block
{
    NSBlockOperation *op = [[self alloc] init];
    
    [op addExecutionBlock: block];
    return AUTORELEASE(op);
}

- (void) addExecutionBlock: (GSBlockOperationBlock)block
{
    GSBlockOperationBlock	blockCopy = [block copy];
    
    [_executionBlocks addObject: blockCopy];
    RELEASE(blockCopy);
}

- (void) dealloc
{
    RELEASE(_executionBlocks);
    [super dealloc];
}

- (NSArray *) executionBlocks
{
    return _executionBlocks;
}

- (id) init
{
    self = [super init];
    if (self != nil)
    {
        _executionBlocks = [[NSMutableArray alloc] initWithCapacity: 1];
    }
    return self;
}

- (void) main
{
    NSEnumerator 		*en = [[self executionBlocks] objectEnumerator];
    GSBlockOperationBlock theBlock;
    
    while ((theBlock = [en nextObject]) != NULL)
    {
        CALL_BLOCK_NO_ARGS(theBlock);
    }
}
@end


#include	"GSInternal.h"

@interface	NSOperationQueue (Private)
- (void) _execute;
- (void) _thread;
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context;
@end

static NSInteger	maxConcurrent = 200;	// Thread pool size

/*
 这里, 直接是按照 queuePriority 进行的排序.
 */
static NSComparisonResult
sortFunc(id o1, id o2, void *ctxt)
{
    NSOperationQueuePriority p1 = [o1 queuePriority];
    NSOperationQueuePriority p2 = [o2 queuePriority];
    
    if (p1 < p2) return NSOrderedDescending;
    if (p1 > p2) return NSOrderedAscending;
    return NSOrderedSame;
}

static NSString	*operationQueueKey = @"NSOperationQueue";
static NSOperationQueue *mainQueue = nil;

@implementation NSOperationQueue

+ (id) currentQueue
{
    if ([NSThread isMainThread])
    {
        return mainQueue;
    }
    return [[[NSThread currentThread] threadDictionary] objectForKey: operationQueueKey];
}

+ (void) initialize
{
    if (nil == mainQueue)
    {
        mainQueue = [self new];
    }
}

+ (id) mainQueue
{
    return mainQueue;
}

- (void) addOperation: (NSOperation *)op
{
    [self->queueLock lock];
    if (NSNotFound == [self->operations indexOfObjectIdenticalTo: op]
        && NO == [op isFinished])
    {
        /*
         OperationQueue 观测每个 Operation 的 isReady, 来进行队列的调度处理.
         */
        [op addObserver: self
             forKeyPath: @"isReady"
                options: NSKeyValueObservingOptionNew
                context: isReadyCtxt];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [self->operations addObject: op];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
        /*
         这里, 如果 op 已经是 ready 了, 显示的调用 observeValueForKeyPath, 主要是为了可以进行队列的调度.
         */
        if (YES == [op isReady])
        {
            [self observeValueForKeyPath: @"isReady"
                                ofObject: op
                                  change: nil
                                 context: isReadyCtxt];
        }
    }
    [self->queueLock unlock];
}


- (void) addOperations: (NSArray *)ops
     waitUntilFinished: (BOOL)shouldWait
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
        for (index = 0; index < total; index++)
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
            [self->queueLock lock];
            [self willChangeValueForKey: @"operationCount"];
            [self willChangeValueForKey: @"operations"];
            for (index = 0; index < total; index++)
            {
                NSOperation	*op = buf[index];
                
                if (op == nil)
                {
                    continue;		// Not added
                }
                if (NSNotFound
                    != [self->operations indexOfObjectIdenticalTo: op])
                {
                    buf[index] = nil;	// Not added
                    toAdd--;
                    continue;
                }
                [op addObserver: self
                     forKeyPath: @"isReady"
                        options: NSKeyValueObservingOptionNew
                        context: isReadyCtxt];
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
                                         context: isReadyCtxt];
                }
            }
            [self->queueLock unlock];
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
    [[self operations] makeObjectsPerformSelector: @selector(cancel)];
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        self->suspended = NO;
        self->count = NSOperationQueueDefaultMaxConcurrentOperationCount;
        self->operations = [NSMutableArray new];
        self->starting = [NSMutableArray new];
        self->waiting = [NSMutableArray new];
        self->queueLock = [NSRecursiveLock new];
        [self->queueLock setName:
         [NSString stringWithFormat: @"lock-for-op-%p", self]];
        self->queueCondition = [[NSConditionLock alloc] initWithCondition: 0];
        [self->queueCondition setName:
         [NSString stringWithFormat: @"cond-for-op-%p", self]];
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

- (NSString*) name
{
    NSString	*s;
    
    [self->queueLock lock];
    if (self->name == nil)
    {
        self->name
        = [[NSString alloc] initWithFormat: @"NSOperation %p", self];
    }
    s = RETAIN(self->name);
    [self->queueLock unlock];
    return AUTORELEASE(s);
}

- (NSUInteger) operationCount
{
    NSUInteger	c;
    
    [self->queueLock lock];
    c = [self->operations count];
    [self->queueLock unlock];
    return c;
}

/*
 复制一份出去.
 */
- (NSArray *) operations
{
    NSArray	*a;
    
    [self->queueLock lock];
    a = [NSArray arrayWithArray: self->operations];
    [self->queueLock unlock];
    return a;
}

- (void) setMaxConcurrentOperationCount: (NSInteger)cnt
{
    [self->queueLock lock];
    if (cnt != self->count)
    {
        [self willChangeValueForKey: @"maxConcurrentOperationCount"];
        self->count = cnt;
        [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
    [self->queueLock unlock];
    [self _execute];
}

- (void) setName: (NSString*)s
{
    if (s == nil) s = @"";
    [self->queueLock lock];
    if (NO == [self->name isEqual: s])
    {
        [self willChangeValueForKey: @"name"];
        RELEASE(self->name);
        self->name = [s copy];
        [self didChangeValueForKey: @"name"];
    }
    [self->queueLock unlock];
}

/*
 A Boolean value indicating whether the queue is actively scheduling operations for execution.
 
 When the value of this property is NO, the queue actively starts operations that are in the queue and ready to execute. Setting this property to YES prevents the queue from starting any queued operations, but already executing operations continue to execute.
 You may continue to add operations to a queue that is suspended but those operations are not scheduled for execution until you change this property to NO.
 */
- (void)setSuspended: (BOOL)flag
{
    [self->queueLock lock];
    if (flag != self->suspended)
    {
        [self willChangeValueForKey: @"suspended"];
        self->suspended = flag;
        [self didChangeValueForKey: @"suspended"];
    }
    [self->queueLock unlock];
    /*
     在相应的地方, 重启队列就可以了.
     已经执行的任务, 不会受到影响.
     */
    [self _execute];
}

/*
 Blocks the current thread until all of the receiver’s queued and executing operations finish executing.
 
 When called, this method blocks the current thread and waits for the receiver’s current and queued operations to finish executing.
 While the current thread is blocked, the receiver continues to launch already queued operations and monitor those that are executing.
 During this time, the current thread cannot add operations to the queue, but other threads may. Once all of the pending operations are finished, this method returns.

 If there are no operations in the queue, this method returns immediately.
 
 这个函数, 是使用了 operation 的 wait 停止的当前线程.
 NSConditionLock 的使用逻辑, 基本可以搞清楚了, 在当前的线程, 进行 wait 的操作, 然后, 在其他的线程, 调用同样的 conditionLock 的 unlockWithCondition 就可以使得原来的线程恢复执行的状态. GNU 类库里面, wiat 相关的函数, 基本都是这样实现的. 比如 PerformSelectorOnThreadWait
 
 在这个函数里面, 找到最后一个 Operation, 是因为这是一个队列, 队列里面, 最后一个任务一定是最后执行的.
 最后一个任务, 调用 waitUntilFinished, 会导致当前线程不调度.
 但是其他的线程, 会执行该任务的 start 方法, 使得该任务可以在其他线程进行执行. 在该任务 finish 之后, 会进行 unlock 的操作, 使得当前的线程可以被唤醒.
 由于这里是一个循环, 所以, 只有所有的任务都执行完毕之后, 才会进行后续的处理.
 */
- (void) waitUntilAllOperationsAreFinished
{
    NSOperation	*op;
    
    [self->queueLock lock];
    while ((op = [self->operations lastObject]) != nil)
    {
        RETAIN(op);
        [self->queueLock unlock];
        [op waitUntilFinished];
        RELEASE(op);
        [self->queueLock lock];
    }
    [self->queueLock unlock];
}
@end

@implementation	NSOperationQueue (Private)

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    /*
     如果, 一个任务执行完毕了, 就立马将监听剔除了.
     */
    if (context == isFinishedCtxt)
    {
        [self->queueLock lock];
        self->executing--;
        [object removeObserver: self forKeyPath: @"isFinished"];
        [self->queueLock unlock];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [self->queueLock lock];
        [self->operations removeObjectIdenticalTo: object];
        [self->queueLock unlock];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
    } else if (context == queuePriorityCtxt || context == isReadyCtxt) {
        NSInteger pos;
        [self->queueLock lock];
        if (context == queuePriorityCtxt)
        {
            [self->waiting removeObjectIdenticalTo: object];
        }
        if (context == isReadyCtxt)
        {
            [object removeObserver: self forKeyPath: @"isReady"];
            [object addObserver: self
                     forKeyPath: @"queuePriority"
                        options: NSKeyValueObservingOptionNew
                        context: queuePriorityCtxt];
        }
        pos = [self->waiting insertionPosition: object
                                 usingFunction: sortFunc
                                       context: 0];
        [self->waiting insertObject: object atIndex: pos];
        [self->queueLock unlock];
    }
    /*
     改变了队列里面的内容之后, 要立马执行调度算法, 进行下一个任务的执行.
     */
    [self _execute];
}

- (void) _thread
{
    ENTER_POOL
    /*
     开辟了一个新的线程, 这个线程不断的做提取
     */
    [[[NSThread currentThread] threadDictionary] setObject: self
                                                    forKey: operationQueueKey];
    while(true) {
        /*
         首先, 等待 5 秒, 看一下有没有新的任务可以执行.
         这里, 需要认清楚 Condition 是干什么的.
         lockWhenCondition 这个函数的内部, 当 参数和当前的 condition_value 不相等的时候, 会一直 wait.
         beforeDate 会在到达时间之后返回 false.
         而 queueCondition unlockWithCondition 会改变这个 condition_value 的值. 分别是在本函数内, 判断 [self->starting count] 值后, 和调度函数内, 明确的知道有着可运营的任务之后.
         
         [self->queueCondition lockWhenCondition: 1 beforeDate: when] 返回 YES 之后, self->queueCondition 已经处在了 lock 状态了.
         但是之后的任务运行时, 不需要加锁的. 所以在 拿取到 currentOperation 之后, 立马进行了 unlockWithCondition 的处理.
         
         线程进入循环之后, 首先根据 condition 的值, 判断有没有任务处理, 如果有, 立马加锁进行任务的提取, 然后释放锁并设置 condition 的值.
         如果没有, 则等待 5 秒, 看有没有其他的任务执行完了, 如果没有, 那么这个线程也就销毁了.
         
         在执行任务的时候, 任务已经拿到手了, 直接在当前线程执行就可以了, 这个时候, 没有公共资源可以修改, 所以不用加锁.
         
         在没有任务执行的时候, 就调用线程的退出处理.
         */
        NSDate *when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0];
        BOOL hasWaitingOperation = [self->queueCondition lockWhenCondition: 1 beforeDate: when];
        if (NO == hasWaitingOperation)
        {
            break;	// Idle for 5 seconds ... exit thread.
        }
        
        NSOperation    *currentOperation;
        if ([self->starting count] > 0)
        {
            currentOperation = RETAIN([self->starting objectAtIndex: 0]);
            [self->starting removeObjectAtIndex: 0];
        } else {
            currentOperation = nil;
        }
        
        if ([self->starting count] > 0)
        {
            // Signal any other idle threads,
            [self->queueCondition unlockWithCondition: 1];
        } else {
            // There are no more operations starting.
            [self->queueCondition unlockWithCondition: 0];
        }
        
        if (nil != currentOperation)
        {
            NS_DURING
            {
                ENTER_POOL
                [NSThread setThreadPriority: [currentOperation threadPriority]];
                [currentOperation start];
                LEAVE_POOL
            }
            NS_HANDLER
            {
                NSLog(@"Problem running operation %@ ... %@",
                      currentOperation, localException);
            }
            NS_ENDHANDLER {
                [currentOperation _finish];
            }
            RELEASE(currentOperation);
        }
    }
    
    [[[NSThread currentThread] threadDictionary] removeObjectForKey: operationQueueKey];
    [self->queueLock lock];
    self->threadCount--;
    [self->queueLock unlock];
    LEAVE_POOL
    [NSThread exit];
}

/*
 队列的调度就是这样, 各个相关的方法, 主动地去进行队列的调度函数.
 在调度算法执行的时候, 要进行加锁处理, 或者, 应该将调度算法放到主线程, 串行队列执行, 保证各个值不会线程冲突.
 调度算法拿到相应的任务之后, 执行任务的时候, 就应该放开锁, 让任务单独在子线程处理.
 在任务执行完毕之后, 应该让任务的回调, 重新执行调度算法, 进行下一步的操作.
 调度算法如果发现没有任务了, 直接 return 就可以了. 所以, 可能会出现停止的情况.
 在添加任务, 或者改变任务优先级的时候, 应该加锁, 并且改变队列的顺序, 然后重新调用调度算法.
 */
- (void) _execute
{
    NSInteger	max;
    
    /*
     所有对于队列的改变, 都在锁下进行.
     */
    [self->queueLock lock];
    
    max = [self maxConcurrentOperationCount];
    if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
        max = maxConcurrent;
    }
    
    NS_DURING
    /*
     如果, 没有暂停, 还有余量, 还有等在执行的队列, 那么就可以开启新的任务.
     */
    while (NO == [self isSuspended]
           && max > self->executing
           && [self->waiting count] > 0)
    {
        NSOperation	*op;
        
        /*
         从 waiting 的第一个进行调度, wait 里面的顺序, 会随着优先级参数的设置随时调整.
         */
        op = [self->waiting objectAtIndex: 0];
        [self->waiting removeObjectAtIndex: 0];
        [op removeObserver: self forKeyPath: @"queuePriority"];
        /*
         只有任务开始执行, 才会去监听它的 finished 状态.
         */
        [op addObserver: self
             forKeyPath: @"isFinished"
                options: NSKeyValueObservingOptionNew
                context: isFinishedCtxt];
        self->executing++;
        /*
         NSOperation isConcurrent == YES, 代表着这个 NSOperation 内部会进行线程的开辟.
         默认的都是 NO.
         */
        if (YES == [op isConcurrent])
        {
            [op start];
        }
        else
        {
            // 如果需要 operationQueue 开辟线程运行任务, 在这里进行线程的新开辟处理.
            NSUInteger	pendingCount;
            
            /*
             self->starting
             self->threadCount
             这些值, 都是在 self->queueCondition 的管理下进行的取值赋值.
             */
            [self->queueCondition lock];
            pendingCount = [self->starting count];
            [self->starting addObject: op];
            /*
             在这里, 进行了新的线程的分配工作.
             */
            if (0 == self->threadCount
                || (pendingCount > 0 && self->threadCount < POOL))
            {
                self->threadCount++;
                NS_DURING
                {
                    [NSThread detachNewThreadSelector: @selector(_thread)
                                             toTarget: self
                                           withObject: nil];
                }
                NS_HANDLER
                {
                    NSLog(@"Failed to create thread for %@: %@",
                          self, localException);
                }
                NS_ENDHANDLER
            }
            /*
             主动的通知新开辟的线程, 可以进行新任务的处理
             */
            [self->queueCondition unlockWithCondition: 1];
        }
    }
    NS_HANDLER
    {
        [self->queueLock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [self->queueLock unlock];
}

@end

