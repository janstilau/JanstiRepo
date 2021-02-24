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
    // 所以, 实际上, 就是把自己包装成任务对象, 扔到线程池里面. 重写里面的 runFactor, 去执行自己记录的各个可调用对象.
    QFuture<T> start()
    {
        return start(QThreadPool::globalInstance());
    }

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
    void run() override
    {
        if (this->isCanceled()) {
            this->reportFinished();
            return;
        }
        this->runFunctor();
        this->reportResult(result);
        this->reportFinished();
    }
    T result;
};

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
        this->runFunctor();
        this->reportFinished();
    }
};

} //namespace QtConcurrent

#endif //Q_QDOC

QT_END_NAMESPACE

#endif // QT_NO_CONCURRENT

#endif
