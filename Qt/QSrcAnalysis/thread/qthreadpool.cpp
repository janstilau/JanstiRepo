#include "qthreadpool.h"
#include "qthreadpool_p.h"
#include "qelapsedtimer.h"

#include <algorithm>

#ifndef QT_NO_THREAD

QT_BEGIN_NAMESPACE

Q_GLOBAL_STATIC(QThreadPool, theInstance)

/*
    一个特殊的 Thread, 就是为了完成 Pool 里面的任务.
    这个类, 和 NSOperationQueue 有着类似的设计的思路.
*/
class QThreadPoolThread : public QThread
{
public:
    QThreadPoolThread(QThreadPoolPrivate *manager);
    void run() Q_DECL_OVERRIDE;
    void registerThreadInactive();

    QWaitCondition runnableReady;
    QThreadPoolPrivate *manager; // 直接引用到了管理器. 正因为如此, 管理器需要等待线程退出后自己才去销毁.
    QRunnable *runnable; // 真正的任务代码对象封装
};

QThreadPoolThread::QThreadPoolThread(QThreadPoolPrivate *manager)
    :manager(manager), runnable(nullptr)
{ }

void QThreadPoolThread::run()
{
    QMutexLocker locker(&manager->mutex);
    for(;;) {
        // 数据的抽取工作. 在抽取之前, 已经上锁了.
        QRunnable *r = runnable;
        runnable = nullptr;

                    do {
                        if (r) {
                            // 有任务, 放开锁开始执行任务.
                            const bool autoDelete = r->autoDelete();
                            locker.unlock();
                            try {
                                r->run();
                            } catch (...) {
                                // 这里有问题, 没在锁环境.
                                registerThreadInactive();
                                throw;
                            }
                            if (autoDelete && !--r->ref) { delete r; }
                            // 运行完任务, 重新加锁.
                            locker.relock();
                        }

                        // 线程过多, 就退出
                        if (manager->tooManyThreadsActive())
                            break;

                        // 没有任务了, 就退出.
                        if (manager->queue.isEmpty()) {
                            r = nullptr;
                            break;
                        }

                        // 获取新的任务, 执行.
                        QueuePage *page = manager->queue.first();
                        r = page->pop();
                        if (page->isFinished()) {
                            manager->queue.removeFirst();
                            delete page;
                        }
                    } while (true);



        if (manager->isExiting) {
            registerThreadInactive();
            break;
        }

        // if too many threads are active, expire this thread
        bool expired = manager->tooManyThreadsActive();
        if (!expired) {
            // 还没达到线程限制, 可以进行 wait 等待任务发生.
            // 先进入到等待队列里.
            // 这里的逻辑, 就和 NSOperationQueue 里面的是一样的, 没有任务的时候, wait 一段时间. 如果到时间还没有任务, 就跳出循环.
            manager->waitingThreads.enqueue(this);
            registerThreadInactive();
            // wait for work, exiting after the expiry timeout is reached
            // 在这里, locker 会自动 unlock.
            // 这里用到了 expiryTimeout
            runnableReady.wait(locker.mutex(), manager->expiryTimeout);
            ++manager->activeThreads;
            // 因为启动的时候, 是把 this 从 waitingThreads 中 take 的, 所以如果来在, 就是时间到了, 而不是主动触发的.
            if (manager->waitingThreads.removeOne(this))
                expired = true;
        }

        if (expired) {
            // 超时了, 就进入到 过期线程中.
            manager->expiredThreads.enqueue(this);
            registerThreadInactive();
            break;
        }
    }
}

void QThreadPoolThread::registerThreadInactive()
{
    if (--manager->activeThreads == 0)
        manager->noActiveThreads.wakeAll();
}




QThreadPoolPrivate:: QThreadPoolPrivate()
    : isExiting(false),
      expiryTimeout(30000),
      maxThreadCount(qAbs(QThread::idealThreadCount())),
      reservedThreads(0),
      activeThreads(0)
{ }

