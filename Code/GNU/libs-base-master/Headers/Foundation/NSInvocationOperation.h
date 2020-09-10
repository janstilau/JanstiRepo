#ifndef __NSInvocationOperation_h_GNUSTEP_BASE_INCLUDE
#define __NSInvocationOperation_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSOperation.h>
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)

@class NSInvocation;
@class NSException;

@interface NSInvocationOperation : NSOperation
{
@private
    NSInvocation *_invocation;
    NSException *_exception;
    void        *_reserved;
}

- (id) initWithInvocation: (NSInvocation *)inv;
- (id) initWithTarget: (id)target selector: (SEL)aSelector object: (id)arg;

- (NSInvocation *) invocation;
- (id) result;

@end

extern const NSString * NSInvocationOperationVoidResultException;
extern const NSString * NSInvocationOperationCancelledException;

#endif /* OS_API_VERSION */
#endif /* __NSInvocationOperation_h_GNUSTEP_BASE_INCLUDE */
