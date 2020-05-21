#ifndef __NSInvocation_h_GNUSTEP_BASE_INCLUDE
#define __NSInvocation_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSMethodSignature.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@interface NSInvocation : NSObject
{
@public
    NSMethodSignature	*_sig;
    void                  *_cframe;
    void			*_retval;
    id			_target;
    SEL			_selector;
    unsigned int		_numArgs;
    void			*_info;
    BOOL			_argsRetained;
    BOOL                  _targetRetained;
    BOOL			_validReturn;
    BOOL			_sendToSuper;
    void			*_retptr;
}

/*
 *	Creating instances.
 */
+ (NSInvocation*) invocationWithMethodSignature: (NSMethodSignature*)_signature;

/*
 *	Accessing message elements.
 */
- (void) getArgument: (void*)buffer
             atIndex: (NSInteger)index;
- (void) getReturnValue: (void*)buffer;
- (SEL) selector;
- (void) setArgument: (void*)buffer
             atIndex: (NSInteger)index;
- (void) setReturnValue: (void*)buffer;
- (void) setSelector: (SEL)aSelector;
- (void) setTarget: (id)anObject;
- (id) target;

/*
 *	Managing arguments.
 */
- (BOOL) argumentsRetained;
- (void) retainArguments;

#if OS_API_VERSION(GS_API_NONE,GS_API_NONE) && GS_API_VERSION( 11101,GS_API_LATEST)
- (BOOL) targetRetained;
- (void) retainArgumentsIncludingTarget: (BOOL)retainTargetFlag;
#endif

/*
 *	Dispatching an Invocation.
 */
- (void) invoke;
- (void) invokeWithTarget: (id)anObject;

/*
 *	Getting the method signature.
 */
- (NSMethodSignature*) methodSignature;

@end

#if GS_API_VERSION(GS_API_NONE, 011700)
@interface NSInvocation (GNUstep)
/**
 * Returns the status of the flag set by -setSendsToSuper:
 */
- (BOOL) sendsToSuper;
/**
 * Sets the flag to tell the invocation that it should actually invoke a
 * method in the superclass of the target rather than the method of the
 * target itself.<br />
 * This extension permits an invocation to act like a regular method
 * call sent to <em>super</em> in the method of a class.
 */
- (void) setSendsToSuper: (BOOL)flag;
@end
#endif

/** For use by macros only.
 */
@interface NSInvocation (MacroSetup)
- (id) initWithMethodSignature: (NSMethodSignature*)aSignature;
+ (id) _newProxyForInvocation: (id)target;
+ (id) _newProxyForMessage: (id)target;
+ (NSInvocation*) _returnInvocationAndDestroyProxy: (id)proxy;
@end
/**
 *  Creates and returns an autoreleased invocation containing a
 *  message to an instance of the class.  The 'message' consists
 *  of selector and arguments like a standard ObjectiveC method
 *  call.<br />
 *  Before using the returned invocation, you need to set its target.
 */
#define NS_INVOCATION(aClass, message...) ({\
id __proxy = [NSInvocation _newProxyForInvocation: aClass]; \
[__proxy message]; \
[NSInvocation _returnInvocationAndDestroyProxy: __proxy]; \
})

/**
 *  Creates and returns an autoreleased invocation containing a
 *  message to the target object.  The 'message' consists
 *  of selector and arguments like a standard ObjectiveC method
 *  call.
 */
#define NS_MESSAGE(target, message...) ({\
id __proxy = [NSInvocation _newProxyForMessage: target]; \
[__proxy message]; \
[NSInvocation _returnInvocationAndDestroyProxy: __proxy]; \
})

#if	defined(__cplusplus)
}
#endif

#endif /* __NSInvocation_h_GNUSTEP_BASE_INCLUDE */
