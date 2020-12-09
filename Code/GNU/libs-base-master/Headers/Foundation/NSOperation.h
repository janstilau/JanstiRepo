#ifndef __NSOperation_h_GNUSTEP_BASE_INCLUDE
#define __NSOperation_h_GNUSTEP_BASE_INCLUDE

@class NSMutableArray;

enum {
    NSOperationQueuePriorityVeryLow = -8,
    NSOperationQueuePriorityLow = -4,
    NSOperationQueuePriorityNormal = 0,
    NSOperationQueuePriorityHigh = 4,
    NSOperationQueuePriorityVeryHigh = 8
};

typedef NSInteger NSOperationQueuePriority;

/*
 An abstract class that represents the code and data associated with a single task.
 The base implementation of NSOperation does include significant logic to coordinate the safe execution of your task.
 */

@interface NSOperation : NSObject
{
    NSRecursiveLock *lock;
    NSConditionLock *operationConditionLock;
    NSOperationQueuePriority priority;
    double threadPriority;
    BOOL cancelled;
    BOOL concurrent;
    BOOL executing;
    BOOL finished;
    BOOL blocked;
    BOOL ready;
    NSMutableArray *dependencies;
    GSOperationCompletionBlock completionBlock;
}

- (void) addDependency: (NSOperation *)op;

- (void) cancel;

- (GSOperationCompletionBlock) completionBlock;

- (NSArray *)dependencies;

- (BOOL) isCancelled;

- (BOOL) isConcurrent;

- (BOOL) isExecuting;

- (BOOL) isFinished;

- (BOOL) isReady;

- (void) main;

- (NSOperationQueuePriority) queuePriority;
- (void) removeDependency: (NSOperation *)op;

- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock;
- (void) setQueuePriority: (NSOperationQueuePriority)priority;

- (void) setThreadPriority: (double)prio;

- (void) start;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Returns the thread priority to be used executing the -main method.
 * The default is 0.5
 */
- (double) threadPriority;

/** This method blocks the current thread until the receiver finishes.<br />
 * Care must be taken to avoid deadlock ... you must not call this method
 * from the same thread that the receiver started in.
 */
- (void) waitUntilFinished;
#endif

@end

@interface NSBlockOperation : NSOperation
{
@private
    NSMutableArray *_executionBlocks;
    void *_reserved;
}

// Managing the blocks in the Operation
+ (instancetype)blockOperationWithBlock: (GSBlockOperationBlock)block;
- (void)addExecutionBlock: (GSBlockOperationBlock)block;
- (NSArray *) executionBlocks;

@end

/**
 * NSOperationQueue
 */

// Enumerated type for default operation count.
enum {
    NSOperationQueueDefaultMaxConcurrentOperationCount = -1
};

@interface NSOperationQueue : NSObject
{
    
    /*
     */
    NSRecursiveLock    *queueLock; // 这个所, 提供了除了 starting 其他属性的互斥保护.
    NSConditionLock    *startingQueueCondition; // 这个锁, 是控制 starting 队列的, 同时带有唤醒作用.
    NSMutableArray    *operations; // 添加到当前 queue 里面的
    NSMutableArray    *waiting; // 还未执行的, 已经处于 Ready 的任务
    NSMutableArray    *starting; // 即将运行的任务, 正在等待线程完成当下任务调用自己. 
    NSString        *name;
    BOOL            suspended;
    NSInteger        executingCount;
    NSInteger        threadCount;
    NSInteger        count;
}
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** If called from within the -main method of an operation which is
 * currently being executed by a queue, this returns the queue instance
 * in use.
 */
+ (id) currentQueue;

/** Returns the default queue on the main thread.
 */
+ (id) mainQueue;
#endif

/** Adds an operation to the receiver.
 */
- (void) addOperation: (NSOperation *)op;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Adds multiple operations to the receiver and (optionally) waits for
 * all the operations in the queue to finish.
 */
- (void) addOperations: (NSArray *)ops
     waitUntilFinished: (BOOL)shouldWait;

/** This method wraps a block in an operation and adds it to the queue.
 */
- (void) addOperationWithBlock: (GSBlockOperationBlock)block;
#endif

/** Cancels all outstanding operations in the queue.
 */
- (void) cancelAllOperations;

/** Returns a flag indicating whether the queue is currently suspended.
 */
- (BOOL) isSuspended;

/** Returns the value set using the -setMaxConcurrentOperationCount:
 * method, or NSOperationQueueDefaultMaxConcurrentOperationCount if
 * none has been set.<br />
 */
- (NSInteger) maxConcurrentOperationCount;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Return the name of this operation queue.
 */
- (NSString*) name;

/** Return the number of operations in the queue at an instant.
 */
- (NSUInteger) operationCount;
#endif

/** Returns all the operations in the queue at an instant.
 */
- (NSArray *) operations;

/** Sets the number of concurrent operations permitted.<br />
 * The default (NSOperationQueueDefaultMaxConcurrentOperationCount)
 * means that the queue should decide how many it does based on
 * system load etc.
 */
- (void) setMaxConcurrentOperationCount: (NSInteger)cnt;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Sets the name for this operation queue.
 */
- (void) setName: (NSString*)s;
#endif

/** Marks the receiver as suspended ... while suspended an operation queue
 * will not start any more operations.
 */
- (void) setSuspended: (BOOL)flag;

/** Waits until all operations in the queue have finished (or been cancelled
 * and removed from the queue).
 */
- (void) waitUntilAllOperationsAreFinished;
@end

#endif

#endif /* __NSOperation_h_GNUSTEP_BASE_INCLUDE */
