#ifndef QFUTUREINTERFACE_H
#define QFUTUREINTERFACE_H

#include <QtCore/qrunnable.h>

#ifndef QT_NO_QFUTURE

#include <QtCore/qmutex.h>
#include <QtCore/qexception.h>
#include <QtCore/qresultstore.h>

QT_BEGIN_NAMESPACE


template <typename T> class QFuture;
class QThreadPool;
class QFutureInterfaceBasePrivate;
class QFutureWatcherBase;
class QFutureWatcherBasePrivate;

class Q_CORE_EXPORT QFutureInterfaceBase
{
public:
    enum State {
        NoState   = 0x00,
        Running   = 0x01,
        Started   = 0x02,
        Finished  = 0x04,
        Canceled  = 0x08,
        Paused    = 0x10,
        Throttled = 0x20
    };

    QFutureInterfaceBase(State initialState = NoState);
    QFutureInterfaceBase(const QFutureInterfaceBase &other);
    virtual ~QFutureInterfaceBase();

    // reporting functions available to the engine author:
    void reportStarted();
    void reportFinished();
    void reportCanceled();
    void reportResultsReady(int beginIndex, int endIndex);

    void setRunnable(QRunnable *runnable);
    void setThreadPool(QThreadPool *pool);
    void setFilterMode(bool enable);
    void setProgressRange(int minimum, int maximum);
    int progressMinimum() const;
    int progressMaximum() const;
    bool isProgressUpdateNeeded() const;
    void setProgressValue(int progressValue);
    int progressValue() const;
    void setProgressValueAndText(int progressValue, const QString &progressText);
    QString progressText() const;

    void setExpectedResultCount(int resultCount);
    int expectedResultCount();
    int resultCount() const;

    bool queryState(State state) const;
    bool isRunning() const;
    bool isStarted() const;
    bool isCanceled() const;
    bool isFinished() const;
    bool isPaused() const;
    bool isThrottled() const;
    bool isResultReadyAt(int index) const;

    void cancel();
    void setPaused(bool paused);
    void togglePaused();
    void setThrottled(bool enable);

    void waitForFinished();
    bool waitForNextResult();
    void waitForResult(int resultIndex);
    void waitForResume();

    QMutex *mutex() const;
    QtPrivate::ExceptionStore &exceptionStore();
    QtPrivate::ResultStoreBase &resultStoreBase();
    const QtPrivate::ResultStoreBase &resultStoreBase() const;

    inline bool operator==(const QFutureInterfaceBase &other) const { return d == other.d; }
    inline bool operator!=(const QFutureInterfaceBase &other) const { return d != other.d; }
    QFutureInterfaceBase &operator=(const QFutureInterfaceBase &other);

protected:
    bool refT() const;
    bool derefT() const;
public:

private:
    QFutureInterfaceBasePrivate *d;

private:
    friend class QFutureWatcherBase;
    friend class QFutureWatcherBasePrivate;
};


// 这个类, 是 Future 的真正实现.
template <typename T>
class QFutureInterface : public QFutureInterfaceBase
{
public:
    QFutureInterface(State initialState = NoState)
        : QFutureInterfaceBase(initialState)
    {
        refT();
    }
    QFutureInterface(const QFutureInterface &other)
        : QFutureInterfaceBase(other)
    {
        refT();
    }
    ~QFutureInterface()
    {
        if (!derefT())
            resultStoreBase().template clear<T>();
    }

    static QFutureInterface canceledResult()
    { return QFutureInterface(State(Started | Finished | Canceled)); }

    QFutureInterface &operator=(const QFutureInterface &other)
    {
        other.refT();
        if (!derefT())
            resultStoreBase().template clear<T>();
        QFutureInterfaceBase::operator=(other);
        return *this;
    }

    inline QFuture<T> future(); // implemented in qfuture.h

