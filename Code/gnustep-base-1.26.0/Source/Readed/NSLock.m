#import "common.h"

#include <pthread.h>
#import "GSPrivate.h"
#include <math.h>

#define	EXPOSE_NSLock_IVARS	1
#define	EXPOSE_NSRecursiveLock_IVARS	1
#define	EXPOSE_NSCondition_IVARS	1
#define	EXPOSE_NSConditionLock_IVARS	1

#import "common.h"

#import "Foundation/NSLock.h"
#import "Foundation/NSException.h"
#import "Foundation/NSThread.h"

#import "GSPThread.h"

#define class_createInstance(C,E) NSAllocateObject(C,E,NSDefaultMallocZone())

static Class    baseConditionClass = Nil;
static Class    baseConditionLockClass = Nil;
static Class    baseLockClass = Nil;
static Class    baseRecursiveLockClass = Nil;

static Class    tracedConditionClass = Nil;
static Class    tracedConditionLockClass = Nil;
static Class    tracedLockClass = Nil;
static Class    tracedRecursiveLockClass = Nil;

static Class    untracedConditionClass = Nil;
static Class    untracedConditionLockClass = Nil;
static Class    untracedLockClass = Nil;
static Class    untracedRecursiveLockClass = Nil;

/*
 * Methods shared between NSLock, NSRecursiveLock, and NSCondition
 *
 * Note: These methods currently throw exceptions when locks are incorrectly
 * acquired.  This is compatible with earlier GNUstep behaviour.  In OS X 10.5
 * and later, these will just NSLog a warning instead.  Throwing an exception
 * is probably better behaviour, because it encourages developer to fix their
 * code.
 */

#define	MDEALLOC \
- (void) dealloc\
{\
[self finalize];\
[_name release];\
[super dealloc];\
}

#if     defined(HAVE_PTHREAD_MUTEX_OWNER)

#define	MDESCRIPTION \
- (NSString*) description\
{\
if (_mutex.__data.__owner)\
{\
if (_name == nil)\
{\
return [NSString stringWithFormat: @"%@ (locked by %llu)",\
[super description], (unsigned long long)_mutex.__data.__owner];\
}\
return [NSString stringWithFormat: @"%@ '%@' (locked by %llu)",\
[super description], _name, (unsigned long long)_mutex.__data.__owner];\
}\
else\
{\
if (_name == nil)\
{\
return [super description];\
}\
return [NSString stringWithFormat: @"%@ '%@'",\
[super description], _name];\
}\
}

#define	MISLOCKED \
- (BOOL) isLockedByCurrentThread\
{\
if (GSPrivateThreadID() == (NSUInteger)_mutex.__data.__owner)\
return YES;\
else\
return NO; \
}

#else

#define	MDESCRIPTION \
- (NSString*) description\
{\
if (_name == nil)\
{\
return [super description];\
}\
return [NSString stringWithFormat: @"%@ '%@'",\
[super description], _name];\
}

#define	MISLOCKED \
- (BOOL) isLockedByCurrentThread\
{\
[NSException raise: NSGenericException format: @"Not supported"];\
return NO;\
}

#endif

#define MFINALIZE \
- (void) finalize\
{\
pthread_mutex_destroy(&_mutex);\
}

#define	MLOCK \
- (void) lock\
{\
int err = pthread_mutex_lock(&_mutex);\
if (EDEADLK == err)\
{\
(*_NSLock_error_handler)(self, _cmd, YES, @"deadlock");\
}\
else if (err != 0)\
{\
[NSException raise: NSLockException format: @"failed to lock mutex"];\
}\
}

#define	MLOCKBEFOREDATE \
- (BOOL) lockBeforeDate: (NSDate*)limit\
{\
do\
{\
int err = pthread_mutex_trylock(&_mutex);\
if (0 == err)\
{\
CHK(Hold) \
return YES;\
}\
sched_yield();\
} while ([limit timeIntervalSinceNow] > 0);\
return NO;\
}

#define MNAME \
- (void) setName: (NSString*)newName\
{\
ASSIGNCOPY(_name, newName);\
}\
- (NSString*) name\
{\
return _name;\
}

#define MSTACK \
- (GSStackTrace*) stack \
{ \
return nil; \
}

#define	MTRYLOCK \
- (BOOL) tryLock\
{\
int err = pthread_mutex_trylock(&_mutex);\
if (0 == err) \
{ \
CHK(Hold) \
return YES; \
} \
else \
{ \
return NO;\
} \
}

