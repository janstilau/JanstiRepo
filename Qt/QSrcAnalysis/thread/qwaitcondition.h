#ifndef QWAITCONDITION_H
#define QWAITCONDITION_H

#include <QtCore/qglobal.h>

#include <limits.h>

QT_BEGIN_NAMESPACE


class QWaitConditionPrivate;
class QMutex;
class QReadWriteLock;

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
