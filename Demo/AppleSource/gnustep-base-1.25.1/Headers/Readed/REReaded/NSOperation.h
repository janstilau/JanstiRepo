
#ifndef __NSOperation_h_GNUSTEP_BASE_INCLUDE
#define __NSOperation_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
#import <GNUstepBase/GSBlocks.h>
DEFINE_BLOCK_TYPE_NO_ARGS(GSOperationCompletionBlock, void);
#endif

@class NSMutableArray;

enum {
  NSOperationQueuePriorityVeryLow = -8,
  NSOperationQueuePriorityLow = -4,
  NSOperationQueuePriorityNormal = 0,
  NSOperationQueuePriorityHigh = 4,
  NSOperationQueuePriorityVeryHigh = 8
};

typedef NSInteger NSOperationQueuePriority;

@interface NSOperation : NSObject
{
    /*
     可以看到, 下面的这些状态很乱, 应该按照 Swift 的建议, 将这些互斥的状态, 用枚举进行定义. 这样, 只会有一个表示状态的值.
     */
NSRecursiveLock *lock; \
NSConditionLock *operationCondition; \
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
}

/*
 这个类里面, 大量的用了 KVO.
 NSOperation, NSOperation 里面有 main , start, 以及一个 denpendency 的数组. 当我们调用 start 的时候, 会去执行 main 方法, 这也就是为什么, 我们要进行 main 方法的重载. start 是我们的主观的调用, 而 queue 里面, 是直接调用 main 方法的.
 queue 里面维护了两个数组, 一个 waiting 数组, 一个 starting 数组, 并且监听了每个 operation 的 isReady KVO.
 当 queue 发现有个 operatin isReady 的时候, 就把这个 operation 放进 waiting 数组里面. 然后在执行 execute 方法里面, 将 waiting 数组的内容, 放置到 starting 数组里面, 按照配置, 创建线程, 在线程里面, 不断的执行 starting 数组里面的方法.
 
 我之前一直在想, Operation 底层是不是dispatch, 现在看来, 并不是.
 
 那么如何实现任务的依赖呢, 这里, 它是用的数组解决的, 只有处于 ready 的 operation 才能到 waitting 里面, 而想要处于 ready 状态, 必须自己 denpendcy 数组里面的所有依赖 operation 全部处于 finish 状态. 通过两个数组, 根本不要什么唤醒之类的操作.
 
之前的MC 代码里面, 有序的下载图片这个事情, 也是用的数组进行的封装, 应该这样说, 有序这个事情, 最好就是通过逻辑进行控制, 那种很底层的唤醒机制, 只有在线程同步的时候用到才好.
 */

/** Adds a dependency to the receiver.<br />
 * The receiver is not considered ready to execute until all of its
 * dependencies have finished executing.<br />
 * You must not add a particular object to the receiver more than once.<br />
 * You must not create loops of dependencies (this would cause deadlock).<br />
 */
- (void) addDependency: (NSOperation *)op;

/**
 标记, 必须在实现文件里面有着对应的控制逻辑才会起作用.
 Marks the operation as cancelled (causes subsequent calls to the
 * -isCancelled method to return YES).<br />
 * This does not directly cause the receiver to stop executing ... it is the
 * responsibility of the receiver to call -isCancelled while executing and
 * act accordingly.<br />
 * If an operation in a queue is cancelled before it starts executing, it
 * will be removed from the queue (though not necessarily immediately).<br />
 * Calling this method on an object which has already finished executing
 * has no effect.
 */
- (void) cancel;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 这其实就是一个回调. 和我们平时写的回调一样.
 * Returns the block that will be executed after the operation finishes.
 */
- (GSOperationCompletionBlock) completionBlock;
#endif

/** Returns all the dependencies of the receiver in the order in which they
 * were added.
 */
- (NSArray *)dependencies;

/** This method should return YES if the -cancel method has been called.<br />
 * NB. a cancelled operation may still be executing.
 */
- (BOOL) isCancelled;

/** This method returns YES if the receiver handles its own environment or
 * threading rather than expecting to run in an evironment set up elsewhere
 * (eg, by an [NSOperationQueue] instance).<br />
 * The default implementation returns NO.
 */
- (BOOL) isConcurrent;

/** This method should return YES if the receiver is currently executing its
 * -main method (even if -cancel has been called).
 */
- (BOOL) isExecuting;

/** This method should return YES if the receiver has finished executing its
 * -main method (irrespective of whether the execution completed due to
 * cancellation, failure, or success).
 */
- (BOOL) isFinished;

/** This method should return YES when the receiver is ready to begin
 * executing.  That is, the receiver must have no dependencies which
 * have not finished executing.<br />
 * Also returns YES if the operation has been cancelled (even if there
 * are unfinished dependencies).<br />
 * An executing or finished operation is also considered to be ready.
 */
- (BOOL) isReady;

/** <override-subclass/>
 * This is the method which actually performs the operation ...
 * the default implementation does nothing.<br />
 * You MUST ensure that your implemention of -main does not raise any
 * exception or call [NSThread-exit] as either of these will terminate
 * the operation prematurely resulting in the operation never reaching
 * the -isFinished state.<br />
 * If you are writing a concurrent subclass, you should override -start
 * instead of (or as well as) the -main method.
 */
- (void) main;

/** Returns the priority set using the -setQueuePriority method, or
 * NSOperationQueuePriorityNormal if no priority has been set.
 */
- (NSOperationQueuePriority) queuePriority;

/** Removes a dependency from the receiver.
 */
- (void) removeDependency: (NSOperation *)op;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Sets the block that will be executed when the operation has finished.
 */
- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock;
#endif

/** Sets the priority for the receiver.  If the value supplied is not one of
 * the predefined queue priorities, it is converted into the next available
 * defined value moving towards NSOperationQueuePriorityNormal.
 */
- (void) setQueuePriority: (NSOperationQueuePriority)priority;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/** Sets the thread priority to be used while executing then -main method.
 * The priority change is implemented in the -start method, so if you are
 * replacing -start you are responsible for managing this.<br />
 * The valid range is 0.0 to 1.0
 */
- (void) setThreadPriority: (double)prio;
#endif

/** This method is called to start execution of the receiver.<br />
 * <p>For concurrent operations, the subclass must override this method
 * to set up the environment for the operation to execute, must execute the
 * -main method, must ensure that -isExecuting and -isFinished return the
 * correct values, and must manually call key-value-observing methods to
 * notify observers of the state of those two properties.<br />
 * The subclass implementation must NOT call the superclass implementation.
 * </p>
 * <p>For non-concurrent operations, the default implementation of this method
 * performs all the work of setting up environment etc, and the subclass only
 * needs to override the -main method.
 * </p>
 */
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


/**
 * NSOperationQueue
 */

// Enumerated type for default operation count.
enum {
   NSOperationQueueDefaultMaxConcurrentOperationCount = -1
};

@interface NSOperationQueue : NSObject
{
NSRecursiveLock    *lock; \
NSConditionLock    *cond; \
NSMutableArray    *operations; \
NSMutableArray    *waiting; \
NSMutableArray    *starting; \
NSString        *name; \
BOOL            suspended; \
NSInteger        executing; \
NSInteger        threadCount; \
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
- (int) operationCount;
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