//
//  KVOHeader.h
//  gdnc
//
//  Created by JustinLau on 2019/4/20.
//

#ifndef KVOHeader_h
#define KVOHeader_h

/*
通过对于 KVO 的源码解读, 我发现 OC 里面, IMP 和JS 里面的方法一样, 里面的 self, 其实和这个方法的书写所在的类是没有必然的联系的. 因为有着 objc_addMethod 方法, 以及 objc_setImplement 的存在, 一个IMP, 它的运行环境在哪里, 其实是可以在运行的过程中进行修改的.
*/

/*
这个类的作用是什么呢, 坦白说, 这是一个操作的集合体, 它的唯一作用就是当KVO 生成一个类的时候, 将它的方法添加到这个新类上去.
为什么要这样呢, 首先, KVO 里面是想着 KVO 生成的类, 父类就是原有类. 那么 GSKVOBase 这个类就不应该出现在继承的层级关系里面. 但是, 子类要对一些操作进行改写, 例如, class 要返回原有的类信息, 所以需要某些特定的操作. 这个时候, GSKVOBase 的意义就出现了. 它只是方法的集合, 这些方法, 是通过 class_addMethod 添加到新创建的那个类上面.
*/

@implementation	GSKVOBase
- (void) dealloc
{
    // Turn off KVO for self ... then call the real dealloc implementation.
    [self setObservationInfo: nil]; // 这样写, 那么在 willChange, didChange 里面, 找不到  ObservationInfo, 也就没有后续的操作了.
    object_setClass(self, [self class]); // 把自己的类型改为原有类型.
    [self dealloc];
}
- (Class) class
{
    return class_getSuperclass(object_getClass(self)); // class 函数, 返回父类,也就是原有类.
}

- (void) setValue: (id)anObject forKey: (NSString*)aKey // 这里, 是对于 KVC 的补充, 这也就是为什么调用 KVC 可以调用到 KVO 的方法的原因.  automaticallyNotifiesObserversForKey 作为框架里面, 给与每个类自身控制 KVO 的入口.
{
    Class		c = [self class];
    void		(*imp)(id,SEL,id,id);
    
    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];
    
    if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    }
    else
    {
        imp(self,_cmd,anObject,aKey);
    }
}

- (Class) superclass
{
    return class_getSuperclass(class_getSuperclass(object_getClass(self)));
}
@end

@interface	GSKVOReplacement : NSObject
{
    Class         original;       /* The original class */
    Class         replacement;    /* The replacement class */
    NSMutableSet  *keys;          /* The observed setter keys */
}

@interface    GSKVOInfo : NSObject
{
    NSObject            *instance;    // 监听的对象
    GSLazyRecursiveLock            *iLock;
    NSMapTable<NSString, GSKVOPathInfo>           *paths; // 监听的 path
}


@interface	GSKVOPathInfo : NSObject
{
@public
    unsigned              recursion;
    unsigned              allOptions;
    NSMutableArray<GSKVOObservation *>       *observations;
    NSMutableDictionary   *change;
}

@interface	GSKVOObservation : NSObject
{
@public
    NSObject      *observer;      // Not retained (zeroing weak pointer)
    void          *context;
    int           options;
}
@end

@interface NSKeyValueObservationForwarder : NSObject
{
    id                                    target;
    NSKeyValueObservationForwarder        *child;
    void                                  *contextToForward;
    id                                    observedObjectForUpdate;
    NSString                              *keyForUpdate;
    id                                    observedObjectForForwarding;
    NSString                              *keyForForwarding;
    NSString                              *keyPathToForward;
}






#endif /* KVOHeader_h */
