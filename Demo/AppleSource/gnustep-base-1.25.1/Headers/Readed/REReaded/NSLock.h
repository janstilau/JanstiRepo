#ifndef __NSLock_h_GNUSTEP_BASE_INCLUDE
#define __NSLock_h_GNUSTEP_BASE_INCLUDE
#import  <GNUstepBase/GSVersionMacros.h>
#import  <GNUstepBase/GSConfig.h>

#import  <Foundation/NSObject.h>

/**
 * Protocol defining lock and unlock operations.
 */
@protocol NSLocking

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

@end

/**
 * <p>Simplest lock for protecting critical sections of code.
 * </p>
 * <p>An <code>NSLock</code> is used in multi-threaded applications to protect
 * critical pieces of code. While one thread holds a lock within a piece of
 * code, another thread cannot execute that code until the first thread has
 * given up its hold on the lock. The limitation of <code>NSLock</code> is
 * that you can only lock an <code>NSLock</code> once and it must be unlocked
 * before it can be acquired again.<br /> Other lock classes, notably
 * [NSRecursiveLock], have different restrictions.
 * </p>
 */
@interface NSLock : NSObject <NSLocking>
{
    gs_mutex_t	_mutex; // 功能的实现
    NSString	*_name; // 提示信息.
}

/** Report whether this lock is held by the current thread.<br />
 * Raises an exception if this is not supported by the system lock mechanism.
 */
- (BOOL) isLockedByCurrentThread;

/**
 *  Try to acquire lock and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit;

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Try to acquire lock and return immediately, YES if succeeded, NO if not.
 */
- (BOOL) tryLock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST) 
/** Return the name of the receiver or nil of none has been set.
 */
- (NSString*) name;

/** Sets the name of the receiver (for use in debugging).
 */
- (void) setName: (NSString*)name;
#endif

@end

/**
 * NSCondition provides an interface to POSIX condition variables.
 */
@interface NSCondition : NSObject <NSLocking>
{
#if	GS_EXPOSE(NSCondition)
@private
    /*
        先通过 mutext 得到锁, 然后 _condition 进行 wait 操作, 在这个 wait 的过程中, 会释放 mutext 的锁, 好让其他的线程获取锁.
        其他线程完成操作之后, 可以进行 singal, 或者 broadcast 唤醒 wait 的线程. 在被唤醒之后, 首先还是要通过 mutext 获得锁, 然后进行之后的操作.
     */
    gs_cond_t	_condition;
    gs_mutex_t	_mutex;
    NSString	*_name;
#endif
}
/**
 * Blocks and atomically unlocks the receiver.
 这里, 进行了一次 unlock 的操作.
 * This method should only be called when the receiver is locked. -- 必须在已经获取到 mutext 之后, 才能调用该方法.
 * The caller will then block until the receiver is sent either a -signal
 * or -broadcast message from another thread.  At which
 * point, the calling thread will reacquire the lock.
 */
- (void) wait;

/**
 * Blocks the calling thread and acquires the lock, in the same way as -wait.
 * Returns YES if the condition is signaled, or NO if the timeout is reached.
 */
- (BOOL) waitUntilDate: (NSDate*)limit;

/**
 * Wakes wany one of the threads that are waiting on this condition.
 */
- (void) signal;

/**
 * Wakes all threads that are waiting on this condition.
 */
- (void) broadcast;

/**
 * Sets the name used for debugging messages.
 */
- (void) setName: (NSString*)newName;

/**
 * Returns the name used for debugging messages.
 */
- (NSString*) name;
@end

/**
 *  Lock that allows user to request it only when an internal integer
 *  condition is equal to a particular value.  The condition is set on
 *  initialization and whenever the lock is relinquished.
 */
@interface NSConditionLock : NSObject <NSLocking>
{
#if	GS_EXPOSE(NSConditionLock)
@private
    NSCondition *_condition; // 其实就是对于 NSCondition 的封装.
    int   _condition_value;
    NSString      *_name;
#endif
}

/**
 * Initialize lock with given condition.
 */
- (id) initWithCondition: (NSInteger)value;

/**
 * Return the current condition of the lock.
 */
- (NSInteger) condition;

#if !NO_GNUSTEP
/** Report whether this lock is held by the current thread.<br />
 * Raises an exception if this is not supported by the system lock mechanism.
 */
- (BOOL) isLockedByCurrentThread;
#endif

/*
 * Acquiring and releasing the lock.
 */

/**
 *  Acquire lock when it is available and the internal condition is equal to
 *  value.  Blocks until this occurs.
 */
- (void) lockWhenCondition: (NSInteger)value;

/**
 *  Relinquish the lock, setting internal condition to value.
 */
- (void) unlockWithCondition: (NSInteger)value;

/**
 *  Try to acquire lock regardless of condition and return immediately, YES if
 *  succeeded, NO if not.
 */
- (BOOL) tryLock;

/**
 *  Try to acquire lock if condition is equal to value and return immediately
 *  in any case, YES if succeeded, NO if not.
 */
- (BOOL) tryLockWhenCondition: (NSInteger)value;

/*
 * Acquiring the lock with a date condition.
 */

/**
 *  Try to acquire lock and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit;

/**
 *  Try to acquire lock, when internal condition is equal to condition_to_meet,
 *  and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockWhenCondition: (NSInteger)condition_to_meet
                beforeDate: (NSDate*)limitDate;

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST) 
/** Return the name of the receiver or nil of none has been set.
 */
- (NSString*) name;

/** Sets the name of the receiver (for use in debugging).
 */
- (void) setName: (NSString*)name;
#endif

@end


/**
 * Allows the lock to be recursively acquired by the same thread.
 *
 * If the same thread locks the mutex (n) times then that same
 * thread must also unlock it (n) times before another thread
 * can acquire the lock.
 */
@interface NSRecursiveLock : NSObject <NSLocking>
{
#if	GS_EXPOSE(NSRecursiveLock)
@private
    gs_mutex_t	_mutex;
    NSString      *_name;
#endif
}

#if !NO_GNUSTEP
/** Report whether this lock is held by the current thread.<br />
 * Raises an exception if this is not supported by the system lock mechanism.
 */
- (BOOL) isLockedByCurrentThread;
#endif

/**
 *  Try to acquire lock regardless of condition and return immediately, YES if
 *  succeeded, NO if not.
 */
- (BOOL) tryLock;

/**
 *  Try to acquire lock and return before limit, YES if succeeded, NO if not.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit;

/**
 *  Block until acquiring lock.
 */
- (void) lock;

/**
 *  Relinquish lock.
 */
- (void) unlock;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST) 
/** Return the name of the receiver or nil of none has been set.
 */
- (NSString*) name;

/** Sets the name of the receiver (for use in debugging).
 */
- (void) setName: (NSString*)name;
#endif

@end

#if     !NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import <GNUstepBase/NSLock+GNUstepBase.h>
#endif

#endif /* __NSLock_h_GNUSTEP_BASE_INCLUDE */

