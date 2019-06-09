//
//  GSKVOBase.m
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import "GSKVOBase.h"


@implementation    GSKVOBase

- (void) dealloc
{
    // Turn off KVO for self ... then call the real dealloc implementation.
    [self setObservationInfo: nil]; // 首先进行了全局 ObservationInfo 的缓存的清除工作.
    object_setClass(self, [self class]); // 这里, 在调用 super dealloc 之前, 回复了自己实际的 class. 猜想原因是, dealloc 里面, 会有一些特殊的操作会被 isa 指针影响.
    [self dealloc];
}

// 返回, superClass
- (Class) class
{
    return class_getSuperclass(object_getClass(self));
}

// 这里, 其实就是为什么 KVC 的时候, 可以触发 KVO, 没有什么黑魔法的存在, 是因为在这里, 对于 setValue ForKey 进行了复写.
- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);
    
    // 首先拿到原来的 setValueForKey 的实现.
    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];
    // automaticallyNotifiesObserversForKey 这个东西, 是 KVO 里面的一个给与用于控制的开关.
    // 从这里我们看到, 它起作用在于, 如果返回值是 false 的话, 就不调用某些代码了.
    // 所以说, 一个属性, 一个配置, 究竟有什么作用, 是需要在代码里面, 专门对于这个值进行判断的, 根据值得不同, 执行不同的分支.
    // 由于分类的机制, NSObject 的很多配置, 可以通过分类进行隐藏, 这其实是对于开发人员很有帮助的. 在不需要 KVO 的时候, 让开发人员知道有 kvo 这回事, 其实是会造成他的恐惧, 因为他不知道是不是必须学习了 KVO 才能正常的使用 NSObject.
    // 这里, 又加强了对于分类的理解.
    if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    } else
    {
        imp(self,_cmd,anObject,aKey);
    }
}

// 返回原有类的 superClass.
- (Class) superclass
{
    return class_getSuperclass(class_getSuperclass(object_getClass(self)));
}
@end
