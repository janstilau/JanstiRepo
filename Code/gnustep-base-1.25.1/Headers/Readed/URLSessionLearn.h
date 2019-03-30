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
 
 
 
 
 
 */
#endif /* URLSessionLearn_h */
