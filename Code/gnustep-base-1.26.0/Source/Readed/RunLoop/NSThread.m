#import "common.h"

#import "GSPThread.h"

// Dummy implementatation
// cleaner than IFDEF'ing the code everywhere
#if !(HAVE_PTHREAD_SPIN_LOCK)
#warning no spin_locks, using dummy versions
typedef int pthread_spinlock_t;
int pthread_spin_init(pthread_spinlock_t *lock, int pshared)
{
#if DEBUG
    fprintf(stderr,"NSThread.m: Warning this platform does not support spin locks - init.\n");
#endif
    return 0;
}
int pthread_spin_lock(pthread_spinlock_t *lock)
{
    return 0;
}
int pthread_spin_unlock(pthread_spinlock_t *lock)
{
    return 0;
}
int pthread_spin_destroy(pthread_spinlock_t *lock)
{
    return 0;
}
#endif

/** Structure for holding lock information for a thread.
 */
typedef struct {
    pthread_spinlock_t    spin;   /* protect access to struct members */
    NSHashTable           *held;  /* all locks/conditions held by thread */
    id                    wait;   /* the lock/condition we are waiting for */
} GSLockInfo;
#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSConnection.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSValue.h"

#import "GSPrivate.h"
#import "GSRunLoopCtxt.h"

#if defined(HAVE_PTHREAD_NP_H)
#  include <pthread_np.h>
#endif

#if defined(HAVE_GETTID)
#  include <unistd.h>
#  include <sys/syscall.h>
#  include <sys/types.h>
#endif

#define GSInternal      NSThreadInternal
#include        "GSInternal.h"
GS_PRIVATE_INTERNAL(NSThread)

#define pthreadID (internal->_pthreadID)
#define threadID (internal->_threadID)
#define lockInfo (internal->_lockInfo)


#if defined(HAVE_PTHREAD_MAIN_NP)
#  define IS_MAIN_PTHREAD (pthread_main_np() == 1)
#elif defined(HAVE_GETTID)
#  define IS_MAIN_PTHREAD (getpid() == (pid_t)syscall(SYS_gettid))
#else
#  define IS_MAIN_PTHREAD (1)
#endif

/* Return the current thread ID as an unsigned long.
 * Ideally, we use the operating-system's notion of a thread ID so
 * that external process monitoring software will be using the same
 * value that we log.  If we don't know the system's mechanism, we
 * use the address of the current NSThread object so that, even if
 * it makes no sense externally, it can still be used to show that
 * different threads generated different logs.
 */
NSUInteger
GSPrivateThreadID()
{
#if defined(_WIN32)
    return (NSUInteger)GetCurrentThreadId();
#elif defined(HAVE_GETTID)
    return (NSUInteger)syscall(SYS_gettid);
#elif defined(HAVE_PTHREAD_GETTHREADID_NP)
    return (NSUInteger)pthread_getthreadid_np();
#else
    return (NSUInteger)GSCurrentThread();
#endif
}

#if 0
/*
 * NSThread setName: method for windows.
 * FIXME ... This is code for the microsoft compiler;
 * how do we make it work for gcc/clang?
 */
#if defined(_WIN32) && defined(HAVE_WINDOWS_H)
// Usage: SetThreadName (-1, "MainThread");
#include <windows.h>
const DWORD MS_VC_EXCEPTION=0x406D1388;

#pragma pack(push,8)
typedef struct tagTHREADNAME_INFO
{
    DWORD dwType; // Must be 0x1000.
    LPCSTR szName; // Pointer to name (in user addr space).
    DWORD dwThreadID; // Thread ID (-1=caller thread).
    DWORD dwFlags; // Reserved for future use, must be zero.
} THREADNAME_INFO;
#pragma pack(pop)

static int SetThreadName(DWORD dwThreadID, const char *threadName)
{
    THREADNAME_INFO info;
    int result;
    
    info.dwType = 0x1000;
    info.szName = threadName;
    info.dwThreadID = dwThreadID;
    info.dwFlags = 0;
    
    __try
    {
        RaiseException(MS_VC_EXCEPTION, 0,
                       sizeof(info)/sizeof(ULONG_PTR), (ULONG_PTR*)&info);
        result = 0;
    }
    __except(EXCEPTION_EXECUTE_HANDLER)
    {
        result = -1;
    }
}

#define PTHREAD_SETNAME(a)  SetThreadName(-1, a)

#endif
#endif

#ifndef PTHREAD_SETNAME
#define PTHREAD_SETNAME(a) -1
#endif


// Some older BSD systems used a non-standard range of thread priorities.
// Use these if they exist, otherwise define standard ones.
#ifndef PTHREAD_MAX_PRIORITY
#define PTHREAD_MAX_PRIORITY 31
#endif
#ifndef PTHREAD_MIN_PRIORITY
#define PTHREAD_MIN_PRIORITY 0
#endif


@interface NSThread (Activation)
- (void) _makeThreadCurrent;
@end

@interface NSAutoreleasePool (NSThread)
+ (void) _endThread: (NSThread*)thread;
@end

static Class                    threadClass = Nil;
static NSNotificationCenter     *nc = nil;
static BOOL                     disableTraceLocks = NO;

/**
 * This class performs a dual function ...
 * <p>
 *   As a class, it is responsible for handling incoming events from
 *   the main runloop on a special inputFd.  This consumes any bytes
 *   written to wake the main runloop.<br />
 *   During initialisation, the default runloop is set up to watch
 *   for data arriving on inputFd.
 * </p>
 * <p>
 *   As instances, each  instance retains perform receiver and argument
 *   values as long as they are needed, and handles locking to support
 *   methods which want to block until an action has been performed.
 * </p>
 * <p>
 *   The initialize method of this class is called before any new threads
 *   run.
 * </p>
 */
@interface GSCrossTheadTaskHolder : NSObject
{
    id			receiver;
    id			argument;
    SEL			selector;
    NSConditionLock	*lock;		// Not retained. If waits flas is YES, this is used for thread sync.
    NSArray		*modes;
    BOOL                  invalidated;
@public
    NSException           *exception;
}
+ (GSCrossTheadTaskHolder*) newForReceiver: (id)r
                                  argument: (id)a
                                  selector: (SEL)s
                                     modes: (NSArray*)m
                                      lock: (NSConditionLock*)l;
- (void) firePerformHolder;
- (void) invalidatePerformHolder;
- (BOOL) isInvalidated;
- (NSArray*) modes;
@end