// 在主函数进行加锁, 在被调用函数里面, 就没有锁的相关操作了.
// 将函数的调用关系理清, 也就没有死锁的问题了.
bool QThreadPoolPrivate::tryStart(QRunnable *task)
{
    if (allThreads.isEmpty()) {
        // always create at least one thread
        startThread(task);
        return true;
    }

    // can't do anything if we're over the limit
    if (activeThreadCount() >= maxThreadCount)
        return false;

    // 有着正在等待的线程, 就唤醒该线程. wakeOne 就是 signal.
    if (waitingThreads.count() > 0) {
        enqueueTask(task);
        waitingThreads.takeFirst()->runnableReady.wakeOne();
        return true;
    }

    // 启动一个过期的线程. 其实没有理解, expiredThreads 的设计意图在哪里.
    if (!expiredThreads.isEmpty()) {
        // restart an expired thread
        QThreadPoolThread *thread = expiredThreads.dequeue();
        ++activeThreads;

        if (task->autoDelete())
            ++task->ref;
        thread->runnable = task;
        thread->start();
        return true;
    }

    // 到了这里, 就是没有备用的资源可以使用, 那就是正常的开启新线程的逻辑了.
    startThread(task);
    return true;
}

// 这个函数, 是为了 std::upper_bound 使用的.
// 所以, 这种为了使用标准库自定义 C 函数的写法, 是很标准的写法.
inline bool comparePriority(int priority, const QueuePage *p)
{
    return p->priority() < priority;
}

// QueuePage 是一个带有 priority 值的对于 task 的容器.
// 有了这样的一个中间类, 可以让 queue 大大减少搬移的工作.
// 这个设计的思路, 应该值得学习.
void QThreadPoolPrivate::enqueueTask(QRunnable *runnable, int priority)
{
    if (runnable->autoDelete())
        ++runnable->ref;

    for (QueuePage *page : qAsConst(queue)) {
        // 对于, 同样的优先级的对象, 直接添加到后面就可以了.
        if (page->priority() == priority && !page->isFull()) {
            page->push(runnable);
            return;
        }
    }
    // 否则先进行二分查找, 在合适的位置, 插入一个新的 Queue 对象.
    auto it = std::upper_bound(queue.constBegin(), queue.constEnd(), priority, comparePriority);
    queue.insert(std::distance(queue.constBegin(), it), new QueuePage(runnable, priority));
}

// 确保了在 lock 状态, 所以这些成员变量的访问, 都没有加锁.
int QThreadPoolPrivate::activeThreadCount() const
{
    return (allThreads.count()
            - expiredThreads.count()
            - waitingThreads.count()
            + reservedThreads);
}

// 这个函数, 是在 MaxThreadCount 被改变的时候主动调用的.
// 良好的命名, 让代码更加清晰.
// 所有的, Thread 开启的操作, 都在 tryStart 中, 其他的函数也就能够更好地进行组织.
void QThreadPoolPrivate::tryToStartMoreThreads()
{
    // try to push tasks on the queue to any available threads
    while (!queue.isEmpty()) {
        QueuePage *page = queue.first();
        if (!tryStart(page->first()))
            break;

        page->pop();
        if (page->isFinished()) {
            queue.removeFirst();
            delete page;
        }
    }
}

// 确保, 调用该函数的时候, 在加锁的环境下, 这个函数内部就不用加锁了
bool QThreadPoolPrivate::tooManyThreadsActive() const
{
    const int activeThreadCount = this->activeThreadCount();
    return activeThreadCount > maxThreadCount && (activeThreadCount - reservedThreads) > 1;
}

void QThreadPoolPrivate::startThread(QRunnable *runnable)
{
    // 这里, QScopedPointer 使用的原因, 可能是为了函数意外退出时, 可以自动进行创建的 Thread 的删除工作
    // 如果可以正常的退出, 在最后, 会有 take 操作, 使得 Thread 不会被删除.
    QScopedPointer<QThreadPoolThread> thread(new QThreadPoolThread(this));
    thread->setObjectName(QLatin1String("Thread (pooled)"));
    allThreads.append(thread.data());
    ++activeThreads;
    if (runnable->autoDelete())
        ++runnable->ref;
    thread->runnable = runnable;
    thread.take()->start();
}

