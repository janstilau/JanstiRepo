#ifndef QFUTUREINTERFACE_P_H
#define QFUTUREINTERFACE_P_H


#include <QtCore/private/qglobal_p.h>
#include <QtCore/qelapsedtimer.h>
#include <QtCore/qcoreevent.h>
#include <QtCore/qlist.h>
#include <QtCore/qwaitcondition.h>
#include <QtCore/qrunnable.h>
#include <QtCore/qthreadpool.h>

QT_BEGIN_NAMESPACE

class QFutureCallOutEvent : public QEvent
{
public:
    enum CallOutType {
        Started,
        Finished,
        Canceled,
        Paused,
        Resumed,
        Progress,
        ProgressRange,
        ResultsReady
    };

    QFutureCallOutEvent()
        : QEvent(QEvent::FutureCallOut), callOutType(CallOutType(0)), index1(-1), index2(-1)
    { }
    explicit QFutureCallOutEvent(CallOutType callOutType, int index1 = -1)
        : QEvent(QEvent::FutureCallOut), callOutType(callOutType), index1(index1), index2(-1)
    { }
    QFutureCallOutEvent(CallOutType callOutType, int index1, int index2)
        : QEvent(QEvent::FutureCallOut), callOutType(callOutType), index1(index1), index2(index2)
    { }

    QFutureCallOutEvent(CallOutType callOutType, int index1, const QString &text)
        : QEvent(QEvent::FutureCallOut),
          callOutType(callOutType),
          index1(index1),
          index2(-1),
          text(text)
    { }

    CallOutType callOutType;
    int index1;
    int index2;
    QString text;

    // 专门有 clone, 作为拷贝作用.
    QFutureCallOutEvent *clone() const
    {
        return new QFutureCallOutEvent(callOutType, index1, index2, text);
    }

private:
    QFutureCallOutEvent(CallOutType callOutType,
                        int index1,
                        int index2,
                        const QString &text)
        : QEvent(QEvent::FutureCallOut),
          callOutType(callOutType),
          index1(index1),
          index2(index2),
          text(text)
    { }
};

class QFutureCallOutInterface
{
public:
    virtual ~QFutureCallOutInterface() {}
    virtual void postCallOutEvent(const QFutureCallOutEvent &) = 0;
    virtual void callOutInterfaceDisconnected() = 0;
};

class QFutureInterfaceBasePrivate
{
public:
    QFutureInterfaceBasePrivate(QFutureInterfaceBase::State initialState);

    // When the last QFuture<T> reference is removed, we need to make
    // sure that data stored in the ResultStore is cleaned out.
    // Since QFutureInterfaceBasePrivate can be shared between QFuture<T>
    // and QFuture<void> objects, we use a separate ref. counter
    // to keep track of QFuture<T> objects.
    class RefCount
    {
    public:
        inline RefCount(int r = 0, int rt = 0)
            : m_refCount(r), m_refCountT(rt) {}

        // Default ref counter for QFIBP
        // 在 QFutureInterfaceBase 的构造函数, 析构函数, operator = 里面, 调用 ref(), deref()
        // 当 deref() == 0 的时候, 进行 delete QFutureInterfaceBasePrivate 的操作.
        // QFutureInterfaceBase 里面, 管理者 QFutureInterfaceBasePrivate 的指针, 所以这里的意思是,
        // QFutureInterfaceBase 充当 QFutureInterfaceBasePrivate 的引用计数管理器, 当引用计数没了, 也就是没有 QFutureInterfaceBase 了, 这个时候, 删除 QFutureInterfaceBasePrivate 的数据
        inline bool ref() { return m_refCount.ref(); }
        inline bool deref() { return m_refCount.deref(); }
        inline int load() const { return m_refCount.load(); }

        // Ref counter for type T
        // 这个会在 QFutureInterface 的构造函数, 析构函数, operator = 里面, 调用 refT(), derefT()
        // 当 derefT()  == 0 的时候, 会调用 ResultStoreBase.clear, 也就是清理 result 的值
        // 因为, QFutureInterface 才是外界使用的类, 所以在外界不需要 result 的数据结果的时候, 清理 ResultStoreBase 的内容.
        inline bool refT() { return m_refCountT.ref(); }
        inline bool derefT() { return m_refCountT.deref(); }
        inline int loadT() const { return m_refCountT.load(); }
    private:
        QAtomicInt m_refCount;
        QAtomicInt m_refCountT;
    };

    // T: accessed from executing thread
    // Q: accessed from the waiting/querying thread
    RefCount refCount;

    // 状态值.
    QAtomicInt state; // reads and writes can happen unprotected, both must be atomic
    // 这两个, 基本的线程之间同步的功能的实现者.
    mutable QMutex m_mutex;
    QWaitCondition waitCondition;
    // 这个是当主动调用任务暂停的时候, 控制任务暂停的.
    QWaitCondition pausedWaitCondition;

    // 对 future 感兴趣的对象, 实现 QFutureCallOutInterface 接口.
    QList<QFutureCallOutInterface *> outputConnections;
    // 进度, Qt 里面, 对于 Future 自己独特的实现.
    int m_progressValue; // TQ
    int m_progressMinimum; // TQ
    int m_progressMaximum; // TQ
    bool manualProgress; // only accessed from executing thread
    QString m_progressText;
    QElapsedTimer progressTime;

    // Result 数据的存储.
    // ResultStoreBase 的各种对于 result 的插入工作, 都有着对于参数的复制, 所以不同担心引用到非法地址.
    QtPrivate::ResultStoreBase m_results;
    QtPrivate::ExceptionStore m_exceptionStore;
    int m_expectedResultCount;

    QRunnable *runnable;
    QThreadPool *m_pool;

    inline QThreadPool *pool() const
    { return m_pool ? m_pool : QThreadPool::globalInstance(); }

    // Internal functions that does not change the mutex state.
    // The mutex must be locked when calling these.
    int internal_resultCount() const;
    bool internal_isResultReadyAt(int index) const;
    bool internal_waitForNextResult();
    bool internal_updateProgress(int progress, const QString &progressText = QString());
    void internal_setThrottled(bool enable);
    void sendCallOut(const QFutureCallOutEvent &callOut);
    void sendCallOuts(const QFutureCallOutEvent &callOut1, const QFutureCallOutEvent &callOut2);
    void connectOutputInterface(QFutureCallOutInterface *iface);
    void disconnectOutputInterface(QFutureCallOutInterface *iface);

    void setState(QFutureInterfaceBase::State state);
};

QT_END_NAMESPACE

#endif
