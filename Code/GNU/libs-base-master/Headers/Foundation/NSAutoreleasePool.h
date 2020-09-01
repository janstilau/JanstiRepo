
#ifndef __NSAutoreleasePool_h_GNUSTEP_BASE_INCLUDE
#define __NSAutoreleasePool_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

@class NSAutoreleasePool;
@class NSThread;


/*
 typedef struct autorelease_thread_vars 这个值, 每个线程都有一份.
 */
typedef struct autorelease_thread_vars
{
    /*
     [NSAutoreleasePool +addObject:] 调用的时候, 会从当前线程的 current_pool 寻找到栈顶的 pool 对象, 将 obj 加到这个 pool 里面.
     */
    __unsafe_unretained NSAutoreleasePool *current_pool;
    
    /*
     当前线程的, 所有 autorelease 的对象的个数.
     */
    unsigned total_objects_count;
    
    /*
     NSAutoreleasePool 对象的缓存系统, 是一个数组.
     */
    __unsafe_unretained id *pool_cache;
    int pool_cache_size; // 数组的 capacity
    int pool_cache_count; // 数组的 length
} thread_vars_struct;

/* Initialize an autorelease_thread_vars structure for a new thread.
 This function is called in NSThread each time an NSThread is created.
 TV should be of type `struct autorelease_thread_vars *' */
#define init_autorelease_thread_vars(TV) \
memset (TV, 0, sizeof (__typeof__ (*TV)))



/**
 *  Each pool holds its objects-to-be-released in a linked-list of
 these structures.
 <example>
 {
 struct autorelease_array_list *next;
 unsigned size;
 unsigned count;
 id objects[0];
 }
 </example>
 */
typedef struct autorelease_array_list
{
    struct autorelease_array_list *next;
    unsigned size;
    unsigned count;
    __unsafe_unretained id objects[0];
} array_list_struct;



NS_AUTOMATED_REFCOUNT_UNAVAILABLE
@interface NSAutoreleasePool : NSObject 
{
    /* For re-setting the current pool when we are dealloc'ed. */
    NSAutoreleasePool *_parent;
    /* This pointer to our child pool is  necessary for co-existing
     with exceptions. */
    NSAutoreleasePool *_child;
    /* A collection of the objects to be released. */
    struct autorelease_array_list *_released;
    struct autorelease_array_list *_released_head;
    /* The total number of objects autoreleased in this pool. */
    unsigned _released_count;
    /* The method to add an object to this pool */
    void 	(*_addImp)(id, SEL, id);
}

/**
 * Adds anObj to the current autorelease pool.<br />
 * If there is no autorelease pool in the thread,
 * a warning is logged and the object is leaked (ie it will not be released).
 */
+ (void) addObject: (id)anObj;

/**
 * Allocate and return an autorelease pool instance.<br />
 * If there is an already-allocated NSAutoreleasePool available,
 * save time by just returning that, rather than allocating a new one.<br />
 * The pool instance becomes the current autorelease pool for this thread.
 */
+ (id) allocWithZone: (NSZone*)zone;

/**
 * Adds anObj to this autorelease pool.
 */
- (void) addObject: (id)anObj;

/**
 * Raises an exception - pools should not be autoreleased.
 */
- (id) autorelease;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)
/**
 * Intended to trigger a garbage collection run (if needed) when called in
 * a garbage collected environment.<br />
 * In a non-garbage collected environment, this method implements the
 * undocumented MacOS-X behavior, and releases the receiver.
 */
- (void) drain;
#endif

/**
 * Destroys the receiver (calls -dealloc).
 */
- (oneway void) release;

/**
 * Raises an exception ... pools should not be retained.
 */
- (id) retain;

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
/**
 * <p>
 *   Counts the number of times that the specified object occurs
 *   in autorelease pools in the current thread.
 * </p>
 * <p>
 *   This method is <em>slow</em> and should probably only be
 *   used for debugging purposes.
 * </p>
 */
+ (unsigned) autoreleaseCountForObject: (id)anObject;

/** 
 * Return the currently active autorelease pool.
 */
+ (id) currentPool;

/**
 * <p>
 *   Specifies whether objects contained in autorelease pools are to
 *   be released when the pools are deallocated (by default YES).
 * </p>
 * <p>
 *   You can set this to NO for debugging purposes.
 * </p>
 */
+ (void) enableRelease: (BOOL)enable;

/**
 * <p>
 *   When autorelease pools are deallocated, the memory they used
 *   is retained in a cache for re-use so that new polls can be
 *   created very quickly.
 * </p>
 * <p>
 *   This method may be used to empty that cache, ensuring that
 *   the minimum memory is used by the application.
 * </p>
 */
+ (void) freeCache;

/**
 * <p>
 *   Specifies a limit to the number of objects that may be added to
 *   an autorelease pool.  When this limit is reached an exception is
 *   raised.
 * </p>
 * <p>
 *   You can set this to a smallish value to catch problems with code
 *   that autoreleases too many objects to operate efficiently.
 * </p>
 * <p>
 *   Default value is maxint.
 * </p>
 */
+ (void) setPoolCountThreshold: (unsigned)c;

/**
 * Return the number of objects in this pool.
 */
- (unsigned) autoreleaseCount;

/**
 * Empties the current pool by releasing all the autoreleased objects
 * in it.  Also destroys any child pools (ones created after
 * the receiver in the same thread) causing any objects in those pools
 * to be released.<br />
 * This is a low cost (efficient) method which may be used to get rid of
 * autoreleased objects in the pool, but carry on using the pool.
 */
- (void) emptyPool;
#endif
@end

#endif /* __NSAutoreleasePool_h_GNUSTEP_BASE_INCLUDE */
