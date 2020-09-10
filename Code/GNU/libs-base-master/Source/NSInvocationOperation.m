#import "common.h"

#import "Foundation/NSInvocationOperation.h"
#import "Foundation/NSException.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/GSObjCRuntime.h"

@implementation NSInvocationOperation

- (id) initWithInvocation: (NSInvocation *)inv
{
    if (((self = [super init])) != nil)
    {
        /*
         因为 Opertation 实际的调用时机不定, 所以, invocation 需要 retain arguments 保证 operation 调用的时候, 参数的生命周期不会出现问题.
         */
        [inv retainArguments];
        _invocation = [inv retain];
    }
    return self;
}

/*
 其实就是构建一个 invocation, 然后通过 initWithInvocation 进行初始化.
 */
- (id) initWithTarget: (id)target selector: (SEL)aSelector object: (id)arg
{
    NSMethodSignature *methodSignature;
    NSInvocation *inv;
    
    methodSignature = [target methodSignatureForSelector: aSelector];
    inv = [NSInvocation invocationWithMethodSignature: methodSignature];
    [inv setTarget: target];
    [inv setSelector: aSelector];
    if ([methodSignature numberOfArguments] > 2)
        [inv setArgument: &arg atIndex: 2];
    return [self initWithInvocation: inv];
}

/*
 main 方法, 简简单单就是 invocation 的调用而已.
 */
- (void) main
{
    if (![self isCancelled])
    {
        NS_DURING
        [_invocation invoke];
        NS_HANDLER
        _exception = [localException copy];
        NS_ENDHANDLER
    }
}

/*
 提供一个 get 方法, 获取最重要的数据.
 */
- (NSInvocation *) invocation
{
    return [[_invocation retain] autorelease];
}

- (id) result
{
    id result = nil;
    
    if (![self isFinished])
    {
        return nil;
    }
    if (nil != _exception)
    {
        [_exception raise];
    }
    else if ([self isCancelled])
    {
        [NSException raise: (id)NSInvocationOperationCancelledException
                    format: @"*** %s: operation was cancelled", __PRETTY_FUNCTION__];
    }
    else
    {
        /*
         这就是 encode 的作用了. 根据 OC 独有的 encode 字符, 可以判断出相应的数据类型, 然后创建该类型的数据, 填充被返回.
         */
        const char *returnType = [[_invocation methodSignature] methodReturnType];
        
        if (0 == strncmp(@encode(void),
                         GSSkipTypeQualifierAndLayoutInfo(returnType), 1))
        {
            [NSException raise: (id)NSInvocationOperationVoidResultException
                        format: @"*** %s: void result", __PRETTY_FUNCTION__];
        }
        else if (0 == strncmp(@encode(id),
                              GSSkipTypeQualifierAndLayoutInfo(returnType), 1))
        {
            [_invocation getReturnValue: &result];
        }
        else
        {
            unsigned char *buffer = malloc([[_invocation methodSignature]
                                            methodReturnLength]);
            
            [_invocation getReturnValue: buffer];
            result = [NSValue valueWithBytes: buffer objCType: returnType];
        }
    }
    return result;
}

- (void) dealloc
{
    [_invocation release];
    [_exception release];
    [super dealloc];
}

@end

const NSString * NSInvocationOperationVoidResultException
= @"NSInvocationOperationVoidResultException";
const NSString * NSInvocationOperationCancelledException
= @"NSInvcationOperationCancelledException";