    // reportResult 是 Template 方法的一环, 是给 Future 的使用者调用的.
    // 在子线程里面, 进行大量的计算工作, 然后将结果使用 reportResult 存放到 Future 的内部.
    // 本质上, 这是一个存值的过程, 在这个存值之后, 会调用 reportResultsReady 方法, 而这个方法, 会进行线程之间的唤醒工作.
    inline void reportResult(const T *result, int index = -1);
    inline void reportResult(const T &result, int index = -1);
    inline void reportResults(const QVector<T> &results, int beginIndex = -1, int count = -1);
    inline void reportFinished(const T *result = 0);

    inline const T &resultReference(int index) const;
    inline const T *resultPointer(int index) const;
    inline QList<T> results();
};

// 把数据, 存到一个位置上. 因为存的是指针, 也就没有了 拷贝构造的调用.
template <typename T>
inline void QFutureInterface<T>::reportResult(const T *result, int index)
{
    QMutexLocker locker(mutex());
    if (this->queryState(Canceled) || this->queryState(Finished)) {
        return;
    }

    // 将传递过来的 Result, 存储到一个区域里面. 然后进行线程间的唤醒工作.
    QtPrivate::ResultStoreBase &store = resultStoreBase();
    if (store.filterMode()) {
        const int resultCountBefore = store.count();
        store.addResult<T>(index, result);
        this->reportResultsReady(resultCountBefore, resultCountBefore + store.count());
    } else {
        const int insertIndex = store.addResult<T>(index, result);
        this->reportResultsReady(insertIndex, insertIndex + 1);
    }
}

template <typename T>
inline void QFutureInterface<T>::reportResult(const T &result, int index)
{
    reportResult(&result, index);
}

template <typename T>
inline void QFutureInterface<T>::reportResults(const QVector<T> &_results, int beginIndex, int count)
{
    QMutexLocker locker(mutex());
    if (this->queryState(Canceled) || this->queryState(Finished)) {
        return;
    }

    auto &store = resultStoreBase();

    if (store.filterMode()) {
        const int resultCountBefore = store.count();
        store.addResults(beginIndex, &_results, count);
        this->reportResultsReady(resultCountBefore, store.count());
    } else {
        const int insertIndex = store.addResults(beginIndex, &_results, count);
        this->reportResultsReady(insertIndex, insertIndex + _results.count());
    }
}

template <typename T>
inline void QFutureInterface<T>::reportFinished(const T *result)
{
    if (result)
        reportResult(result);
    QFutureInterfaceBase::reportFinished();
}

template <typename T>
inline const T &QFutureInterface<T>::resultReference(int index) const
{
    QMutexLocker lock(mutex());
    return resultStoreBase().resultAt(index).template value<T>();
}

template <typename T>
inline const T *QFutureInterface<T>::resultPointer(int index) const
{
    QMutexLocker lock(mutex());
    return resultStoreBase().resultAt(index).template pointer<T>();
}

template <typename T>
inline QList<T> QFutureInterface<T>::results()
{
    if (this->isCanceled()) {
        exceptionStore().throwPossibleException();
        return QList<T>();
    }
    QFutureInterfaceBase::waitForResult(-1);

    QList<T> res;
    QMutexLocker lock(mutex());

    QtPrivate::ResultIteratorBase it = resultStoreBase().begin();
    while (it != resultStoreBase().end()) {
        res.append(it.value<T>());
        ++it;
    }

    return res;
}

template <>
class QFutureInterface<void> : public QFutureInterfaceBase
{
public:
    explicit QFutureInterface<void>(State initialState = NoState)
        : QFutureInterfaceBase(initialState)
    { }

    static QFutureInterface<void> canceledResult()
    { return QFutureInterface(State(Started | Finished | Canceled)); }


    inline QFuture<void> future(); // implemented in qfuture.h

    void reportResult(const void *, int) { }
    void reportResults(const QVector<void> &, int) { }
    void reportFinished(const void * = Q_NULLPTR) { QFutureInterfaceBase::reportFinished(); }
};

QT_END_NAMESPACE
#endif // QT_NO_QFUTURE

#endif // QFUTUREINTERFACE_H
