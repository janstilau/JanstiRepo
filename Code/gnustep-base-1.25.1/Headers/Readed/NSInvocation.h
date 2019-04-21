#ifndef __NSInvocation_h_GNUSTEP_BASE_INCLUDE
#define __NSInvocation_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSMethodSignature.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@interface NSInvocation : NSObject
{
#if	GS_EXPOSE(NSInvocation)
@public
  NSMethodSignature	*_sig; // 里面记录了返回值和各个参数的类型
  void                  *_cframe;
  void			*_retval;
  id			_target;
  SEL			_selector;
  unsigned int		_argsNum;
  void			*_info;
  BOOL			_argsRetained;
  BOOL                  _targetRetained; // 记录着需不需要进行 retain 操作. 如果需要, 那么在有关 target 的设置中, 要进行 retain 操作.
  BOOL			_validReturn;
  BOOL			_sendToSuper;
  void			*_retptr;
#endif
#if     GS_NONFRAGILE
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
@private id _internal GS_UNUSED_IVAR; // 发现好多类库里面, 都有这个东西, 作为内部的存储值; 猜测, OC 之前也是需要把成员变量放到头文件里面来的, 这样, 为了将真正的实现隐藏, 就用一个 void* 来指代真正的实现, 然后在实现文件里面, 在引入真正的头文件.
#endif
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
