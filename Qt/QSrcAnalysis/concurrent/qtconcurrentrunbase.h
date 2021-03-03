#ifndef QTCONCURRENT_RUNBASE_H
#define QTCONCURRENT_RUNBASE_H

#include <QtConcurrent/qtconcurrent_global.h>

#ifndef QT_NO_CONCURRENT

#include <QtCore/qfuture.h>
#include <QtCore/qrunnable.h>
#include <QtCore/qthreadpool.h>

QT_BEGIN_NAMESPACE


// QTConcurrentRun 的抽象层.
#ifndef Q_QDOC

namespace QtConcurrent {

template <typename T>
struct SelectSpecialization
{
    template <class Normal, class Void>
    struct Type { typedef Normal type; };
};

template <>
struct SelectSpecialization<void>
{
    template <class Normal, class Void>
    struct Type { typedef Void type; };
};

// 在 RunFunctionTaskBase 里面, 一直在使用 QFutureInterface 的接口, 来做多线程数据同步的事情.
// 从这里可以看出, Future 这个类, 其实应该算作是数据类, 算法类, 流程类, 还是在 RunFunctionTaskBase 这里.
template <typename T>
class RunFunctionTaskBase : public QFutureInterface<T> , public QRunnable
{
public:
    // start, 就是在 某个线程池里面, 调动自己.
    QFuture<T> start()
    {
        return start(QThreadPool::globalInstance());
    }

    // start 返回自己存储的 future 对象.
    QFuture<T> start(QThreadPool *pool)
    {
        // 这里, 使用了 QFutureInterface 的方法, 来做线程之间的通信.
        this->setThreadPool(pool);
        this->setRunnable(this);
        this->reportStarted();
        // 这里, 是生成一个新的 Future,
        // Future 这个对象, 实际的数据是一个指针.
        // 每次进行复制的时候, 其实就是这个指针的复制. 这也是 C++ 的复杂之处, 需要考虑复制时数据是否应该拷贝.
        // 对于 Future 而然, 它应该是只控制一份数据. 这样, 才能够在多线程环境下使用一份数据进行 wait, wakeup, get 等操作.
        QFuture<T> theFuture = this->future();
        pool->start(this, /*m_priority*/ 0); // 这就是为什么提交了任务, 不用主动触发任务执行的原因. 提交到了 pool 中由 pool 管理.
        return theFuture;
    }

    void run() override {}
    virtual void runFunctor() = 0;
};

template <typename T>
class RunFunctionTask : public RunFunctionTaskBase<T>
{
public:
    // 对于 QRunable 的适配工作.
    void run() override
    {
        if (this->isCanceled()) {
            this->reportFinished();
            return;
        }
        // 在调用 this->runFunctor(); 的周围, 包裹着对于异常的处理.
        // 如果发生了异常, 就把异常存储在 future 的内部. 以便异步获取.
        try {
            this->runFunctor();
        } catch (QException &e) {
            QFutureInterface<T>::reportException(e);
        } catch (...) {
            QFutureInterface<T>::reportException(QUnhandledException());
        }

        // 然后, 调用 reportResult 方法, 这是 future 里面的方法, 会将 result, 存到 future 的管理的某个位置, 然后唤醒 wait 的线程.
        this->reportResult(result);
        this->reportFinished();
    }
    T result;
};

// 如果, 没有返回值, 那么就不 report result, 略过这一步.
template <>
class RunFunctionTask<void> : public RunFunctionTaskBase<void>
{
public:
    void run() override
    {
        if (this->isCanceled()) {
            this->reportFinished();
            return;
        }
        try {
            this->runFunctor();
        } catch (QException &e) {
            QFutureInterface<void>::reportException(e);
        } catch (...) {
            QFutureInterface<void>::reportException(QUnhandledException());
        }
        this->reportFinished();
    }
};

} //namespace QtConcurrent

#endif //Q_QDOC

QT_END_NAMESPACE

#endif // QT_NO_CONCURRENT

#endif
