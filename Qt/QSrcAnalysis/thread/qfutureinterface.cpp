// qfutureinterface.h included from qfuture.h
#include "qfuture.h"

#ifndef QT_NO_QFUTURE

#include "qfutureinterface_p.h"

#include <QtCore/qatomic.h>
#include <QtCore/qthread.h>
#include <private/qthreadpool_p.h>

QT_BEGIN_NAMESPACE

enum {
    MaxProgressEmitsPerSecond = 25
};

namespace {
class ThreadPoolThreadReleaser {
    QThreadPool *m_pool;
public:
    explicit ThreadPoolThreadReleaser(QThreadPool *pool)
        : m_pool(pool)
    { if (pool) pool->releaseThread(); }
    ~ThreadPoolThreadReleaser()
    { if (m_pool) m_pool->reserveThread(); }
};
} // unnamed namespace


QFutureInterfaceBase::QFutureInterfaceBase(State initialState)
    : d(new QFutureInterfaceBasePrivate(initialState))
{ }

// 这里, 直接是进行引用计数的控制.
// Future 的数据部分是 QFutureInterface, 传递的时候会有复制
// QFutureInterface 的数据部分是 QFutureInterfaceBasePrivate*, 复制的时候, 是引用计数的管理
// 所以, 最终 Future 管理的, 其实是一份数据.
QFutureInterfaceBase::QFutureInterfaceBase(const QFutureInterfaceBase &other)
    : d(other.d)
{
    d->refCount.ref();
}

QFutureInterfaceBase::~QFutureInterfaceBase()
{
    if (!d->refCount.deref())
        delete d;
}

static inline int switch_on(QAtomicInt &a, int which)
{
    return a.fetchAndOrRelaxed(which) | which;
}

static inline int switch_off(QAtomicInt &a, int which)
{
    return a.fetchAndAndRelaxed(~which) & ~which;
}

static inline int switch_from_to(QAtomicInt &a, int from, int to)
{
    int newValue;
    int expected = a.load();
    do {
        newValue = (expected & ~from) | to;
    } while (!a.testAndSetRelaxed(expected, newValue, expected));
    return newValue;
}

void QFutureInterfaceBase::cancel()
{
    QMutexLocker locker(&d->m_mutex);
    if (d->state.load() & Canceled)
        return;

    switch_from_to(d->state, Paused, Canceled);
    d->waitCondition.wakeAll();
    d->pausedWaitCondition.wakeAll();
    d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Canceled));
}

void QFutureInterfaceBase::setPaused(bool paused)
{
    QMutexLocker locker(&d->m_mutex);
    if (paused) {
        switch_on(d->state, Paused);
        d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Paused));
    } else {
        switch_off(d->state, Paused);
        d->pausedWaitCondition.wakeAll();
        d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Resumed));
    }
}

void QFutureInterfaceBase::togglePaused()
{
    QMutexLocker locker(&d->m_mutex);
    if (d->state.load() & Paused) {
        switch_off(d->state, Paused);
        d->pausedWaitCondition.wakeAll();
        d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Resumed));
    } else {
        switch_on(d->state, Paused);
        d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Paused));
    }
}

void QFutureInterfaceBase::setThrottled(bool enable)
{
    QMutexLocker lock(&d->m_mutex);
    if (enable) {
        switch_on(d->state, Throttled);
    } else {
        switch_off(d->state, Throttled);
        if (!(d->state.load() & Paused))
            d->pausedWaitCondition.wakeAll();
    }
}


// 虽然, 各个状态就是 bit 位的验证, 但专门的写出对应的方法来, 让代码更加的清晰.
bool QFutureInterfaceBase::isRunning() const
{
    return queryState(Running);
}

bool QFutureInterfaceBase::isStarted() const
{
    return queryState(Started);
}

bool QFutureInterfaceBase::isCanceled() const
{
    return queryState(Canceled);
}

bool QFutureInterfaceBase::isFinished() const
{
    return queryState(Finished);
}

bool QFutureInterfaceBase::isPaused() const
{
    return queryState(Paused);
}

bool QFutureInterfaceBase::isThrottled() const
{
    return queryState(Throttled);
}

// 这个类, 就是做线程间的同步的, 所以一定是线程安全的.
bool QFutureInterfaceBase::isResultReadyAt(int index) const
{
    QMutexLocker lock(&d->m_mutex);
    return d->internal_isResultReadyAt(index);
}

