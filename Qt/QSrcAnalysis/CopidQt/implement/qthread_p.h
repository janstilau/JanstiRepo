#ifndef QTHREAD_P_H
#define QTHREAD_P_H

#include "qplatformdefs.h"
#include "QtCore/qthread.h"
#include "QtCore/qmutex.h"
#include "QtCore/qstack.h"
#include "QtCore/qwaitcondition.h"
#include "QtCore/qmap.h"
#include "QtCore/qcoreapplication.h"
#include "private/qobject_p.h"


QT_BEGIN_NAMESPACE

class QAbstractEventDispatcher;
class QEventLoop;

//! 对于每一个 postEvent, 在内部会直接记录下 receiver 和 对应的 event. 这样, 在可以执行的时候, 流程可以直接找到 receiver 调用对应的 event 方法
//! 这个类, 是定义在 Thread 的相关文件里面的, 类的使用如果有关联, 相关的文件应该聚合在一起.
class QPostEvent
{
public:
    QObject *receiver;
    QEvent *event;
    int priority;
    inline QPostEvent()
        : receiver(0),
          event(0),
          priority(0)
    { }
    inline QPostEvent(QObject *r, QEvent *e, int p)
        : receiver(r), event(e), priority(p)
    { }
};
Q_DECLARE_TYPEINFO(QPostEvent, Q_MOVABLE_TYPE);

//! C++ 的特性, 大量的操作符重载用来满足泛型算法.
inline bool operator<(const QPostEvent &first, const QPostEvent &second)
{
    return first.priority > second.priority;
}


class QPostEventList : public QVector<QPostEvent>
{
public:
    // recursion == recursion count for sendPostedEvents()
    int recursion;

    // sendOffset == the current event to start sending
    int startOffset;
    // insertionOffset == set by sendPostedEvents to tell postEvent() where to start insertions
    int insertionOffset;

    QMutex mutex;

    inline QPostEventList()
        : QVector<QPostEvent>(), recursion(0), startOffset(0), insertionOffset(0)
    { }

    // 在每次进行 event 插入的时候, 其实会根据 priority 的值, 进行合适的位置的插入的.
    void addEvent(const QPostEvent &ev) {
        int priority = ev.priority;
        if (isEmpty() ||
            constLast().priority >= priority ||
            insertionOffset >= size()) {
            // optimization: we can simply append if the last event in
            // the queue has higher or equal priority
            append(ev);
        } else {
            // insert event in descending priority order, using upper
            // bound for a given priority (to ensure proper ordering
            // of events with the same priority)
            // upper_bound 应该是用到了二分查找.
            QPostEventList::iterator at = std::upper_bound(begin() + insertionOffset, end(), ev);
            insert(at, ev);
        }
    }
private:
    //hides because they do not keep that list sorted. addEvent must be used
    using QVector<QPostEvent>::append;
    using QVector<QPostEvent>::insert;
};

#ifndef QT_NO_THREAD

// 这是数据类, 是 QThread 的成员变量保存的地方.
class QThreadPrivate : public QObjectPrivate
{
    Q_DECLARE_PUBLIC(QThread)

public:
    QThreadPrivate(QThreadData *d = 0);
    ~QThreadPrivate();

    void setPriority(QThread::Priority prio);

    static QThread *threadForId(int id);

#ifdef Q_OS_UNIX

    static void *start(void *arg);
    static void finish(void *);

#endif // Q_OS_UNIX

    static void createEventDispatcher(QThreadData *data);

    void ref()
    {
        quitLockRef.ref();
    }

    void deref()
    {
        if (!quitLockRef.deref() && running) {
            QCoreApplication::instance()->postEvent(q_ptr, new QEvent(QEvent::Quit));
        }
    }


    mutable QMutex mutex;
    QAtomicInt quitLockRef;

    bool running;
    bool finished;
    bool isInFinish; //when in QThreadPrivate::finish
    bool interruptionRequested;

    bool exited;
    int returnCode;

    uint stackSize;
    QThread::Priority priority;
    QWaitCondition thread_done;

    //! 以上的部分, 是经典的 Thread 概念, 都会保留的部分, QThreadData 则是 Qt 的环境下, Thread 应该处理的部分.
    QThreadData *data;
};

#endif // QT_NO_THREAD

class QThreadData
{
public:
    QThreadData(int initialRefCount = 1);
    ~QThreadData();

    static QThreadData *current(bool createIfNecessary = true);
    static void clearCurrentThreadData();
    static QThreadData *get2(QThread *thread)
    { Q_ASSERT_X(thread != 0, "QThread", "internal error"); return thread->d_func()->data; }


    void ref();
    void deref();
    inline bool hasEventDispatcher() const
    { return eventDispatcher.load() != 0; }

    bool canWaitLocked()
    {
        QMutexLocker locker(&postEventList.mutex);
        return canWait;
    }

    // This class provides per-thread (by way of being a QThreadData
    // member) storage for qFlagLocation()
    class FlaggedDebugSignatures
    {
        static const uint Count = 2;

        uint idx;
        const char* locations[Count];

    public:
        FlaggedDebugSignatures() : idx(0)
        { std::fill_n(locations, Count, static_cast<char*>(0)); }

        void store(const char* method)
        { locations[idx++ % Count] = method; }

        bool contains(const char *method) const
        { return std::find(locations, locations + Count, method) != locations + Count; }
    };

private:
    QAtomicInt _ref;

public:
    int loopLevel;
    int scopeLevel;

    QStack<QEventLoop *> eventLoops; // 一个线程里面, 可以有很多 eventLoop
    QPostEventList postEventList; // 每一个线程, 都会保存一下 postEvent 的列表, 这些事件, 将会在下一个事件循环处理.
    QAtomicPointer<QThread> thread;
    QAtomicPointer<void> threadId;
    QAtomicPointer<QAbstractEventDispatcher> eventDispatcher;
    QVector<void *> tls;
    FlaggedDebugSignatures flaggedSignatures;

    bool quitNow;
    bool canWait;
    bool isAdopted;
    bool requiresCoreApplication;
};

class QScopedScopeLevelCounter
{
    QThreadData *threadData;
public:
    inline QScopedScopeLevelCounter(QThreadData *threadData)
        : threadData(threadData)
    { ++threadData->scopeLevel; }
    inline ~QScopedScopeLevelCounter()
    { --threadData->scopeLevel; }
};

// thread wrapper for the main() thread
class QAdoptedThread : public QThread
{
    Q_DECLARE_PRIVATE(QThread)

public:
    QAdoptedThread(QThreadData *data = 0);
    ~QAdoptedThread();
    void init();

private:
    void run() Q_DECL_OVERRIDE;
};

QT_END_NAMESPACE

#endif // QTHREAD_P_H
