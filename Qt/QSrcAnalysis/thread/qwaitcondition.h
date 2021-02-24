#ifndef QWAITCONDITION_H
#define QWAITCONDITION_H

#include <QtCore/qglobal.h>

#include <limits.h>

QT_BEGIN_NAMESPACE


class QWaitConditionPrivate;
class QMutex;
class QReadWriteLock;

// 对于 condition 的 Qt 版本的实现.
// Qt 的信号量, 是通过 QWaitCondition 实现的.
// 一般来说, 同步这个问题, 都可以通过 mutex 加 condition 实现.
// 这个类, 不同的平台, 都着各自的实现方案.
class Q_CORE_EXPORT QWaitCondition
{
public:
    QWaitCondition();
    ~QWaitCondition();

    bool wait(QMutex *lockedMutex, unsigned long time = ULONG_MAX);
    bool wait(QReadWriteLock *lockedReadWriteLock, unsigned long time = ULONG_MAX);

    void wakeOne();
    void wakeAll();

    void notify_one() { wakeOne(); }
    void notify_all() { wakeAll(); }

private:
    Q_DISABLE_COPY(QWaitCondition)

    QWaitConditionPrivate * d;
};

QT_END_NAMESPACE

#endif // QWAITCONDITION_H