bool QFutureInterfaceBase::waitForNextResult()
{
    QMutexLocker lock(&d->m_mutex);
    return d->internal_waitForNextResult();
}

void QFutureInterfaceBase::waitForResume()
{
    // return early if possible to avoid taking the mutex lock.
    {
        const int state = d->state.load();
        if (!(state & Paused) || (state & Canceled))
            return;
    }

    QMutexLocker lock(&d->m_mutex);
    const int state = d->state.load();
    if (!(state & Paused) || (state & Canceled))
        return;

    // decrease active thread count since this thread will wait.
    const ThreadPoolThreadReleaser releaser(d->pool());

    d->pausedWaitCondition.wait(&d->m_mutex);
}

int QFutureInterfaceBase::progressValue() const
{
    const QMutexLocker lock(&d->m_mutex);
    return d->m_progressValue;
}

int QFutureInterfaceBase::progressMinimum() const
{
    const QMutexLocker lock(&d->m_mutex);
    return d->m_progressMinimum;
}

int QFutureInterfaceBase::progressMaximum() const
{
    const QMutexLocker lock(&d->m_mutex);
    return d->m_progressMaximum;
}

int QFutureInterfaceBase::resultCount() const
{
    QMutexLocker lock(&d->m_mutex);
    return d->internal_resultCount();
}

QString QFutureInterfaceBase::progressText() const
{
    QMutexLocker locker(&d->m_mutex);
    return d->m_progressText;
}

bool QFutureInterfaceBase::isProgressUpdateNeeded() const
{
    QMutexLocker locker(&d->m_mutex);
    return !d->progressTime.isValid() || (d->progressTime.elapsed() > (1000 / MaxProgressEmitsPerSecond));
}

// 这里, report 主要是对 Future 的监听者的. 也就是 sendCallOut 相关逻辑.
// 在这个函数里面, 会改变 state 到 start.
// start, 和 report 两个动作, 在这个函数里面归到一块去了.
void QFutureInterfaceBase::reportStarted()
{
    QMutexLocker locker(&d->m_mutex);
    if (d->state.load() & (Started|Canceled|Finished))
        return;

    d->setState(State(Started | Running));
    d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Started));
}

void QFutureInterfaceBase::reportCanceled()
{
    cancel();
}

// 这也是模板方法里面的一环, 是外界主动在异步程序完成之后, 主动调用的.
void QFutureInterfaceBase::reportFinished()
{
    QMutexLocker locker(&d->m_mutex);
    if (!isFinished()) {
        switch_from_to(d->state, Running, Finished);
        d->waitCondition.wakeAll();
        d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Finished));
    }
}

void QFutureInterfaceBase::setExpectedResultCount(int resultCount)
{
    if (d->manualProgress == false)
        setProgressRange(0, resultCount);
    d->m_expectedResultCount = resultCount;
}

int QFutureInterfaceBase::expectedResultCount()
{
    return d->m_expectedResultCount;
}

bool QFutureInterfaceBase::queryState(State state) const
{
    return d->state.load() & state;
}

void QFutureInterfaceBase::waitForResult(int resultIndex)
{
    QMutexLocker lock(&d->m_mutex);
    if (!isRunning()) return;
    lock.unlock();

    // 这个函数, 其实就是 pool 里面, 启动 d->runnable 对应的可执行任务.
    // 这个函数, 会使得相应的任务脱离原有的队列, 尽早运行.
    // pool 里面, 会做数据局的管理, 不会一直重复运行 d->runnable
    d->pool()->d_func()->stealAndRunRunnable(d->runnable);

    lock.relock();


    // 所以, future 其实就是, 当发现还没有结果的时候, 进行 wait 而已.
    const int waitIndex = (resultIndex == -1) ? INT_MAX : resultIndex;
    while (isRunning() && !d->internal_isResultReadyAt(waitIndex)) {
        d->waitCondition.wait(&d->m_mutex);
    }
}

void QFutureInterfaceBase::waitForFinished()
{
    QMutexLocker lock(&d->m_mutex);
    const bool alreadyFinished = !isRunning();
    lock.unlock();

    if (!alreadyFinished) {
        d->pool()->d_func()->stealAndRunRunnable(d->runnable);

        lock.relock();

        // 和 waitForResult 没有太大的区别, 只不过 wait 的判断条件, 从判断 Index, 变为了对于状态的判断.
        while (isRunning()) {
            d->waitCondition.wait(&d->m_mutex);
        }
    }
}

