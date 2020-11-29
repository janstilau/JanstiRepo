#include "qsemaphore.h"

#ifndef QT_NO_THREAD
#include "qmutex.h"
#include "qwaitcondition.h"
#include "qdeadlinetimer.h"
#include "qdatetime.h"

QT_BEGIN_NAMESPACE

class QSemaphorePrivate {
public:
    inline QSemaphorePrivate(int n) : avail(n) { }

    QMutex mutex;
    QWaitCondition cond;

    int avail;
};

QSemaphore::QSemaphore(int n)
{
    Q_ASSERT_X(n >= 0, "QSemaphore", "parameter 'n' must be non-negative");
    d = new QSemaphorePrivate(n);
}

QSemaphore::~QSemaphore()
{ delete d; }

void QSemaphore::acquire(int n)
{
    Q_ASSERT_X(n >= 0, "QSemaphore::acquire", "parameter 'n' must be non-negative");
    QMutexLocker locker(&d->mutex);
    while (n > d->avail)
        d->cond.wait(locker.mutex());
    d->avail -= n;
}

void QSemaphore::release(int n)
{
    Q_ASSERT_X(n >= 0, "QSemaphore::release", "parameter 'n' must be non-negative");
    QMutexLocker locker(&d->mutex);
    d->avail += n;
    d->cond.wakeAll();
}


int QSemaphore::available() const
{
    QMutexLocker locker(&d->mutex);
    return d->avail;
}

bool QSemaphore::tryAcquire(int n)
{
    Q_ASSERT_X(n >= 0, "QSemaphore::tryAcquire", "parameter 'n' must be non-negative");
    QMutexLocker locker(&d->mutex);
    if (n > d->avail)
        return false;
    d->avail -= n;
    return true;
}

bool QSemaphore::tryAcquire(int n, int timeout)
{
    Q_ASSERT_X(n >= 0, "QSemaphore::tryAcquire", "parameter 'n' must be non-negative");

    // We're documented to accept any negative value as "forever"
    // but QDeadlineTimer only accepts -1.
    timeout = qMax(timeout, -1);

    QDeadlineTimer timer(timeout);
    QMutexLocker locker(&d->mutex);
    qint64 remainingTime = timer.remainingTime();
    while (n > d->avail && remainingTime != 0) {
        if (!d->cond.wait(locker.mutex(), remainingTime))
            return false;
        remainingTime = timer.remainingTime();
    }
    if (n > d->avail)
        return false;
    d->avail -= n;
    return true;


}

QT_END_NAMESPACE

#endif // QT_NO_THREAD
