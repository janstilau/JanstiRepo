# 事件循环

## Runtime

A JavaScript runtime uses a message queue, which is a list of messages to be processed. Each message has an associated function which gets called in order to handle the message.
这个和 gcd 的队列没什么区别, 至于 gcd 的队列里面每一个元素有没有 message 信息, 没有太多的印象, 因为 gcd 中, 我们每次放进去的是一个 block 操作, 并没有设置其他的相关的信息.

At some point during the event loop, the runtime starts handling the messages on the queue, starting with the oldest one. To do so, the message is removed from the queue and its corresponding function is called with the message as an input parameter. As always, calling a function creates a new stack frame for that function's use.

Function is called with the message as an input parameter. ?? 相对应的function 的输入参数, 不是在组织它的代码里面写好的吗 ??

## EventLoop

pseudoCode

```JS
while (queue.waitForMessage()) {
  queue.processNextMessage();
}
```

queue.waitForMessage() waits synchronously for a message to arrive if there is none currently.

Each message is processed completely before any other message is processed. This offers some nice properties when reasoning about your program, including the fact that whenever a function runs, it cannot be pre-empted and will run entirely before any other code runs (and can modify data the function manipulates). This differs from C, for instance, where if a function runs in a thread, it may be stopped at any point by the runtime system to run some other code in another thread.

所以, 在 JS 里面, 其实是不用做 lock 操作的, 所有的代码都是在主线程里面, 没有资源的抢占.

A downside of this model is that if a message takes too long to complete, the web application is unable to process user interactions like click or scroll. The browser mitigates this with the "a script is taking too long to run" dialog. A good practice to follow is to make message processing short and if possible cut down one message into several messages.

单线程的问题在于, 如果真的是一个耗时操作, 也是在主线程完成的. 之前在多线程的环境里面, 子线程可能是因为IO 操作, IO 操作本身不是计算密集型操作, 只是因为 IO 阻塞不能放主线程. JS 里面, IO 操作其实还是在子线程里面, 不过这个子线程是宿主环境进行管理的, 在宿主环境发现 IO 操作完成之后, 将异步回调放到 JS 的任务队列里面. 但是, 对于计算密集型操作, 在 JS 里面是没有办法让这个计算密集型操作放到宿主环境里面的. 这个时候, JS 就会卡住.

## Adding Message

In web browsers, messages are added anytime an event occurs and there is an event listener attached to it. If there is no listener, the event is lost. So a click on an element with a click event handler will add a message--likewise with any other event.

The function setTimeout is called with 2 arguments: a message to add to the queue, and a time value (optional; defaults to 0). The time value represents the (minimum) delay after which the message will actually be pushed into the queue. If there is no other message in the queue, the message is processed right after the delay; however, if there are messages, the setTimeout message will have to wait for other messages to be processed. For that reason, the second argument indicates a minimum time and not a guaranteed time.

这里, setTimeout 的后面的时间, 指的是这个 message 什么时候会被添加到 queue 里面去. 其实也应该是这样, 因为如果被添加到 queue 里面去, runTime 是不管这个 message 是不是什么延时 message, 而是轮到这个 message 就会被执行. 所以, setTimeout 保证的也就是什么时候将 function 加入到队列里面.

## Zero delays

The execution depends on the number of waiting tasks in the queue. In the example below, the message ''this is just a message'' will be written to the console before the message in the callback gets processed, because the delay is the minimum time required for the runtime to process the request, but not a guaranteed time.

我们可以这样理解, 当前运行的代码, 必须执行完, JS 才有可能去读取 queue 里面的下一个任务, setTimeOut 这个函数运行完之后, 这个他所携带的 function 并没有放到队列里面, 这个函数应该是, 设置了一个时间点去 trigger 某些操作, 这个操作就是, 把 functin 放到队列的末尾.
