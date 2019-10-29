#ifndef __NSProtocolChecker_h_GNUSTEP_BASE_INCLUDE
#define __NSProtocolChecker_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSProxy.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class Protocol;

@interface NSProtocolChecker : NSProxy
{
#if	GS_EXPOSE(NSProtocolChecker)
@private
  Protocol *_myProtocol;
  NSObject *_myTarget;
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

// Creating a checker

+ (id) protocolCheckerWithTarget: (NSObject*)anObject
			protocol: (Protocol*)aProtocol;

- (id) initWithTarget: (NSObject*)anObject
	     protocol: (Protocol*)aProtocol;

// Reimplemented NSObject methods
 
- (void) forwardInvocation: (NSInvocation*)anInvocation;
   
// Getting information
- (Protocol*) protocol;
- (NSObject*) target;

@end

#if	defined(__cplusplus)
}
#endif

#endif