@implementation GSCrossTheadTaskHolder
+ (GSCrossTheadTaskHolder*) newForReceiver: (id)r
                                  argument: (id)a
                                  selector: (SEL)s
                                     modes: (NSArray*)m
                                      lock: (NSConditionLock*)l
{
    GSCrossTheadTaskHolder    *h;
    h = (GSCrossTheadTaskHolder*)NSAllocateObject(self, 0, NSDefaultMallocZone());
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

/**
 * All crossThread task, is just record and run the code in the later time. Just like commond mode.
 */
- (void) firePerformHolder
{
    if (receiver == nil)
    {
        return;    // Already fired!
    }
    GSRunLoopThreadRelatedInfo   *threadInfo = GSRunLoopInfoForThread(GSCurrentThread());
    [threadInfo->loop cancelPerformSelectorsWithTarget: self];
    NS_DURING
    {   // 真正执行的方法.
        [receiver performSelector: selector withObject: argument];
    }
    NS_HANDLER
    {
        ASSIGN(exception, localException);
        if (nil == lock)
        {
            NSLog(@"*** NSRunLoop ignoring exception '%@' (reason '%@') "
                  @"raised during perform in other thread... with receiver %p "
                  @"and selector '%s'",
                  [localException name], [localException reason], receiver,
                  sel_getName(selector));
        }
    }
    NS_ENDHANDLER
    DESTROY(receiver);
    DESTROY(argument);
    DESTROY(modes);
    if (lock != nil)
    {
        NSConditionLock    *l = lock;
        
        [lock lock];
        lock = nil;
        [l unlockWithCondition: 1];
    }
}

- (void) invalidatePerformHolder
{
    if (invalidated == NO)
    {
        invalidated = YES;
        DESTROY(receiver);
        if (lock != nil)
        {
            NSConditionLock    *l = lock;
            
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

/**
 * Sleep until the current date/time is the specified time interval
 * past the reference date/time.<br />
 * Implemented as a function taking an NSTimeInterval argument in order
 * to avoid objc messaging and object allocation/deallocation (NSDate)
 * overheads.<br />
 * Used to implement [NSThread+sleepUntilDate:]
 * If the date is in the past, this function simply allows other threads
 * (if any) to run.
 */
/**
 * In this method, with different scope remain time, Call different sleep method.
 */
void
GSSleepUntilIntervalSinceReferenceDate(NSTimeInterval endTime)
{
    NSTimeInterval delay;
    
    // delay is always the number of seconds we still need to wait
    delay = endTime - GSPrivateTimeNow();
    if (delay <= 0.0)
    {
        /* We don't need to wait, but since we are willing to wait at this
         * point, we should let other threads have preference over this one.
         */
        /**
         * At first, yield the thread to make other thread is able to run.
         Just one yield, so this thread will be in run immediately.
         */
        sched_yield();
        return;
    }
    /*
     * Avoid integer overflow by breaking up long sleeps.
     */
    while (delay > 30.0*60.0)
    {
        // sleep 30 minutes
        // call sleep, and update delay every time when wake up.
        sleep(30*60);
        delay = endTime - GSPrivateTimeNow();
    }
    
    if (delay > 0)
    {
        struct timespec request;
        struct timespec remainder;
        
        request.tv_sec = (time_t)delay;
        request.tv_nsec = (long)((delay - request.tv_sec) * 1000000000);
        remainder.tv_sec = 0;
        remainder.tv_nsec = 0;
        
        /*
         * With nanosleep, we can restart the sleep after a signal by using
         * the remainder information ... so we can be sure to sleep to the
         * desired limit without having to re-generate the delay needed.
         */
        while (nanosleep(&request, &remainder) < 0
               && (remainder.tv_sec > 0 || remainder.tv_nsec > 0))
        {
            request.tv_sec = remainder.tv_sec;
            request.tv_nsec = remainder.tv_nsec;
            remainder.tv_sec = 0;
            remainder.tv_nsec = 0;
        }
    }
    
    /*
     * sleeping may return early because of signals, so we need to re-calculate
     * the required delay and check to see if we need to sleep again.
     */
    while (delay > 0)
    {
#if	defined(HAVE_USLEEP)
        usleep((NSInteger)(delay*1000000));
#else	/* HAVE_USLEEP */
        sleep((NSInteger)delay);
#endif	/* !HAVE_USLEEP */
        delay = endTime - GSPrivateTimeNow();
    }
#endif	/* !HAVE_NANOSLEEP */
#endif	/* !_WIN32 */
}

static NSArray *
commonModes(void)
{
    NSArray	*modes = [[NSArray alloc] initWithObjects:
                      NSDefaultRunLoopMode, NSConnectionReplyMode, nil];
    return modes;
}

/*
 * Flag indicating whether the objc runtime ever went multi-threaded.
 */
static BOOL	entered_multi_threaded_state = NO;

static NSThread *defaultThread;

static BOOL             keyInitialized = NO;
static pthread_key_t    thread_object_key; // 线程私有存储空间--pthread_key_t

static NSHashTable *_activeBlocked = nil;
static NSHashTable *_activeThreads = nil;
static pthread_mutex_t _activeLock = PTHREAD_MUTEX_INITIALIZER;

/**
 * pthread_t is an opaque type. It might be a scalar type or
 * some kind of struct depending on the implementation, so we
 * need to wrap it up in an NSValue object if we want to pass
 * it around.
 * This follows the CoreFoundation 'create rule' and returns an object with
 * a reference count of 1.
 */
static inline NSValue* NSValueCreateFromPthread(pthread_t thread)
{
    return [[NSValue alloc] initWithBytes: &thread
                                 objCType: @encode(pthread_t)];
}

/**
 * Conversely, we need to be able to retrieve the pthread_t
 * from an NSValue.
 */
static inline void
_getPthreadFromNSValue(const void *value, pthread_t *thread_ptr)
{
    const char    *enc;
    
    NSCAssert(thread_ptr, @"No storage for thread reference");
# ifndef NS_BLOCK_ASSERTIONS
    enc = [(NSValue*)value objCType];
    NSCAssert(enc != NULL && (0 == strcmp(@encode(pthread_t),enc)),
              @"Invalid NSValue container for thread reference");
# endif
    [(NSValue*)value getValue: (void*)thread_ptr];
}

/**
 * This is the comparison function for boxed pthreads, as used by the
 * NSMapTable containing them.
 */
static BOOL
_boxedPthreadIsEqual(NSMapTable *t,
                     const void *boxed,
                     const void *boxedOther)
{
    pthread_t thread;
    pthread_t otherThread;
    
    _getPthreadFromNSValue(boxed, &thread);
    _getPthreadFromNSValue(boxedOther, &otherThread);
    return pthread_equal(thread, otherThread);
}

/**
 * Since pthread_t is opaque, we cannot make any assumption about how
 * to hash it. There are a few problems here:
 * 1. Functions to obtain the thread ID of an arbitrary thread
 *    exist in the in the Win32 and some pthread APIs (GetThreadId() and
 *    pthread_getunique_np(), respectively), but there is no protable solution
 *    for this problem.
 * 2. Even where pthread_getunique_np() is available, it might have different
 *    definitions, so it's not really robust to use it.
 *
 * For these reasons, we always return the same hash. That fulfills the API
 * contract for NSMapTable (key-hash equality as a necessary condition for key
 * equality), but makes things quite inefficient (linear search over all
 * elements), so we need to keep the table small.
 */
static NSUInteger _boxedPthreadHash(NSMapTable *t, const void *value)
{
    return 0;
}

/**
 * Retain callback for boxed thread references.
 */
static void _boxedPthreadRetain(NSMapTable *t, const void *value)
{
    RETAIN((NSValue*)value);
}

/**
 * Release callback for boxed thread references.
 */
static void _boxedPthreadRelease(NSMapTable *t, void *value)
{
    RELEASE((NSValue*)value);
}

/**
 * Description callback for boxed thread references.
 */
static NSString *_boxedPthreadDescribe(NSMapTable *t, const void *value)
{
    return [(NSValue*)value description];
}


static const NSMapTableKeyCallBacks _boxedPthreadKeyCallBacks =
{
    _boxedPthreadHash,
    _boxedPthreadIsEqual,
    _boxedPthreadRetain,
    _boxedPthreadRelease,
    _boxedPthreadDescribe,
    NULL
};


/**
 * This map table maintains a list of all threads currently undergoing
 * cleanup. This is a required so that +currentThread can still find the
 * thred if called from within the late-cleanup function.
 */
static NSMapTable *_exitingThreads = nil;
static pthread_mutex_t _exitingThreadsLock = PTHREAD_MUTEX_INITIALIZER;


/**
 * Called before late cleanup is run and inserts the NSThread object into the
 * table that is used by GSCurrentThread to find the thread if it is called
 * during cleanup. The boxedThread variable contains a boxed reference to
 * the result of calling pthread_self().
 */
static inline void _willLateUnregisterThread(NSValue *boxedThread,
                                             NSThread *specific)
{
    pthread_mutex_lock(&_exitingThreadsLock);
    /* The map table is created lazily/late so that the NSThread
     * +initialize method can be called without causing other
     * classes to be initialized.
     * NB this locked section cannot be protected by an exception handler
     * because the exception handler stores information in the current
     * thread variables ... which causes recursion.
     */
    if (nil == _exitingThreads)
    {
        _exitingThreads = NSCreateMapTable(_boxedPthreadKeyCallBacks,
                                           NSObjectMapValueCallBacks, 10);
    }
    NSMapInsert(_exitingThreads, (const void*)boxedThread,
                (const void*)specific);
    pthread_mutex_unlock(&_exitingThreadsLock);
}

/**
 * Called after late cleanup has run. Will remove the current thread from
 * the lookup table again. The boxedThread variable contains a boxed reference
 * to the result of calling pthread_self().
 */
static inline void _didLateUnregisterCurrentThread(NSValue *boxedThread)
{
    /* NB this locked section cannot be protected by an exception handler
     * because the exception handler stores information in the current
     * thread variables ... which causes recursion.
     */
    pthread_mutex_lock(&_exitingThreadsLock);
    if (nil != _exitingThreads)
    {
        NSMapRemove(_exitingThreads, (const void*)boxedThread);
    }
    pthread_mutex_unlock(&_exitingThreadsLock);
}

/*
 * Forward declaration of the thread unregistration function
 */
static void
unregisterActiveThread(NSThread *thread);

/**
 * Pthread cleanup call.
 *
 * We should normally not get here ... because threads should exit properly
 * and clean up, so that this function doesn't get called.  However if a
 * thread terminates for some reason without calling the exit method, we
 * we add it to a special lookup table that is used by GSCurrentThread() to
 * obtain the NSThread object.
 * We need to be a bit careful about this regarding object allocation because
 * we must not call into NSAutoreleasePool unless the NSThread object can still
 * be found using GSCurrentThread()
 */
static void exitedThread(void *thread)
{
    if (thread == defaultThread) { return; }
    
    NSValue           *ref;
    if (0 == thread)
    {
        thread = pthread_getspecific(thread_object_key);
        if (0 == thread)
        {
            return;    // no thread info
        }
    }
    RETAIN((NSThread*)thread);
    ref = NSValueCreateFromPthread(pthread_self());
    _willLateUnregisterThread(ref, (NSThread*)thread);
    
    {
        CREATE_AUTORELEASE_POOL(arp);
        NS_DURING
        {
            unregisterActiveThread((NSThread*)thread);
        }
        NS_HANDLER
        {
            DESTROY(arp);
            _didLateUnregisterCurrentThread(ref);
            DESTROY(ref);
            RELEASE((NSThread*)thread);
        }
        NS_ENDHANDLER
        DESTROY(arp);
    }
    
    /* At this point threre shouldn't be any autoreleased objects lingering
     * around anymore. So we may remove the thread from the lookup table.
     */
    _didLateUnregisterCurrentThread(ref);
    DESTROY(ref);
    RELEASE((NSThread*)thread);
}

/**
 * These functions needed because sending messages to classes is a seriously
 * slow process with gcc and the gnu runtime.
 
 NSThread is been set as a privete value in each thread.
 
 */
inline NSThread*
GSCurrentThread(void)
{
    NSThread *thr;
    
    if (NO == keyInitialized)
    {
        if (pthread_key_create(&thread_object_key, exitedThread))
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Unable to create thread key!"];
        }
        keyInitialized = YES;
    }
    thr = pthread_getspecific(thread_object_key); // Set NSThread as a thread private value.
    if (nil == thr)
    {
        NSValue *selfThread = NSValueCreateFromPthread(pthread_self());
        
        /* NB this locked section cannot be protected by an exception handler
         * because the exception handler stores information in the current
         * thread variables ... which causes recursion.
         */
        if (nil != _exitingThreads)
        {
            pthread_mutex_lock(&_exitingThreadsLock);
            thr = NSMapGet(_exitingThreads, (const void*)selfThread);
            pthread_mutex_unlock(&_exitingThreadsLock);
        }
        DESTROY(selfThread);
        if (nil == thr)
        {
            GSRegisterCurrentThread();
            thr = pthread_getspecific(thread_object_key);
            if ((nil == defaultThread) && IS_MAIN_PTHREAD)
            {
                defaultThread = RETAIN(thr);
            }
        }
        assert(nil != thr && "No main thread");
    }
    return thr;
}

NSMutableDictionary*
GSDictionaryForThread(NSThread *t)
{
    if (nil == t)
    {
        t = GSCurrentThread();
    }
    return [t threadDictionary];
}

/**
 * Fast access function for thread dictionary of current thread.
 */
NSMutableDictionary*
GSCurrentThreadDictionary(void)
{
    return GSDictionaryForThread(nil);
}

/*
 * Callback function to send notifications on becoming multi-threaded.
 */
static void
gnustep_base_thread_callback(void)
{
    // Code is deleted. The code will be called when app enter into multi thread. The code will be thread safe and post a notification to indicate app is already become multi-thread.
}

@implementation NSThread (Activation)

/**
 *
 Set the NSThread self to thread private value. And update _activeThreads.
 */
- (void) _makeThreadCurrent
{
    /* NB. We must set up the pointer to the new NSThread instance from
     * pthread specific memory before we do anything which might need to
     * check what the current thread is (like getting the ID)!
     */
    pthread_setspecific(thread_object_key, self);
    threadID = GSPrivateThreadID();
    pthread_mutex_lock(&_activeLock);
    /* The hash table is created lazily/late so that the NSThread
     * +initialize method can be called without causing other
     * classes to be initialized.
     * NB this locked section cannot be protected by an exception handler
     * because the exception handler stores information in the current
     * thread variables ... which causes recursion.
     */
    if (nil == _activeThreads)
    {
        _activeThreads = NSCreateHashTable(
                                           NSNonRetainedObjectHashCallBacks, 100);
    }
    NSHashInsert(_activeThreads, (const void*)self);
    pthread_mutex_unlock(&_activeLock);
}
@end

@implementation NSThread

static void
setThreadForCurrentThread(NSThread *t)
{
    [t _makeThreadCurrent];
}

/**
 * Make thread finished and not runable.
 */
static void
unregisterActiveThread(NSThread *thread)
{
    if (thread->_active == YES)
    {
        /*
         * Set the thread to be inactive to avoid any possibility of recursion.
         */
        thread->_active = NO;
        thread->_finished = YES;
        
        /*
         * Let observers know this thread is exiting.
         */
        if (nc == nil)
        {
            nc = RETAIN([NSNotificationCenter defaultCenter]);
        }
        [nc postNotificationName: NSThreadWillExitNotification
                          object: thread
                        userInfo: nil];
        
        [(GSRunLoopThreadInfo*)thread->_runLoopInfo invalidateThreadInfo];
        RELEASE(thread);
        pthread_setspecific(thread_object_key, nil);
    }
}

+ (NSArray*) callStackReturnAddresses
{
    // code deleted.
    return nil;
}

+ (BOOL) _createThreadForCurrentPthread
{
    NSThread	*thread = pthread_getspecific(thread_object_key);
    
    if (thread == nil)
    {
        thread = [self new];
        t->_active = YES;
        [thread _makeThreadCurrent];
        return YES;
    }
    return NO;
}

/**
 *
 NSThread class method will call this method every time to get current NSThread value. So calss method is like
 1. get current thread
 2. using the got value to do sth.
 */
+ (NSThread*) currentThread
{
    return GSCurrentThread();
}

+ (void) detachNewThreadSelector: (SEL)aSelector
                        toTarget: (id)aTarget
                      withObject: (id)anArgument
{
    NSThread	*thread;
    thread = [[NSThread alloc] initWithTarget: aTarget
                                     selector: aSelector
                                       object: anArgument];
    
    [thread start];
    RELEASE(thread);
}

+ (void) exit
{
    NSThread	*thread;
    
    t = GSCurrentThread();
    if (t->_active == YES)
    {
        unregisterActiveThread(thread);
        
        if (thread == defaultThread || defaultThread == nil)
        {
            // main thread exit as the process will be exit.
            exit(0);
        }
        else
        {
            pthread_exit(NULL);
        }
    }
}

/*
 * Class initialization
 */
+ (void) initialize
{
    if (self == [NSThread class])
    {
        if (NO == keyInitialized)
        {
            if (pthread_key_create(&thread_object_key, exitedThread))
            {
                [NSException raise: NSInternalInconsistencyException
                            format: @"Unable to create thread key!"];
            }
            keyInitialized = YES;
        }
        /* Ensure that the default thread exists.
         * It's safe to create a lock here (since [NSObject+initialize]
         * creates locks, and locks don't depend on any other class),
         * but we want to avoid initialising other classes while we are
         * initialising NSThread.
         */
        threadClass = self;
        GSCurrentThread();
    }
}

+ (BOOL) isMainThread
{
    
    // defaultThread is set in intilize which must be the main thread.
    return (GSCurrentThread() == defaultThread ? YES : NO);
}

+ (BOOL) isMultiThreaded
{
    return entered_multi_threaded_state;
}

+ (NSThread*) mainThread
{
    return defaultThread;
}

/**
 * Set the priority of the current thread.  This is a value in the
 * range 0.0 (lowest) to 1.0 (highest) which is mapped to the underlying
 * system priorities.
 */
+ (void) setThreadPriority: (double)pri
{
    int	policy;
    struct sched_param param;
    // Guard cluase.
    if (pri > 1) { pri = 1; }
    if (pri < 0) { pri = 0; }
    
    // Scale pri based on the range of the host system.
    pri *= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);
    pri += PTHREAD_MIN_PRIORITY;
    // using the pthread function.
    pthread_getschedparam(pthread_self(), &policy, &param);
    param.sched_priority = pri;
    pthread_setschedparam(pthread_self(), policy, &param);
}

+ (void) sleepForTimeInterval: (NSTimeInterval)ti
{
    GSSleepUntilIntervalSinceReferenceDate(GSPrivateTimeNow() + ti);
}
+ (void) sleepUntilDate: (NSDate*)date
{
    GSSleepUntilIntervalSinceReferenceDate([date timeIntervalSinceReferenceDate]);
}


/**
 * Return the priority of the current thread.
 
 Just using pthread funciton to get property.
 */
+ (double) threadPriority
{
    double pri = 0;
    int policy;
    struct sched_param param;
    pthread_getschedparam(pthread_self(), &policy, &param);
    pri = param.sched_priority;
    // Scale pri based on the range of the host system.
    pri -= PTHREAD_MIN_PRIORITY;
    pri /= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);
    return pri;
    
}

/**
 * Just a flag varible. In start, if cancel is Yes, return immediately.
 As for flag instance variable, there must be control logic somewhere else to use it, otherwise it's useless.
 */
- (void) cancel
{
    _cancelled = YES;
}

- (void) dealloc
{
    int   retries = 0;
    
    if (_active == YES)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Deallocating an active thread without [+exit]!"];
    }
    if (_autorelease_vars.pool_cache != 0)
    {
        [NSAutoreleasePool _endThread: self];
    }
    
    while ((_thread_dictionary != nil || _runLoopInfo != nil) && retries++ < 10)
    {
        /* Try again.
         */
        DESTROY(_runLoopInfo);
        DESTROY(_thread_dictionary);
        if (_autorelease_vars.pool_cache != 0)
        {
            [NSAutoreleasePool _endThread: self];
        }
    }
    
    if (_runLoopInfo != nil)
    {
        NSLog(@"Oops - leak - run loop is %@", _runLoopInfo);
        if (_autorelease_vars.pool_cache != 0)
        {
            [NSAutoreleasePool _endThread: self];
        }
    }
    if (_thread_dictionary != nil)
    {
        NSLog(@"Oops - leak - thread dictionary is %@", _thread_dictionary);
        if (_autorelease_vars.pool_cache != 0)
        {
            [NSAutoreleasePool _endThread: self];
        }
    }
    DESTROY(_gcontext);
    if (_activeThreads)
    {
        pthread_mutex_lock(&_activeLock);
        NSHashRemove(_activeThreads, self);
        pthread_mutex_unlock(&_activeLock);
    }
    if (GS_EXISTS_INTERNAL)
    {
        pthread_spin_lock(&lockInfo.spin);
        DESTROY(lockInfo.held);
        lockInfo.wait = nil;
        pthread_spin_unlock(&lockInfo.spin);
        pthread_spin_destroy(&lockInfo.spin);
        if (internal != nil)
        {
            GS_DESTROY_INTERNAL(NSThread);
        }
    }
    [super dealloc];
}

