# 通知GNU 实现

```CPP
#ifndef __NSNotification_h_GNUSTEP_BASE_INCLUDE
#define __NSNotification_h_GNUSTEP_BASE_INCLUDE
#endif

以上是 CPP 中防止重复编译的宏定义.

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
- (id) addObserverForName: (NSString *)name 
                   object: (id)object 
                    queue: (NSOperationQueue *)queue 
               usingBlock: (GSNotificationBlock)block;
#endif

以上是通过条件编译, 控制编译内容的具体应用.

```

```
+ (void) initialize
{
  if (concreteClass == 0)
    {
      abstractClass = [NSNotification class];
      concreteClass = [GSNotification class];
    }
}

尽量, 把类相关的初始化工作放到 initialize 方法里面, 然后用 dispatch_one 或者判断的方式进行初始化. 因为 load 方法会在程序运行一开始就运行, 而initialize 是在程序用到这个类的时候才运行, 可以加快程序的启动. initialize 的问题在于, 子类如果没有定义过, 那么会调用父类的这个方法. 所以要加上一次性执行的判断.

```

NONotification 只是一个协议类, 真正的实现是 GSNotification, 放在了 NotificationCenter 里面.


