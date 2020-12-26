#include "qthreadpool.h"
#include "qthreadpool_p.h"
#include "qelapsedtimer.h"

#include <algorithm>

#ifndef QT_NO_THREAD

QT_BEGIN_NAMESPACE

Q_GLOBAL_STATIC(QThreadPool, theInstance)

/*
    一个特殊的 Thread, 就是为了完成 Pool 里面的任务.
*/
class QThreadPoolThread : public QThread
{
public:
    QThreadPoolThread(QThreadPoolPrivate *manager);
    void run() Q_DECL_OVERRIDE;
    void registerThreadInactive();

    QWaitCondition runnableReady;
    QThreadPoolPrivate *manager;
    QRunnable *runnable; // 一个线程,  一个任务.
};

QThreadPoolThread::QThreadPoolThread(QThreadPoolPrivate *manager)
    :manager(manager), runnable(nullptr)
{ }

void QThreadPoolThread::run()
{
    QMutexLocker locker(&manager->mutex);
    for(;;) {
        QRunnable *r = runnable;
        runnable = nullptr;

                    // 不断地执行任务.
                    do {
                        if (r) {
                            const bool autoDelete = r->autoDelete();
                            // 开始运行任务, 就放开锁.
                            locker.unlock();
                            try {
                                r->run();
                            } catch (...) {
                                // 这里有问题, 没在锁环境.
                                registerThreadInactive();
                                throw;
                            }
                            // 运行完任务, 重新加锁.
                            locker.relock();
                            if (autoDelete && !--r->ref)
                                delete r;
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

// 调度算法.
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

    if (waitingThreads.count() > 0) {
        // recycle an available thread
        enqueueTask(task);
        // 启动一个沉睡的线程.
        waitingThreads.takeFirst()->runnableReady.wakeOne();
        return true;
    }

    // 启动一个过期的线程.
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

    // start a new thread
    startThread(task);
    return true;
}

inline bool comparePriority(int priority, const QueuePage *p)
{
    return p->priority() < priority;
}

void QThreadPoolPrivate::enqueueTask(QRunnable *runnable, int priority)
{
    Q_ASSERT(runnable != nullptr);
    if (runnable->autoDelete())
        ++runnable->ref;

    for (QueuePage *page : qAsConst(queue)) {
        if (page->priority() == priority && !page->isFull()) {
            page->push(runnable);
            return;
        }
    }
    auto it = std::upper_bound(queue.constBegin(), queue.constEnd(), priority, comparePriority);
    queue.insert(std::distance(queue.constBegin(), it), new QueuePage(runnable, priority));
}

int QThreadPoolPrivate::activeThreadCount() const
{
    return (allThreads.count()
            - expiredThreads.count()
            - waitingThreads.count()
            + reservedThreads);
}

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

bool QThreadPoolPrivate::tooManyThreadsActive() const
{
    const int activeThreadCount = this->activeThreadCount();
    return activeThreadCount > maxThreadCount && (activeThreadCount - reservedThreads) > 1;
}

void QThreadPoolPrivate::startThread(QRunnable *runnable)
{
    QScopedPointer <QThreadPoolThread> thread(new QThreadPoolThread(this));
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
        // move the contents of the set out so that we can iterate without the lock
        QList<QThreadPoolThread *> allThreadsCopy;
        allThreadsCopy.swap(allThreads); // 这里, 清空了 allThread 的数据.
        locker.unlock();

        // 不太明白这里的作用.
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

bool QThreadPoolPrivate::waitForDone(int msecs)
{
    QMutexLocker locker(&mutex);
    if (msecs < 0) {
        // 如果  msecs < 0, 就是等到所有线程退出才可以.
        // 还有任务, 还有线程在运行, 就一直等.
        while (!(queue.isEmpty() && activeThreads == 0))
            noActiveThreads.wait(locker.mutex());
    } else {
        QElapsedTimer timer;
        timer.start();
        int t;
        while (!(queue.isEmpty() && activeThreads == 0) &&
               ((t = msecs - timer.elapsed()) > 0)
               )
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

    /*!
     \internal
     Searches for \a runnable in the queue, removes it from the queue and
     runs it if found. This function does not return until the runnable
     has completed.
     */
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

/*!
    \class QThreadPool
    \inmodule QtCore
    \brief The QThreadPool class manages a collection of QThreads.
    \since 4.4
    \threadsafe

    \ingroup thread

    QThreadPool manages and recyles individual QThread objects to help reduce
    thread creation costs in programs that use threads. Each Qt application
    has one global QThreadPool object, which can be accessed by calling
    globalInstance().

    To use one of the QThreadPool threads, subclass QRunnable and implement
    the run() virtual function. Then create an object of that class and pass
    it to QThreadPool::start().

    \snippet code/src_corelib_concurrent_qthreadpool.cpp 0

    QThreadPool deletes the QRunnable automatically by default. Use
    QRunnable::setAutoDelete() to change the auto-deletion flag.

    QThreadPool supports executing the same QRunnable more than once
    by calling tryStart(this) from within QRunnable::run().
    If autoDelete is enabled the QRunnable will be deleted when
    the last thread exits the run function. Calling start()
    multiple times with the same QRunnable when autoDelete is enabled
    creates a race condition and is not recommended.

    Threads that are unused for a certain amount of time will expire. The
    default expiry timeout is 30000 milliseconds (30 seconds). This can be
    changed using setExpiryTimeout(). Setting a negative expiry timeout
    disables the expiry mechanism.

    Call maxThreadCount() to query the maximum number of threads to be used.
    If needed, you can change the limit with setMaxThreadCount(). The default
    maxThreadCount() is QThread::idealThreadCount(). The activeThreadCount()
    function returns the number of threads currently doing work.

    The reserveThread() function reserves a thread for external
    use. Use releaseThread() when your are done with the thread, so
    that it may be reused.  Essentially, these functions temporarily
    increase or reduce the active thread count and are useful when
    implementing time-consuming operations that are not visible to the
    QThreadPool.

    Note that QThreadPool is a low-level class for managing threads, see
    the Qt Concurrent module for higher level alternatives.

    \sa QRunnable
*/


QThreadPool::QThreadPool(QObject *parent)
    : QObject(*new QThreadPoolPrivate, parent)
{ }

/*!
    Destroys the QThreadPool.
    This function will block until all runnables have been completed.
*/
QThreadPool::~QThreadPool()
{
    waitForDone();
}

/*!
    Returns the global QThreadPool instance.
*/
QThreadPool *QThreadPool::globalInstance()
{
    return theInstance();
}

/*!
    Reserves a thread and uses it to run \a runnable, unless this thread will
    make the current thread count exceed maxThreadCount().  In that case,
    \a runnable is added to a run queue instead. The \a priority argument can
    be used to control the run queue's order of execution.
*/
void QThreadPool::start(QRunnable *runnable, int priority)
{
    if (!runnable)
        return;

    Q_D(QThreadPool);
    QMutexLocker locker(&d->mutex);
    if (!d->tryStart(runnable)) {
        d->enqueueTask(runnable, priority);
        // 在这里, 启动一个正在等待的线程. 这里, 是利用了每一个线程的 condition 进行的唤醒.
        if (!d->waitingThreads.isEmpty()) {
            d->waitingThreads.takeFirst()->runnableReady.wakeOne();
        }
    }
    // 这里没有调度算法, 因为如果可以开启线程在 tryStart 中就执行了.
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
