#ifndef QTHREADPOOL_P_H
#define QTHREADPOOL_P_H

#include "QtCore/qmutex.h"
#include "QtCore/qwaitcondition.h"
#include "QtCore/qset.h"
#include "QtCore/qqueue.h"
#include "private/qobject_p.h"

#ifndef QT_NO_THREAD

QT_BEGIN_NAMESPACE

// 这个类很好, 解决了频繁插入的问题了.
// 有点类似于桶排序, QueuePage 是一个大桶, 进行 priority 的排序, 然后桶内是按照时间进行排序.
// 在插入数据的时候, 遍历整个队列, 变为了遍历几个桶, 效率大大提高.
// QueuePage 的设计很简单, 就是一个固定长度的数组.
class QueuePage {
public:
    // 这种, 类内定义常量的方式.
    enum {
        MaxPageSize = 256
    };

    QueuePage(QRunnable *runnable, int pri)
        : m_priority(pri)
    {
        push(runnable);
    }

    // 使用良好的命名, 来封装实现的细节.
    bool isFull() {
        return m_lastIndex >= MaxPageSize - 1;
    }

    bool isFinished() {
        return m_firstIndex > m_lastIndex;
    }

    // 固定大小的好处就在于, 根本不用考虑目标位置的数据, 可不可用.
    void push(QRunnable *runnable) {
        m_lastIndex += 1;
        m_entries[m_lastIndex] = runnable;
    }

    void skipToNextOrEnd() {
        while (!isFinished() && m_entries[m_firstIndex] == nullptr) {
            m_firstIndex += 1;
        }
    }

    QRunnable *first() {
        QRunnable *runnable = m_entries[m_firstIndex];
        return runnable;
    }

    QRunnable *pop() {
        QRunnable *runnable = first();

        // clear the entry although this should not be necessary
        m_entries[m_firstIndex] = nullptr;
        m_firstIndex += 1;

        // make sure the next runnable returned by first() is not a nullptr
        skipToNextOrEnd();

        return runnable;
    }

    bool tryTake(QRunnable *runnable) {
        Q_ASSERT(!isFinished());
        for (int i = m_firstIndex; i <= m_lastIndex; i++) {
            if (m_entries[i] == runnable) {
                m_entries[i] = nullptr;
                if (i == m_firstIndex) {
                    // make sure first() does not return a nullptr
                    skipToNextOrEnd();
                }
                return true;
            }
        }
        return false;
    }

    int priority() const {
        return m_priority;
    }

private:
    int m_priority = 0;
    // 作为一个类, 里面的数据处于正确的状态, 是类的设计者的责任.
    int m_firstIndex = 0;
    int m_lastIndex = -1;
    QRunnable *m_entries[MaxPageSize]; // 在类创建的时候, 整个就存在了. 所以, 整个类的大小是固定的, 没有动态开辟的开销.
};

class QThreadPoolThread;
class Q_CORE_EXPORT QThreadPoolPrivate : public QObjectPrivate
{
    Q_DECLARE_PUBLIC(QThreadPool)
    friend class QThreadPoolThread;

public:
    QThreadPoolPrivate();

    bool tryStart(QRunnable *task);
    void enqueueTask(QRunnable *task, int priority = 0);
    int activeThreadCount() const;

    void tryToStartMoreThreads();
    bool tooManyThreadsActive() const;

    void startThread(QRunnable *runnable = 0);
    void reset();
    bool waitForDone(int msecs);
    void clear();
    void stealAndRunRunnable(QRunnable *runnable);
    void deletePageIfFinished(QueuePage *page);

    mutable QMutex mutex;
    QWaitCondition waitForAllThreadEixt; // 这个 condition, 是在线程退出的时候 wake 的.
    QList<QThreadPoolThread *> allThreads; //没见过删除啊.
    QQueue<QThreadPoolThread *> waitingThreads;
    QQueue<QThreadPoolThread *> expiredThreads;
    QVector<QueuePage*> queue; // taskqueue.

    bool isExiting;
    int expiryTimeout; // wait 时间.
    int maxThreadCount;
    int reservedThreads;
    int activeThreads;
};

QT_END_NAMESPACE

#endif // QT_NO_THREAD
#endif