- (id) init
{
    GS_CREATE_INTERNAL(NSThread);
    pthread_spin_init(&lockInfo.spin, 0);
    lockInfo.held = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 10);
    init_autorelease_thread_vars(&_autorelease_vars);
    return self;
}

- (id) initWithTarget: (id)aTarget
             selector: (SEL)aSelector
               object: (id)anArgument
{
    if (nil != (self = [self init]))
    {
        _selector = aSelector;
        _target = RETAIN(aTarget);
        _arg = RETAIN(anArgument);
    }
    return self;
}

- (BOOL) isCancelled
{
    return _cancelled;
}

- (BOOL) isExecuting
{
    return _active;
}

- (BOOL) isFinished
{
    return _finished;
}

- (BOOL) isMainThread
{
    return (self == defaultThread ? YES : NO);
}

// main method just call _selector.
- (void) main
{
    if (_active == NO)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on inactive thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    
    [_target performSelector: _selector withObject: _arg];
}

- (NSString*) name
{
    return _name;
}

- (void) setName: (NSString*)aName
{
    ASSIGN(_name, aName);
}

- (void) setStackSize: (NSUInteger)stackSize
{
    _stackSize = stackSize;
}

- (NSUInteger) stackSize
{
    return _stackSize;
}

/**
 * Trampoline function called to launch the thread
 */