/*!
    \internal
    Makes all threads exit, waits for each thread to exit and deletes it.
*/
void QThreadPoolPrivate::reset()
{
    QMutexLocker locker(&mutex);
    isExiting = true;

    while (!allThreads.empty()) {
        // 一个简单地 move 操作, 让容器的数据, 瞬间转移.
        // 这里也是线程操作的经典写法, 复制, 然后改变成员变量. 后续的操作, 都在复制量上进行.
        QList<QThreadPoolThread *> allThreadsCopy;
        allThreadsCopy.swap(allThreads); // 这里, 清空了 allThread 的数据.
        locker.unlock();

        for (QThreadPoolThread *thread : qAsConst(allThreadsCopy)) {
            thread->runnableReady.wakeAll();
            thread->wait();
            delete thread;
        }

        locker.relock();
        // repeat until all newly arrived threads have also completed
    }

    waitingThreads.clear();
    expiredThreads.clear();

    isExiting = false;
}

// QThreadPool wait 所有的线程都退出之后在释放, 是非常有必要的.
// 在自己实现的线程池里面, 因为子线程的有些操作, 是引用到了线程控制对象的. 线程控制对象消亡的时候, 子线程的代码还会继续执行. 所以, 子线程就访问了非法的空间, 导致了内存错误.
bool QThreadPoolPrivate::waitForDone(int msecs)
{
    QMutexLocker locker(&mutex);
    if (msecs < 0) {
        /*
         * 基本上, 线程同步都可以使用 mutex 加 condition 来完成. NSConditionLock 只不过是在类的内部, 用了一个 int 值代替了 Predicate
         * Condition wait 被唤醒的时候, 会同时加锁, 这个时候, 可以进行 predicate 的判断, 然后如果为 false, 继续 wait 就好了.
         */
        while (!(queue.isEmpty() && activeThreads == 0))
            noActiveThreads.wait(locker.mutex());
    } else {
        QElapsedTimer timer;
        timer.start();
        int t;
        // 这里是同样的套路,只不过增加了时间, 作为循环推出的条件了.
        while (
               !(queue.isEmpty() && activeThreads == 0) &&
               ((t = msecs - timer.elapsed()) > 0) )
            noActiveThreads.wait(locker.mutex(), t);
    }
    // 最后返回当前任务状态, 线程状态.
    return queue.isEmpty() && activeThreads == 0;
}

// 删除所有的任务, 和线程无关.
void QThreadPoolPrivate::clear()
{
    QMutexLocker locker(&mutex);
    for (QueuePage *page : qAsConst(queue)) {
        while (!page->isFinished()) {
            QRunnable *r = page->pop();
            if (r && r->autoDelete() && !--r->ref)
                delete r;
        }
    }
    qDeleteAll(queue);
    queue.clear();
}

/*!
    \since 5.9

    Attempts to remove the specified \a runnable from the queue if it is not yet started.
    If the runnable had not been started, returns \c true, and ownership of \a runnable
    is transferred to the caller (even when \c{runnable->autoDelete() == true}).
    Otherwise returns \c false.

    \note If \c{runnable->autoDelete() == true}, this function may remove the wrong
    runnable. This is known as the \l{https://en.wikipedia.org/wiki/ABA_problem}{ABA problem}:
    the original \a runnable may already have executed and has since been deleted.
    The memory is re-used for another runnable, which then gets removed instead of
    the intended one. For this reason, we recommend calling this function only for
    runnables that are not auto-deleting.

    \sa start(), QRunnable::autoDelete()
*/
bool QThreadPool::tryTake(QRunnable *runnable)
{
    Q_D(QThreadPool);

    if (runnable == nullptr) { return false; }
    {
        QMutexLocker locker(&d->mutex);

        for (QueuePage *page : qAsConst(d->queue)) {
            if (page->tryTake(runnable)) {
                if (page->isFinished()) {
                    d->queue.removeOne(page);
                    delete page;
                }
                if (runnable->autoDelete())
                    --runnable->ref; // undo ++ref in start()
                return true;
            }
        }
    }

    return false;
}

// 这个函数, 就是找到相应的任务, 立马调用, 将他从调度队列中删除.
// 在 Future 的 get 函数里面, 有可能到这里来.
// 也就是, 在需要结果的时候, 优先进行这里的计算.
void QThreadPoolPrivate::stealAndRunRunnable(QRunnable *runnable)
{
    Q_Q(QThreadPool);
    if (!q->tryTake(runnable))
        return;
    const bool del = runnable->autoDelete() && !runnable->ref; // tryTake already deref'ed

    runnable->run();

    if (del) {
        delete runnable;
    }

}

