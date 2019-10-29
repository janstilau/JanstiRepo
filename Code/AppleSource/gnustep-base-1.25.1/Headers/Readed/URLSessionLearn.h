//
//  URLSessionLearn.h
//  base
//
//  Created by JustinLau on 2019/3/30.
//

#ifndef URLSessionLearn_h
#define URLSessionLearn_h
/*
 NSURLSession
 An object that coordinates a group of related network data transfer tasks.
 也就是说, 一个 session 里面, 可以有很多的网络交互的请求, 和响应. 这些在 Session 里面, 叫做一个 task.
 You use a NSURLSessionConfiguration instance when creating a session, also passing in a class that implements NSURLSessionDelegate or one of its subprotocols.
 NSURLSessionConfiguration 这个类是一个配置类, 就是将公共的配置项放在里面.
 应该是将, 对于网络交互相近的配置的网络请求, 用一个 session 来进行管理. 其实就是, 在生成 request 的时候, 赋值给一样的参数.
 
 NSURLSessionTask
 这个类, 就是
 
 NSURLSessionDataTask:
 这个类的作用, 是将数据直接下载到内存里面使用.
 Data tasks send and receive data using NSData objects. Data tasks are intended for short, often interactive requests to a server.
 
 NSURLSessionDownloadTask:
 这个类的作用, 是将数据下载到file system 中.
 Download tasks retrieve data in the form of a file, and support background downloads and uploads while the app isn’t running.
 
 NSURLSessionUploadTask:
 Upload tasks are similar to data tasks, but they also send data (often in the form of a file), and support background uploads while the app isn’t running.
 
 NSURLSessionConfiguration 这个类就是一个配置类, 我们如果想要发送一个请求, 其实是要做很多 NSURLRequest 的参数的设置的, 而这个类, 就是将这些参数设置用一个配置类进行了抽取.
 
  Once configured, the session object ignores any changes you make to the NSURLSessionConfiguration object. If you need to modify your transfer policies, you must update the session configuration object and use it to create a new NSURLSession object.
 这句话也就是说, session 里面运用了 copy. 从文档上看来, configuration 和 request 里面的参数, 是谁的限制多用谁的. 所以, 如果要进行一个特殊的网络请求, 还要用一个新的 session , 配以新的 configuration. 不过, 一般来说, 我们用的网络请求固定不变, 这样的机会其实不多.
 
 defaultSessionConfiguration, 这个方法的返回值, 可以当做配置的起点, 也就是说, 更改这个返回值, 并不会影响之后调用的结果. 从这里我们可以看出, 返回值一定进行了一次 copy 函数. 系统的类的设计, 有很多安全的考量, 这其实应该在平时的业务功能中也考虑.
 
 backgroundSessionConfigurationWithIdentifier:
 A session configured with this object hands control of the transfers over to the system, which handles the transfers in a separate process. In iOS, this configuration makes it possible for transfers to continue even when the app itself is suspended or terminated.
 这句话的意思是说, 这个下载任务不由 app 掌握, 而是系统进行管理.
 This behavior applies only for normal termination of the app by the system. If the user terminates the app from the multitasking screen, the system cancels all of the session’s background transfers. 也就是用户自己杀了app 的话, 系统也会停掉这个任务.
 
 
 
 */
#endif /* URLSessionLearn_h */