static void *
nsthreadLauncher(void *thread)
{
    NSThread *t = (NSThread*)thread;
    
    setThreadForCurrentThread(t);
    
    /*
     * Let observers know a new thread is starting.
     */
    if (nc == nil)
    {
        nc = RETAIN([NSNotificationCenter defaultCenter]);
    }
    [nc postNotificationName: NSThreadDidStartNotification
                      object: t
                    userInfo: nil];
    [t main]; // Here call t main method.
    
    [NSThread exit]; // and then call exit method.
    // Not reached
    return NULL;
}

/**
 * The pthread create is the real thead created which is interact with OS, NSThread is more like a adapter for pthread.
 */
- (void) start
{
    pthread_attr_t	attr;
    
    if (_active == YES) // alread start before.
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on active thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    if (_cancelled == YES) // alread cancelled before.
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on cancelled thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    if (_finished == YES) // alread finished before
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on finished thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    
    /* The thread must persist until it finishes executing.
     */
    RETAIN(self); // A retian without release. exitedThread() will relase this NSThread obj.  pthread_key_create will pass the private value to exitedThread. and the private value for a pthread is NSThread obj.
    
    /* Mark the thread as active while it's running.
     */
    _active = YES;
    
    errno = 0;
    pthread_attr_init(&attr);
    /* Create this thread detached, because we never use the return state from
     * threads.
     */
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    /* Set the stack size when the thread is created.  Unlike the old setrlimit
     * code, this actually works.
     */
    if (_stackSize > 0)
    {
        pthread_attr_setstacksize(&attr, _stackSize);
    }
    // Use nsthreadLauncher to start a thead. And pass NSThread to this funcion. In this function, will call [target startSelector];
    if (pthread_create(&pthreadID, &attr, nsthreadLauncher, self))
    {
    }
}