// 在 QThreadPool 的构造方法里面, 进行 QThreadPoolPrivate 的创建
QThreadPool::QThreadPool(QObject *parent)
    : QObject(*new QThreadPoolPrivate, parent)
{ }

// 等待所有的子线程结束之后, 才继续执行,
QThreadPool::~QThreadPool()
{
    waitForDone();
}


QThreadPool *QThreadPool::globalInstance()
{
    return theInstance();
}

// Interface 和 imp 之间的界限到底在哪里.
// 这个方法, 其实是可以写到 Private 类里面的, 这样, interface 直接就一个函数调用就可以了.
// 但是这里, 其实是 Interface 这个类, 在使用自己的成员变量, 在进行逻辑的编写了.
void QThreadPool::start(QRunnable *runnable, int priority)
{
    if (!runnable) return;

    Q_D(QThreadPool);
    QMutexLocker locker(&d->mutex);
    // tryStart 是真正的调用算法.
    if (!d->tryStart(runnable)) {
        d->enqueueTask(runnable, priority);
        // 在这里, 启动一个正在等待的线程. 这里, 是利用了每一个线程的 condition 进行的唤醒.
        if (!d->waitingThreads.isEmpty()) {
            d->waitingThreads.takeFirst()->runnableReady.wakeOne();
        }
    }
}

/*!
    Attempts to reserve a thread to run \a runnable.

    If no threads are available at the time of calling, then this function
    does nothing and returns \c false.  Otherwise, \a runnable is run immediately
    using one available thread and this function returns \c true.
*/
bool QThreadPool::tryStart(QRunnable *runnable)
{
    if (!runnable)
        return false;

    Q_D(QThreadPool);

    QMutexLocker locker(&d->mutex);

    // 如果, 已经超过了当前的可运行的状态了, 直接返回.
    if (d->allThreads.isEmpty() == false && d->activeThreadCount() >= d->maxThreadCount)
        return false;

    return d->tryStart(runnable);
}

int QThreadPool::expiryTimeout() const
{
    Q_D(const QThreadPool);
    return d->expiryTimeout;
}

void QThreadPool::setExpiryTimeout(int expiryTimeout)
{
    Q_D(QThreadPool);
    if (d->expiryTimeout == expiryTimeout)
        return;
    d->expiryTimeout = expiryTimeout;
}

int QThreadPool::maxThreadCount() const
{
    Q_D(const QThreadPool);
    return d->maxThreadCount;
}

void QThreadPool::setMaxThreadCount(int maxThreadCount)
{
    Q_D(QThreadPool);
    QMutexLocker locker(&d->mutex);

    if (maxThreadCount == d->maxThreadCount)
        return;

    d->maxThreadCount = maxThreadCount;
    d->tryToStartMoreThreads();
}

int QThreadPool::activeThreadCount() const
{
    Q_D(const QThreadPool);
    QMutexLocker locker(&d->mutex);
    return d->activeThreadCount();
}

void QThreadPool::reserveThread()
{
    Q_D(QThreadPool);
    QMutexLocker locker(&d->mutex);
    ++d->reservedThreads;
}


void QThreadPool::releaseThread()
{
    Q_D(QThreadPool);
    QMutexLocker locker(&d->mutex);
    --d->reservedThreads;
    d->tryToStartMoreThreads();
}

/*!
    Waits up to \a msecs milliseconds for all threads to exit and removes all
    threads from the thread pool. Returns \c true if all threads were removed;
    otherwise it returns \c false. If \a msecs is -1 (the default), the timeout
    is ignored (waits for the last thread to exit).
*/
bool QThreadPool::waitForDone(int msecs)
{
    Q_D(QThreadPool);
    bool rc = d->waitForDone(msecs);
    if (rc)
      d->reset();
    return rc;
}

/*!
    \since 5.2

    Removes the runnables that are not yet started from the queue.
    The runnables for which \l{QRunnable::autoDelete()}{runnable->autoDelete()}
    returns \c true are deleted.

    \sa start()
*/
void QThreadPool::clear()
{
    Q_D(QThreadPool);
    d->clear();
}

void QThreadPool::cancel(QRunnable *runnable)
{
    if (tryTake(runnable) && runnable->autoDelete() && !runnable->ref) // tryTake already deref'ed
        delete runnable;
}
#endif

QT_END_NAMESPACE

#include "moc_qthreadpool.cpp"

#endif
