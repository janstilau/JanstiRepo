#ifndef QTCONCURRENT_THREADENGINE_H
#define QTCONCURRENT_THREADENGINE_H

#include <QtConcurrent/qtconcurrent_global.h>

#if !defined(QT_NO_CONCURRENT) ||defined(Q_CLANG_QDOC)

#include <QtCore/qthreadpool.h>
#include <QtCore/qfuture.h>
#include <QtCore/qdebug.h>
#include <QtCore/qexception.h>
#include <QtCore/qwaitcondition.h>
#include <QtCore/qatomic.h>
#include <QtCore/qsemaphore.h>

QT_BEGIN_NAMESPACE


namespace QtConcurrent {

// The ThreadEngineBarrier counts worker threads, and allows one
// thread to wait for all others to finish. Tested for its use in
// QtConcurrent, requires more testing for use as a general class.
class ThreadEngineBarrier
{
private:
    // The thread count is maintained as an integer in the count atomic
    // variable. The count can be either positive or negative - a negative
    // count signals that a thread is waiting on the barrier.

    QAtomicInt count;
    QSemaphore semaphore;
public:
    ThreadEngineBarrier();
    void acquire();
    int release();
    void wait();
    int currentCount();
    bool releaseUnlessLast();
};

enum ThreadFunctionResult { ThrottleThread, ThreadFinished };

// The ThreadEngine controls the threads used in the computation.
// Can be run in three modes: single threaded, multi-threaded blocking
// and multi-threaded asynchronous.
// The code for the single threaded mode is
class Q_CONCURRENT_EXPORT ThreadEngineBase: public QRunnable
{
public:
    // Public API:
    ThreadEngineBase();
    virtual ~ThreadEngineBase();
    void startSingleThreaded();
    void startBlocking();
    void startThread();
    bool isCanceled();
    void waitForResume();
    bool isProgressReportingEnabled();
    void setProgressValue(int progress);
    void setProgressRange(int minimum, int maximum);
    void acquireBarrierSemaphore();

protected: // The user overrides these:
    virtual void start() {}
    virtual void finish() {}
    virtual ThreadFunctionResult threadFunction() { return ThreadFinished; }
    virtual bool shouldStartThread() { return futureInterface ? !futureInterface->isPaused() : true; }
    virtual bool shouldThrottleThread() { return futureInterface ? futureInterface->isPaused() : false; }
private:
    bool startThreadInternal();
    void startThreads();
    void threadExit();
    bool threadThrottleExit();
    void run() override;
    virtual void asynchronousFinish() = 0;
#ifndef QT_NO_EXCEPTIONS
    void handleException(const QException &exception);
#endif
protected:
    QFutureInterfaceBase *futureInterface;
    QThreadPool *threadPool;
    ThreadEngineBarrier barrier;
    QtPrivate::ExceptionStore exceptionStore;
};

/*
 *  ThreadEngine 还是使用了 future 相关类的设计.
 *   startAsynchronously 新建一个 futureInterface, 作为共享数据.
 *   run 方法里面, 调用 threadFunction, 在里面, 是各个业务类进行业务计算的代码.
 *   在其中, 会调用 ThreadEngine 的 report result 方法, 而 ThreadEngine 中, 会将数据填充到自己的 futureInterface 中去.
 * 在业务完成之后, 会调用 reportFinish.
 */
template <typename T>
class ThreadEngine : public virtual ThreadEngineBase
{
public:
    typedef T ResultType;

    virtual T *result() { return nullptr; }

    QFutureInterface<T> *futureInterfaceTyped()
    {
        return static_cast<QFutureInterface<T> *>(futureInterface);
    }

    // Runs the user algorithm using a single thread.
    T *startSingleThreaded()
    {
        ThreadEngineBase::startSingleThreaded();
        return result();
    }

    // Runs the user algorithm using multiple threads.
    // This function blocks until the algorithm is finished,
    // and then returns the result.
    T *startBlocking()
    {
        ThreadEngineBase::startBlocking();
        return result();
    }