/**
 * Return the thread dictionary.  This dictionary can be used to store
 * arbitrary thread specific data.<br />
 * NB. This cannot be autoreleased, since we cannot be sure that the
 * autorelease pool for the thread will continue to exist for the entire
 * life of the thread!
 
 Now the operationQueue use this dictionary to save it with a coorsponding thread.
 
 */
- (NSMutableDictionary*) threadDictionary
{
    if (_thread_dictionary == nil)
    {
        _thread_dictionary = [NSMutableDictionary new];
    }
    return _thread_dictionary;
}

@end



@implementation NSThread (GSLockInfo)

static NSString *
lockInfoErr(NSString *str)
{
    if (disableTraceLocks)
    {
        return nil;
    }
    return str;
}

- (NSString *) mutexDrop: (id)mutex
{
    if (GS_EXISTS_INTERNAL)
    {
        GSLockInfo        *li = &lockInfo;
        int               err;
        
        if (YES == disableTraceLocks) return nil;
        err = pthread_spin_lock(&li->spin);
        if (EDEADLK == err) return lockInfoErr(@"thread spin lock deadlocked");
        if (EINVAL == err) return lockInfoErr(@"thread spin lock invalid");
        
        if (mutex == li->wait)
        {
            /* The mutex was being waited for ... simply remove it.
             */
            li->wait = nil;
        }
        else if (NSHashGet(li->held, (void*)mutex) == (void*)mutex)
        {
            GSStackTrace  *stck = [mutex stack];
            
            /* The mutex was being held ... if the recursion count was zero
             * we remove it (otherwise the count is decreased).
             */
            if (stck->recursion-- == 0)
            {
                NSHashRemove(li->held, (void*)mutex);
                // fprintf(stderr, "%lu: Drop %p (final) %lu\n", (unsigned long)_threadID, mutex, [li->held count]);
            }
            else
            {
                // fprintf(stderr, "%lu: Drop %p (%lu) %lu\n", (unsigned long)threadID, mutex, (unsigned long)stck->recursion, [li->held count]);
            }
        }
        else
        {
            // fprintf(stderr, "%lu: Drop %p (bad) %lu\n", (unsigned long)threadID, mutex, [li->held count]);
            pthread_spin_unlock(&li->spin);
            return lockInfoErr(
                               @"attempt to unlock mutex not locked by this thread");
        }
        pthread_spin_unlock(&li->spin);
        return nil;
    }
    return lockInfoErr(@"thread not active");
}