#define	MUNLOCK \
- (void) unlock\
{\
if (0 != pthread_mutex_unlock(&_mutex))\
{\
[NSException raise: NSLockException\
format: @"failed to unlock mutex"];\
}\
CHK(Drop) \
}

static pthread_mutex_t deadlock;
static pthread_mutexattr_t attr_normal;
static pthread_mutexattr_t attr_reporting;
static pthread_mutexattr_t attr_recursive;

NSString *NSLockException = @"NSLockException";

@implementation NSLock

+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(self, 0);
}

+ (void) initialize
{
    static BOOL	beenHere = NO;
    /**
     * GNU cannot use dispatch_once ???
     */
    if (beenHere == NO)
    {
        beenHere = YES;
        
        /* Initialise attributes for the different types of mutex.
         * We do it once, since attributes can be shared between multiple
         * mutexes.
         * If we had a pthread_mutexattr_t instance for each mutex, we would
         * either have to store it as an ivar of our NSLock (or similar), or
         * we would potentially leak instances as we couldn't destroy them
         * when destroying the NSLock.  I don't know if any implementation
         * of pthreads actually allocates memory when you call the
         * pthread_mutexattr_init function, but they are allowed to do so
         * (and deallocate the memory in pthread_mutexattr_destroy).
         */
        /**
         *  Use the shared instance
         */
        pthread_mutexattr_init(&attr_normal);
        pthread_mutexattr_settype(&attr_normal, PTHREAD_MUTEX_NORMAL);
        pthread_mutexattr_init(&attr_reporting);
        pthread_mutexattr_settype(&attr_reporting, PTHREAD_MUTEX_ERRORCHECK);
        pthread_mutexattr_init(&attr_recursive);
        pthread_mutexattr_settype(&attr_recursive, PTHREAD_MUTEX_RECURSIVE);
        
        /* To emulate OSX behavior, we need to be able both to detect deadlocks
         * (so we can log them), and also hang the thread when one occurs.
         * the simple way to do that is to set up a locked mutex we can
         * force a deadlock on.
         */
        pthread_mutex_init(&deadlock, &attr_normal);
        pthread_mutex_lock(&deadlock);
        
        baseConditionClass = [NSCondition class];
        baseConditionLockClass = [NSConditionLock class];
        baseLockClass = [NSLock class];
        baseRecursiveLockClass = [NSRecursiveLock class];
    }
}

- (void) dealloc
{
    [self finalize];
    [_name release];
    [super dealloc];
}

- (NSString*) description
{
    if (_name == nil)
    {
        return [super description];
    }
    return [NSString stringWithFormat: @"%@ '%@'",
            [super description], _name];
}

- (void) finalize
{
    pthread_mutex_destroy(&_mutex);
}

/* Use an error-checking lock.  This is marginally slower, but lets us throw
 * exceptions when incorrect locking occurs.
 
 Just encapsulate the pthread_mutex
 */
- (id) init
{
    if (nil != (self = [super init]))
    {
        if (0 != pthread_mutex_init(&_mutex, &attr_reporting))
        {
            DESTROY(self);
        }
    }
    return self;
}

- (void) lock
{
    int err = pthread_mutex_lock(&_mutex);
    if (EDEADLK == err)
    {
        (*_NSLock_error_handler)(self, _cmd, YES, @"deadlock");
    }
    else if (err != 0)
    {
        [NSException raise: NSLockException format: @"failed to lock mutex"];
    }
}