    // Runs the user algorithm using multiple threads.
    // Does not block, returns a future.
    QFuture<T> startAsynchronously()
    {
        // 在这里, 新建了一个 Future 的共享数据.
        futureInterface = new QFutureInterface<T>();
        // reportStart() must be called before starting threads, otherwise the
        // user algorithm might finish while reportStart() is running, which
        // is very bad.
        futureInterface->reportStarted();
        QFuture<T> future = QFuture<T>(futureInterfaceTyped());
        start();

        acquireBarrierSemaphore();
        threadPool->start(this);
        return future;
    }

    void asynchronousFinish() override
    {
        finish();
        futureInterfaceTyped()->reportFinished(result());
        delete futureInterfaceTyped();
        delete this;
    }


    // report Result 其实就是存储到 future 的共享存储里面.
    void reportResult(const T *_result, int index = -1)
    {
        if (futureInterface)
            futureInterfaceTyped()->reportResult(_result, index);
    }

    void reportResults(const QVector<T> &_result, int index = -1, int count = -1)
    {
        if (futureInterface)
            futureInterfaceTyped()->reportResults(_result, index, count);
    }
};


// 这个类, 叫做 start 的作用就是, 可以自动调用锁存储的 engine 的 start 方法.
template <typename T>
class ThreadEngineStarterBase
{
public:
    ThreadEngineStarterBase(ThreadEngine<T> *_threadEngine)
    : threadEngine(_threadEngine) { }

    inline ThreadEngineStarterBase(const ThreadEngineStarterBase &other)
    : threadEngine(other.threadEngine) { }

    QFuture<T> startAsynchronously()
    {
        return threadEngine->startAsynchronously();
    }

    // 在各种函数的返回值里面, 是返回一个 QFuture, 所以, 各种信息包装到最后, 会到这里, 调用 startAsynchronously 方法.
    // 这种设计, 太让人困惑了.
    operator QFuture<T>()
    {
        return startAsynchronously();
    }

protected:
    ThreadEngine<T> *threadEngine;
};


// We need to factor out the code that dereferences the T pointer,
// with a specialization where T is void. (code that dereferences a void *
// won't compile)
template <typename T>
class ThreadEngineStarter : public ThreadEngineStarterBase<T>
{
    typedef ThreadEngineStarterBase<T> Base;
    typedef ThreadEngine<T> TypedThreadEngine;
public:
    ThreadEngineStarter(TypedThreadEngine *eng)
        : Base(eng) { }

    T startBlocking()
    {
        T t = *this->threadEngine->startBlocking();
        delete this->threadEngine;
        return t;
    }
};

// Full template specialization where T is void.
// 偏特化, 不仅仅是提供更加具体的实现.
// 方法的签名, 都能改变.
// 细想一下, 就是因为, 真正的类, 其实是 ThreadEngineStarter_void_xjij23123 这样的一个类.
// 就是有自己独特的类型,
template <>
class ThreadEngineStarter<void> : public ThreadEngineStarterBase<void>
{
public:
    ThreadEngineStarter<void>(ThreadEngine<void> *_threadEngine)
    :ThreadEngineStarterBase<void>(_threadEngine) {}

    void startBlocking()
    {
        this->threadEngine->startBlocking();
        delete this->threadEngine;
    }
};

// 一个方法, 方法的主要作用是返回一个对象.
// 这个对象, 符合某种抽象, 可以在方法的返回值所在的位置继续充当角色.
// 例如, swift 的 for...in
// 也例如这里, startThreadEngine 的返回值, 要成为 future.
// 而 ThreadEngineStarter 提供了到 future 的转化
template <typename ThreadEngine>
inline ThreadEngineStarter<typename ThreadEngine::ResultType> startThreadEngine(ThreadEngine *threadEngine)
{
    return ThreadEngineStarter<typename ThreadEngine::ResultType>(threadEngine);
}

} // namespace QtConcurrent


QT_END_NAMESPACE

#endif // QT_NO_CONCURRENT

#endif
