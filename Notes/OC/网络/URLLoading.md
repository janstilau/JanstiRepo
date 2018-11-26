# URL Loading

* NSURLSession 

用来创建一系列的 task, 进行数据的传递

* NSURLSessionConfiguration

用来进行控制的配置, 例如如何使用缓存, 如何使用 cookies.


##  NSURLSessionDataTask

将数据保存到内存中, 与之相对的是, NSURLSessionDownloadTask, 将数据存放到硬盘上.
一般我们用的都是 dataTask, 因为大部分网络请求, 都是 json 数据的交互.

sharedSession 是系统提供的 session 对象, 可以实现简单的网络请求, 如果想要进行精密的控制, 自己创建一个 configuration, 设置好 delegate 对象, 然后创建自己的一个 session 对象进行任务的创建.

最简单的就是创建一个带有 complete 回调的 dataTask. 不过回调其实是在子线程被调用的, 应该在回调里面明确的写明在主线程执行 UI 操作.

如果想要更加细度的控制, 设置代理对象.

## NSURLSessionDelegate --> 一般不常用.

下面的三个代理都是这个代理的子代理. 这个代理处理和 session 相关的事件.

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error;

If you invalidate a session by calling its finishTasksAndInvalidate method, the session waits until after the final task in the session finishes or fails before calling this delegate method. If you call the invalidateAndCancel method, the session calls this delegate method immediately.
Calling this method on the session returned by the sharedSession method has no effect.

当你明确的想要取消一个 session 的时候, finishTasksAndInvalidate 会触发这个代理函数.

- URLSessionDidFinishEventsForBackgroundURLSession:

In iOS, when a background transfer completes or requires credentials, if your app is no longer running, your app is automatically relaunched in the background, and the app’s UIApplicationDelegate is sent an application:handleEventsForBackgroundURLSession:completionHandler: message. This call contains the identifier of the session that caused your app to be launched. You should then store that completion handler before creating a background configuration object with the same identifier, and creating a session with that configuration. The newly created session is automatically reassociated with ongoing background activity.

When your app later receives a URLSessionDidFinishEventsForBackgroundURLSession: message, this indicates that all messages previously enqueued for this session have been delivered, and that it is now safe to invoke the previously stored completion handler or to begin any internal updates that may result in invoking the completion handler.

Important

Because the provided completion handler is part of UIKit, you must call it on your main thread.

- URLSession:didReceiveChallenge:completionHandler:

This method is called in two situations:

When a remote server asks for client certificates or Windows NT LAN Manager (NTLM) authentication, to allow your app to provide appropriate credentials

When a session first establishes a connection to a remote server that uses SSL or TLS, to allow your app to verify the server’s certificate chain

If you do not implement this method, the session calls its delegate’s URLSession:task:didReceiveChallenge:completionHandler: method instead.

第一种情况不多见, 一般都是 https 请求的时候.

## NSURLSessionTaskDelegate -> handle task-level events

- URLSession:task:didCompleteWithError:
Tells the delegate that the task finished transferring data.

- URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:
Tells the delegate that the remote server requested an HTTP redirect.

- URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:
Periodically informs the delegate of the progress of sending body content to the server.

- URLSession:task:didReceiveChallenge:completionHandler:
Requests credentials from the delegate in response to an authentication request from the remote server.



## NSURLSessionDataDelegate

## NSURLSessionDownDelegate