- (NSString *) mutexHold: (id)mutex
{
    if (GS_EXISTS_INTERNAL)
    {
        GSLockInfo        *li = &lockInfo;
        int               err;
        
        if (YES == disableTraceLocks) return nil;
        err = pthread_spin_lock(&li->spin);
        if (EDEADLK == err) return lockInfoErr(@"thread spin lock deadlocked");
        if (EINVAL == err) return lockInfoErr(@"thread spin lock invalid");
        if (nil == mutex)
        {
            mutex = li->wait;
            if (nil == mutex)
            {
                pthread_spin_unlock(&li->spin);
                return lockInfoErr(@"attempt to hold nil mutex");
            }
        }
        else if (nil != li->wait && mutex != li->wait)
        {
            pthread_spin_unlock(&li->spin);
            return lockInfoErr(@"attempt to hold mutex without waiting for it");
        }
        if (NSHashGet(li->held, (void*)mutex) == NULL)
        {
            [[mutex stack] trace];                // Get current strack trace
            NSHashInsert(li->held, (void*)mutex);
            // fprintf(stderr, "%lu: Hold %p (initial) %lu\n", (unsigned long)threadID, mutex, [li->held count]);
        }
        else
        {
            GSStackTrace  *stck = [mutex stack];
            
            stck->recursion++;
            // fprintf(stderr, "%lu: Hold %p (%lu) %lu\n", (unsigned long)threadID, mutex, (unsigned long)stck->recursion, [li->held count]);
        }
        li->wait = nil;
        pthread_spin_unlock(&li->spin);
        return nil;
    }
    return lockInfoErr(@"thread not active");
}

