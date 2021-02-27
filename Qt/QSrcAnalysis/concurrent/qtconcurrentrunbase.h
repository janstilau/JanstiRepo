#ifndef QTCONCURRENT_RUNBASE_H
#define QTCONCURRENT_RUNBASE_H

#include <QtConcurrent/qtconcurrent_global.h>

#ifndef QT_NO_CONCURRENT

#include <QtCore/qfuture.h>
#include <QtCore/qrunnable.h>
#include <QtCore/qthreadpool.h>

QT_BEGIN_NAMESPACE


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
        this->setThreadPool(pool);
        this->setRunnable(this);
        this->reportStarted();
        QFuture<T> theFuture = this->future();
        pool->start(this, /*m_priority*/ 0);
        return theFuture;
    }

    void run() override {}
    virtual void runFunctor() = 0;
};

template <typename T>
class RunFunctionTask : public RunFunctionTaskBase<T>
{
public:
    // 模板方法, 在这里面, 有着对于 Future 的相关函数的调用.
    // 这里, 是对 QRunAble 的适配.
    void run() override
    {
        if (this->isCanceled()) {
            this->reportFinished();
            return;
        }
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
