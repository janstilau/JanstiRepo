//
//  GSKVOSetter.m
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import "GSKVOSetter.h"


@implementation    GSKVOSetter
/*
 这个类, 可以看做是, IMP 的一个集合体.
 这个类的所有方法, 都不是给自己写的, 仅仅是为了 class_addMethod 的调用.
 也就是说, 这个类的里面所有方法里面的 self, 不是 GSKVOSetter, 而是 class_addMethod 里面的 class 参数.
 这里, 突然觉得 JS 很像, JS 里面this 是一个和运行环境相关的量, 但是什么是和运行环境相关呢.
 OC 里面, objcMsgSend(obj, sel, arguments). 然后会从 obj 的类对象里面寻找 IMP, 找到了之后, 会传入 obj, sel, arguments.
 可以说, 这个IMP, 是挂靠在 OBJ 的类对象里面的, 通过 obj 能找到IMP, IMP 里面的 self 就是什么类型. 虽然, self 的真实值是 objcMsgSend 传递过去的,
 但是, 这个查找的过程能够成功, 是 classAddMethod 决定的. 也就是, IMP 挂靠在类对象上, 才能导致后面找到IMP, 并且把 obj 当做第一个参数传递过去.
 那么JS 也可以这样里面, JS 里面的方法, 都是一个执行体, 这个执行体里面 self 到底是什么, 是通过它的运行环境决定的. 通过哪个环境, 能够找到方法执行体, 那么方法在执行的时候, self 就被确定为什么. 这应该能够解释, JS 里面的运行环境的细节.
 */
/*
 在这里, 要注意 _cmd 不是 setter, 而是 setKey, 例如, setName: 所以下面的 imp, 是 setName, 而不是 setter
 */

- (void) setter: (void*)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,void*);
    
    imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterChar: (unsigned char)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned char);
    
    imp = (void (*)(id,SEL,unsigned char))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterDouble: (double)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,double);
    
    imp = (void (*)(id,SEL,double))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterFloat: (float)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,float);
    
    imp = (void (*)(id,SEL,float))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterInt: (unsigned int)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned int);
    
    imp = (void (*)(id,SEL,unsigned int))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterLong: (unsigned long)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned long);
    
    imp = (void (*)(id,SEL,unsigned long))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned long long);
    
    imp = (void (*)(id,SEL,unsigned long long))
    [c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}
#endif

- (void) setterShort: (unsigned short)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned short);
    
    imp = (void (*)(id,SEL,unsigned short))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterRange: (NSRange)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSRange);
    
    imp = (void (*)(id,SEL,NSRange))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterPoint: (NSPoint)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSPoint);
    
    imp = (void (*)(id,SEL,NSPoint))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterSize: (NSSize)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSSize);
    
    imp = (void (*)(id,SEL,NSSize))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterRect: (NSRect)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSRect);
    
    imp = (void (*)(id,SEL,NSRect))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}
@end