- (NSString *) mutexWait: (id)mutex
{
    if (GS_EXISTS_INTERNAL)
    {
        NSMutableArray    *dependencies;
        id                want;
        BOOL              done;
        GSLockInfo        *li = &lockInfo;
        BOOL              owned = NO;
        int               err;
        
        if (YES == disableTraceLocks) return nil;
        err = pthread_spin_lock(&li->spin);
        if (EDEADLK == err) return lockInfoErr(@"thread spin lock deadlocked");
        if (EINVAL == err) return lockInfoErr(@"thread spin lock invalid");
        if (nil != li->wait)
        {
            NSString      *msg = [NSString stringWithFormat:
                                  @ "trying to lock %@ when already trying to lock %@",
                                  mutex, li->wait];
            pthread_spin_unlock(&li->spin);
            return lockInfoErr(msg);
        }
        li->wait = mutex;
        if (nil != NSHashGet(li->held, (const void*)mutex))
        {
            owned = YES;
        }
        pthread_spin_unlock(&li->spin);
        // fprintf(stderr, "%lu: Wait %p\n", (unsigned long)_threadID, mutex);
        if (YES == owned && [mutex isKindOfClass: [NSRecursiveLock class]])
        {
            return nil;   // We can't deadlock on a recursive lock we own
        }
        
        /* While checking for deadlocks we don't want threads created/destroyed
         * So we hold the lock to prevent thread activity changes.
         * This also ensures that no more than one thread can be checking for
         * deadlocks at a time (no interference between checks).
         */
        pthread_mutex_lock(&_activeLock);
        
        /* As we isolate dependencies (a thread holding the lock another thread
         * is waiting for) we disable locking in each thread and record the
         * thread in a hash table.  Once we have determined all the dependencies
         * we can re-enable locking in each of the threads.
         */
        if (nil == _activeBlocked)
        {
            _activeBlocked = NSCreateHashTable(
                                               NSNonRetainedObjectHashCallBacks, 100);
        }
        
        dependencies = nil;
        want = mutex;
        done = NO;
        
        while (NO == done)
        {
            NSHashEnumerator	enumerator;
            NSThread              *found = nil;
            BOOL                  foundWasLocked = NO;
            NSThread              *th;
            
            /* Look for a thread which is holding the mutex we are currently
             * interested in.  We are only interested in thread which are
             * themselves waiting for a lock (if they aren't waiting then
             * they can't be part of a deadlock dependency list).
             */
            enumerator = NSEnumerateHashTable(_activeThreads);
            while ((th = NSNextHashEnumeratorItem(&enumerator)) != nil)
            {
                GSLockInfo        *info = &GSIVar(th, _lockInfo);
                
                if (YES == th->_active && nil != info->wait)
                {
                    BOOL          wasLocked;
                    GSStackTrace  *stck;
                    
                    if (th == self
                        || NULL != NSHashGet(_activeBlocked, (const void*)th))
                    {
                        /* Don't lock ... this is the current thread or is
                         * already in the set of blocked threads.
                         */
                        wasLocked = YES;
                    }
                    else
                    {
                        pthread_spin_lock(&info->spin);
                        wasLocked = NO;
                    }
                    if (nil != info->wait
                        && nil != (stck = NSHashGet(info->held, (const void*)want)))
                    {
                        /* This thread holds the lock we are interested in and
                         * is waiting for another lock.
                         * We therefore record the details in the dependency list
                         * and will go on to look for the thread this found one
                         * depends on.
                         */
                        found = th;
                        foundWasLocked = wasLocked;
                        want = info->wait;
                        if (nil == dependencies)
                        {
                            dependencies = [NSMutableArray new];
                        }
                        [dependencies addObject: found];  // thread
                        [dependencies addObject: want];   // mutex
                        /* NB. breaking out here holds the spin lock so that
                         * the lock state of each dependency thread is
                         * preserved (if we don't have a deadlock, we get a
                         * consistent snapshot of the threads and their locks).
                         * We therefore have to unlock the threads when done.
                         */
                        break;
                    }
                    /* This thread did not hold the lock we are interested in,
                     * so we can unlock it (if necessary) and check another.
                     */
                    if (NO == wasLocked)
                    {
                        pthread_spin_unlock(&info->spin);
                    }
                }
            }
            NSEndHashTableEnumeration(&enumerator);
            if (nil == found)
            {
                /* There is no thread blocked on the mutex we are checking,
                 * so we can't have a deadlock.
                 */
                DESTROY(dependencies);
                done = YES;
            }
            else if (foundWasLocked)
            {
                /* The found thread is the current one or in the blocked set
                 * so we have a deadlock.
                 */
                done = YES;
            }
            else
            {
                /* Record the found (and locked) thread and continue
                 * to find the next dependency.
                 */
                NSHashInsert(_activeBlocked, (const void*)found);
            }
        }
        
        /* Ensure any locked threads are unlocked again.
         */
        if (NSCountHashTable(_activeBlocked) > 0)
        {
            NSHashEnumerator	enumerator;
            NSThread              *th;
            
            enumerator = NSEnumerateHashTable(_activeThreads);
            while ((th = NSNextHashEnumeratorItem(&enumerator)) != nil)
            {
                GSLockInfo        *info = &GSIVar(th, _lockInfo);
                
                pthread_spin_unlock(&info->spin);
            }
            NSEndHashTableEnumeration(&enumerator);
            NSResetHashTable(_activeBlocked);
        }
        
        /* Finished check ... re-enable thread activity changes.
         */
        pthread_mutex_unlock(&_activeLock);
        
        
        if (nil != dependencies)
        {
            GSStackTrace          *stack;
            NSUInteger            count;
            NSUInteger            index = 0;
            NSMutableString       *m;
            
            disableTraceLocks = YES;
            m = [NSMutableString stringWithCapacity: 1000];
            stack = [GSStackTrace new];
            [stack trace];
            [m appendFormat: @"Deadlock on %@ at\n  %@\n",
             mutex, [stack symbols]];
            RELEASE(stack);
            count = [dependencies count];
            while (index < count)
            {
                NSArray           *symbols;
                NSThread          *thread;
                NSUInteger        frameCount;
                
                thread = [dependencies objectAtIndex: index++];
                mutex = [dependencies objectAtIndex: index++];
                symbols = [[mutex stack] symbols];
                frameCount = [symbols count];
                if (frameCount > 0)
                {
                    NSUInteger    i;
                    
                    [m appendFormat: @"  depends on %@\n  blocked by %@\n  at\n",
                     mutex, thread];
                    for (i = 0; i < frameCount; i++)
                    {
                        [m appendFormat: @"    %@\n", [symbols objectAtIndex: i]];
                    }
                }
                else
                {
                    [m appendFormat: @"  depends on %@\n  blocked by %@\n",
                     mutex, thread];
                }
            }
            DESTROY(dependencies);
            /* NB. Return m directly because we have turned off tracing to
             * avoid recursion, and don't want lockInfoErr() to stop the
             * error being ruturned.
             */
            return m;
        }
        return nil;
    }
    return lockInfoErr(@"thread not active");
}

@end



@implementation GSRunLoopThreadRelatedInfo

- (void) addPerformer: (id)performer
{
    BOOL  signalled = NO;
    
    [lock lock];
    NSTimeInterval        start = 0.0;
    
    /* The write could concievably fail if the pipe is full.
     * In that case we need to release the lock temporarily to allow the other
     * thread to consume data from the pipe.  It's possible that the thread
     * and its runloop might stop during that ... so we need to check that
     * outputFd is still valid.
     */
    while (outputFd >= 0
           && NO == (signalled = (write(outputFd, "0", 1) == 1) ? YES : NO))
    {
        NSTimeInterval    now = [NSDate timeIntervalSinceReferenceDate];
        
        if (0.0 == start)
        {
            start = now;
        }
        else if (now - start >= 1.0)
        {
            NSLog(@"Unable to signal %@ within a second; blocked?", self);
            break;
        }
        [lock unlock];
        [lock lock];
    }
    if (YES == signalled)
    {
        [performers addObject: performer];
    }
    [lock unlock];
    if (NO == signalled)
    {
        /* We failed to add the performer ... so we must invalidate it in
         * case there is code waiting for it to complete.
         */
        [performer invalidate];
    }
}


- (void) dealloc
{
    [self invalidateThreadInfo];
    DESTROY(lock);
    DESTROY(loop);
    [super dealloc];
}

- (id) init
{
    int	fd[2];
    if (pipe(fd) == 0)
    {
        int	e;
        
        inputFd = fd[0];
        outputFd = fd[1];
        if ((e = fcntl(inputFd, F_GETFL, 0)) >= 0)
        {
            e |= NBLK_OPT;
            if (fcntl(inputFd, F_SETFL, e) < 0)
            {
                [NSException raise: NSInternalInconsistencyException
                            format: @"Failed to set non block flag for perform in thread"];
            }
        }
        else
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Failed to get non block flag for perform in thread"];
        }
        if ((e = fcntl(outputFd, F_GETFL, 0)) >= 0)
        {
            e |= NBLK_OPT;
            if (fcntl(outputFd, F_SETFL, e) < 0)
            {
                [NSException raise: NSInternalInconsistencyException
                            format: @"Failed to set non block flag for perform in thread"];
            }
        }
        else
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Failed to get non block flag for perform in thread"];
        }
    }
    else
    {
        DESTROY(self);
        [NSException raise: NSInternalInconsistencyException
                    format: @"Failed to create pipe to handle perform in thread"];
    }
    lock = [NSLock new];
    performers = [NSMutableArray new];
    return self;
}

