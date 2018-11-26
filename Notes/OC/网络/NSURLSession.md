# NSURLSession

An object that coordinates a group of related network data transfer tasks.

NSObject 的子类, 也就是说, 这是一个纯粹的类, 它的作用在于, 管理一组网络数据任务.

## Configuration

Session objects make a copy of the configuration settings you provide and use those settings to configure the session. Once configured, the session object ignores any changes you make to the NSURLSessionConfiguration object. If you need to modify your transfer policies, you must update the session configuration object and use it to create a new NSURLSession object.

Any policy specified on the request object is respected unless the session’s policy is more restrictive. For example, if the session configuration specifies that cellular networking should not be allowed, the NSURLRequest object cannot request cellular networking.

配置, 控制的是使用它的类. session 里面, 会创建 task, 而这些 task, 最终会变成一个个的请求. 配置, 可能会影响到, session 创建task 的行为, 可能会影响到请求的一些参数. 这些都是内部控制的. 也就是说, 在设计类的时候, 应该还是先有了 session, task 这些东西, 然后发现, 有一些东西可以抽取出来, 做一个 configuration 类进行外部的控制. 所以就有了这个类.