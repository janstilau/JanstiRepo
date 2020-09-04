#ifndef __OBJC_SNYC_H_
#define __OBJC_SNYC_H_

#include <objc/objc.h>
/*
 @synchronized 这个的具体的实现
 */
/** 
 * Begin synchronizing on 'obj'.  
 * Allocates recursive pthread_mutex associated with 'obj' if needed.
 * 
 * @param obj The object to begin synchronizing on.
 * 
 * @return OBJC_SYNC_SUCCESS once lock is acquired.  
 */
OBJC_EXPORT int
objc_sync_enter(id _Nonnull obj)
    OBJC_AVAILABLE(10.3, 2.0, 9.0, 1.0, 2.0);

/** 
 * End synchronizing on 'obj'. 
 * 
 * @param obj The object to end synchronizing on.
 * 
 * @return OBJC_SYNC_SUCCESS or OBJC_SYNC_NOT_OWNING_THREAD_ERROR
 */
OBJC_EXPORT int
objc_sync_exit(id _Nonnull obj)
    OBJC_AVAILABLE(10.3, 2.0, 9.0, 1.0, 2.0);

enum {
    OBJC_SYNC_SUCCESS                 = 0,
    OBJC_SYNC_NOT_OWNING_THREAD_ERROR = -1
};


#endif // __OBJC_SYNC_H_