/**
 * lockBeforeDate just a loop. Attemp to trylock every time. Failed yield thread.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit
{
    do
    {
        int err = pthread_mutex_trylock(&_mutex);
        if (0 == err)
        {
            return YES;
        }
        if (EDEADLK == err)
        {
            (*_NSLock_error_handler)(self, _cmd, NO, @"deadlock");
        }
        sched_yield();
    } while ([limit timeIntervalSinceNow] > 0);
    return NO;
}

- (BOOL) tryLock
{
    int err = pthread_mutex_trylock(&_mutex);
    if (0 == err)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void) unlock
{
if (0 != pthread_mutex_unlock(&_mutex))
{
}
}

@end

@implementation NSRecursiveLock

+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(self, 0);
}

+ (void) initialize
{
    [NSLock class];	// Ensure mutex attributes are set up.
}

// Just set recurive property. Other is same as NSLock
- (id) init
{
    if (nil != (self = [super init]))
    {
        if (0 != pthread_mutex_init(&_mutex, &attr_recursive))
        {
            DESTROY(self);
        }
    }
    return self;
}

//MDEALLOC
//MDESCRIPTION
//MFINALIZE
//MISLOCKED
//MLOCK
//MLOCKBEFOREDATE
//MNAME
//MSTACK
//MTRYLOCK
//MUNLOCK

@end

@implementation NSCondition

+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(self, 0);
}

+ (void) initialize
{
    [NSLock class];	// Ensure mutex attributes are set up.
}

- (void) broadcast
{
    pthread_cond_broadcast(&_condition);
}

- (void) finalize
{
    pthread_cond_destroy(&_condition);
    pthread_mutex_destroy(&_mutex);
}

- (id) init
{
    if (nil != (self = [super init]))
    {
        if (0 != pthread_cond_init(&_condition, NULL))
        {
            DESTROY(self);
        }
        else if (0 != pthread_mutex_init(&_mutex, &attr_reporting))
        {
            pthread_cond_destroy(&_condition);
            DESTROY(self);
        }
    }
    return self;
}

- (void) signal
{
    pthread_cond_signal(&_condition);
}

- (void) wait
{
    pthread_cond_wait(&_condition, &_mutex);
}

- (BOOL) waitUntilDate: (NSDate*)limit
{
    NSTimeInterval endTimeStamp = [limit timeIntervalSince1970];
    double secs, subsecs;
    struct timespec timeout;
    int retVal = 0;
    
    // Split the float into seconds and fractions of a second
    subsecs = modf(endTimeStamp, &secs);
    timeout.tv_sec = secs;
    // Convert fractions of a second to nanoseconds
    timeout.tv_nsec = subsecs * 1e9;
    
    /* NB. On timeout the lock is still held even through condition is not met
     */
    
    retVal = pthread_cond_timedwait(&_condition, &_mutex, &timeout);
    if (retVal == 0)
    {
        return YES;
    }
    if (retVal == ETIMEDOUT)
    {
        return NO;
    }
    if (retVal == EINVAL)
    {
        NSLog(@"Invalid arguments to pthread_cond_timedwait");
    }
    return NO;
}

//MDEALLOC
//MDESCRIPTION
//MISLOCKED
//MLOCK
//MLOCKBEFOREDATE
//MNAME
//MSTACK
//MTRYLOCK
//MUNLOCK

@end

@implementation NSConditionLock

+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(self, 0);
}

+ (void) initialize
{
    [NSLock class];	// Ensure mutex attributes are set up.
}

- (NSInteger) condition
{
    return _condition_value;
}

- (void) dealloc
{
    [_name release];
    [_condition release];
    [super dealloc];
}

- (id) init
{
    return [self initWithCondition: 0];
}

- (id) initWithCondition: (NSInteger)value
{
    if (nil != (self = [super init]))
    {
        if (nil == (_condition = [NSCondition new]))
        {
            DESTROY(self);
        }
        else
        {
            _condition_value = value;
            [_condition setName:
             [NSString stringWithFormat: @"condition-for-lock-%p", self]];
        }
    }
    return self;
}

- (void) lock
{
    [_condition lock];
}

- (BOOL) lockBeforeDate: (NSDate*)limit
{
    return [_condition lockBeforeDate: limit];
}

// Here. If value if not match cached condition, wait forever.
- (void) lockWhenCondition: (NSInteger)value
{
    [_condition lock];
    while (value != _condition_value)
    {
        [_condition wait];
    }
}

- (BOOL) lockWhenCondition: (NSInteger)condition_to_meet
                beforeDate: (NSDate*)limitDate
{
    if (NO == [_condition lockBeforeDate: limitDate])
    {
        return NO;        // Not locked
    }
    if (condition_to_meet == _condition_value)
    {
        return YES;       // Keeping the lock
    }
    while ([_condition waitUntilDate: limitDate])
    {
        if (condition_to_meet == _condition_value)
        {
            return YES;   // Keeping the lock
        }
    }
    [_condition unlock];
    return NO;            // Not locked
}

MNAME
MSTACK

- (BOOL) tryLock
{
    return [_condition tryLock];
}

- (BOOL) tryLockWhenCondition: (NSInteger)condition_to_meet
{
    if ([_condition tryLock])
    {
        if (condition_to_meet == _condition_value)
        {
            return YES;
        }
        else
        {
            [_condition unlock];
        }
    }
    return NO;
}

- (void) unlock
{
    [_condition unlock];
}

- (void) unlockWithCondition: (NSInteger)value
{
    _condition_value = value;
    [_condition broadcast];
    [_condition unlock];
}

@end