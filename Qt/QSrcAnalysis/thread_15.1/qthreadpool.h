#ifndef QTHREADPOOL_H
#define QTHREADPOOL_H

#include <QtCore/qglobal.h>

#include <QtCore/qthread.h>
#include <QtCore/qrunnable.h>

#include <functional>

QT_REQUIRE_CONFIG(thread);

QT_BEGIN_NAMESPACE


class QThreadPoolPrivate;
class Q_CORE_EXPORT QThreadPool : public QObject
{
    Q_OBJECT
    Q_DECLARE_PRIVATE(QThreadPool)
    Q_PROPERTY(int expiryTimeout READ expiryTimeout WRITE setExpiryTimeout)
    Q_PROPERTY(int maxThreadCount READ maxThreadCount WRITE setMaxThreadCount)
    Q_PROPERTY(int activeThreadCount READ activeThreadCount)
    Q_PROPERTY(uint stackSize READ stackSize WRITE setStackSize)
    friend class QFutureInterfaceBase;

public:
    QThreadPool(QObject *parent = nullptr);
    ~QThreadPool();

    static QThreadPool *globalInstance();

    void start(QRunnable *runnable, int priority = 0);
    bool tryStart(QRunnable *runnable);

    void start(std::function<void()> functionToRun, int priority = 0);
    bool tryStart(std::function<void()> functionToRun);

    int expiryTimeout() const;
    void setExpiryTimeout(int expiryTimeout);

    int maxThreadCount() const;
    void setMaxThreadCount(int maxThreadCount);

    int activeThreadCount() const;

    void setStackSize(uint stackSize);
    uint stackSize() const;

    void reserveThread();
    void releaseThread();

    bool waitForDone(int msecs = -1);

    void clear();

    bool contains(const QThread *thread) const;

#if QT_DEPRECATED_SINCE(5, 9)
    QT_DEPRECATED_X("use tryTake(), but note the different deletion rules")
    void cancel(QRunnable *runnable);
#endif
    Q_REQUIRED_RESULT bool tryTake(QRunnable *runnable);
};

QT_END_NAMESPACE

#endif
