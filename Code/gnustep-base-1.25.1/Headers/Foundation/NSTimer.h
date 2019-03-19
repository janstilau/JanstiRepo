#ifndef __NSTimer_h_GNUSTEP_BASE_INCLUDE
#define __NSTimer_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSDate.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/*
 *	NB. NSRunLoop is optimised using a hack that knows about the
 *	class layout for the fire date and invialidation flag in NSTimer.
 *	These MUST remain the first two items in the class.
 *	Other classes must not attempt to use instance variables as
 *	they are subject to change.
 */
@interface NSTimer : NSObject
{
#if	GS_EXPOSE(NSTimer)
@public
  NSDate 	*_date;		/* Must be first - for NSRunLoop optimisation */
  BOOL		_invalidated;	/* Must be 2nd - for NSRunLoop optimisation */
  BOOL		_repeats;
  NSTimeInterval _interval;
  id		_target;
  SEL		_selector;
  id		_info;
#endif
#if     GS_NONFRAGILE
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}

/* Creating timer objects. */

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				 invocation: (NSInvocation*)invocation
				    repeats: (BOOL)f;
+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				     target: (id)object
				   selector: (SEL)selector
				   userInfo: (id)info
				    repeats: (BOOL)f;

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
		        invocation: (NSInvocation*)invocation
			   repeats: (BOOL)f;
+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
			    target: (id)object
			  selector: (SEL)selector
			  userInfo: (id)info
			   repeats: (BOOL)f;

- (void) fire;
- (NSDate*) fireDate;
- (void) invalidate;
- (id) userInfo;

#if	OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL) isValid;
- (NSTimeInterval) timeInterval;
#endif

#if	OS_API_VERSION(MAC_OS_X_VERSION_10_2, GS_API_LATEST)
- (id) initWithFireDate: (NSDate*)fd
	       interval: (NSTimeInterval)ti
		 target: (id)object
	       selector: (SEL)selector
	       userInfo: (id)info
		repeats: (BOOL)f;
- (void) setFireDate: (NSDate*)fireDate;
#endif

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* __NSTimer_h_GNUSTEP_BASE_INCLUDE */
