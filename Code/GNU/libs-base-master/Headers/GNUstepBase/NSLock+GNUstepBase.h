#ifndef	INCLUDED_NSLock_GNUstepBase_h
#define	INCLUDED_NSLock_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSLock.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

/**
 * Returns IDENT which will be initialized
 * to an instance of a CLASSNAME in a thread safe manner.  
 * If IDENT has been previously initialized 
 * this macro merely returns IDENT.
 * IDENT is considered uninitialized, if it contains nil.
 * CLASSNAME must be either NSLock, NSRecursiveLock or one
 * of their subclasses.
 * See [NSLock+newLockAt:] for details.
 * This macro is intended for code that cannot insure
 * that a lock can be initialized in thread safe manner otherwise.
 * <example>
 * NSLock *my_lock = nil;
 *
 * void function (void)
 * {
 *   [GS_INITIALIZED_LOCK(my_lock, NSLock) lock];
 *   do_work ();
 *   [my_lock unlock];
 * }
 *
 * </example>
 */
#define GS_INITIALIZED_LOCK(IDENT,CLASSNAME) \
           (IDENT != nil ? (id)IDENT : (id)[CLASSNAME newLockAt: &IDENT])

@interface NSLock (GNUstepBase)
/**
 * Initializes the id pointed to by location
 * with a new instance of the receiver's class
 * in a thread safe manner, unless
 * it has been previously initialized.
 * Returns the contents pointed to by location.  
 * The location is considered unintialized if it contains nil.
 * <br/>
 * This method is used in the GS_INITIALIZED_LOCK macro
 * to initialize lock variables when it cannot be insured
 * that they can be initialized in a thread safe environment.
 * <example>
 * NSLock *my_lock = nil;
 *
 * void function (void)
 * {
 *   [GS_INITIALIZED_LOCK(my_lock, NSLock) lock];
 *   do_work ();
 *   [my_lock unlock];
 * }
 * 
 * </example>
 */
+ (id) newLockAt: (id *)location;
@end

@interface NSRecursiveLock (GNUstepBase)
/**
 * Initializes the id pointed to by location
 * with a new instance of the receiver's class
 * in a thread safe manner, unless
 * it has been previously initialized.
 * Returns the contents pointed to by location.  
 * The location is considered unintialized if it contains nil.
 * <br/>
 * This method is used in the GS_INITIALIZED_LOCK macro
 * to initialize lock variables when it cannot be insured
 * that they can be initialized in a thread safe environment.
 * <example>
 * NSLock *my_lock = nil;
 *
 * void function (void)
 * {
 *   [GS_INITIALIZED_LOCK(my_lock, NSLock) lock];
 *   do_work ();
 *   [my_lock unlock];
 * }
 * 
 * </example>
 */
+ (id) newLockAt: (id *)location;
@end

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSLock_GNUstepBase_h */