// 唤醒工作,
void QFutureInterfaceBase::reportResultsReady(int beginIndex, int endIndex)
{
    if (beginIndex == endIndex || (d->state.load() & (Canceled|Finished)))
        return;
    // 其实就是最简单的 wake 操作而已.
    d->waitCondition.wakeAll();

    // 后面的逻辑, 是 Future 的 Event监听机制. 不是这个类的核心.
    if (d->manualProgress == false) {
        if (d->internal_updateProgress(d->m_progressValue + endIndex - beginIndex) == false) {
            d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::ResultsReady,
                                               beginIndex,
                                               endIndex));
            return;
        }

        d->sendCallOuts(QFutureCallOutEvent(QFutureCallOutEvent::Progress,
                                            d->m_progressValue,
                                            d->m_progressText),
                        QFutureCallOutEvent(QFutureCallOutEvent::ResultsReady,
                                            beginIndex,
                                            endIndex));
        return;
    }
    d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::ResultsReady, beginIndex, endIndex));
}

void QFutureInterfaceBase::setRunnable(QRunnable *runnable)
{
    d->runnable = runnable;
}

// 记录一下 ThreadPool. 也就是 runnabel 的调度对象. 默认是 globalInstance.
void QFutureInterfaceBase::setThreadPool(QThreadPool *pool)
{
    d->m_pool = pool;
}

void QFutureInterfaceBase::setFilterMode(bool enable)
{
    QMutexLocker locker(&d->m_mutex);
    resultStoreBase().setFilterMode(enable);
}

void QFutureInterfaceBase::setProgressRange(int minimum, int maximum)
{
    QMutexLocker locker(&d->m_mutex);
    d->m_progressMinimum = minimum;
    d->m_progressMaximum = maximum;
    d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::ProgressRange, minimum, maximum));
}

void QFutureInterfaceBase::setProgressValue(int progressValue)
{
    setProgressValueAndText(progressValue, QString());
}

void QFutureInterfaceBase::setProgressValueAndText(int progressValue,
                                                   const QString &progressText)
{
    QMutexLocker locker(&d->m_mutex);
    if (d->manualProgress == false)
        d->manualProgress = true;
    if (d->m_progressValue >= progressValue)
        return;

    if (d->state.load() & (Canceled|Finished))
        return;

    if (d->internal_updateProgress(progressValue, progressText)) {
        d->sendCallOut(QFutureCallOutEvent(QFutureCallOutEvent::Progress,
                                           d->m_progressValue,
                                           d->m_progressText));
    }
}

QMutex *QFutureInterfaceBase::mutex() const
{
    return &d->m_mutex;
}

QtPrivate::ExceptionStore &QFutureInterfaceBase::exceptionStore()
{
    return d->m_exceptionStore;
}

QtPrivate::ResultStoreBase &QFutureInterfaceBase::resultStoreBase()
{
    return d->m_results;
}

const QtPrivate::ResultStoreBase &QFutureInterfaceBase::resultStoreBase() const
{
    return d->m_results;
}

QFutureInterfaceBase &QFutureInterfaceBase::operator=(const QFutureInterfaceBase &other)
{
    other.d->refCount.ref();
    if (!d->refCount.deref())
        delete d;
    d = other.d;
    return *this;
}

bool QFutureInterfaceBase::refT() const
{
    return d->refCount.refT();
}

bool QFutureInterfaceBase::derefT() const
{
    return d->refCount.derefT();
}

QFutureInterfaceBasePrivate::QFutureInterfaceBasePrivate(QFutureInterfaceBase::State initialState)
    : refCount(1), m_progressValue(0), m_progressMinimum(0), m_progressMaximum(0),
      state(initialState),
      manualProgress(false), m_expectedResultCount(0), runnable(0), m_pool(0)
{
    progressTime.invalidate();
}

int QFutureInterfaceBasePrivate::internal_resultCount() const
{
    return m_results.count(); // ### subtract canceled results.
}

// 询问 Index 位置的数据, 是否已经存在, 就是简单的查询下内存区域
bool QFutureInterfaceBasePrivate::internal_isResultReadyAt(int index) const
{
    return (m_results.contains(index));
}

bool QFutureInterfaceBasePrivate::internal_waitForNextResult()
{
    if (m_results.hasNextResult())
        return true;

    while ((state.load() & QFutureInterfaceBase::Running) && m_results.hasNextResult() == false)
        waitCondition.wait(&m_mutex);

    return !(state.load() & QFutureInterfaceBase::Canceled) && m_results.hasNextResult();
}