- (void) invalidateThreadInfo
{
    NSArray       *p;
    
    [lock lock];
    p = AUTORELEASE(performers);
    performers = nil;
#ifdef _WIN32
    if (event != INVALID_HANDLE_VALUE)
    {
        CloseHandle(event);
        event = INVALID_HANDLE_VALUE;
    }
#else
    if (inputFd >= 0)
    {
        close(inputFd);
        inputFd = -1;
    }
    if (outputFd >= 0)
    {
        close(outputFd);
        outputFd = -1;
    }
#endif
    [lock unlock];
    [p makeObjectsPerformSelector: @selector(invalidatePerformHolder)];
}

- (void) fireThreadInfo
{
    NSArray	*toDo;
    unsigned int	i;
    unsigned int	c;
    
    [lock lock];
    if (inputFd >= 0)
    {
        char	buf[BUFSIZ];
        
        /* We don't care how much we read.  If there have been multiple
         * performers queued then there will be multiple bytes available,
         * but we always handle all available performers, so we can also
         * read all available bytes.
         * The descriptor is non-blocking ... so it's safe to ask for more
         * bytes than are available.
         */
        while (read(inputFd, buf, sizeof(buf)) > 0)
            ;
    }
    
    c = [performers count];
    if (0 == c)
    {
        /* We deal with all available performers each time we fire, so
         * it's likely that we will fire when we have no performers left.
         * In that case we can skip the copying and emptying of the array.
         */
        [lock unlock];
        return;
    }
    toDo = [NSArray arrayWithArray: performers];
    [performers removeAllObjects];
    [lock unlock];
    
    for (i = 0; i < c; i++)
    {
        GSCrossTheadTaskHolder	*h = [toDo objectAtIndex: i];
        [loop performSelector: @selector(firePerformHolder)
                       target: h
                     argument: nil
                        order: 0
                        modes: [h modes]];
    }
}
@end


/**
 * Just a get method, get the info related with a thread.
 Delete the thread safe code.
 */
GSRunLoopThreadRelatedInfo *
GSRunLoopInfoForThread(NSThread *aThread)
{
    GSRunLoopThreadRelatedInfo   *info;
    
    if (aThread == nil)
    {
        aThread = GSCurrentThread();
    }
    if (aThread->_runLoopInfo == nil)
    {
        aThread->_runLoopInfo = [GSRunLoopThreadInfo new];
    }
    info = aThread->_runLoopInfo;
    return info;
}

@implementation	NSObject (NSThreadPerformAdditions)

- (void) performSelectorOnMainThread: (SEL)aSelector
                          withObject: (id)anObject
                       waitUntilDone: (BOOL)aFlag
                               modes: (NSArray*)anArray
{
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


/**
 * All the perform selector will be here. Make a object container in GSRunLoopThreadInfo. And runlopp will run the selector in the current time.
 */
- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)aFlag
                   modes: (NSArray*)anArray
{
    GSRunLoopThreadRelatedInfo   *info;
    NSThread	        *currentThread;
    if ([anArray count] == 0)
    {
        return;
    }
    currentThread = GSCurrentThread();
    if (aThread == nil)
    {
        aThread = currentThread;
    }
    info = GSRunLoopInfoForThread(aThread);
    if (currentThread == aThread)
    {
        /* Perform in current thread.
         */
        if (aFlag == YES || info->loop == nil)
        {
            /* Wait until done or no run loop.
             */
            [self performSelector: aSelector withObject: anObject];
        }
        else
        {
            /* Don't wait ... schedule operation in run loop.
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
        GSCrossTheadTaskHolder   *hoderPerfomer;
        NSConditionLock	*conditionLock = nil;
        
        if ([aThread isFinished] == YES)
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"perform [%@-%@] attempted on finished thread (%@)",
             NSStringFromClass([self class]),
             NSStringFromSelector(aSelector),
             aThread];
        }
        if (aFlag == YES)
        {
            conditionLock = [[NSConditionLock alloc] init];
        }
        
        hoderPerfomer = [GSCrossTheadTaskHolder newForReceiver: self
                                          argument: anObject
                                          selector: aSelector
                                             modes: anArray
                                              lock: conditionLock];
        [info addPerformer: hoderPerfomer];
        if (conditionLock != nil)
        {
            [conditionLock lockWhenCondition: 1]; // Here, thead will be block until the condition unlock it in GSCrossTheadTaskHolder invkoe related tash.
            [conditionLock unlock];
            RELEASE(conditionLock);
            if ([hoderPerfomer isInvalidated] == NO)
            {
                /* If we have an exception passed back from the remote thread,
                 * re-raise it.
                 */
                if (nil != hoderPerfomer->exception)
                {
                    NSException       *e = AUTORELEASE(RETAIN(hoderPerfomer->exception));
                    
                    RELEASE(hoderPerfomer);
                    [e raise];
                }
            }
        }
        RELEASE(hoderPerfomer);
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

/**
 * <p>
 *   This function is provided to let threads started by some other
 *   software library register themselves to be used with the
 *   GNUstep system.  All such threads should call this function
 *   before attempting to use any GNUstep objects.
 * </p>
 * <p>
 *   Returns <code>YES</code> if the thread can be registered,
 *   <code>NO</code> if it is already registered.
 * </p>
 * <p>
 *   Sends out a <code>NSWillBecomeMultiThreadedNotification</code>
 *   if the process was not already multithreaded.
 * </p>
 */
BOOL
GSRegisterCurrentThread(void)
{
    return [NSThread _createThreadForCurrentPthread];
}

/**
 * <p>
 *   This function is provided to let threads started by some other
 *   software library unregister themselves from the GNUstep threading
 *   system.
 * </p>
 * <p>
 *   Calling this function causes a
 *   <code>NSThreadWillExitNotification</code>
 *   to be sent out, and destroys the GNUstep NSThread object
 *   associated with the thread (like [NSThread+exit]) but does
 *   not exit the underlying thread.
 * </p>
 */
void
GSUnregisterCurrentThread(void)
{
    unregisterActiveThread(GSCurrentThread());
}
