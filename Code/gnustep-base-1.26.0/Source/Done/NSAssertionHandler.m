#import "common.h"
#import "Foundation/NSException.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSThread.h"

@implementation NSAssertionHandler

/* Key for thread dictionary. */
NSString *const NSAssertionHandlerKey = @"NSAssertionHandler";

// 这个类的唯一的作用, 就是将 NSAssert 宏触发的信息, 包装成为一个 异常 对象, 然后抛出. 用异常捕获进行
/**
 * Returns the assertion handler object for the current thread.<br />
 * If none exists, creates one and returns it.
 * // 懒加载
 */
+ (NSAssertionHandler*) currentHandler
{
  NSMutableDictionary	*dict;
  NSAssertionHandler	*handler;

  dict = GSCurrentThreadDictionary();
  handler = [dict objectForKey: NSAssertionHandlerKey];
  if (handler == nil)
    {
      handler = [[NSAssertionHandler alloc] init];
      [dict setObject: handler forKey: NSAssertionHandlerKey];
      RELEASE(handler);
    }
  return handler;
}

/**
 * Handles an assertion failure by using NSLogv() to print an error
 * message built from the supplied arguments, and then raising an
 * NSInternalInconsistencyException
 */
- (void) handleFailureInFunction: (NSString*)functionName
			    file: (NSString*)fileName
		      lineNumber: (NSInteger)line
		     description: (NSString*)format,...
{
  id		message;
  va_list	ap;

  va_start(ap, format);
  message =
    [NSString
      stringWithFormat: @"%@:%"PRIdPTR"  Assertion failed in %@.  %@",
      fileName, line, functionName, format];
  NSLogv(message, ap);

  [NSException raise: NSInternalInconsistencyException
	      format: message arguments: ap];
  va_end(ap);
  GS_UNREACHABLE();
  /* NOT REACHED */
}

/**
 * Handles an assertion failure by using NSLogv() to print an error
 * message built from the supplied arguments, and then raising an
 * NSInternalInconsistencyException
 */
- (void) handleFailureInMethod: (SEL) aSelector
                        object: object
                          file: (NSString *) fileName
                    lineNumber: (NSInteger) line
                   description: (NSString *) format,...
{
  id		message;
  va_list	ap;

  va_start(ap, format);
  message =
    [NSString stringWithFormat:
      @"%@:%"PRIdPTR"  Assertion failed in %@(%@), method %@.  %@",
      fileName, line, NSStringFromClass([object class]),
      class_isMetaClass([object class]) ? @"class" : @"instance",
      NSStringFromSelector(aSelector), format];
  NSLogv(message, ap);

  [NSException raise: NSInternalInconsistencyException
	      format: message arguments: ap];
  va_end(ap);
  /* NOT REACHED */
  GS_UNREACHABLE();
}

@end