bool QFutureInterfaceBasePrivate::internal_updateProgress(int progress,
                                                          const QString &progressText)
{
    if (m_progressValue >= progress)
        return false;

    m_progressValue = progress;
    m_progressText = progressText;

    if (progressTime.isValid() && m_progressValue != m_progressMaximum) // make sure the first and last steps are emitted.
        if (progressTime.elapsed() < (1000 / MaxProgressEmitsPerSecond))
            return false;

    progressTime.start();
    return true;
}

void QFutureInterfaceBasePrivate::internal_setThrottled(bool enable)
{
    // bail out if we are not changing the state
    if ((enable && (state.load() & QFutureInterfaceBase::Throttled))
        || (!enable && !(state.load() & QFutureInterfaceBase::Throttled)))
        return;

    // change the state
    if (enable) {
        switch_on(state, QFutureInterfaceBase::Throttled);
    } else {
        switch_off(state, QFutureInterfaceBase::Throttled);
        if (!(state.load() & QFutureInterfaceBase::Paused))
            pausedWaitCondition.wakeAll();
    }
}

void QFutureInterfaceBasePrivate::sendCallOut(const QFutureCallOutEvent &callOutEvent)
{
    if (outputConnections.isEmpty())
        return;

    for (int i = 0; i < outputConnections.count(); ++i)
        outputConnections.at(i)->postCallOutEvent(callOutEvent);
}

void QFutureInterfaceBasePrivate::sendCallOuts(const QFutureCallOutEvent &callOutEvent1,
                                     const QFutureCallOutEvent &callOutEvent2)
{
    if (outputConnections.isEmpty())
        return;

    for (int i = 0; i < outputConnections.count(); ++i) {
        QFutureCallOutInterface *interface = outputConnections.at(i);
        interface->postCallOutEvent(callOutEvent1);
        interface->postCallOutEvent(callOutEvent2);
    }
}

// This function connects an output interface (for example a QFutureWatcher)
// to this future. While holding the lock we check the state and ready results
// and add the appropriate callouts to the queue. In order to avoid deadlocks,
// the actual callouts are made at the end while not holding the lock.
void QFutureInterfaceBasePrivate::connectOutputInterface(QFutureCallOutInterface *interface)
{
    QMutexLocker locker(&m_mutex);

    if (state.load() & QFutureInterfaceBase::Started) {
        interface->postCallOutEvent(QFutureCallOutEvent(QFutureCallOutEvent::Started));
        interface->postCallOutEvent(QFutureCallOutEvent(QFutureCallOutEvent::ProgressRange,
                                                        m_progressMinimum,
                                                        m_progressMaximum));
        interface->postCallOutEvent(QFutureCallOutEvent(QFutureCallOutEvent::Progress,
                                                        m_progressValue,
                                                        m_progressText));
    }

    QtPrivate::ResultIteratorBase it = m_results.begin();
    while (it != m_results.end()) {
        const int begin = it.resultIndex();
        const int end = begin + it.batchSize();
        interface->postCallOutEvent(QFutureCallOutEvent(QFutureCallOutEvent::ResultsReady,
                                                        begin,
                                                        end));
        it.batchedAdvance();
    }

    if (state.load() & QFutureInterfaceBase::Paused)
        interface->postCallOutEvent(QFutureCallOutEvent(QFutureCallOutEvent::Paused));

    if (state.load() & QFutureInterfaceBase::Canceled)
        interface->postCallOutEvent(QFutureCallOutEvent(QFutureCallOutEvent::Canceled));

    if (state.load() & QFutureInterfaceBase::Finished)
        interface->postCallOutEvent(QFutureCallOutEvent(QFutureCallOutEvent::Finished));

    outputConnections.append(interface);
}

void QFutureInterfaceBasePrivate::disconnectOutputInterface(QFutureCallOutInterface *interface)
{
    QMutexLocker lock(&m_mutex);
    const int index = outputConnections.indexOf(interface);
    if (index == -1)
        return;
    outputConnections.removeAt(index);

    interface->callOutInterfaceDisconnected();
}

void QFutureInterfaceBasePrivate::setState(QFutureInterfaceBase::State newState)
{
    state.store(newState);
}

QT_END_NAMESPACE

#endif // QT_NO_QFUTURE
